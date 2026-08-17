# Tokospace — Technical Specification

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain** | tokospace.com |
| **Versi** | 2.3 |
| **Tanggal** | 17 Agustus 2026 |
| **Menggantikan** | `tokospace-tech-spec.md` v2.2 |
| **Status** | **Approved — Development Baseline** |
| **Selaras dengan** | `tokospace-PRD.md` v1.2, `tokospace-design-brief.md` v2.0, `tokospace-master-plan.md` v1.2, `tokospace-prompt-development.md` v1.3 |

---

## 0. Keputusan Final

**Stack:** Laravel 11 API di Oracle Cloud target environment + Next.js 15 frontend di Vercel + PostgreSQL + Redis/Horizon + Cloudflare R2. GitHub menjadi source of truth dan menggunakan **satu monorepo Tokospace**. CI/CD backend dan frontend tetap independen berdasarkan path/perubahan aplikasi.

### 0.1 Architecture Boundaries

- **PRD** menentukan business requirements.
- **Tech Spec** menentukan technical architecture/infrastructure.
- **Design Brief** menentukan visual/interaction.
- **Master Plan** menentukan dependency/sequence.
- **Prompt Development** menjadi instruksi AI yang tunduk pada keempat authority di atas.

### 0.2 Non-Negotiable Architecture Rules

1. Next.js **tidak mengakses PostgreSQL langsung**; seluruh business/API access melalui Laravel.
2. Semua data tenant-aware wajib `tenant_id` + Global Scope + Policy + PostgreSQL RLS.
3. Tenant context untuk RLS tidak boleh berasal dari raw client input.
4. Media production wajib R2; Oracle filesystem hanya transient.
5. Payment customer→seller menggunakan credential seller sendiri (Midtrans/Tripay pada baseline). Payment subscription seller→Tokospace menggunakan gateway platform Tokospace. Dua context tidak boleh bercampur.
6. Order module tidak boleh mengimpor SDK/provider langsung. Provider abstraction wajib dipakai.
7. Webhook wajib signature-verified dan idempotent.
8. Custom-domain UI adalah P1, tetapi tenant/domain model sudah menjadi P0 foundation.
9. Tidak ada seller wallet/payout/transaction-fee ledger pada baseline.
10. Backend dan frontend berada dalam satu monorepo tetapi tetap merupakan dua application boundaries dan dua deployment pipelines.
11. Perubahan arsitektur yang melanggar aturan di atas memerlukan ADR + perubahan PRD/Tech Spec sebelum coding.

---

## 1. Stack Final

| Lapisan | Pilihan | Keterangan |
|---|---|---|
| Backend API | Laravel 11 + PHP 8.3 | Eloquent, Sanctum, Horizon, Scheduler |
| Frontend | Next.js 15 + TypeScript | App Router, SSR/ISR, route groups |
| Database | PostgreSQL 16 | Self-hosted pada Oracle target environment |
| Cache/Queue broker | Redis | Laravel cache + Horizon |
| Web server | Nginx + PHP-FPM | Backend reverse proxy |
| Process manager | Supervisor | Menjaga Horizon/worker |
| Storage | Cloudflare R2 | S3-compatible permanent media |
| Email | Resend | MVP provider |
| Error tracking | Sentry | Backend + frontend |
| Frontend hosting | Vercel | Auto-deploy dari GitHub monorepo |
| Backend hosting | Oracle Cloud Always Free target | Docker Compose; tidak hard-dependent |

---

## 1.1 Storage Boundary

**Permanent/business media → R2.**

R2 wajib digunakan untuk:
- foto produk/varian;
- logo/banner/theme assets;
- bukti transfer;
- invoice;
- import/export files;
- dokumen bisnis permanen lainnya.

Oracle local disk hanya:
- temp upload/process;
- application/web logs;
- framework cache;
- generated transient files.

`storage/app/public` **tidak boleh** menjadi source of truth media production.

---

## 2. Repository & Application Architecture

Tokospace menggunakan **monorepo** sebagai source of truth untuk dokumentasi, backend, frontend, dan infrastructure configuration.

```text
tokospace/
├── apps/
│   ├── api/                 # Laravel 11 backend
│   └── web/                 # Next.js 15 frontend
├── docs/                    # PRD, Tech Spec, Design Brief, Master Plan, AI prompts
├── infra/                   # Docker, Nginx, deployment/ops scripts
├── packages/                # Shared generated contracts/types only when needed
├── .github/
│   └── workflows/           # Independent API/Web CI/CD workflows
├── AGENTS.md                # Global AI/repository rules
└── README.md
```

### 2.1 Application Boundaries

Monorepo **tidak berarti satu application**.

```text
apps/api → Laravel → PostgreSQL/Redis/R2 → Oracle
apps/web → Next.js → Laravel API → Vercel
```

Rules:

- `apps/web` tidak boleh mengakses database, Redis, atau internal Laravel classes.
- `apps/api` menjadi authority untuk business logic, authorization, tenant isolation, orders, payments, and persistence.
- `apps/web` menjadi authority untuk presentation, SSR/ISR, storefront, dashboard, and admin frontend.
- Shared code hanya boleh ditempatkan di `packages/` jika memang reusable dan tidak membocorkan backend internals.
- Generated API types/contracts boleh dibagikan; model Eloquent, service Laravel, secret, atau database code tidak boleh di-import frontend.

### 2.2 Local Development

Root repository menyediakan satu developer entry point untuk menjalankan service yang diperlukan.

Target development flow:

```text
clone tokospace
   ↓
docker compose / documented dev command
   ├── Laravel API
   ├── PostgreSQL
   ├── Redis/Horizon
   └── Next.js web
```

Frontend dan backend boleh dijalankan pada port berbeda, tetapi boundary komunikasi tetap HTTP API.

### 2.3 CI/CD Boundary

Satu monorepo menggunakan pipeline terpisah:

```text
apps/api/**
  ↓
API CI
  ↓
API deployment → Oracle

apps/web/**
  ↓
Web CI
  ↓
Vercel deployment
```

Perubahan `docs/**` saja tidak boleh memicu deployment aplikasi. Perubahan `infra/**` atau root configuration dapat memicu pipeline yang relevan berdasarkan aturan workflow.

---

## 3. Arsitektur Runtime

```text
                         VERCEL
                   Next.js 15 + TS
             ┌─────────────┼─────────────┐
             │             │             │
         marketing      dashboard     storefront/admin
             │             │             │
             └─────────────┼─────────────┘
                           │ HTTPS
                           ▼
                    api.tokospace.com
                           │
                   ORACLE TARGET ENV
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
       Laravel          PostgreSQL        Redis
       API/Auth/         database         cache/queue
       business logic                     │
                                          ▼
                                       Horizon
                           │
                           ▼
                    Cloudflare R2
                    permanent media
```

---

## 4. Tenant Resolution & Isolation

### 4.1 Public Storefront

```text
Customer request
      ↓
Host/domain
      ↓
Next.js middleware identifies hostname
      ↓
Laravel TenantResolver validates domain
      ↓
tenant_id
      ↓
tenant-scoped query
```

Next.js boleh membantu routing, tetapi **Laravel adalah source of truth untuk tenant validation**.

Public endpoint tidak menerima `tenant_id` mentah sebagai sumber otoritas.

### 4.2 Seller Dashboard

```text
Seller login
   ↓
Sanctum identity
   ↓
TenantContext dari authenticated user
   ↓
Policy + Global Scope
   ↓
PostgreSQL RLS
```

### 4.3 Domain Model

Minimum:

```text
tenants
- id
- slug
- name
- status

domains
- id
- tenant_id
- domain
- type (subdomain|custom)
- is_primary
- status
- verified_at
```

Canonical subdomain dibuat sejak Tahap 1. Custom domain hanya menambah record dan Vercel integration pada Tahap 7.

---

## 4.4 PostgreSQL RLS Tenant Context

RLS wajib mempunyai tenant context yang konsisten dengan Laravel request context.

Aturan implementasi:

1. Request masuk.
2. Laravel melakukan authentication/tenant resolution.
3. Laravel menetapkan tenant context **server-side** untuk transaksi/database session menggunakan mekanisme yang aman dan terdokumentasi di migration/policy.
4. Query tenant-aware berjalan di bawah RLS.
5. Tenant context dibersihkan di akhir transaksi/request sesuai connection lifecycle.

Pola konseptual:

```text
Request
  ↓
TenantResolver / Auth
  ↓
TenantContext
  ↓
DB transaction/session context
  ↓
PostgreSQL RLS
```

**Larangan:** `tenant_id` dari query string/body/header yang tidak tervalidasi tidak boleh menjadi nilai RLS.

RLS tests wajib membuktikan:
- tenant A tidak dapat SELECT tenant B;
- tenant A tidak dapat UPDATE/DELETE tenant B;
- privileged Super Admin path adalah explicit dan teruji.

Detail mekanisme PostgreSQL session context yang dipilih saat implementasi harus dicatat dalam ADR dan tidak boleh diganti diam-diam.

---

## 5. Infrastructure Portability

Oracle adalah **target environment**, bukan hard dependency.

Semua service backend dibungkus Docker Compose:
- Nginx
- PHP-FPM
- Laravel
- PostgreSQL
- Redis
- Horizon/worker

Environment-driven resource tuning:

```text
DB_* / POSTGRES_* / PHP_FPM_* / REDIS_* / HORIZON_*
```

Tidak boleh ada kode aplikasi yang mengasumsikan CPU/RAM Oracle tertentu.

---

## 6. Domain & Vercel

### 6.1 Canonical Subdomain

Tahap 1 harus menghasilkan:

```text
namatoko.tokospace.com
        ↓
Vercel
        ↓
Next.js
        ↓
Laravel TenantResolver
        ↓
Tenant
```

### 6.2 Custom Domain

Fitur seller custom domain dilakukan pada Tahap 7.

Laravel menggunakan abstraction:

```text
VercelDomainService
├── add()
├── status()
└── remove()
```

**Implementation rule:** gunakan **latest supported Vercel Domains API** pada saat coding. Versi endpoint/API path yang tertulis di dokumen sebelumnya adalah implementation detail, bukan contract bisnis.

Vercel menjadi source of truth untuk domain verification/SSL status jika API menyediakan status tersebut.

---

## 7. Deployment

### Backend

```text
feature branch
   ↓
Pull Request
   ↓
API CI
   ├── tests
   ├── static/architecture checks
   └── build/deploy validation
   ↓
merge main
   ↓
release folder
   ↓
atomic symlink switch
   ↓
Laravel migrate/optimize
   ↓
queue restart
```

Deployment workflow berada di `.github/workflows/` dan hanya menjalankan backend deployment ketika perubahan backend/infrastructure yang relevan terjadi.

Rollback harus dapat mengubah symlink ke release sebelumnya tanpa rebuild source.

### Frontend

```text
GitHub monorepo
  ↓
Vercel project (root directory: apps/web)
  ↓
Preview
  ↓
Production after merge
```

Vercel harus dikonfigurasi dengan root directory `apps/web` sehingga frontend deployment tidak memperlakukan seluruh monorepo sebagai Next.js project.

---

## 8. Payment Architecture

### 8.1 Platform Subscription

```text
Seller
 ↓
Tokospace billing
 ↓
Tokospace-owned gateway account
```

### 8.2 Tenant Customer Payment

```text
Customer
 ↓
Tenant storefront
 ↓
Laravel PaymentService
 ↓
PaymentProviderInterface
 ├── MidtransProvider
 └── TripayProvider
 ↓
Seller-owned provider account
 ↓
Seller settlement
```

Seller credentials encrypted server-side.

Order module hanya mengenal:

```text
PaymentProviderInterface
```

dan tidak boleh tahu detail SDK Midtrans/Tripay.

Webhook flow:

```text
provider webhook
      ↓
signature verification
      ↓
idempotency/event uniqueness
      ↓
transaction persistence
      ↓
order state transition
      ↓
optional queued notification
```

---

## 9. Queue, Scheduler & Horizon

Laravel Scheduler menjadi scheduler utama backend.

Horizon mengelola queue.

```text
Scheduler/Event
      ↓
Dispatch Job
      ↓
Redis
      ↓
Horizon Worker
```

Scheduled jobs dan jobs dari webhook wajib idempotent.

Contoh:
- expire unpaid orders;
- restore stock;
- daily analytics aggregation;
- email/notification;
- provider synchronization.

---

## 10. Modular Architecture

Backend:

```text
apps/api/app/Modules/
├── Tenant
├── Auth
├── Catalog
├── Order
├── Payment
├── Shipping
├── Billing
├── Theme
├── Domain
├── Notification
├── Discount
├── Analytics
├── Return
└── Admin
```

Aturan:

```text
Controller
  ↓
Service / Use Case
  ↓
Repository
  ↓
Model / Database
```

Provider-dependent integrations hanya melalui interface/contract.

Repository guidance berada di root `AGENTS.md`; backend-specific guidance dapat berada di `apps/api/CLAUDE.md` bila diperlukan. Jangan membuat duplikasi aturan yang saling bertentangan.

---

## 11. API Contract

Laravel menghasilkan OpenAPI.

Next.js generate TypeScript types dari OpenAPI pada CI.

```text
apps/api
 ↓
OpenAPI
 ↓
openapi-typescript
 ↓
packages/api-types atau apps/web/generated
 ↓
apps/web
```

Generated contract harus berasal dari backend; frontend tidak boleh mendefinisikan ulang response shape secara manual jika type sudah tersedia.

Breaking API change harus terdeteksi di CI sebelum merge.

---

## 12. Performance & Caching

Prinsip: traffic customer tidak boleh 1:1 terhadap Postgres queries.

### Layer 1 — Next.js

Catalog/storefront boleh menggunakan ISR/tag-based cache.

### Layer 2 — Laravel Redis

Cache key harus tenant-aware:

```text
tenant:{tenant_id}:product:{slug}
tenant:{tenant_id}:category:{slug}
```

### Layer 3 — PostgreSQL

Gunakan index dan eager loading; hindari N+1.

### Dynamic Data

No stale cache untuk:
- cart
- checkout
- account
- order
- stock reservation
- payment state

### Cache Invalidation Contract

Semua invalidasi dilakukan melalui satu abstraction:

```text
CacheInvalidationService
├── invalidateRedis(...)
└── requestNextRevalidation(...)
```

Catalog/Theme changes → `CacheInvalidationService` → Redis invalidation + Next.js revalidation.

Jangan menyebarkan raw HTTP revalidation calls ke banyak model event/controller.

---

## 13. Storage & Upload Flow

```text
Browser
  ↓
Laravel upload authorization
  ↓
presigned/direct upload atau server upload sesuai kebutuhan
  ↓
R2
  ↓
metadata/key disimpan PostgreSQL
```

File permanent tidak pernah menjadi dependency filesystem Oracle.

---

## 14. Backup & Recovery

Database backup terjadwal + restore test.

Backup harus:
- encrypted where applicable;
- retained according to release policy;
- stored separately from primary database disk;
- tested by restoring at least one sample backup before MVP Release.

R2 data retention/backup mengikuti object-storage policy provider; application metadata harus tetap menyimpan object key yang dapat direkonstruksi.

---

## 15. Security Checklist

- HTTPS.
- Encrypted third-party credentials.
- Secure auth/session handling.
- Rate limiting.
- Webhook signature verification.
- Idempotency.
- Tenant Global Scope.
- PostgreSQL RLS.
- Laravel Policies.
- No secrets in source.
- File type/size validation.
- R2 upload authorization.
- Audit logs untuk aksi privileged penting.

---

## 16. Environment Separation

Minimum:

```text
development
preview/staging
production
```

Environment secrets disimpan pada secret manager/platform masing-masing, bukan repository.

---

## 17. Readiness Gate

Tahap 0 boleh dimulai setelah:

- PRD v1.2 berstatus Approved.
- Master Plan v1.2 berstatus Approved.
- Design Brief v2.0 menjadi visual authority.
- Prompt Development v1.3 memiliki NON-NEGOTIABLE rules.
- D1/D2/D3 final.
- Monorepo strategy final: `apps/api` + `apps/web` dalam satu repository.
- Domain foundation dipastikan Tahap 1.
- RLS tenant context implementation strategy dicatat sebagai ADR sebelum modul tenant selesai.

