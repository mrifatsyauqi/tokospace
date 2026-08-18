# Tokospace — Master Plan Development

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Versi** | 1.2 |
| **Tanggal** | 17 Agustus 2026 |
| **Mengikat** | `tokospace-PRD.md` v1.2 · `tokospace-design-brief.md` v2.0 · `tokospace-tech-spec.md` v2.4 |
| **Pasangan dokumen** | `tokospace-prompt-development.md` v1.3 — prompt siap pakai per tahap |
| **Status** | **Approved — Development Baseline** |

> PRD menjawab **apa**, Design Brief menjawab **visual/interaksi**, Tech Spec menjawab **bagaimana secara teknis**, Master Plan menjawab **urutan/dependency**, dan Prompt Development menjawab **instruksi eksekusi AI**.

---

## 1. Prinsip Eksekusi

1. Urutan mengikuti dependency data.
2. Backend Laravel dan frontend Next.js dibangun berpasangan per tahap dalam **satu monorepo**.
3. Setiap tahap memiliki Definition of Done yang dapat diverifikasi.
4. Desain yang belum tersedia harus dibuat dan di-handoff sebelum halaman dikodekan.
5. P0 diselesaikan sebelum P1, tetapi fondasi domain/tenant yang diperlukan fitur P1 tetap dibuat di P0.
6. Semua perubahan lintas dokumen harus mengikuti authority masing-masing dan dicatat sebagai ADR bila mengubah keputusan arsitektur.
7. Monorepo tidak berarti satu deployment: `apps/api` dan `apps/web` tetap memiliki boundary, CI, dan deployment pipeline masing-masing.

---

## 2. Repository & Development Topology

Tokospace menggunakan satu repository sebagai source of truth:

```text
tokospace/
├── apps/
│   ├── api/                 # Laravel 11
│   └── web/                 # Next.js 15
├── docs/                    # product + technical source of truth
├── infra/                   # Docker/Nginx/ops configuration
├── packages/                # shared generated contracts/types bila diperlukan
├── .github/workflows/       # independent API/Web CI/CD
├── AGENTS.md
└── README.md
```

### Deployment boundary

```text
apps/api/**
   ↓
API CI
   ↓
Google Compute Engine deployment

apps/web/**
   ↓
Web CI
   ↓
Vercel deployment
```

### Development boundary

```text
apps/web
   ↓ HTTPS
apps/api
   ↓
PostgreSQL / Redis / R2
```

`apps/web` tidak boleh mengakses database atau internal Laravel classes secara langsung.

---

## 3. Peta Ketergantungan Modul

```text
                         ┌──────────┐
                         │  Tenant   │
                         └────┬─────┘
                              │
                         ┌────▼─────┐
                         │   Auth    │
                         └────┬─────┘
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
        ┌──────────┐    ┌──────────┐     ┌──────────┐
        │ Catalog  │    │ Billing  │     │  Theme   │
        └────┬─────┘    └──────────┘     └──────────┘
             │
        ┌────▼─────┐
        │   Order   │
        │  + Cart   │
        └────┬──────┘
             │
       ┌─────┴─────┐
       ▼           ▼
   ┌────────┐  ┌──────────┐
   │Payment │  │ Shipping │
   │ manual │  │  manual  │
   └────┬───┘  └────┬─────┘
        └──────┬─────┘
               ▼
      ═════════════════════
        CORE SELLABLE
      seller sudah bisa
      berjualan end-to-end
      secara manual
      ═════════════════════
               │
               ▼
      ┌─────────────────────┐
      │ SEO + Hardening     │
      │ → MVP RELEASE       │
      └─────────┬───────────┘
                │
       ┌────────┼────────┬──────────┐
       ▼        ▼        ▼          ▼
   Payment   Shipping  Custom      WA
   Gateway     API     Domain    Gateway
```

**Core Sellable** bukan sinonim dengan **MVP Release**. Core Sellable berarti alur jualan manual sudah bekerja. MVP Release baru tercapai setelah Billing, Theme, SEO, dan hardening selesai.

---

## 4. Tahapan Development

| Tahap | Fokus | Backend | Frontend | Prioritas |
|---|---|---|---|---|
| **0** | Fondasi infrastruktur | setup/deploy/CI | placeholder | Prasyarat |
| **1** | Tenant, Auth, Onboarding | `tenant`, `auth`, `domain` | auth + onboarding | P0 |
| **2** | Katalog | `catalog` | product dashboard + storefront | P0 |
| **3** | Order & transaksi manual | `order`, `payment`, `shipping` | cart, checkout, order | P0 |
| **4** | Billing & Theme | `billing`, `theme` | billing, theme editor | P0 |
| **5** | SEO & MVP Hardening | cross-module | cross-page | P0 |
| **6** | Payment & Shipping otomatis | payment/shipping providers | settings + checkout integration | P1 |
| **7** | Custom Domain & WhatsApp | `domain`, `notification` | domain + notification | P1 |
| **8** | Fitur seller | discount, analytics, return | seller features | P1 |
| **9** | Super Admin lengkap | `admin` | admin panel | P1 |

---

## 5. Detail per Tahap

### Tahap 0 — Fondasi Infrastruktur

Menghasilkan tempat fitur dibangun.

**Repository:** satu monorepo `tokospace`.

**Backend:** `apps/api` — Laravel 11, Docker Compose, API health endpoint, PostgreSQL, Redis, Horizon, scheduler, CI/CD dasar, backup job.

**Frontend:** `apps/web` — Next.js 15 placeholder production route di Vercel.

**Infrastructure:** `infra/` untuk konfigurasi Docker/Nginx/operasional yang memang perlu dibagikan repository.

**DoD:**
- `api.tokospace.com/health` → 200
- `tokospace.com` menampilkan placeholder Vercel
- push `main` memicu deployment target tanpa error
- database backup terjadwal
- restore backup diuji sebelum MVP Release
- API/Web CI berjalan independen sesuai perubahan path

### Tahap 1 — Tenant, Auth, Onboarding

**Kenapa dulu:** seluruh data bisnis bergantung pada tenant.

**Backend:**
- `tenants`
- `domains`
- `users`
- `otp_codes`
- `password_resets`
- canonical subdomain
- reserved words/domains
- TenantResolver
- Sanctum
- Global Scope tenant
- PostgreSQL RLS + tenant context sesuai Tech Spec/ADR
- Policy
- tenant isolation tests

**Frontend:** login, register, password reset, verification, onboarding wizard.

**DoD:** seller dapat daftar → verifikasi → memilih subdomain → toko dapat diakses melalui `namatoko.tokospace.com` <15 menit; tenant isolation tests lulus CI.

> **Catatan:** custom-domain UI belum dibuat di tahap ini. Yang dibuat di sini adalah **fondasi domain internal** yang menjadi sumber mapping domain → tenant.

### Tahap 2 — Katalog Produk

**Backend:** categories, products, variants, stock, CSV import, R2 media.

**Frontend:** product dashboard, catalog, product detail.

**DoD:** seller dapat membuat produk lengkap dengan gambar R2 dan produk muncul di storefront; no cross-tenant access.

### Tahap 3 — Pesanan & Transaksi Manual

**Backend:** carts, orders, order_items dengan snapshot, payments manual, shipments manual, stock reservation dengan row lock, scheduled expiration.

**Frontend:** cart, checkout, bukti transfer, order list/detail, manual shipment.

**DoD:** customer → checkout → transfer manual → seller verifikasi → resi → selesai; concurrent checkout stok=1 hanya satu berhasil.

### Tahap 4 — Billing Platform & Theme

**Backend:** plans, subscriptions, quota, platform gateway subscription, theme config.

**Frontend:** billing, upgrade, invoice history, theme editor dasar, static store pages.

**DoD:** seller dapat upgrade dan membayar subscription Tokospace; quota enforcement bekerja sebagai CTA upgrade, bukan error generik.

### Tahap 5 — SEO & MVP Hardening

Ini adalah **gerbang resmi MVP Release**.

**Wajib:**
- SEO storefront
- sitemap/robots/JSON-LD/Open Graph
- cache invalidation on-demand
- konsistensi error response
- N+1 audit
- tenant isolation audit
- backup + restore test
- R2 media audit
- Lighthouse/performance test
- design handoff checklist
- rollback test

**DoD:** seluruh acceptance criteria P0 dan global DoD lulus. Setelah ini Tokospace dapat dinyatakan **MVP Release** dan masuk Fase 1.

### Tahap 6 — Payment & Shipping Otomatis

**Backend:**
- `PaymentProviderInterface`
- `MidtransProvider`
- `TripayProvider`
- `ShippingProviderInterface`
- `JntProvider`
- `KiriminAjaProvider`
- webhook verification/idempotency

**Frontend:** provider settings, test connection, checkout payment/shipping automation.

**DoD:** seller Pro/Business dapat menghubungkan provider milik sendiri dan transaksi berjalan sesuai kontrak provider.

### Tahap 7 — Custom Domain & WhatsApp Gateway

**Backend:** Vercel Domains API abstraction, WhatsApp provider, notification logs.

**Frontend:** domain settings, DNS instructions, status polling, OTP/notifikasi.

**DoD:** seller dapat mengaktifkan custom domain tanpa intervensi manual tim Tokospace; status domain terverifikasi dari provider.

### Tahap 8 — Fitur Penunjang Seller

Discount/promo, analytics aggregation, return/refund dengan provider-agnostic service boundary.

### Tahap 9 — Super Admin Lengkap

Monitoring integrasi, package management, theme management, billing reporting, seller support, operational tools.

---

## 6. Dependency & Design Gate

Sebelum coding sebuah halaman:

```text
PRD requirement
      ↓
Design Brief / handoff
      ↓
Prompt Development
      ↓
Implementation
      ↓
DoD
```

Jangan mengubah UI/business behavior langsung di prompt coding jika perubahan tersebut belum diselaraskan ke dokumen authority.

---

## 7. Global MVP Release Gate

Sebelum Fase 1:

- [ ] Semua P0 PRD selesai
- [ ] Core Sellable end-to-end berjalan
- [ ] Billing subscription berjalan
- [ ] Theme dasar berjalan
- [ ] SEO dasar aktif
- [ ] Tenant isolation lulus CI
- [ ] RLS tenant context diuji
- [ ] Concurrent stock reservation lulus test
- [ ] Semua media production berada di R2
- [ ] Backup + restore berhasil diuji
- [ ] Lighthouse/performance target tercapai
- [ ] Rollback pernah diuji
- [ ] Design handoff checklist selesai

---

## 8. Strategy Model AI

Model AI yang ditetapkan di Prompt Development adalah rekomendasi efisiensi, bukan bagian dari application architecture. Prompt harus selalu membawa aturan non-negotiable yang relevan dengan tahap yang sedang dikerjakan.

AI agent bekerja terhadap monorepo dan wajib memahami:

```text
root docs
  ↓
apps/api + apps/web
  ↓
shared contracts only when needed
```

AI tidak boleh membuat repository kedua untuk API atau Web tanpa ADR dan perubahan Tech Spec.

---

## 9. Authority antar Dokumen

- **PRD** = business requirements dan acceptance criteria.
- **Tech Spec** = technical architecture/infrastructure.
- **Design Brief** = visual/interaction.
- **Master Plan** = dependency dan sequence.
- **Prompt Development** = eksekusi AI sesuai tiga authority di atas.

Jika ada konflik yang memengaruhi architecture atau scope, hentikan implementasi dan buat ADR/perubahan dokumen terlebih dahulu.
