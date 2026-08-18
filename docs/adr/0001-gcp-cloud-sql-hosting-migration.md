# ADR-0001 — Google Cloud Hosting + Cloud SQL for PostgreSQL Migration

| | |
|---|---|
| **Status** | Accepted (decision only — infrastructure/deploy code not yet implemented) |
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

**Dokumen ini adalah architecture decision record — bukan laporan status
implementasi.** Bagian Current State di bawah menggambarkan apa yang
benar-benar berjalan di repository (`main`) pada saat ADR ini ditulis;
bagian Target State menggambarkan arsitektur yang disetujui untuk dituju.
Selisih antara keduanya adalah pekerjaan implementasi fase migrasi
selanjutnya (Phase 5 — Laravel Configuration, Phase 6 — Google Cloud
Infrastructure, Phase 7 — Storage Migration, Phase 8 — GitHub/CI-CD, per
execution order master migration prompt), **di luar cakupan PR
dokumentasi ini.**

## Current State (pre-migration, kondisi repository saat ini)

- Compute: tidak ada VM produksi yang benar-benar di-provision — Stage 0
  hanya membangun dan memverifikasi stack secara lokal (Docker Compose) +
  CI. `.github/workflows/api-deploy.yml` dan `rollback.yml` membaca
  `secrets.ORACLE_SSH_HOST` / `ORACLE_SSH_USER` / `ORACLE_SSH_KEY` /
  `ORACLE_DEPLOY_ROOT` — nama secret ini masih literal `ORACLE_*` di kedua
  workflow.
- Database: `docker-compose.yml` (root) memiliki service `postgres`
  (self-hosted PostgreSQL 16), dan `php`/`horizon`/`scheduler`
  `depends_on` service ini secara langsung. Tidak ada service
  `cloud-sql-proxy`.
- Deploy script: `infra/scripts/deploy-release.sh` menjalankan
  `docker compose up -d postgres redis` di server target pada first
  deploy.
- Object storage: `config/filesystems.php` menggunakan disk `r2`
  (Cloudflare R2, S3-compatible) sebagai disk media production default —
  ini yang benar-benar dipakai kode saat ini.
- Secrets: kredensial (`DB_PASSWORD`, kredensial R2) disimpan sebagai
  plaintext di `$DEPLOY_ROOT/shared/apps-api.env` di server target (pola
  yang sudah ada sejak Stage 0, belum diubah).

## Target State (disetujui, menunggu implementasi)

1. **Compute**: backend (`apps/api`) pindah ke **Google Compute Engine**,
   region `asia-southeast2` (Jakarta) — dipilih untuk latency terbaik ke
   pengguna Indonesia, menggantikan asumsi `ap-singapore-1` Oracle.
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
4. **Object storage**: **Google Cloud Storage (GCS)** — sesuai arsitektur
   Google Cloud yang disetujui pada master migration prompt (komponen
   "Cloud Storage — Files/Media"). Cloudflare R2 yang dipakai saat ini
   **bermigrasi ke GCS**, bukan dipertahankan permanen. Migrasi dilakukan
   pada level abstraksi filesystem Laravel (`config/filesystems.php`) —
   disk driver berubah dari S3-compatible (R2) ke GCS, tanpa mengubah
   kontrak upload/media di application layer (Order/Catalog/Theme module
   tetap memanggil `Storage::disk(...)`, bukan SDK provider langsung).
   Perubahan kode filesystem ini **tidak dilakukan pada PR dokumentasi
   ini** — ini adalah Phase 7 (Storage Migration) pada execution order.
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
7. **Secrets**: kredensial produksi (`DB_PASSWORD`, kredensial GCS, dll.)
   pindah dari plaintext di `$DEPLOY_ROOT/shared/apps-api.env` ke **Google
   Secret Manager**. GCE VM menggunakan service account least-privilege
   dengan scope `roles/cloudsql.client` +
   `roles/secretmanager.secretAccessor` — bukan default Compute Engine
   service account. Tidak ada credential yang di-commit ke GitHub.
8. **GitHub Secrets**: `ORACLE_SSH_HOST`/`ORACLE_SSH_USER`/`ORACLE_SSH_KEY`/
   `ORACLE_DEPLOY_ROOT` akan di-rename menjadi `GCE_SSH_HOST`/
   `GCE_SSH_USER`/`GCE_SSH_KEY`/`GCE_DEPLOY_ROOT` **pada saat workflow
   file diperbarui di fase implementasi** — rename secret dan update
   workflow harus terjadi dalam PR/commit yang sama agar deploy/rollback
   tidak pernah membaca secret kosong di antara keduanya.

## Konsekuensi (berlaku setelah implementasi Phase 5–8, belum berlaku sekarang)

- `docker-compose.yml` (produksi) akan berhenti memuat service `postgres`;
  `php`/`horizon`/`scheduler` akan bergantung pada `redis` +
  `cloud-sql-proxy`. Local dev akan memakai compose override yang
  menambahkan kembali `postgres`. **Belum diterapkan** — `docker-compose.yml`
  saat ini masih memiliki service `postgres` dan tidak ada
  `cloud-sql-proxy`.
- `infra/scripts/deploy-release.sh` akan berhenti menjalankan
  `docker compose up -d postgres redis` di server produksi, digantikan
  `redis` (dan `cloud-sql-proxy`) saja. **Belum diterapkan** — script saat
  ini masih menjalankan `docker compose up -d postgres redis`.
- `BackupDatabase.php` tidak perlu berubah secara logic — `pg_dump` sudah
  membaca host/port dari koneksi database aktif, otomatis mengarah ke
  `cloud-sql-proxy` begitu env var berubah di fase implementasi. Cloud SQL
  automated backups/PITR akan diaktifkan sebagai lapisan tambahan begitu
  instance dibuat, bukan pengganti backup object-storage custom yang sudah
  ada.
- `config/filesystems.php` akan menambah/mengganti disk target media
  production ke GCS. **Belum diterapkan** — disk `r2` masih yang dipakai
  kode saat ini.
- `.github/workflows/api-deploy.yml` dan `rollback.yml` akan di-update
  untuk membaca `secrets.GCE_*` menggantikan `secrets.ORACLE_*`. **Belum
  diterapkan** — kedua workflow saat ini masih membaca `secrets.ORACLE_*`
  secara literal; jangan rename/hapus secret `ORACLE_*` di GitHub sampai
  workflow ini benar-benar diperbarui pada commit yang sama, atau setiap
  deploy/rollback akan menerima host/key kosong dan gagal.
- Cloud SQL Auth Proxy adalah tunnel TCP transparan — tidak mengubah
  semantik session/transaction PostgreSQL. Ini relevan untuk implementasi
  RLS tenant context di masa depan — lihat
  `docs/adr/0002-tenant-rls-session-context.md`.
- Biaya berjalan sejak Cloud SQL instance dibuat (berbeda dari GCE VM yang
  punya opsi always-free tier tertentu) — budget alert GCP Console wajib
  dikonfigurasi sebelum provisioning (lihat Tech Spec §5.1).

## Alternatif yang dipertimbangkan dan ditolak

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
- **Mempertahankan Cloudflare R2 secara permanen** — dipertimbangkan
  (R2 tanpa biaya egress, sudah teruji sejak Stage 0), tetapi ditolak
  karena master migration prompt eksplisit menetapkan Google Cloud
  Storage sebagai komponen arsitektur target (§2, §14). Lihat poin 4 di
  atas untuk rencana migrasi tanpa mengubah kontrak application layer.
