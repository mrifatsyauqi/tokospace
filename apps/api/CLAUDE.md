# CLAUDE.md — apps/api

Laravel 11 + PHP 8.3 backend. Read root `AGENTS.md` first for monorepo-wide
rules and the authority-document reading order — this file only covers
things specific to this app.

## Aturan wajib

1. Logika bisnis HANYA di `app/Modules/*/`, bukan di `Http/Controllers/`.
   Controllers stay thin: routing + request validation. See
   `app/Modules/README.md` for the layering (`Controller → Service →
   Repository → Model`) and the module-boundary rule.
2. Tambah kurir/gateway baru = buat Provider baru yang implement interface
   (`Contracts/*ProviderInterface`), JANGAN ubah `ShippingService`/
   `PaymentService` untuk mengakomodasi provider tertentu.
3. Setiap query wajib ter-scope tenant (Global Scope aktif secara default,
   jangan pernah pakai `withoutGlobalScope` kecuali di konteks Super Admin
   yang eksplisit dan diaudit).
4. Media production (foto produk, logo, banner, bukti transfer, invoice,
   import/export) selalu ke disk `r2` (`config/filesystems.php`) — `local`
   disk hanya untuk temp/cache/log.
5. Jalankan `vendor/bin/pest --group=arch` sebelum selesai — kalau gagal,
   ada modul yang saling mengimpor secara ilegal.
6. `.env` never gets committed. `.env.example` is the template — update it
   whenever you add a new required variable, and note whether it's an
   app-level setting or one of the `infra/scripts/tune.sh`-managed values.

## Commands you'll actually use

```bash
composer install
php artisan test                    # host-local (sqlite, see .env)
docker compose exec php php artisan test   # against real Postgres/Redis
vendor/bin/pint                     # auto-fix code style
composer export-openapi             # regenerate openapi.json — commit it
                                     # whenever routes/Form Requests change,
                                     # api-ci.yml fails the PR if you forget
```

## Storage disks

Two disks, both defined explicitly (Tech Spec §1.1) — never add a third
without updating this file and the Tech Spec:

- `local` — transient only (temp upload processing, framework cache/log).
  Never production media.
- `r2` — default disk, S3-compatible, Cloudflare R2. Every upload feature
  writes here unless it's explicitly a `Temp/` path.

## Module layout (Tech Spec §10)

`app/Modules/{Tenant,Auth,Catalog,Order,Payment,Shipping,Billing,Theme,
Domain,Notification,Discount,Analytics,Return,Admin}/` — empty until Tahap 1
adds the first ones. See `app/Modules/README.md` before creating a new one.
