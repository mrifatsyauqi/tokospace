# infra/

Docker Compose stack for `apps/api` (Tech Spec §4, §5). `apps/web` deploys to
Vercel separately and is not part of this stack — run it locally with `pnpm
dev` inside `apps/web`.

## Local setup

`docker-compose.yml` alone is the **production** topology (ADR-0001 target —
PostgreSQL is Cloud SQL, not a Docker service). For local development, layer
`docker-compose.local.yml` on top — it's the only file that restores a
self-hosted `postgres` service:

```bash
cp .env.example .env
infra/scripts/tune.sh          # fills in POSTGRES_SHARED_BUFFERS, PHP_FPM_MAX_CHILDREN, etc.
cp apps/api/.env.example apps/api/.env
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build   # first boot auto-runs `composer install` — no vendor/ on the host needed
docker compose -f docker-compose.yml -f docker-compose.local.yml exec php php artisan key:generate
curl http://localhost:8000/health
```

`infra/scripts/tune.sh` reads this machine's actual detected RAM/CPU
(cgroup limits if running inside a container, `/proc`/`nproc` otherwise) and
writes the resource-dependent settings to `.env` at the repo root. Re-run it
whenever you move to different hardware — nothing in `docker-compose.yml` or
the Dockerfiles hardcodes a specific RAM/CPU target (Tech Spec §4.1).

## What's in this folder

```text
infra/
├── docker/
│   ├── php/
│   │   ├── Dockerfile              # PHP 8.3-FPM + extensions + pg_dump client
│   │   ├── entrypoint.sh           # envsubst's www.conf.template before starting
│   │   └── www.conf.template       # pm.max_children driven by PHP_FPM_MAX_CHILDREN
│   └── nginx/
│       └── default.conf            # reverse proxy to php:9000
└── scripts/
    └── tune.sh                     # writes resource settings to .env
```

## Services

Base (`docker-compose.yml` at repo root) — the production topology, gated
behind the `production` Compose profile:

| Service | Role |
|---|---|
| `nginx` | Reverse proxy, exposes `:8000` |
| `php` | PHP-FPM running `apps/api` |
| `horizon` | Queue worker (`php artisan horizon`) |
| `scheduler` | Runs `php artisan schedule:work` — this is what fires the daily backup (Tech Spec §14) |
| `cloud-sql-proxy` | TCP tunnel to Google Cloud SQL for PostgreSQL (ADR-0001) — `profiles: ["production"]`, never starts locally |
| `redis` | Redis 7 |

Local override (`docker-compose.local.yml`) adds back:

| Service | Role |
|---|---|
| `postgres` | PostgreSQL 16, self-hosted — local dev only, never production (ADR-0001) |

Any `docker compose` command against the base file in production (deploy,
rollback, or a manual admin command) needs the `production` profile active —
`export COMPOSE_PROFILES=production`, already set by
`infra/scripts/deploy-release.sh` and `rollback.sh` — otherwise Compose
rejects the whole file over the profile-gated `cloud-sql-proxy` dependency.

## Backup & restore (Tech Spec §14)

`app:backup-database` (scheduled daily at 02:00 by `routes/console.php`) runs
`pg_dump`, gzips it, and uploads to the `gcs` disk (ADR-0001 target — see
`config/filesystems.php`) under `backups/database/`, pruning anything older
than 30 days. It never writes the backup to a path that isn't immediately
uploaded off the VM.

To test a restore (local dev, against the `docker-compose.local.yml`
`postgres` service):

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml exec php php artisan app:backup-database
# download the resulting backups/database/*.sql.gz from GCS, then:
gunzip -c backup.sql.gz | docker compose -f docker-compose.yml -f docker-compose.local.yml exec -T postgres psql -U tokospace -d tokospace
```

Per the Master Plan MVP release gate, this must be run at least once before
declaring MVP Release — a backup that has never been restored is not a
verified backup.

## Cloud SQL Auth Proxy (production, ADR-0001)

`cloud-sql-proxy` needs `CLOUD_SQL_CONNECTION_NAME` (format
`PROJECT:REGION:INSTANCE`) in the production `shared/apps-api.env` — this is
a Phase 2 infrastructure value that doesn't exist until the Cloud SQL
instance is provisioned, so it's left blank in `.env.example` rather than
invented. No credentials file is needed: the proxy uses the GCE VM's
attached service account via Application Default Credentials automatically.

The published `gcr.io/cloud-sql-connectors/cloud-sql-proxy` image is
distroless (no shell, no `curl`/`wget`/`nc`), so it has no Docker
`healthcheck`. `docker-compose.yml`'s dependents use
`condition: service_started` instead of a health-gated wait, and
`infra/scripts/deploy-release.sh` retries the first migration attempt to
absorb the resulting startup race. Revisiting this with the proxy's built-in
`--health-check` HTTP endpoint (checked from a different container, since
this one can't probe itself) is a reasonable follow-up, not done here.

## Google Cloud Storage (production, ADR-0001)

The `gcs` disk (`config/filesystems.php`, driver registered in
`App\Providers\AppServiceProvider::boot()`) needs `GCS_PROJECT_ID` and
`GCS_BUCKET` in production — also Phase 2 infrastructure values, left blank
in `.env.example`. `GCS_KEY_FILE` should stay unset in production; the same
GCE service account used by `cloud-sql-proxy` authenticates the Google Cloud
Storage client via Application Default Credentials. `r2` stays defined and
configured until the storage cutover in ADR-0001 is actually executed.
