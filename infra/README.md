# infra/

Docker Compose stack for `apps/api` (Tech Spec §4, §5). `apps/web` deploys to
Vercel separately and is not part of this stack — run it locally with `pnpm
dev` inside `apps/web`.

## Local setup

```bash
cp .env.example .env
infra/scripts/tune.sh          # fills in POSTGRES_SHARED_BUFFERS, PHP_FPM_MAX_CHILDREN, etc.
cp apps/api/.env.example apps/api/.env
php -r "echo bin2hex(random_bytes(16));"   # or: cd apps/api && php artisan key:generate
docker compose up -d --build
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

## Services (`docker-compose.yml` at repo root)

| Service | Role |
|---|---|
| `nginx` | Reverse proxy, exposes `:8000` |
| `php` | PHP-FPM running `apps/api` |
| `horizon` | Queue worker (`php artisan horizon`) |
| `scheduler` | Runs `php artisan schedule:work` — this is what fires the daily backup (Tech Spec §14) |
| `postgres` | PostgreSQL 16 |
| `redis` | Redis 7 |

## Backup & restore (Tech Spec §14)

`app:backup-database` (scheduled daily at 02:00 by `routes/console.php`) runs
`pg_dump`, gzips it, and uploads to the `r2` disk under `backups/database/`,
pruning anything older than 30 days. It never writes the backup to a path
that isn't immediately uploaded off the Oracle instance.

To test a restore:

```bash
docker compose exec php php artisan app:backup-database
# download the resulting backups/database/*.sql.gz from R2, then:
gunzip -c backup.sql.gz | docker compose exec -T postgres psql -U tokospace -d tokospace
```

Per the Master Plan MVP release gate, this must be run at least once before
declaring MVP Release — a backup that has never been restored is not a
verified backup.
