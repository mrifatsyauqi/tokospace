# Tokospace — Prompt Development (Claude Code)

Pasangan `tokospace-master-plan.md`. Jalankan **satu tahap per sesi**, berurutan, dan jangan lanjut ke tahap berikutnya sebelum DoD tahap berjalan terpenuhi.

## 0. Aturan Global untuk Semua Prompt

Sebelum menjalankan prompt tahap mana pun, Claude Code wajib membaca dan mengikuti:

- `docs/tokospace-PRD.md` — **business/requirements authority**.
- `docs/tokospace-tech-spec.md` — **technical/infrastructure authority**.
- `docs/tokospace-design-brief.md` — **visual/interaction authority**.
- `docs/tokospace-master-plan.md` — **sequence/dependency authority**.

### NON-NEGOTIABLE RULES

1. **Tenant isolation adalah aturan keamanan inti.** Semua data tenant-aware harus punya `tenant_id`, Global Scope aktif, Policy, PostgreSQL RLS, dan test cross-tenant.
2. **Tenant context tidak boleh berasal langsung dari input client.** Public request direresolve melalui `TenantResolver`; dashboard menggunakan tenant dari identity/session authenticated.
3. **Media production selalu R2.** Jangan menyimpan foto produk, logo, banner, bukti transfer, invoice, import/export, atau media bisnis permanen di disk lokal Oracle.
4. **Payment context tidak boleh dicampur.** Gateway platform Tokospace hanya untuk subscription Tokospace; gateway tenant (Midtrans/Tripay) untuk customer membayar seller.
5. **Order module tidak boleh bergantung langsung pada provider.** Gunakan `PaymentProviderInterface` / `ShippingProviderInterface` dan provider implementation.
6. **Credential pihak ketiga tidak pernah dikirim ke browser atau ditulis ke source code.** Credential persisten harus encrypted di backend.
7. **Semua webhook wajib signature-verified dan idempotent.** Jangan memproses event hanya berdasarkan payload tanpa verifikasi.
8. **Data finansial/order bersifat authoritative di Laravel/PostgreSQL.** Next.js tidak boleh mengakses database langsung.
9. **Cart, checkout, account, dan order tidak boleh memakai stale cache.** Catalog/storefront boleh di-cache sesuai Tech Spec.
10. **Jangan mengubah architecture/scope secara diam-diam.** Jika implementasi menemukan konflik antar dokumen atau membutuhkan keputusan baru, berhenti, jelaskan konflik, dan buat ADR/perubahan dokumen sebelum coding lanjut.
11. **Test harus berjalan sebelum mengklaim selesai.** Jangan menganggap compile/build saja sebagai DoD.
12. **Jangan membuat branch atau repository baru yang tidak diminta.** Kerjakan pada branch fitur yang sudah ada dan buat Pull Request ke `main`.

### Workflow setiap tahap

```text
Read authority docs
      ↓
Inspect current repository state
      ↓
Plan
      ↓
Implement
      ↓
Run tests/lint/build
      ↓
Verify tenant/security constraints
      ↓
Check DoD tahap
      ↓
Commit
      ↓
Pull Request → main
```

---

## Tahap -1 — Hubungkan Claude Code ke Repo

Repo sudah ada. Jangan `git init` ulang.

### Mode A — Claude Code langsung di repo

1. Clone repo yang relevan.
2. Buka Claude Code dari folder repo.
3. Pastikan Git authentication aktif.
4. Baca `docs/` dan `CLAUDE.md` sebelum mengubah code.
5. Buat branch fitur dari `main`.
6. Commit perubahan dan buka PR; jangan push langsung ke `main`.

### Mode B — GitHub-triggered Claude

Gunakan hanya untuk perubahan kecil jika workflow GitHub App Claude sudah dikonfigurasi. Tetap mengikuti NON-NEGOTIABLE RULES dan wajib membuka PR.

---

## Tahap 0 — Fondasi Infrastruktur

**Model:** Sonnet
**Repo:** `tokospace-api` + `tokospace-web`

```text
Tujuan: membangun fondasi deployable, bukan fitur bisnis.

BACKEND — tokospace-api
1. Setup Laravel 11 + PHP 8.3 di repo yang sudah ada; JANGAN git init ulang.
2. Docker Compose: Nginx, PHP-FPM, PostgreSQL 16, Redis, Supervisor/Horizon.
3. Semua resource-dependent settings lewat environment; siapkan scripts/tune.sh.
4. Filesystems: local untuk temp/cache/log saja; r2 sebagai disk media production.
5. GET /health → HTTP 200 dan memeriksa koneksi DB + Redis.
6. Pest + architecture test group.
7. GitHub Actions: CI test/lint/arch-test; deployment ke Oracle memakai release-folder + symlink + rollback-ready flow sesuai Tech Spec.
8. Backup PostgreSQL terjadwal; backup media/database mengikuti kebijakan Tech Spec.
9. Buat CLAUDE.md, CODEMAP.md, dan ADR-0001 stack.

FRONTEND — tokospace-web
1. Setup Next.js 15 App Router + TypeScript.
2. Route groups: (marketing), (dashboard), (storefront), (admin).
3. Design tokens dari Design Brief.
4. Placeholder pada route utama.
5. Deploy via Vercel.
6. Buat shared API/types foundation untuk OpenAPI-generated types.

DoD:
- health endpoint 200;
- Vercel placeholder aktif;
- CI lulus;
- deployment path tervalidasi;
- backup job ada;
- tidak ada secret di repo.
```

---

## Tahap 1 — Tenant, Auth, Onboarding

**Model:** Opus → Sonnet
**Repo:** keduanya

```text
Ini tahap keamanan paling kritis. Rencanakan tenant isolation terlebih dahulu.

BACKEND
1. Migrasi: tenants, domains, users, otp_codes, password_resets.
2. users memakai UNIQUE(tenant_id, email) sesuai D3.
3. TenantResolver adalah satu abstraction untuk domain → tenant.
4. Public storefront: resolve tenant dari canonical subdomain/domain; jangan percaya tenant_id dari request body/query.
5. Dashboard: tenant berasal dari authenticated identity/session, bukan hostname.
6. Base model Global Scope untuk tenant-aware models.
7. PostgreSQL RLS + mekanisme tenant context yang sesuai Tech Spec/ADR. Tenant context tidak boleh diambil dari raw client input.
8. Policies untuk authorization.
9. Reserved subdomain/domain config dan validation.
10. Sanctum auth, email verification, password reset, rate limit.
11. Test wajib: Tenant A tidak dapat membaca/mengubah data Tenant B.

FRONTEND
1. Login, register, forgot-password, verify-email.
2. Onboarding 4 step: nama toko/subdomain → kategori → theme → logo.
3. Live availability check subdomain.
4. Semua form mengikuti validation contract yang konsisten dengan backend.

DOMAIN FOUNDATION WAJIB DI TAHAP INI
- canonical subdomain tersimpan;
- record `domains` tersedia;
- TenantResolver bekerja;
- reserved words final;
- `namatoko.tokospace.com` dapat membuka tenant yang benar.

CUSTOM DOMAIN UI BELUM DIKERJAKAN. Itu Tahap 7.

DoD:
seller daftar → verifikasi → pilih subdomain → storefront tenant benar → isolation tests lulus CI.
```

---

## Tahap 2 — Katalog Produk

**Model:** Sonnet
**Repo:** keduanya

```text
Bangun Catalog hanya setelah Tenant/Auth DoD lulus.

BACKEND
1. categories, products, product_variants, weight_gram.
2. Semua tabel tenant-aware dan scoped.
3. Catalog Service + Repository.
4. CRUD produk + variants.
5. CSV import dengan preview + row validation.
6. Upload media wajib ke R2.
7. Public storefront endpoints resolve tenant melalui TenantResolver.
8. Tidak ada query lintas tenant.

FRONTEND
1. Product dashboard.
2. Storefront catalog + product detail.
3. Gunakan caching sesuai Tech Spec dan tag tenant/product.

DoD:
produk + media R2 berhasil dibuat, tampil di tenant storefront yang benar, dan isolation test tetap lulus.
```

---

## Tahap 3 — Pesanan & Transaksi Manual

**Model:** Opus → Sonnet
**Repo:** keduanya

```text
Ini tahap paling kritis secara bisnis.

BACKEND
1. carts, orders, order_items, payments, shipments.
2. Order snapshot: product, variant, price, shipping address, customer contact.
3. Reserve stock ketika order dibuat memakai DB transaction + SELECT ... FOR UPDATE.
4. Expiration job untuk unpaid order; stok dikembalikan secara idempotent.
5. Payment module: ManualPaymentProvider.
6. Shipping module: ManualShippingProvider.
7. PaymentProviderInterface dan ShippingProviderInterface dibuat SEKARANG.
8. Semua upload bukti transfer → R2.
9. Order state transition harus tervalidasi dan audit/history dicatat.

FRONTEND
1. Cart.
2. Checkout.
3. Manual transfer proof upload.
4. Seller order list/detail.
5. Manual shipping/resi.
6. Order confirmation/tracking.

TEST WAJIB
Simulasikan dua checkout bersamaan untuk stok=1. Hanya satu request boleh berhasil.

DoD:
customer → checkout → manual payment → seller verification → shipment → selesai berjalan end-to-end tanpa akses DB manual.
```

---

## Tahap 4 — Billing Platform & Theme

**Model:** Sonnet
**Repo:** keduanya

```text
Billing di sini adalah SUBSCRIPTION SELLER KE TOKOSPACE.
Jangan mencampurnya dengan payment customer→seller.

BACKEND
1. plans, subscriptions, invoices/records sesuai PRD schema.
2. Satu platform payment account Tokospace; credential server-side.
3. Starter gratis permanen; Pro/Business berbayar.
4. Quota dan features berupa data.
5. Grace period/read-only/suspend sesuai Master Plan.
6. Theme config per tenant; media → R2.

FRONTEND
1. Billing dashboard.
2. Upgrade/plan selection.
3. Invoice/history.
4. Theme editor dasar.
5. Static store pages.

DoD:
subscription lifecycle bekerja; quota enforcement benar; theme tersimpan per tenant; tidak ada credential payment platform di browser.
```

---

## Tahap 5 — SEO & MVP Hardening

**Model:** Sonnet
**Repo:** keduanya

```text
Ini GERBANG MVP RELEASE.

1. SEO storefront lengkap sesuai PRD.
2. Cache invalidation on-demand menggunakan abstraction tunggal; Laravel menjadi pemicu invalidasi setelah perubahan catalog/theme.
3. Error response konsisten.
4. N+1 audit endpoint kritis.
5. Tenant isolation + RLS audit.
6. Backup + restore test nyata.
7. R2 media audit.
8. Lighthouse/performance test.
9. Rollback test.
10. Design Brief handoff checklist.

DoD:
semua P0 selesai, Core Sellable bekerja, Billing bekerja, Theme dasar bekerja, SEO aktif, hardening lolos.
Hanya setelah DoD ini Fase 1 boleh dimulai.
```

---

## Tahap 6 — Payment & Shipping Otomatis

**Model:** Opus → Sonnet

```text
Fokus payment customer→seller dan shipping provider.

PAYMENT
1. Implement PaymentProviderInterface → MidtransProvider + TripayProvider.
2. Seller memasukkan credential milik seller sendiri.
3. Credential encrypted di backend.
4. Test Connection server-side.
5. Create payment transaction melalui provider.
6. Verify webhook signature.
7. Idempotent webhook processing + provider event/reference unique constraint.
8. Persist transaction record untuk order reconciliation.
9. Jangan membuat seller wallet/payout/transaction-fee ledger Tokospace.

SHIPPING
1. ShippingProviderInterface → JntProvider + KiriminAjaProvider.
2. Credential seller encrypted.
3. Timeout/retry/fallback sesuai provider contract.
4. Gunakan queue untuk pekerjaan yang cocok asynchronous.

FRONTEND
Payment/shipping settings + checkout automation.

DoD:
provider connection berhasil, payment callback aman/idempotent, seller menerima settlement sesuai provider account sendiri, shipping flow bekerja.
```

---

## Tahap 7 — Custom Domain & WhatsApp

**Model:** Sonnet

```text
CUSTOM DOMAIN
1. Gunakan Vercel Domains API abstraction di Laravel.
2. Seller submit custom domain.
3. Simpan domain mapping tenant.
4. Poll/status melalui provider status API; jangan implement DNS verification sendiri jika provider sudah menjadi source of truth.
5. UI menampilkan pending/verified/error/SSL states.

WHATSAPP
1. OTP dan transaction notifications.
2. Signature/auth validation provider.
3. Retry/fallback email sesuai Tech Spec.
4. Notification history.

DoD:
custom domain dapat di-onboard tanpa manual admin intervention dan mapping domain → tenant tetap benar.
```

---

## Tahap 8 — Fitur Penunjang Seller

Diskon/promo, analytics aggregation, return/refund sesuai PRD dan Design Brief.

```text
NON-NEGOTIABLE:
- tenant scoped;
- policy checked;
- queue untuk pekerjaan berat;
- audit/logging;
- tidak mengubah payment ownership baseline tanpa ADR + PRD change.
```

---

## Tahap 9 — Super Admin Lengkap

```text
Monitoring seller/integration, package/quota/theme management, billing reporting, support tools, dan operational controls.

Pastikan Super Admin bypass tenant scope hanya melalui explicit privileged path yang diaudit dan diuji.
```

---

## Final Instruction untuk Claude Code

Jangan menganggap dokumentasi terbaru sebagai alasan untuk melewati test. Untuk setiap tahap:

```text
read → plan → implement → test → inspect diff → verify DoD → commit → PR
```

Jika ada konflik antara prompt ini dan PRD/Tech Spec/Design Brief/Master Plan, **jangan menebak**. Laporkan konflik dan minta keputusan/ADR sebelum melanjutkan implementasi.
