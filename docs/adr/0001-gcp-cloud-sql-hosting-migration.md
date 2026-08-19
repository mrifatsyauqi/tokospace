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
   `ORACLE_DEPLOY_ROOT` menjadi `GCP_SSH_HOST`/`GCP_SSH_USER`/`GCP_SSH_KEY`/
   `GCP_DEPLOY_ROOT` di workflow — rename secret aktual di GitHub Settings
   harus terjadi bersamaan (bukan sebelum) workflow file diperbarui, agar
   deploy/rollback tidak pernah membaca secret kosong di antara keduanya.

## Status implementasi (diperbarui setelah Phase 1 — repository changes)

Perubahan **kode repository** untuk poin 2–8 di atas sudah diterapkan:
`docker-compose.yml` sudah tidak memuat `postgres` di jalur produksi dan
sudah punya service `cloud-sql-proxy`; `docker-compose.local.yml` menambahkan
kembali `postgres` untuk local dev; `infra/scripts/deploy-release.sh` sudah
menjalankan `redis`+`cloud-sql-proxy`; disk `gcs` sudah terdaftar di
`config/filesystems.php` dan dipakai `BackupDatabase.php`; kedua workflow
deploy/rollback sudah membaca `secrets.GCP_*`.

**Yang BELUM diterapkan** (infrastruktur GCP, di luar cakupan Phase 1 —
repository changes only): instance Cloud SQL belum di-provision (nilai
`CLOUD_SQL_CONNECTION_NAME` masih kosong di `.env.example`), bucket GCS
belum dibuat (`GCS_PROJECT_ID`/`GCS_BUCKET` masih kosong), Secret Manager
belum diisi, dan secret `GCP_SSH_*`/`GCP_DEPLOY_ROOT` **belum benar-benar
dibuat** di GitHub — secret `ORACLE_*` yang lama juga belum dihapus. Jangan
hapus secret `ORACLE_*` sampai secret `GCP_*` yang baru benar-benar dibuat
dan diverifikasi bekerja, karena workflow sekarang membaca nama yang baru.

## Konsekuensi (rincian per file — status implementasi per item di atas)

- `docker-compose.yml` (produksi) tidak lagi memuat service `postgres`;
  `php`/`horizon`/`scheduler` bergantung pada `redis` + `cloud-sql-proxy`
  (gated di belakang Compose profile `production`). Local dev memakai
  `docker-compose.local.yml` yang menambahkan kembali `postgres`. **Repo:
  diterapkan.** Cloud SQL instance-nya sendiri belum ada — service
  `cloud-sql-proxy` tidak akan bisa benar-benar konek sampai
  `CLOUD_SQL_CONNECTION_NAME` diisi nilai nyata (Phase 2 infrastructure).
- `infra/scripts/deploy-release.sh` dan `rollback.sh` menjalankan
  `export COMPOSE_PROFILES=production` di awal (wajib — dikonfirmasi lewat
  `docker compose config`/`restart`: tanpa ini Compose menolak seluruh file
  karena `cloud-sql-proxy` ter-gate profile). `deploy-release.sh` sekarang
  menjalankan `docker compose up -d redis cloud-sql-proxy`, dan attempt
  migration pertama di-retry (10×/3s) karena `cloud-sql-proxy` tidak punya
  Docker healthcheck (image distroless, tidak ada shell/tooling untuk
  `CMD`-based probe — dikonfirmasi dengan inspeksi image langsung). **Repo:
  diterapkan.**
- `BackupDatabase.php` — logic tidak berubah, disk target diganti ke `gcs`.
  `pg_dump` sudah membaca host/port dari koneksi database aktif, otomatis
  mengarah ke `cloud-sql-proxy` begitu env var produksi diisi. **Repo:
  diterapkan.** Cloud SQL automated backups/PITR akan diaktifkan sebagai
  lapisan tambahan begitu instance dibuat (Phase 2 infrastructure), bukan
  pengganti backup object-storage custom yang sudah ada.
- `config/filesystems.php` menambahkan disk `gcs` (driver didaftarkan di
  `AppServiceProvider::boot()` — Laravel core tidak mengenali `gcs` secara
  native), menjadi default disk baru. Disk `r2` tetap ada untuk masa
  transisi. **Repo: diterapkan** (`league/flysystem-google-cloud-storage`
  ditambahkan ke `composer.json`). `GCS_PROJECT_ID`/`GCS_BUCKET` masih
  kosong — bucket-nya sendiri belum dibuat (Phase 2 infrastructure).
- `.github/workflows/api-deploy.yml` dan `rollback.yml` membaca
  `secrets.GCP_*` menggantikan `secrets.ORACLE_*`. **Repo: diterapkan.**
  Secret `GCP_*` yang baru **belum benar-benar dibuat** di GitHub — jangan
  hapus secret `ORACLE_*` lama sampai `GCP_*` dibuat dan diverifikasi
  bekerja, karena workflow sekarang membaca nama yang baru dan deploy akan
  gagal dengan host/key kosong sampai itu terjadi.
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
