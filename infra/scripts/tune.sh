#!/usr/bin/env bash
#
# Computes resource-dependent settings from the host's actual detected
# RAM/CPU and writes them to .env at the repo root, consumed by
# docker-compose.yml (Tech Spec §4.1/§5 — nothing here may be a fixed
# constant baked into the image or compose file itself; a move to a
# different VM spec is a re-run of this script, not a code change).
#
# Usage: infra/scripts/tune.sh [path-to-env-file]
# Safe to re-run — it only touches the TUNE_* managed block, everything
# else you put in .env is left alone.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"

detect_ram_mb() {
  if [ -r /sys/fs/cgroup/memory.max ] && [ "$(cat /sys/fs/cgroup/memory.max)" != "max" ]; then
    # cgroup v2 (typical inside a container / most modern Docker hosts)
    echo $(( $(cat /sys/fs/cgroup/memory.max) / 1024 / 1024 ))
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    local limit
    limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    # cgroup v1 reports an effectively-unlimited huge number when uncapped
    if [ "$limit" -lt $((1024 * 1024 * 1024 * 1024)) ]; then
      echo $(( limit / 1024 / 1024 ))
      return
    fi
    awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo
  else
    awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo
  fi
}

detect_cpu_count() {
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    local quota period
    read -r quota period < /sys/fs/cgroup/cpu.max
    if [ "$quota" != "max" ]; then
      echo $(( (quota + period - 1) / period ))
      return
    fi
  fi
  nproc
}

RAM_MB=$(detect_ram_mb)
CPU_COUNT=$(detect_cpu_count)
[ "$CPU_COUNT" -lt 1 ] && CPU_COUNT=1

# Tech Spec §4.2 allocation targets, expressed as ratios of whatever RAM/CPU
# is actually detected rather than the 2 OCPU/12GB numbers themselves:
#   Postgres   ~25% RAM  (shared_buffers, standard Postgres tuning guideline)
#   PHP-FPM    one worker per ~40MB, capped by ~35% RAM and 2x CPU count
#   Redis      ~10% RAM
#   Horizon    matches CPU count, min 2

POSTGRES_SHARED_BUFFERS_MB=$(( RAM_MB / 4 ))
[ "$POSTGRES_SHARED_BUFFERS_MB" -lt 64 ] && POSTGRES_SHARED_BUFFERS_MB=64

PHP_FPM_BUDGET_MB=$(( RAM_MB * 35 / 100 ))
PHP_FPM_MAX_CHILDREN=$(( PHP_FPM_BUDGET_MB / 40 ))
PHP_FPM_CPU_CAP=$(( CPU_COUNT * 2 ))
[ "$PHP_FPM_MAX_CHILDREN" -gt "$PHP_FPM_CPU_CAP" ] && PHP_FPM_MAX_CHILDREN=$PHP_FPM_CPU_CAP
[ "$PHP_FPM_MAX_CHILDREN" -lt 2 ] && PHP_FPM_MAX_CHILDREN=2

REDIS_MAXMEMORY_MB=$(( RAM_MB / 10 ))
[ "$REDIS_MAXMEMORY_MB" -lt 32 ] && REDIS_MAXMEMORY_MB=32

HORIZON_MAX_PROCESSES=$CPU_COUNT
[ "$HORIZON_MAX_PROCESSES" -lt 2 ] && HORIZON_MAX_PROCESSES=2

echo "Detected: ${RAM_MB}MB RAM, ${CPU_COUNT} CPU"
echo "  POSTGRES_SHARED_BUFFERS=${POSTGRES_SHARED_BUFFERS_MB}MB"
echo "  PHP_FPM_MAX_CHILDREN=${PHP_FPM_MAX_CHILDREN}"
echo "  REDIS_MAXMEMORY=${REDIS_MAXMEMORY_MB}mb"
echo "  HORIZON_MAX_PROCESSES=${HORIZON_MAX_PROCESSES}"

touch "$ENV_FILE"

update_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

update_var "POSTGRES_SHARED_BUFFERS" "${POSTGRES_SHARED_BUFFERS_MB}MB"
update_var "PHP_FPM_MAX_CHILDREN" "$PHP_FPM_MAX_CHILDREN"
update_var "REDIS_MAXMEMORY" "${REDIS_MAXMEMORY_MB}mb"
update_var "HORIZON_MAX_PROCESSES" "$HORIZON_MAX_PROCESSES"

echo "Written to $ENV_FILE"
