# Tokospace — Technical Specification

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain** | tokospace.com |
| **Versi** | 2.4 |
| **Tanggal** | 18 Agustus 2026 |
| **Menggantikan** | `tokospace-tech-spec.md` v2.3 |
| **Status** | **Approved — Development Baseline** |
| **Selaras dengan** | `tokospace-PRD.md` v1.2, `tokospace-design-brief.md` v2.0, `tokospace-master-plan.md` v1.2, `tokospace-prompt-development.md` v1.3 |

### Changelog v2.4
- **Ini adalah architecture decision, bukan laporan implementasi.** Seluruh referensi Google Compute Engine/Cloud SQL/GCS/Cloud SQL Auth Proxy/Secret Manager di bawah adalah **TARGET architecture yang disetujui** (lihat `docs/adr/0001-gcp-cloud-sql-hosting-migration.md`). Repository saat ini (`main`) masih berada pada kondisi **pre-migration**: GitHub Secrets `ORACLE_SSH_HOST`/`ORACLE_SSH_USER`/`ORACLE_SSH_KEY`/`ORACLE_DEPLOY_ROOT` masih dipakai literal di `.github/workflows/api-deploy.yml` dan `rollback.yml`; `docker-compose.yml` masih memiliki service `postgres` self-hosted tanpa `cloud-sql-proxy`; `infra/scripts/deploy-release.sh` masih menjalankan `docker compose up -d postgres redis`; dan disk media production masih `r2` (Cloudflare R2) di `config/filesystems.php`. Implementasi kode untuk mencapai target ini adalah fase migrasi selanjutnya (Phase 5–8), di luar cakupan revisi dokumentasi ini.
- Backend hosting: TARGET berpindah dari Oracle Cloud Infrastructure (Always Free target) ke **Google Compute Engine** (`asia-southeast2`) — perpindahan hosting/compute target, bukan migrasi engine database (PostgreSQL sudah menjadi database engine sejak awal).
- Database: TARGET berpindah dari PostgreSQL self-hosted (Docker di VM) ke **Google Cloud SQL for PostgreSQL** (managed), diakses via Cloud SQL Auth Proxy (TCP, jaringan Docker Compose internal). Local development tetap memakai PostgreSQL self-hosted via Docker.
- Object storage: TARGET berpindah dari Cloudflare R2 ke **Google Cloud Storage (GCS)**, sesuai komponen arsitektur Google Cloud yang disetujui pada master migration prompt. Migrasi terjadi di level abstraksi filesystem Laravel (`config/filesystems.php`), tanpa mengubah kontrak upload di application layer. R2 tetap yang dipakai kode saat ini sampai Phase 7 (Storage Migration) dieksekusi.
- Secrets: TARGET kredensial produksi (`DB_PASSWORD`, kredensial GCS, dsb.) berpindah dari plaintext di `shared/apps-api.env` ke **Google Secret Manager**, diambil oleh GCE service account least-privilege (`Cloud SQL Client`, `Secret Manager Secret Accessor`).
- Pola tenant-context RLS (`SET LOCAL` dalam transaksi eksplisit) dicatat formal di `docs/adr/0002-tenant-rls-session-context.md` sebagai syarat wajib sebelum modul Tenant dibangun (belum diimplementasikan — Stage 0 murni infrastruktur) — lihat §4.4.
- Lihat `docs/adr/0001-gcp-cloud-sql-hosting-migration.md` untuk rasional lengkap dan pembagian current state/target state dari keputusan hosting/database/storage/secrets di atas.

---

## 0. Keputusan Final

**Stack (TARGET — lihat ADR-0001 untuk current state):** Laravel 11 API di Google Compute Engine (`asia-southeast2`) + Next.js 15 frontend di Vercel + Google Cloud SQL for PostgreSQL + Redis/Horizon (self-hosted di Compute Engine) + Google Cloud Storage. GitHub menjadi source of truth dan menggunakan **satu monorepo Tokospace**. CI/CD backend dan frontend tetap independen berdasarkan path/perubahan aplikasi.

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
4. Media production wajib disk object-storage produksi (§1.1) — Laravel filesystem abstraction, bukan disk lokal transient VM.
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
| Database | PostgreSQL 16 | TARGET: managed Google Cloud SQL for PostgreSQL (produksi) via Cloud SQL Auth Proxy; self-hosted Docker tetap dipakai untuk local dev. CURRENT: self-hosted Docker di produksi juga (belum bermigrasi — lihat ADR-0001) |
| Cache/Queue broker | Redis | Laravel cache + Horizon; self-hosted Docker, tidak diekspos publik (tidak berubah oleh migrasi ini) |
| Web server | Nginx + PHP-FPM | Backend reverse proxy |
| Process manager | Supervisor | Menjaga Horizon/worker |
| Storage | Google Cloud Storage | TARGET media production disk. CURRENT: Cloudflare R2 (`config/filesystems.php` disk `r2`) — migrasi disk belum dieksekusi, lihat ADR-0001 |
| Secrets | Google Secret Manager | TARGET penyimpanan kredensial produksi (DB, storage, dll.), diambil GCE service account. CURRENT: plaintext di `shared/apps-api.env` server — belum bermigrasi |
| Email | Resend | MVP provider |
| Error tracking | Sentry | Backend + frontend |
| Frontend hosting | Vercel | Auto-deploy dari GitHub monorepo |
| Backend hosting | Google Compute Engine (`asia-southeast2`) | TARGET environment; Docker Compose, tidak hard-dependent pada spesifikasi VM tertentu. Belum ada VM produksi yang di-provision — lihat ADR-0001 |

---

## 1.1 Storage Boundary

**Permanent/business media → disk object-storage produksi**, diakses melalui Laravel filesystem abstraction (`config/filesystems.php`), bukan SDK provider langsung — sehingga provider di baliknya dapat berpindah tanpa mengubah kontrak upload di application layer.

TARGET disk object-storage produksi: **Google Cloud Storage**. CURRENT (belum bermigrasi): Cloudflare R2 (disk `r2`) — lihat ADR-0001.

Disk ini wajib digunakan untuk:
- foto produk/varian;
- logo/banner/theme assets;
- bukti transfer;
- invoice;
- import/export files;
- dokumen bisnis permanen lainnya.

Compute Engine local disk hanya:
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
apps/api → Laravel → Cloud SQL (PostgreSQL) / Redis / GCS → Google Compute Engine   [TARGET]
apps/web → Next.js → Laravel API → Vercel
```

TARGET — lihat ADR-0001 untuk current state (masih Postgres self-hosted + R2, belum ada VM produksi ter-provision).

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
API deployment → Google Compute Engine   [TARGET — CURRENT: workflow masih membaca secrets.ORACLE_*, lihat ADR-0001]

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
       GOOGLE COMPUTE ENGINE TARGET ENV (asia-southeast2)
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
       Laravel      Cloud SQL Auth        Redis
       API/Auth/        Proxy           cache/queue
       business logic     │                 │
                           │                 ▼
                           │              Horizon
                           ▼
                Google Cloud SQL for PostgreSQL
                (managed, private tunnel via proxy)
                           │
                           ▼
                  Google Cloud Storage
                    permanent media
```

Seluruh diagram di atas adalah **TARGET** — belum ada VM produksi ter-provision saat ini; repository masih berjalan dengan Postgres self-hosted dan Cloudflare R2 (lihat `docs/adr/0001-gcp-cloud-sql-hosting-migration.md` §Current State).

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

Mekanisme yang dipilih: `SET LOCAL app.tenant_id = ?` di dalam transaksi eksplisit yang membungkus setiap request/job tenant-scoped — dicatat formal di `docs/adr/0002-tenant-rls-session-context.md`. `SET LOCAL` otomatis ter-reset saat transaksi berakhir (commit/rollback), sehingga aman dipakai ulang pada koneksi yang sama oleh request/job berikutnya tanpa reset manual — penting khususnya untuk worker Horizon yang me-reuse satu koneksi PDO lintas banyak job. Cloud SQL Auth Proxy adalah tunnel TCP transparan dan tidak mengubah semantik session/transaction ini. Pola ini wajib dipatuhi saat modul Tenant diimplementasikan dan tidak boleh diganti diam-diam.

---

## 5. Infrastructure Portability

Google Compute Engine adalah **target environment** untuk aplikasi (Laravel, Redis, Horizon), bukan hard dependency — arsitektur tetap portable ke VM/compute provider lain selama Docker Compose dan environment-driven tuning dipertahankan.

**TARGET** — database produksi menggunakan **Google Cloud SQL for PostgreSQL** (managed), PostgreSQL tidak lagi dijalankan sebagai service Docker di jalur produksi. **CURRENT** — `docker-compose.yml` masih menjalankan `postgres` sebagai service self-hosted di jalur produksi juga; migrasi ke Cloud SQL belum diimplementasikan. Lihat `docs/adr/0001-gcp-cloud-sql-hosting-migration.md` untuk rincian.

**TARGET** — service backend produksi dibungkus Docker Compose di Compute Engine:
- Nginx
- PHP-FPM
- Laravel
- Cloud SQL Auth Proxy (tunnel TCP ke Cloud SQL for PostgreSQL, jaringan Compose internal)
- Redis
- Horizon/worker

Local development akan tetap menjalankan PostgreSQL sebagai service Docker tambahan (bukan Cloud SQL) melalui compose override file setelah implementasi — lihat `infra/README.md`. Ini akan menjadi satu-satunya perbedaan topologi antara local dev dan produksi setelah migrasi selesai. **Saat ini** (sebelum implementasi) `docker-compose.yml` belum di-split; tidak ada `cloud-sql-proxy` maupun compose override file.

Environment-driven resource tuning:

```text
DB_* / PHP_FPM_* / REDIS_* / HORIZON_*
```

(`POSTGRES_*` hanya relevan pada override compose local dev, karena Cloud SQL mengelola tuning-nya sendiri di sisi managed service.)

Tidak boleh ada kode aplikasi yang mengasumsikan CPU/RAM VM tertentu.

### 5.1 Region & Cost Guardrails

TARGET — belum ada resource yang di-provision di GCP saat ini; bagian ini adalah acuan untuk provisioning di fase implementasi.

- Region produksi: `asia-southeast2` (Jakarta) — dipilih untuk latency terbaik ke pengguna Indonesia. Region adalah parameter provisioning/infrastructure, tidak boleh di-hardcode pada application code.
- Resource yang mengonsumsi kredit trial: Compute Engine VM (berjalan 24/7), Cloud SQL instance (berjalan 24/7 termasuk storage), Cloud Storage bucket (storage + egress bandwidth setelah migrasi dari R2 dieksekusi).
- Resource yang berpotensi menimbulkan biaya berkelanjutan setelah trial berakhir: Compute Engine VM, Cloud SQL instance, Cloud SQL automated backup storage, Cloud Storage (storage + egress — beda dari R2 yang tanpa biaya egress; jadikan pertimbangan cost saat Phase 7 Storage Migration dieksekusi).
- Resource yang tidak dibuat pada baseline ini (tidak ada kebutuhan bisnis yang mensyaratkan): load balancer, Kubernetes, multi-region, Memorystore, CDN, Cloud SQL read replica.
- Billing monitoring: budget alert GCP Console wajib dikonfigurasi sebelum provisioning — didokumentasikan sebagai langkah setup di `infra/README.md`, bukan bagian source code.

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
disk object-storage produksi (TARGET: GCS · CURRENT: R2 — lihat ADR-0001)
  ↓
metadata/key disimpan PostgreSQL
```

File permanent tidak pernah menjadi dependency filesystem lokal Compute Engine.

---

## 14. Backup & Recovery

Database backup terjadwal + restore test.

Backup harus:
- encrypted where applicable;
- retained according to release policy;
- stored separately from primary database disk;
- tested by restoring at least one sample backup before MVP Release.

Data retention/backup pada disk object-storage produksi mengikuti policy provider yang sedang dipakai (TARGET: GCS · CURRENT: R2); application metadata harus tetap menyimpan object key yang dapat direkonstruksi terlepas dari provider.

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
- Object-storage upload authorization.
- Audit logs untuk aksi privileged penting.
- TARGET, belum diimplementasikan (lihat ADR-0001): kredensial produksi (DB, object storage) di Google Secret Manager, bukan file plaintext di disk VM.
- TARGET: GCE service account least-privilege (`Cloud SQL Client`, `Secret Manager Secret Accessor`), bukan default service account.
- TARGET: Cloud SQL diakses via Cloud SQL Auth Proxy (autentikasi IAM), tidak diekspos ke internet publik.

---

## 16. Environment Separation

Minimum:

```text
development
preview/staging
production
```

Environment secrets disimpan pada secret manager/platform masing-masing, bukan repository — TARGET: Google Secret Manager untuk backend/Compute Engine (CURRENT: plaintext di `shared/apps-api.env`, lihat ADR-0001), Vercel environment variables untuk frontend (tidak berubah).

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
- RLS tenant context implementation strategy (`SET LOCAL` dalam transaksi) sudah dicatat sebagai ADR (`docs/adr/0002-tenant-rls-session-context.md`) sebelum modul tenant dibangun.
- Hosting/database/secrets target (Google Compute Engine, Cloud SQL for PostgreSQL, Secret Manager) sudah dicatat sebagai ADR (`docs/adr/0001-gcp-cloud-sql-hosting-migration.md`).

