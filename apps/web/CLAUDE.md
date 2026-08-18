# CLAUDE.md — apps/web

Next.js 15 (App Router) + TypeScript + Tailwind v4. Read root `AGENTS.md`
first for monorepo-wide rules — this file only covers things specific to
this app.

## Aturan wajib

1. **Tidak pernah** mengakses PostgreSQL, Redis, atau kelas internal
   Laravel secara langsung — semua data lewat HTTP API ke `apps/api`
   (Tech Spec §0.2 rule 1). Kalau terasa perlu "jalan pintas" ke database,
   itu tanda butuh endpoint API baru, bukan alasan melanggar aturan ini.
2. Response contract API mengikuti tipe hasil generate dari OpenAPI
   (`src/generated/api-types.ts`, gitignored — jalankan
   `pnpm generate:api-types` setelah `composer export-openapi` di
   `apps/api`). Jangan definisikan ulang shape response secara manual kalau
   tipe generated-nya sudah ada.
3. Host-based routing (marketing/dashboard/storefront/admin dari satu app)
   ditangani `src/middleware.ts` — lihat komentar di file itu sebelum
   menambah route group baru. Route groups (`(marketing)`, `(dashboard)`,
   dst.) tidak boleh punya `page.tsx` yang resolve ke path yang sama;
   middleware yang membedakan lewat rewrite ke prefix nyata
   (`/dashboard`, `/admin`, `/s/[tenant]`).
4. Design tokens dari `docs/tokospace-design-brief.md` §2 — didefinisikan
   di `src/app/globals.css` (`@theme` block). Jangan pakai warna/radius di
   luar token itu; kalau butuh nilai baru, itu perubahan Design Brief dulu,
   bukan hardcode di komponen.
5. Tidak ada dark mode di V1/Fase 1 (Design Brief §2.4) — jangan tambah
   `prefers-color-scheme` override.

## Commands you'll actually use

```bash
pnpm install
pnpm dev              # http://localhost:3000 — test host-based routing via
                       # Host header override or /etc/hosts entries for
                       # app.localhost, admin.localhost, <tenant>.localhost
pnpm lint
pnpm exec tsc --noEmit
pnpm build
pnpm generate:api-types   # regenerate src/generated/api-types.ts
```

## Structure

```text
src/
├── app/
│   ├── (marketing)/          apex domain — tokospace.com
│   ├── dashboard/(dashboard)/  app.tokospace.com
│   ├── s/[tenant]/(storefront)/  *.tokospace.com
│   └── admin/(admin)/         admin.tokospace.com
├── middleware.ts              host → path-prefix rewrite
└── generated/                 gitignored, see api-types above
```
