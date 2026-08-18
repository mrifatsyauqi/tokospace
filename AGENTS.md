# AGENTS.md — tokospace (monorepo)

This is a single monorepo (ADR-0002 equivalent — see `docs/tokospace-tech-spec.md`
§2, "Repository & Application Architecture"). `apps/api` and `apps/web` are
**not** separate repositories. Never run `git init` inside either, never
create `tokospace-api`/`tokospace-web` as separate GitHub repos, never push
directly to `main` — work on a feature branch and open a PR.

## Before touching any code

Read, in this order (`docs/tokospace-tech-spec.md` §0.1 authority hierarchy):

1. `docs/tokospace-PRD.md` — business requirements
2. `docs/tokospace-tech-spec.md` — technical/infrastructure architecture
3. `docs/tokospace-design-brief.md` — visual/interaction
4. `docs/tokospace-master-plan.md` — build sequence/dependency
5. `docs/tokospace-prompt-development.md` — per-stage AI execution instructions

If two of these disagree on something that affects architecture or scope:
**stop, name the exact files/sections in conflict, and ask** — don't guess
which one wins.

Area-specific rules: `apps/api/CLAUDE.md` (backend), `apps/web/CLAUDE.md`
(frontend). Read the one for whichever app you're editing — don't apply
Laravel-module rules to Next.js code or vice versa.

## Structure

```text
tokospace/
├── apps/
│   ├── api/     Laravel 11 (PHP 8.3) — api.tokospace.com
│   └── web/     Next.js 15 — marketing/dashboard/storefront/admin, one app
├── docs/        PRD, Tech Spec, Design Brief, Master Plan, AI prompts, ADRs
├── infra/       Docker Compose services, tune.sh, deploy/rollback scripts
└── .github/workflows/   path-filtered CI/CD, independent per app
```

`apps/web` never touches PostgreSQL, Redis, or Laravel internals directly —
everything goes through the HTTP API (Tech Spec §0.2 rule 1). Generated API
types live at `apps/web/src/generated/api-types.ts` (gitignored, regenerate
with `pnpm generate:api-types` after `composer export-openapi` in `apps/api`)
— Tech Spec §11: if the API contract changed, the generated types must
change too, and a TypeScript compile error is exactly how you're supposed to
find out before it reaches production.

## Non-negotiable rules (Tech Spec §0.2, prompt-development.md §0)

1. Tenant isolation is the core security rule: every tenant-aware table gets
   `tenant_id`, an active Global Scope, a Policy, PostgreSQL RLS, and a
   cross-tenant test in CI. No exceptions without an ADR.
2. Tenant context never comes straight from client input — public routes
   resolve it via `TenantResolver`, dashboard routes from the authenticated
   session.
3. Production media (product photos, logos, banners, proof-of-transfer,
   invoices, import/export) always goes to the `r2` disk. The `local` disk
   is for temp/cache/log only.
4. Payment contexts never mix: the platform gateway is for sellers paying
   Tokospace; tenant gateways (Midtrans/Tripay) are for customers paying
   sellers.
5. The `Order` module depends only on `PaymentProviderInterface` /
   `ShippingProviderInterface`, never a specific SDK.
6. Third-party credentials are encrypted at rest and never sent to the
   browser or committed to source.
7. Webhooks are signature-verified and idempotent before any processing.
8. Tests actually run before you claim a task done — `pest --group=arch`
   included. A green build that skipped tests isn't done.
9. Found a conflict, or a decision an architecture doc doesn't cover? Stop
   and say so. Don't improvise a new architectural decision mid-task.

## Local development

```bash
cp .env.example .env && infra/scripts/tune.sh   # resource settings from actual host RAM/CPU
cp apps/api/.env.example apps/api/.env
docker compose up -d --build   # first boot auto-runs `composer install`
docker compose exec php php artisan key:generate
curl http://localhost:8000/health

cd apps/web && pnpm install && pnpm dev          # separate — Vercel deploys apps/web independently
```

See `infra/README.md` for the full breakdown of what each Compose service
does and how backup/restore works.
