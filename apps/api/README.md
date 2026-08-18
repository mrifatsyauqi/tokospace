# apps/api

Laravel 11 (PHP 8.3) backend for Tokospace — `api.tokospace.com`.

Part of the `tokospace` monorepo, not a standalone repository. See the root
[`AGENTS.md`](../../AGENTS.md) for the authority-document reading order and
monorepo-wide rules, and [`CLAUDE.md`](./CLAUDE.md) for backend-specific
conventions.

## Local development

```bash
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

Or via the full stack (Postgres, Redis, Horizon, scheduler) — see the
[repo root README](../../README.md) and [`infra/README.md`](../../infra/README.md).

## Testing

```bash
php artisan test              # host-local (sqlite, see .env)
vendor/bin/pest --group=arch  # module boundary rules only
vendor/bin/pint               # code style
```
