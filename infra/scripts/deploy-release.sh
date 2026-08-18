#!/usr/bin/env bash
#
# Runs ON the Oracle target host, invoked over SSH by
# .github/workflows/api-deploy.yml. Implements the release-folder + atomic
# symlink pattern from Tech Spec §7 — "current" only ever moves once the new
# release is fully prepared, so a request never sees a half-deployed state.
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

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$DEPLOY_ROOT/releases/$TIMESTAMP"

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

echo "==> Flipping current -> releases/$TIMESTAMP"
ln -sfn "$RELEASE_DIR" "$DEPLOY_ROOT/current"

echo "==> Running migrations and cache warmup"
(cd "$DEPLOY_ROOT/current" && docker compose exec -T php php artisan migrate --force)
(cd "$DEPLOY_ROOT/current" && docker compose exec -T php php artisan config:cache)
(cd "$DEPLOY_ROOT/current" && docker compose exec -T php php artisan route:cache)

echo "==> Restarting php/horizon/scheduler (nginx and data services stay up — zero downtime)"
(cd "$DEPLOY_ROOT/current" && docker compose restart php horizon scheduler)

echo "==> Pruning old releases (keeping last $KEEP_RELEASES)"
cd "$DEPLOY_ROOT/releases"
ls -1t | tail -n "+$((KEEP_RELEASES + 1))" | xargs -r rm -rf

echo "==> Deployed $GIT_REF as $TIMESTAMP"
