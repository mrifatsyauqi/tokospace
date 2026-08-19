# Tokospace

SaaS multi-tenant e-commerce builder for Indonesian UMKM sellers — register,
get a subdomain, sell products, all from one dashboard.

Single monorepo (see `docs/tokospace-tech-spec.md` §2 and `AGENTS.md`):

```text
apps/api    Laravel 11 (PHP 8.3) — api.tokospace.com
apps/web    Next.js 15 — marketing / seller dashboard / storefront / admin
infra/      Docker Compose, resource tuning, deploy/rollback scripts
docs/       Product & technical source of truth
```

## Documentation

Start with `AGENTS.md` — it links to everything else, including the
authority-document reading order (`docs/tokospace-PRD.md`,
`docs/tokospace-tech-spec.md`, `docs/tokospace-design-brief.md`,
`docs/tokospace-master-plan.md`, `docs/tokospace-prompt-development.md`).

## Local development

```bash
cp .env.example .env && infra/scripts/tune.sh
cp apps/api/.env.example apps/api/.env
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build   # first boot auto-runs `composer install` (see infra/docker/php/entrypoint.sh)
docker compose -f docker-compose.yml -f docker-compose.local.yml exec php php artisan key:generate
curl http://localhost:8000/health

cd apps/web && pnpm install && pnpm dev
```

`docker-compose.yml` alone is the production topology (ADR-0001 — PostgreSQL
is Cloud SQL, not a Docker service); `docker-compose.local.yml` layers a
self-hosted `postgres` back in for local dev. See `infra/README.md`.

See `infra/README.md` for what each Compose service does, and
`apps/api/CLAUDE.md` / `apps/web/CLAUDE.md` for per-app conventions.
