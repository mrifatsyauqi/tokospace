# apps/web

Next.js 15 (App Router) + TypeScript + Tailwind v4 frontend for Tokospace —
marketing, seller dashboard, storefront, and admin, all one app, split by
hostname via `src/middleware.ts`.

Part of the `tokospace` monorepo, not a standalone repository. See the root
[`AGENTS.md`](../../AGENTS.md) for the authority-document reading order and
monorepo-wide rules, and [`CLAUDE.md`](./CLAUDE.md) for frontend-specific
conventions.

## Local development

```bash
pnpm install
pnpm dev
```

Test the four host-based route groups by editing `/etc/hosts` (or your
platform's equivalent) to point `app.localhost`, `admin.localhost`, and
`<anything>.localhost` at `127.0.0.1`, then visit e.g.
`http://app.localhost:3000`. Plain `http://localhost:3000` serves marketing.

## Deployment

Vercel, auto-deploy on push to `main` (Root Directory: `apps/web`) — see
`docs/tokospace-tech-spec.md` §7. Not wired through GitHub Actions;
`.github/workflows/web-ci.yml` is a pre-merge gate only (lint/type-check/build).
