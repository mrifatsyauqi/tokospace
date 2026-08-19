#!/usr/bin/env bash
#
# Runs ON the Google Compute Engine target host, invoked over SSH by
# .github/workflows/rollback.yml (manually triggered from GitHub, per Tech
# Spec §7 — "Rollback harus dapat mengubah symlink ke release sebelumnya
# tanpa rebuild source"). No rebuild: this only ever flips the symlink to a
# release directory that deploy-release.sh already fully prepared.
#
# Usage: rollback.sh <deploy_root> [release_timestamp]
#   With no release_timestamp, rolls back to the previous release relative
#   to whatever "current" points at right now.

set -euo pipefail

DEPLOY_ROOT="${1:?deploy_root required}"
TARGET="${2:-}"

# See the matching comment in deploy-release.sh — required so Compose
# doesn't reject the whole file over the profile-gated cloud-sql-proxy
# service (ADR-0001).
export COMPOSE_PROFILES=production

cd "$DEPLOY_ROOT/releases"

if [ -z "$TARGET" ]; then
  CURRENT_RELEASE="$(basename "$(readlink -f "$DEPLOY_ROOT/current")")"
  TARGET="$(ls -1t | grep -v "^${CURRENT_RELEASE}$" | head -n 1)"
fi

if [ -z "$TARGET" ] || [ ! -d "$DEPLOY_ROOT/releases/$TARGET" ]; then
  echo "::error::No valid release found to roll back to (target: '${TARGET}')." >&2
  exit 1
fi

echo "==> Rolling back current -> releases/$TARGET"
ln -sfn "$DEPLOY_ROOT/releases/$TARGET" "$DEPLOY_ROOT/current"

echo "==> Restarting php/horizon/scheduler"
(cd "$DEPLOY_ROOT/current" && docker compose restart php horizon scheduler)

echo "==> Rolled back to $TARGET"
