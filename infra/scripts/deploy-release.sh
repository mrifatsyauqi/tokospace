#!/usr/bin/env bash
#
# Runs ON the Google Compute Engine target host, invoked over SSH by
# .github/workflows/api-deploy.yml. Implements the release-folder + atomic
# symlink pattern from Tech Spec §7 — "current" only ever moves once the new
# release's migrations and cache warmup have actually succeeded, so a
# request never sees a half-deployed state and a failed migration never
# leaves "current" pointed at code that hasn't actually been prepared.
#
# Layout on the server:
#   $DEPLOY_ROOT/
#   ├── repo.git/                    (bare mirror clone — one-time setup, see infra/README.md)
#   ├── releases/{timestamp}/        (a `git worktree` checkout of repo.git)
#   ├── shared/apps-api.env          (persists across releases)
#   ├── shared/storage/              (persists across releases)
#   └── current -> releases/{timestamp}
#
# Usage: deploy-release.sh <deploy_root> <git_ref>

set -euo pipefail

DEPLOY_ROOT="${1:?deploy_root required}"
GIT_REF="${2:?git_ref required}"
KEEP_RELEASES=5

# ADR-0001: docker-compose.yml's `cloud-sql-proxy` service is gated behind
# the `production` Compose profile so a bare local `docker compose up` never
# tries to start it (there's no Cloud SQL instance for local dev to point
# at). Every `docker compose` invocation against this project in production
# — including this script and rollback.sh — needs the profile active, or
# Compose refuses the whole file with "depends on undefined service
# cloud-sql-proxy" (php/horizon/scheduler all depend on it).
export COMPOSE_PROFILES=production

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$DEPLOY_ROOT/releases/$TIMESTAMP"
IS_FIRST_DEPLOY=false
[ -e "$DEPLOY_ROOT/current" ] || IS_FIRST_DEPLOY=true

mkdir -p "$DEPLOY_ROOT/releases" "$DEPLOY_ROOT/shared/storage"

echo "==> Fetching $GIT_REF and checking out into $RELEASE_DIR"
git --git-dir="$DEPLOY_ROOT/repo.git" fetch --quiet origin "$GIT_REF"
git --git-dir="$DEPLOY_ROOT/repo.git" worktree add --quiet "$RELEASE_DIR" FETCH_HEAD

echo "==> Linking shared resources"
ln -sfn "$DEPLOY_ROOT/shared/apps-api.env" "$RELEASE_DIR/apps/api/.env"
rm -rf "$RELEASE_DIR/apps/api/storage"
ln -sfn "$DEPLOY_ROOT/shared/storage" "$RELEASE_DIR/apps/api/storage"

echo "==> Installing Composer dependencies (no-dev, optimized)"
(cd "$RELEASE_DIR/apps/api" && composer install --no-dev --optimize-autoloader --no-interaction)

# On a brand-new host nothing is running yet — "current" doesn't even exist,
# so there's no docker-compose.yml to `exec`/`restart` against. Use the new
# release's own compose file to bring up the data services this first time;
# every later deploy just no-ops here since they're already running.
COMPOSE_DIR="$DEPLOY_ROOT/current"
if [ "$IS_FIRST_DEPLOY" = true ]; then
  COMPOSE_DIR="$RELEASE_DIR"
fi
echo "==> Ensuring redis/cloud-sql-proxy are up"
(cd "$COMPOSE_DIR" && docker compose up -d redis cloud-sql-proxy)

echo "==> Running migrations and cache warmup against the NEW release (current not yet switched)"
# cloud-sql-proxy has no Docker healthcheck to wait on (ADR-0001 — the
# published image is distroless, no shell/CLI tooling to run a CMD-based
# probe against; see the comment on the service in docker-compose.yml), so
# unlike the old postgres `condition: service_healthy` gate, "up -d" above
# returns as soon as the container starts, not once it can actually reach
# Cloud SQL. Retry the first migration attempt (same 10x/3s pattern already
# used for the post-deploy health check below) to absorb that startup race
# instead of failing the whole deploy on a transient connection error.
migrate_attempt=0
until (cd "$COMPOSE_DIR" && docker compose run --rm --no-deps \
  -v "$RELEASE_DIR/apps/api:/var/www/html" \
  php php artisan migrate --force); do
  migrate_attempt=$((migrate_attempt + 1))
  if [ "$migrate_attempt" -ge 10 ]; then
    echo "::error::Migrations failed after ${migrate_attempt} attempts — is cloud-sql-proxy able to reach Cloud SQL?" >&2
    exit 1
  fi
  echo "==> Migration attempt ${migrate_attempt} failed, retrying in 3s..."
  sleep 3
done
(cd "$COMPOSE_DIR" && docker compose run --rm --no-deps \
  -v "$RELEASE_DIR/apps/api:/var/www/html" \
  php php artisan config:cache)
(cd "$COMPOSE_DIR" && docker compose run --rm --no-deps \
  -v "$RELEASE_DIR/apps/api:/var/www/html" \
  php php artisan route:cache)

echo "==> Migrations succeeded — flipping current -> releases/$TIMESTAMP"
ln -sfn "$RELEASE_DIR" "$DEPLOY_ROOT/current"

echo "==> Starting/recreating php, horizon, scheduler on the new release (nginx and data services stay up)"
(cd "$DEPLOY_ROOT/current" && docker compose up -d --force-recreate --no-deps php horizon scheduler)
(cd "$DEPLOY_ROOT/current" && docker compose up -d nginx)

echo "==> Pruning old releases (keeping last $KEEP_RELEASES)"
cd "$DEPLOY_ROOT/releases"
ls -1t | tail -n "+$((KEEP_RELEASES + 1))" | xargs -r rm -rf

echo "==> Deployed $GIT_REF as $TIMESTAMP"
