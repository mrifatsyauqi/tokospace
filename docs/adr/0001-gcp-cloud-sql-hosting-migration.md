# ADR-0001 — Google Cloud Hosting + Cloud SQL for PostgreSQL Migration

| | |
|---|---|
| **Status** | Accepted |
| **Tanggal** | 18 Agustus 2026 |
| **Terkait** | `tokospace-tech-spec.md` §0, §1, §5, §5.1, §15 |

## Konteks

Tokospace sebelumnya menargetkan Oracle Cloud Infrastructure (OCI) Always
Free tier sebagai compute host untuk `apps/api` — Laravel, PostgreSQL
self-hosted, dan Redis semuanya berjalan sebagai service Docker Compose di
satu VM Oracle.

Audit repository (Phase 1 & 2 migrasi, lihat riwayat percakapan) memastikan
"Oracle" pada seluruh dokumentasi/kode hanya pernah berarti **Oracle Cloud
Infrastructure sebagai compute host** — bukan Oracle Database. PostgreSQL
sudah menjadi database engine Tokospace sejak awal proyek; tidak pernah ada
`oci8`, `pdo_oci`, atau Oracle SQL dialect di codebase. Migrasi ini karena
itu adalah **migrasi hosting provider + database management model**
(self-hosted → managed), bukan migrasi database engine.

## Keputusan

1. **Compute**: backend (`apps/api`) pindah ke **Google Compute Engine**,
   region `asia-southeast2` (Jakarta) — dipilih untuk latency terbaik ke
   pengguna Indonesia, menggantikan `ap-singapore-1` Oracle.
2. **Database**: produksi menggunakan **Google Cloud SQL for PostgreSQL 16**
   (managed), bukan lagi self-hosted di Docker Compose. Local development
   tetap memakai PostgreSQL self-hosted via Docker (override compose file)
   — tidak ada alasan mempersulit dev lokal dengan dependency Cloud SQL.
3. **Koneksi ke Cloud SQL**: **Cloud SQL Auth Proxy over TCP**, berjalan
   sebagai service `cloud-sql-proxy` di jaringan Docker Compose internal
   (bukan Unix socket). Laravel connect seperti biasa:
   `DB_HOST=cloud-sql-proxy`, `DB_PORT=5432`; driver `pgsql` tidak berubah.
   Alasan TCP dipilih atas Unix socket: proyek sudah punya pola koneksi
   service-to-service via nama service di jaringan Compose (`redis`
   sekarang) — TCP mempertahankan pola yang sama persis tanpa menambah
   kebutuhan shared-volume/socket-file antar container. Sesuai prioritas
   proyek (Correctness → **Simplicity** → Maintainability → Security →
   Cost Efficiency → Scalability), Unix socket menambah kompleksitas
   operasional tanpa manfaat berarti pada skala satu VM.
4. **Object storage**: **Cloudflare R2 dipertahankan** — tidak diganti
   Google Cloud Storage. Tidak ada kebutuhan bisnis/teknis yang
   mensyaratkan penggantian; R2 tidak membebankan biaya egress bandwidth
   (signifikan untuk media e-commerce), dan mengganti storage provider
   semata-mata karena pindah compute provider adalah overengineering yang
   secara eksplisit dilarang oleh master migration prompt ini sendiri.
5. **Deployment mechanism**: **dipertahankan** — GitHub Actions → SSH →
   release-folder + atomic symlink + rollback, target berpindah ke GCE VM.
   Pattern ini baru dibangun dan diverifikasi penuh di Stage 0 (termasuk
   rollback capability); mengganti ke Cloud Run/Cloud Build berarti
   containerizing ulang seluruh model deployment tanpa kebutuhan yang
   diminta.
6. **Redis/Horizon**: **dipertahankan** self-hosted via Docker Compose di
   GCE VM yang sama — bukan Memorystore. Redis sudah menjadi dependency
   yang ada (dibutuhkan Horizon queue), bukan penambahan baru; memindahkan
   ke Memorystore adalah biaya tambahan tanpa kebutuhan yang jelas saat
   ini. Redis tetap tidak diekspos publik.
7. **Secrets**: kredensial produksi (`DB_PASSWORD`, kredensial R2, dll.)
   pindah dari plaintext di `$DEPLOY_ROOT/shared/apps-api.env` ke **Google
   Secret Manager**. GCE VM menggunakan service account least-privilege
   dengan scope `roles/cloudsql.client` +
   `roles/secretmanager.secretAccessor` — bukan default Compute Engine
   service account. Tidak ada credential yang di-commit ke GitHub.
8. **GitHub Secrets**: `ORACLE_SSH_HOST`/`ORACLE_SSH_USER`/`ORACLE_SSH_KEY`/
   `ORACLE_DEPLOY_ROOT` di-rename menjadi `GCE_SSH_HOST`/`GCE_SSH_USER`/
   `GCE_SSH_KEY`/`GCE_DEPLOY_ROOT`.

## Konsekuensi

- `docker-compose.yml` (produksi) tidak lagi memuat service `postgres`;
  `php`/`horizon`/`scheduler` bergantung pada `redis` + `cloud-sql-proxy`.
  Local dev memakai compose override yang menambahkan kembali `postgres`.
- `infra/scripts/deploy-release.sh` tidak lagi menjalankan
  `docker compose up -d postgres redis` di server produksi — hanya
  `redis` (dan `cloud-sql-proxy`).
- `BackupDatabase.php` tidak berubah secara logic — `pg_dump` sudah
  membaca host/port dari koneksi database aktif, otomatis mengarah ke
  `cloud-sql-proxy` begitu env var berubah. Cloud SQL automated
  backups/PITR diaktifkan sebagai lapisan tambahan, bukan pengganti
  backup R2 custom yang sudah ada.
- Cloud SQL Auth Proxy adalah tunnel TCP transparan — tidak mengubah
  semantik session/transaction PostgreSQL. Ini relevan untuk implementasi
  RLS tenant context di masa depan — lihat
  `docs/adr/0002-tenant-rls-session-context.md`.
- Biaya berjalan sejak Cloud SQL instance dibuat (berbeda dari GCE VM yang
  punya opsi always-free tier tertentu) — budget alert GCP Console wajib
  dikonfigurasi sebelum provisioning (lihat Tech Spec §5.1).

## Alternatif yang dipertimbangkan dan ditolak

- **Google Cloud Storage menggantikan R2** — ditolak, lihat poin 4 di atas.
- **Self-hosted PostgreSQL di Compute Engine (bukan Cloud SQL)** — ditolak;
  master migration prompt eksplisit melarang menjalankan PostgreSQL di
  Compute Engine ketika Cloud SQL menjadi database utama, dan Cloud SQL
  memberi automated backup/HA yang tidak dimiliki setup self-hosted saat
  ini.
- **Cloud Run/Cloud Build sebagai target deployment** — ditolak, lihat
  poin 5 di atas.
- **Cloud SQL Auth Proxy mode Unix socket** — ditolak, lihat poin 3 di
  atas.
- **Google Memorystore untuk Redis** — ditolak, lihat poin 6 di atas.
