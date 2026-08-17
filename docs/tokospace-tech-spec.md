# Tokospace — Technical Specification

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain** | tokospace.com |
| **Versi** | 2.1 |
| **Tanggal** | 17 Agustus 2026 |
| **Menggantikan** | `tokospace-tech-spec.md` v2.0 |
| **Selaras dengan** | `tokospace-PRD.md` v1.1, `tokospace-design-brief.md` v2.0 |

---

## 0. Keputusan Final & Changelog

**Stack: Laravel (API) di Oracle Cloud Always Free + Next.js (frontend) di Vercel**, dihubungkan lewat GitHub Actions untuk CI/CD penuh tanpa PC. Ini mengonfirmasi ulang stack yang sudah ditetapkan PRD v1.1 §6.1 — **PRD tidak perlu diubah**.

### Changelog v2.1 (revisi atas 4 poin)

1. **Oracle jadi "target environment", bukan hard dependency** (§4) — semua service dibungkus Docker Compose, resource limit dihitung dari env var lewat `scripts/tune.sh`, bukan angka tetap. Pindah ke spek lain (4 vCPU/8GB, 8 vCPU/16GB, atau VPS lain) jadi operasi konfigurasi, bukan migrasi kode
2. **Storage dipisah tegas** (§1.1) — Oracle disk lokal hanya untuk temp/log/cache; semua media produksi (foto produk, logo, banner, invoice, import/export) wajib lewat R2, tidak pernah lewat `storage/app/public`
3. **Domain & DNS ditulis ulang berdasarkan verifikasi ke dokumentasi Vercel Platforms terkini** (§5) — custom domain tenant ternyata bisa **full otomatis** lewat Vercel Domains API (bukan verifikasi manual via cron seperti asumsi sebelumnya)
4. **Strategi caching berlapis ditulis eksplisit** (§10) — 3 lapis pertahanan (Next.js tag-based cache → Redis → query database) supaya traffic tidak proporsional 1:1 ke Postgres, dengan pengecualian tegas untuk data dinamis (keranjang/checkout/akun/pesanan)

**Koreksi atas v1.0**: klaim sebelumnya "Laravel tidak bisa di-deploy dari HP" terlalu tegas. Begitu proses SSH-deploy diotomatisasi lewat GitHub Actions, pengguna tidak pernah membuka terminal secara manual — cukup push kode, sisanya otomatis. Ini didokumentasikan penuh di §6.

**Yang perlu diketahui sebelum lanjut** — dua fakta yang berubah baru-baru ini dan memengaruhi perencanaan kapasitas:
- Oracle memangkas diam-diam jatah Always Free Ampere A1 dari 4 OCPU/24GB menjadi **2 OCPU/12GB**, berlaku sejak Juni 2026, tanpa pengumuman resmi. Semua panduan lama di internet yang menyebut "4 OCPU 24GB gratis selamanya" **sudah tidak akurat**.
- Error **"Out of host capacity"** saat membuat instance A1 adalah hal umum di region padat peminat, tapi region **Singapore (ap-singapore-1)** dilaporkan konsisten tersedia dalam hitungan menit — sekaligus latency terbaik dari Indonesia. Ini dipakai sebagai region pilihan di spec ini.

---

## 1. Stack Final

| Lapisan | Pilihan | Keterangan |
|---|---|---|
| **Backend API** | Laravel 11 + PHP 8.3 | Eloquent ORM, Sanctum (auth token), Horizon (queue), Laravel Scheduler |
| **Frontend** | Next.js 15 (App Router) + TypeScript | SSR/ISR untuk SEO storefront, satu repo untuk marketing + dashboard + storefront + admin (route groups) |
| **Database** | PostgreSQL 16 (self-hosted di Oracle A1) | Sama persis dengan yang di PRD, tapi dikelola sendiri, bukan Supabase |
| **Cache & Queue broker** | Redis (self-hosted di Oracle A1) | Dipakai Horizon + cache Laravel |
| **Web server** | Nginx + PHP-FPM | Reverse proxy ke Laravel |
| **Process manager** | Supervisor | Menjaga Horizon & queue worker tetap hidup |
| **Storage file** | Cloudflare R2 | 10GB gratis, S3-compatible, egress gratis, dipakai via driver S3 Laravel |
| **Email** | Resend | Free tier cukup untuk MVP |
| **Error tracking** | Sentry | Terpisah untuk Laravel (backend) dan Next.js (frontend) |
| **Hosting API** | Oracle Cloud Always Free (Ampere A1, region Singapore) | 2 OCPU / 12GB RAM / 200GB storage |
| **Hosting Frontend** | Vercel (Hobby → Pro saat live) | Deploy otomatis dari GitHub |
| **DNS** | Vercel Nameservers (untuk domain apex tokospace.com) | Wajib, agar wildcard `*.tokospace.com` bisa auto-SSL — lihat §5 |

### 1.1 Pemisahan Storage: Sementara (Oracle) vs Permanen (R2)

Aturan tegas yang wajib dipatuhi sejak baris kode pertama: **`storage/app/public` di Oracle tidak pernah jadi sumber data media produksi.** Disk lokal Oracle hanya untuk data yang boleh hilang tanpa dampak bisnis kalau instance direstart, direbuild, atau dipindah host (lihat §4.3 soal fallback pindah host).

| Lokasi | Isi | Alasan |
|---|---|---|
| **Oracle (disk lokal)** | File temporer proses upload, log aplikasi (Laravel log, Nginx access/error log), cache Laravel (`storage/framework/cache`, kompilasi view) | Bersifat sementara/regeneratable — hilang saat pindah host tidak masalah, dan menyimpannya secara lokal lebih cepat (tidak perlu round-trip ke R2 untuk file yang cuma dipakai sesaat) |
| **Cloudflare R2** | Foto produk, logo toko, banner, invoice, file import CSV, hasil export | Data yang **wajib bertahan** meski instance Oracle hilang/direklamasi/dipindah — semua ditulis lewat Laravel Filesystem driver `s3` (kompatibel R2), tidak pernah lewat driver `local` untuk kategori ini |

**Penerapan di kode**: dua disk Laravel didefinisikan eksplisit di `config/filesystems.php` — `local` (untuk temp/cache/log saja) dan `r2` (untuk semua media production, jadi disk default untuk upload). Setiap fitur upload (§4 PRD: produk, logo, banner, bukti transfer, foto retur) **wajib** secara eksplisit menulis ke disk `r2`, ditegakkan lewat code review checklist dan Pest test yang menolak penggunaan `Storage::disk('local')` di luar folder `app/Modules/*/Temp/`.

Konsekuensi langsung dari aturan ini: skenario "Oracle instance direklamasi/pindah host" (§4.3-4.4) menjadi **jauh lebih aman** — karena satu-satunya data yang benar-benar hilang cuma cache & log, sementara seluruh media seller tetap utuh di R2 tanpa tergantung nasib instance compute.

---

## 2. Arsitektur

```
                         ┌─────────────────────┐
                         │   Vercel (Frontend)   │
                         │   Next.js 15 + TS      │
                         │                        │
  tokospace.com    ──►   │  (marketing)/          │
  app.tokospace.com ──►  │  (dashboard)/          │
  *.tokospace.com  ──►   │  (storefront)/         │
  admin.tokospace.com──► │  (admin)/              │
                         └──────────┬─────────────┘
                                    │  HTTPS (fetch ke API)
                                    ▼
                         ┌─────────────────────┐
  api.tokospace.com ──►  │   Oracle A1 (Backend)  │
                         │   Laravel 11 + PHP     │
                         │                        │
                         │   Nginx → PHP-FPM       │
                         │   PostgreSQL            │
                         │   Redis                 │
                         │   Horizon (queue)        │
                         │   Supervisor             │
                         │                          │
                         │   Disk lokal (sementara): │
                         │   log, cache, temp upload │
                         └──────────┬───────────────┘
                                    │  (S3 driver, bukan local)
                                    ▼
                         Cloudflare R2 (storage PERMANEN)
                         foto produk · logo · banner
                         invoice · import/export
```

**Dua repo terpisah** (bukan satu repo raksasa), masing-masing dengan pipeline deploy sendiri:

```
tokospace-api/       → Laravel → GitHub Actions → SSH → Oracle A1
tokospace-web/        → Next.js → Vercel (auto-deploy bawaan, tanpa Action tambahan)
```

Kenapa Next.js **tidak** dipecah jadi 3 repo terpisah (storefront/dashboard/admin) seperti yang disarankan di rekomendasi awal: untuk solo developer, satu repo Next.js dengan route groups (`(marketing)`, `(dashboard)`, `(storefront)`, `(admin)`) lebih mudah dikelola — satu `pnpm install`, satu deploy, satu tempat komponen UI dibagi. Vercel tetap bisa melayani ke-4 domain/subdomain dari satu project yang sama. Ini bisa dipecah nanti kalau tim bertambah.

---

## 3. Resolusi Tenant & Isolasi Data

Karena frontend dan backend kini terpisah, ada **dua jalur resolusi tenant** yang berbeda — ini penting dipahami sebelum menulis kode pertama.

### 3.1 Jalur publik (Storefront, tanpa login)

```
Customer buka namatoko.tokospace.com
        │
        ▼
Next.js middleware baca Host header → ambil "namatoko"
        │
        ▼
Next.js panggil API: GET api.tokospace.com/v1/storefront/namatoko/products
        │
        ▼
Laravel: validasi "namatoko" adalah subdomain tenant aktif
        │  (kalau tidak ditemukan/nonaktif → 404, bukan error)
        ▼
Query di-scope ke tenant_id tersebut, hasil dikembalikan
```

Endpoint storefront **tidak memerlukan autentikasi** — isolasinya murni dari validasi subdomain di setiap request, dilakukan di Laravel (bukan dipercayakan ke Next.js).

### 3.2 Jalur dashboard (Seller, dengan login)

```
Seller login di app.tokospace.com
        │
        ▼
Laravel Sanctum terbitkan token, terikat ke user & tenant_id miliknya
        │
        ▼
Setiap request dashboard membawa token
        │
        ▼
Laravel resolve tenant_id dari user yang terautentikasi
        │  (BUKAN dari subdomain — app.tokospace.com sama untuk semua seller)
        ▼
Query di-scope otomatis via Eloquent Global Scope
```

### 3.3 Pengaman berlapis (wajib, sesuai PRD §5.1)

1. **Repository/Model wajib pakai Global Scope tenant** — didaftarkan di base Model, tidak bisa "lupa ditambahkan" per query
2. **Postgres Row Level Security (RLS)** sebagai lapis kedua — bahkan jika ada bug di Eloquent, database menolak baris lintas tenant
3. **Laravel Policy** untuk memastikan user hanya bisa aksi pada resource milik tenant-nya sendiri
4. **Test isolasi tenant wajib ada di CI** (Pest test) — PR yang menghapus/melewati proteksi ini otomatis gagal build

---

## 4. Infrastruktur Compute — Target Environment, Bukan Hard Dependency

**Prinsip desain**: arsitektur ini ditulis supaya jalan di **2 OCPU/12GB** sebagai target awal, tapi tidak boleh ada satupun kode yang mengasumsikan angka itu tetap. Alasannya konkret: Oracle sudah sekali memangkas alokasi Always Free tanpa pengumuman (lihat §4.2) — kalau itu terjadi lagi, atau kalau kamu terpaksa pindah ke VPS lain dengan spek berbeda (4 vCPU/8GB, 8 vCPU/16GB, dsb.), aplikasi harus tetap jalan tanpa perubahan kode, hanya perubahan konfigurasi.

### 4.1 Cara memastikan portabilitas ini

- **Semua service dikemas Docker Compose** (Nginx, PHP-FPM, PostgreSQL, Redis, Horizon), bukan diinstal langsung ke OS. Ini satu-satunya cara realistis memastikan "jalan di mesin manapun" tanpa drift konfigurasi antar environment
- **Resource limit tidak di-hardcode** — `docker-compose.yml` memakai environment variable untuk parameter yang bergantung resource (`POSTGRES_SHARED_BUFFERS`, `PHP_FPM_MAX_CHILDREN`, `REDIS_MAXMEMORY`), dihitung oleh skrip setup (`scripts/tune.sh`) berdasarkan RAM/CPU yang terdeteksi di mesin saat itu — bukan angka tetap yang ditulis manual
- **Tidak ada asumsi jumlah core di kode aplikasi** — queue worker Horizon dikonfigurasi lewat `config/horizon.php` dengan jumlah proses yang juga diturunkan dari env var, bukan angka tetap
- **Database & compute dipisah secara logis sejak awal** meski keduanya kebetulan hidup di mesin yang sama sekarang — koneksi Postgres selalu lewat `DB_HOST` env var, bukan `localhost` yang di-hardcode. Ini membuat migrasi ke Postgres terpisah (managed atau instance lain) nanti hanya soal ganti env var, bukan ubah kode

### 4.2 Target environment vs kapasitas Oracle saat ini

Kapasitas Oracle Always Free Ampere A1 **saat dokumen ini ditulis** (bisa berubah kapan saja, ini bukan jaminan): <cite index="40-1">2 OCPU dan 12 GB memori, dari total 1.500 OCPU-jam dan 9.000 GB-jam per bulan</cite> — separuh dari angka lama (4 OCPU/24GB) yang masih banyak beredar di tutorial internet dan sudah tidak akurat.

**Tabel alokasi berikut adalah target/estimasi awal, bukan konfigurasi tetap** — angka aktual dihitung otomatis oleh `scripts/tune.sh` saat setup:

| Layanan | Target di 2 OCPU/12GB | Target di 4 vCPU/8GB (alternatif) |
|---|---|---|
| PostgreSQL | ~0.75 OCPU, 3GB RAM | ~1.5 vCPU, 2.5GB RAM |
| Laravel (PHP-FPM + Nginx) | ~0.75 OCPU, 4GB RAM | ~1.5 vCPU, 2.5GB RAM |
| Redis | ~0.25 OCPU, 1GB RAM | ~0.5 vCPU, 0.8GB RAM |
| Horizon + queue worker | ~0.25 OCPU, 2GB RAM | ~0.5 vCPU, 1.5GB RAM |
| Sisa (OS, buffer) | ~2GB RAM | ~0.7GB RAM |

Kolom kedua sengaja disertakan untuk membuktikan bahwa perpindahan target tidak memerlukan desain ulang — hanya angka yang berbeda, dihasilkan oleh skrip yang sama.

Ini realistis untuk tahap awal (puluhan-ratusan toko), tapi **bukan untuk skala besar** — lihat §4.5 untuk kapan harus pindah.

### 4.3 Risiko "Out of Capacity" saat provisioning

<cite index="49-1">Ketersediaan Always Free tergantung kapasitas di region yang dipilih saat signup, dan region tidak bisa diganti setelahnya.</cite> Region dengan histori paling reliable untuk A1: **Singapore (ap-singapore-1)** <cite index="46-1">— biasanya ter-provision dalam hitungan menit, dibanding region padat seperti US East yang bisa butuh hari</cite>. Ini juga region dengan latency terendah dari Indonesia.

**Rencana kalau tetap kena "Out of host capacity" saat setup:**
1. Coba availability domain lain dalam region yang sama (kalau ada lebih dari satu)
2. Tunggu beberapa jam, coba lagi — kapasitas berfluktuasi
3. **Fallback siap pakai**: kalau setelah beberapa hari tetap gagal, pindah ke VPS berbayar murah (Contabo/Hetzner/DigitalOcean, ~$6/bulan) dengan spesifikasi setara — karena arsitektur dibungkus Docker Compose (§4.1), pindah host **hanya soal `docker compose up` di mesin baru** + restore backup dari R2 (§8), tidak ada kode yang perlu ditulis ulang

### 4.4 Risiko reklamasi instance idle

<cite index="36-1">Oracle menganggap instance idle jika selama periode 7 hari: CPU persentil-95 di bawah 10%, penggunaan jaringan di bawah 10%, dan memori di bawah 10% (khusus shape A1) — instance idle bisa direklamasi.</cite>

**Mitigasi**: risiko ini kecil untuk Tokospace karena PostgreSQL, Redis, dan Horizon adalah proses yang selalu berjalan (bukan idle murni) — beban dasarnya biasanya sudah di atas ambang batas begitu ada development aktif atau bahkan 1-2 toko live. Sebagai jaring pengaman tambahan, tambahkan health-check ringan (curl endpoint tiap beberapa jam via GitHub Actions cron) yang sekaligus berguna sebagai uptime monitor.

### 4.5 Kapan harus pindah dari target environment saat ini

| Sinyal | Aksi |
|---|---|
| RAM konsisten >80% terpakai | Jalankan `scripts/tune.sh` (§4.1) di mesin dengan spek lebih besar — Oracle PAYG atau VPS lain, konfigurasi menyesuaikan otomatis |
| Query Postgres mulai lambat karena I/O storage gratis terbatas | Pertimbangkan managed Postgres (Supabase Pro/Neon), tinggal ganti `DB_HOST` |
| >~500 toko aktif atau traffic checkout tinggi bersamaan | Evaluasi ulang arsitektur — mungkin waktunya pisah DB dari compute, load balancer |

Ini bukan keputusan yang perlu diambil sekarang — hanya sinyal untuk dipantau. Karena §4.1 sudah memastikan tidak ada hard dependency ke angka 2 OCPU/12GB, pindah target environment adalah **operasi rutin**, bukan proyek migrasi darurat.

---

## 5. Strategi Domain & DNS (terverifikasi terhadap dokumentasi Vercel terkini)

Bagian ini adalah fondasi kritis Tokospace, jadi tidak ditulis berdasarkan asumsi lama — setiap klaim di bawah diverifikasi ulang terhadap dokumentasi resmi Vercel per Agustus 2026. Kabar baik: Vercel punya lini produk resmi khusus untuk kasus persis seperti Tokospace, bernama **"Vercel for Platforms"** (`vercel.com/docs/multi-tenant`), dipakai produksi oleh SaaS sejenis (Cal.com, Zapier disebut sebagai contoh pengguna). Ini bukan workaround yang kita rakit sendiri — ini jalur yang didukung resmi.

### 5.1 Wildcard domain (`*.tokospace.com`)

<cite index="29-1">Wildcard domain mensyaratkan penggunaan nameserver Vercel (`ns1.vercel-dns.com` dan `ns2.vercel-dns.com`) supaya Vercel bisa mengelola DNS challenge yang diperlukan untuk generate sertifikat SSL wildcard.</cite> Ini terverifikasi ulang dan **tidak berubah** dari asumsi sebelumnya — tidak ada cara lain di luar memindahkan nameserver domain apex ke Vercel kalau ingin wildcard otomatis.

<cite index="34-1">Begitu nameserver diarahkan, Vercel otomatis mengonfigurasi dan mengatur nameserver-nya sendiri — tidak perlu setel DNS record manual untuk bagian ini.</cite> Setelah wildcard domain `*.tokospace.com` ditambahkan ke project, <cite index="29-1">setiap subdomain seperti `namatoko.tokospace.com` otomatis resolve ke deployment Vercel, dan Vercel menerbitkan sertifikat individual untuk tiap subdomain secara on-the-fly.</cite>

### 5.2 Custom domain tenant (mis. `tokoku.com` milik seller) — onboarding otomatis

Ini bagian yang paling penting untuk diverifikasi, dan hasilnya: **prosesnya memang bisa sepenuhnya otomatis**, bukan verifikasi manual via cron seperti asumsi di draft sebelumnya.

<cite index="29-1">Vercel menyediakan Vercel SDK/REST API untuk menambahkan domain ke project secara programatik: provisioning domain tenant, verifikasi kepemilikan, dan generate sertifikat SSL — semuanya lewat panggilan API.</cite> <cite index="30-1">Setelah domain ditambahkan lewat API, Vercel otomatis mencoba menerbitkan sertifikat SSL; kalau domain tersebut sudah dipakai di Vercel sebelumnya, sistem meminta user memasang TXT record untuk membuktikan kepemilikan.</cite>

**Alur onboarding custom domain tenant di Tokospace:**

```
1. Seller di dashboard Tokospace input custom domain (mis. "tokoku.com")
        │
        ▼
2. Laravel panggil Vercel REST API:
   POST https://api.vercel.com/v10/projects/{projectId}/domains
   { "name": "tokoku.com" }
        │
        ▼
3. Vercel balas dengan instruksi DNS yang harus dipasang seller:
   - CNAME "tokoku.com" → "cname.vercel-dns.com" (kalau subdomain, mis. "toko.tokoku.com")
   - ATAU A record ke IP Vercel + ALIAS/ANAME (kalau domain apex tanpa dukungan CNAME di apex)
        │
        ▼
4. Laravel simpan instruksi ini, tampilkan ke seller di dashboard (step-by-step,
   sesuai design brief — instruksi CNAME ditampilkan sebagai step vertikal jelas)
        │
        ▼
5. Seller pasang DNS record di registrar domainnya sendiri
        │
        ▼
6. Laravel job terjadwal polling status via:
   GET https://api.vercel.com/v9/projects/{projectId}/domains/{domain}
   → cek status: "Pending Verification" → "Valid Configuration" → "Valid" (SSL aktif)
        │
        ▼
7. Begitu status "Valid", Tokospace update domain_verifications.status = 'aktif',
   notifikasi ke seller (dashboard + WhatsApp)
```

**Catatan realistis soal waktu**: <cite index="35-1">setelah DNS record dipasang, propagasi DNS bisa makan waktu 24-48 jam</cite> tergantung registrar seller — ini bukan sesuatu yang bisa dipercepat Tokospace, jadi UI dashboard harus menampilkan status "Menunggu propagasi DNS" secara jujur, bukan terlihat seperti error.

### 5.3 Domain apex tenant tanpa dukungan CNAME

<cite index="35-1">Kalau provider DNS seller tidak mendukung CNAME di domain apex, seller perlu memakai nameserver Vercel untuk domain itu, atau provider yang mendukung ALIAS/ANAME record.</cite> Ini kondisi tepi yang perlu diakomodasi di UI: instruksi DNS yang ditampilkan sebaiknya menyesuaikan apakah domain yang diinput seller adalah apex (`tokoku.com`) atau subdomain (`toko.tokoku.com`) — subdomain jauh lebih mudah (CNAME biasa), apex kadang perlu langkah tambahan tergantung provider DNS seller.

### 5.4 Rute `api.tokospace.com` ke Oracle A1

Bagian ini **tidak berubah** dari draft sebelumnya dan tidak bertentangan dengan apapun yang ditemukan saat verifikasi: karena nameserver `tokospace.com` diarahkan ke Vercel, panel DNS Vercel (`Domains → tokospace.com → DNS Records`) dipakai untuk menambahkan satu record biasa:

```
api.tokospace.com  →  A record  →  <IP publik Oracle A1>
```

Ini bukan bagian dari "multi-tenant domain" Vercel — ini cuma DNS record biasa untuk sub-domain milik Tokospace sendiri (bukan milik tenant), jadi tidak butuh API call atau proses onboarding apapun, cukup diset sekali secara manual saat setup.

### 5.5 Ringkasan implementasi yang wajib dibangun

Empat komponen konkret yang perlu ada di modul `domain` (Laravel), sebagai hasil verifikasi ini — lebih presisi dari draft sebelumnya yang menyebut "cron job cek DNS" secara generik:

| Komponen | Fungsi |
|---|---|
| `VercelDomainService::add()` | Panggil `POST /v10/projects/{id}/domains` saat seller submit custom domain |
| `VercelDomainService::checkStatus()` | Panggil `GET /v9/projects/{id}/domains/{domain}`, dipanggil job terjadwal (bukan Laravel yang cek DNS sendiri — cukup tanya status ke Vercel) |
| `VercelDomainService::remove()` | Panggil delete domain API saat seller ganti/hapus custom domain |
| Token Vercel API | Disimpan di `.env` Laravel (bukan per-tenant), dibuat dari Vercel dashboard (Account Settings → Tokens) |

Ini menggantikan asumsi lama "cron job cek DNS sendiri" — jauh lebih reliable karena Vercel yang jadi sumber kebenaran status verifikasi & SSL, Tokospace cuma polling dan menampilkan hasilnya.

### 5.6 Yang tetap perlu diverifikasi ulang saat implementasi

Meski sudah diverifikasi terhadap dokumentasi resmi, dua hal ini disarankan dicek langsung di dashboard Vercel saat setup (bukan cuma dari dokumentasi), karena detail UI/limit produk cenderung berubah:
- <cite index="27-1">Custom domain tanpa batas memerlukan paket Pro</cite> — pastikan sudah upgrade sebelum seller pertama mencoba pasang custom domain
- Format response API (`v9`/`v10`) — versi endpoint di dokumentasi bisa naik; cek versi terbaru saat menulis kode integrasi, bukan mengikuti angka di dokumen ini secara membabi buta

---

## 6. Deploy Sepenuhnya dari HP

### 6.1 Setup awal (sekali saja, juga bisa dari HP)

Bagian yang paling sering dikira butuh PC adalah provisioning server pertama kali. Ini bisa dihindari dengan **cloud-init**: skrip setup (install Nginx, PHP, Postgres, Redis, Supervisor) ditempel di kolom "User Data" saat membuat instance dari **OCI Console lewat browser HP** — server akan menjalankan skrip ini otomatis saat pertama kali menyala, tanpa kamu perlu SSH masuk sama sekali di tahap ini.

```
Buka OCI Console di browser HP
        │
        ▼
Compute → Create Instance → pilih Ampere A1, Singapore
        │
        ▼
Tempel cloud-init script di "Advanced Options → User Data"
        │
        ▼
Create → server hidup dengan Nginx/PHP/Postgres/Redis/Supervisor
        sudah terpasang, tanpa SSH manual
```

SSH tetap dipakai nanti hanya untuk **debug sesekali** (opsional), bukan untuk operasi rutin.

### 6.2 Alur kerja rutin (deploy harian)

```
Claude Code (app mobile)  ──► tulis/ubah kode Laravel atau Next.js
        │
        ▼
GitHub (app mobile)  ──► review diff, commit, buat PR
        │
        ▼ (otomatis)
GitHub Actions
        │
   ┌────┴────┐
   │         │
   ▼         ▼
tokospace-api          tokospace-web
   │                        │
   │ test, migrate,          │ (Vercel auto-deploy,
   │ SSH deploy ke Oracle     │  bawaan tanpa Action)
   ▼                        ▼
Oracle A1 (Laravel updated)   Vercel (Next.js updated)
```

**Kredensial SSH** disimpan sebagai GitHub Secret (private key), bukan disimpan di kode. GitHub sendiri merekomendasikan OIDC untuk mengurangi credential jangka panjang, tapi untuk tahap awal **SSH key sederhana sudah cukup dan lebih gampang dipahami** — OIDC/IAM policy bisa jadi peningkatan nanti, bukan syarat awal.

### 6.3 Deploy tanpa downtime + rollback dari HP

Karena Laravel tidak punya "Instant Rollback" bawaan seperti Vercel, ini dibangun manual dengan pola **release folder + symlink** (skema umum ala Laravel Envoyer/Deployer, dijalankan lewat skrip di GitHub Actions, bukan tool berbayar):

```
/var/www/tokospace-api/
├── releases/
│   ├── 2026-08-15-1200/   ← rilis sebelumnya (tetap disimpan, tidak dihapus)
│   ├── 2026-08-17-0930/   ← rilis aktif
│   └── 2026-08-17-1400/   ← rilis baru (di-deploy ke sini dulu)
├── current -> releases/2026-08-17-1400/   ← symlink, ini yang dibaca Nginx
└── shared/
    ├── .env
    └── storage/
```

Deploy = clone kode baru ke folder rilis baru → jalankan migrasi → pindahkan symlink `current` → restart PHP-FPM & Horizon. Karena symlink dipindah dalam sepersekian detik, **tidak ada downtime**.

**Rollback dari HP**: workflow terpisah (`rollback.yml`) yang bisa dipicu manual dari GitHub mobile app (`workflow_dispatch`) — cukup pilih rilis mana yang mau dikembalikan, symlink dipindah balik. Satu ketukan, tanpa SSH.

### 6.4 Perkakas di HP

| Kebutuhan | Aplikasi |
|---|---|
| Menulis kode | **Claude Code** (app Claude mobile) |
| Review & merge PR, trigger rollback | **GitHub mobile app** |
| Setup awal server (sekali) | **Browser HP** → OCI Console |
| Monitor deploy Next.js | **Vercel mobile app** |
| Monitor deploy Laravel | **GitHub Actions** (notifikasi lewat GitHub app) |
| Cek database | **Adminer/pgAdmin web** yang di-deploy di Oracle (akses via browser HP, dilindungi password) |
| Lihat error produksi | **Sentry mobile app** |

---

## 7. Risiko & Mitigasi (lengkap)

| Risiko | Level | Mitigasi |
|---|---|---|
| Out of host capacity saat setup awal | Sedang | Region Singapore (paling reliable), siap fallback VPS berbayar ~$6/bln |
| Reklamasi instance idle (7 hari) | Rendah | Beban dasar Postgres/Redis/Horizon biasanya sudah di atas ambang; health-check cron sebagai jaring tambahan |
| Vercel Hobby melarang penggunaan komersial | **Tinggi jika diabaikan** | <cite index="9-1">Penggunaan komersial mencakup segala cara memproses pembayaran dari pengunjung</cite> — wajib upgrade ke Pro ($20/bln) **sebelum** transaksi pertama, bukan sesudah |
| Beban operasional server sendiri (patch keamanan OS, firewall, monitoring) | Sedang | `unattended-upgrades` untuk patch otomatis, `ufw` + Oracle Security List sebagai firewall, uptime monitor eksternal gratis (mis. UptimeRobot) |
| Tidak ada backup otomatis seperti layanan managed database | **Tinggi jika diabaikan** | Wajib disiapkan sejak awal — lihat §8 |
| Single point of failure (satu instance untuk semua) | Sedang, diterima untuk tahap ini | Backup rutin + rollback cepat sebagai mitigasi utama; high-availability sungguhan ditunda sampai skala mengharuskan |
| Struktur kode melenceng seiring waktu, dua repo makin sulit disinkronkan | Sedang | CLAUDE.md per repo + Pest Arch test (Laravel) + ESLint boundary rule (Next.js) — lihat §9 |
| Kontrak API antara Laravel & Next.js tidak sinkron (field berubah di satu sisi, sisi lain tidak update) | Sedang | Skema OpenAPI/Zod dibagikan sebagai sumber kebenaran tipe — lihat §9.3 |
| Repo private → kuota GitHub Actions terbatas (2.000 menit/bulan gratis, beda dari repo publik yang tanpa batas) | Rendah | Cukup longgar untuk solo dev dengan CI per-PR; pantau di Settings → Billing kalau job CI mulai lebih sering/lebih lama. Set spending limit $0 sebagai default supaya job berhenti otomatis (bukan tagihan mendadak) kalau kuota habis |

---

## 8. Backup & Disaster Recovery

Ini **sepenuhnya tanggung jawab sendiri** sekarang — beda dengan layanan managed database yang backup-nya otomatis. Wajib ada sejak hari pertama produksi, bukan ditambahkan belakangan.

- **Backup database**: cron harian (`pg_dump`) → kompresi → upload ke Cloudflare R2 (terpisah dari server asal, supaya kalau instance Oracle bermasalah, data tetap aman)
- **Retensi**: 30 hari, sesuai PRD §5.8
- **Uji restore**: dijadwalkan tiap kuartal — backup yang tidak pernah diuji tidak bisa disebut backup, dan ini paling gampang dilupakan oleh solo developer
- **Target**: RPO ≤ 24 jam, RTO ≤ 4 jam (sesuai PRD), realistis karena restore Postgres dari dump di instance baru bisa dilakukan dalam waktu tersebut

---

## 9. Modularitas & Dokumentasi Struktur Kode

Prinsip yang sama dengan sebelumnya — modular, gampang dicari, terdokumentasi otomatis — tapi diterapkan lintas dua repo dengan idiom masing-masing ekosistem.

### 9.1 Struktur modul Laravel (`tokospace-api`)

```
app/
├── Modules/
│   ├── Shipping/
│   │   ├── Contracts/ShippingProviderInterface.php   ← kontrak
│   │   ├── Providers/ManualProvider.php
│   │   ├── Providers/JntProvider.php
│   │   ├── Providers/KiriminAjaProvider.php
│   │   ├── Services/ShippingService.php
│   │   ├── Models/
│   │   ├── Http/Controllers/
│   │   └── README.md
│   ├── Payment/       ← struktur sama, provider: Manual, Tripay, Midtrans
│   ├── Catalog/
│   ├── Order/
│   ├── Notification/
│   └── Billing/
├── Http/               ← tipis, hanya routing & request validation
└── Console/            ← scheduled command (polling tracking, dsb)
```

Aturan sama seperti sebelumnya: modul lain **hanya** boleh memanggil lewat `Services/`, tidak boleh mengimpor `Models/` atau `Providers/` modul lain secara langsung. Ditegakkan otomatis lewat **Pest Architecture Testing** (`pest --group=arch`), berjalan di CI — kalau ada import yang melanggar batas modul, build gagal. Ini padanan langsung dari aturan ESLint yang dipakai di sisi Next.js.

### 9.2 Struktur Next.js (`tokospace-web`) — tetap seperti spec sebelumnya

Karena logika bisnis kini terpusat di Laravel, folder `modules/` di Next.js jadi lebih tipis — isinya kebanyakan pemanggilan API + presentasi UI, bukan business logic penuh:

```
src/
├── app/(marketing|dashboard|storefront|admin)/   ← routing
├── modules/            ← client untuk tiap domain API + hook TanStack Query
│   ├── shipping/api.ts    (memanggil api.tokospace.com/v1/shipping/*)
│   ├── payment/api.ts
│   └── ...
├── shared/ui/           ← komponen design system
└── shared/types/         ← tipe yang di-generate dari OpenAPI Laravel (§9.3)
```

### 9.3 Menjaga kontrak API tetap sinkron

Risiko nyata dari dua repo terpisah: field API berubah di Laravel, Next.js tidak tahu sampai runtime error. Mitigasi: Laravel menghasilkan **spesifikasi OpenAPI** otomatis dari route & Form Request (pakai package seperti `dedoc/scramble`), lalu Next.js menjalankan `openapi-typescript` di CI untuk generate ulang tipe TypeScript dari spek tersebut. Kalau ada perubahan API yang tidak kompatibel, TypeScript compiler di Next.js akan gagal — ketahuan saat CI, bukan saat production.

### 9.4 CODEMAP — dua repo, dua file, saling terhubung

Setiap repo punya `docs/CODEMAP.md` sendiri, digenerate otomatis oleh CI masing-masing (skrip untuk Laravel membaca docblock di tiap `README.md` modul; skrip Next.js sama seperti spec v1.0). Di root masing-masing repo, `README.md` saling menaut ke repo pasangannya, supaya siapapun yang membuka salah satu repo tahu keberadaan repo lainnya.

### 9.5 ADR & CLAUDE.md

Sama seperti sebelumnya — `docs/adr/` untuk keputusan mahal-dibalik (kali ini contoh nyatanya: "ADR-0001: Laravel + Oracle A1, bukan Next.js full-stack, karena X"), dan **satu `CLAUDE.md` per repo** karena Claude Code akan bekerja di konteks repo yang berbeda-beda tergantung sesi:

```markdown
# CLAUDE.md — tokospace-api

## Aturan wajib
1. Logika bisnis HANYA di app/Modules/, bukan di Http/Controllers/
2. Tambah kurir/gateway baru = buat Provider baru yang implement interface,
   JANGAN ubah ShippingService/PaymentService
3. Setiap query wajib ter-scope tenant (Global Scope aktif secara default,
   jangan pernah pakai withoutGlobalScope kecuali di konteks Super Admin)
4. Jalankan `pest --group=arch` sebelum selesai — kalau gagal, ada modul
   yang saling mengimpor secara ilegal
```

---

## 10. Performa & Strategi Caching Berlapis

Prinsip disiplin yang wajib dipegang: **traffic customer tidak boleh proporsional 1:1 dengan query database.** 1.000 visitor mengunjungi halaman produk yang sama tidak boleh berarti 1.000 request ke Laravel apalagi 1.000 query ke Postgres — kalau itu terjadi, storefront collapse duluan sebelum bisnisnya sempat besar.

### 10.1 Dua kategori data dengan perlakuan berbeda

| Kategori | Contoh | Perlakuan |
|---|---|---|
| **Cacheable agresif** | Produk, kategori, homepage, koleksi/collection | Boleh "agak basi" beberapa puluh detik–menit; dioptimalkan untuk kecepatan, bukan real-time |
| **Selalu dinamis** | Keranjang, checkout, akun, pesanan | Tidak boleh di-cache sama sekali — data personal & harus akurat detik itu juga |

Aturan ini menentukan strategi caching di **tiga lapis sekaligus**, bukan cuma satu:

### 10.2 Lapis 1 — Next.js fetch cache + tag-based revalidation (baris pertahanan utama)

Untuk kategori "cacheable agresif", Next.js **tidak perlu memanggil Laravel sama sekali** kalau cache masih valid — request tidak pernah keluar dari edge Vercel:

```
1000 visitor buka /produk/kaos-hitam
        │
        ▼
Next.js cek fetch cache (tagged: `product:kaos-hitam`, `tenant:namatoko`)
        │
   ┌────┴────┐
   │ HIT      │ MISS/expired
   ▼          ▼
Serve dari    1 request ke Laravel → simpan ke cache
cache Vercel  → 999 visitor berikutnya kena cache HIT
(0 request    lagi, bukan 999 request baru
ke Laravel)
```

Implementasi: `fetch()` di Next.js pakai `next: { revalidate: 60, tags: ['product:{slug}', 'tenant:{subdomain}'] }`. Untuk data yang jarang berubah (homepage, kategori), revalidate bisa lebih panjang (300 detik).

**Invalidasi on-demand (bukan cuma menunggu revalidate habis)**: saat seller mengubah produk di dashboard, Laravel memanggil endpoint revalidasi khusus di Next.js:

```
Seller update harga produk di dashboard
        │
        ▼
Laravel simpan perubahan ke Postgres
        │
        ▼
Laravel panggil: POST https://tokospace.com/api/revalidate
                 { tag: "product:kaos-hitam", secret: REVALIDATE_SECRET }
        │
        ▼
Next.js route handler panggil revalidateTag('product:kaos-hitam')
        │
        ▼
Cache untuk produk itu langsung invalid — customer berikutnya
dapat data baru, TANPA harus menunggu 60 detik revalidate window
```

Ini memberi yang terbaik dari dua dunia: cache agresif untuk kecepatan, tapi perubahan seller tetap terasa "langsung" karena invalidasi dipicu aktif, bukan pasif menunggu timeout.

### 10.3 Lapis 2 — Redis cache di Laravel (pertahanan kedua)

Kalau lapis 1 miss (cache Next.js kedaluwarsa/di-invalidate), request **tetap tidak langsung membombardir Postgres** — Laravel cek Redis dulu:

```
Next.js request ke Laravel (karena cache Vercel miss)
        │
        ▼
Laravel cek Redis cache (key: "tenant:{id}:product:{slug}")
        │
   ┌────┴────┐
   │ HIT      │ MISS
   ▼          ▼
Return dari   Query Postgres → simpan ke Redis (TTL 5-15 menit)
Redis, TIDAK
query Postgres
```

Laravel model events (`saved`, `deleted`) pada modul Catalog otomatis membersihkan key Redis terkait, jadi Redis tidak pernah menyajikan data basi lebih dari sela waktu request-ke-request yang sangat singkat.

### 10.4 Lapis 3 — Query database yang efisien (pertahanan terakhir)

Untuk request yang memang harus sampai ke Postgres (cache miss di kedua lapis di atas, atau data dinamis yang memang tidak boleh di-cache):

- Index database untuk semua kolom yang dipakai filter/sort di katalog (`tenant_id`, `category_id`, `status`, `slug`)
- Eager loading wajib (`with()`) untuk hindari N+1 query — ditegakkan lewat `spatie/laravel-query-detector` di environment development, gagal-kan CI kalau terdeteksi N+1 di endpoint kritis
- Connection pooling (PgBouncer) dipasang di depan Postgres begitu traffic mulai naik — bukan syarat MVP, tapi dicatat sebagai langkah berikutnya yang jelas

### 10.5 Yang TIDAK di-cache (dan kenapa itu benar)

Keranjang, checkout, akun, dan pesanan sengaja dikecualikan dari seluruh strategi di atas — `cache: 'no-store'` di Next.js, tidak ada Redis cache di Laravel untuk endpoint ini. Ini bukan celah performa yang terlewat, ini keputusan sadar: data yang salah di halaman checkout (stok basi, harga basi) jauh lebih mahal daripada satu query database ekstra. Reservasi stok (PRD §4.3) secara khusus **butuh** data real-time, bukan cache.

### 10.6 Target & cara menegakkannya

- **LCP < 2,5 detik** tetap target utama — lebih menantang sekarang karena ada hop tambahan (Next.js → Laravel) dibanding akses database langsung, makanya tiga lapis caching di atas bukan optimisasi opsional, tapi bagian dari desain sejak awal
- Lighthouse CI tetap menggagalkan build kalau melebihi threshold (sesuai spec v1.0)
- **Load test sebelum launch**: simulasikan skenario "1.000 visitor bersamaan ke satu halaman produk populer" (mis. pakai `k6` atau `autocannon`) sebagai bagian dari checklist pra-launch — memverifikasi bahwa fan-out yang dikhawatirkan di atas benar-benar tidak terjadi, bukan cuma diasumsikan dari desain di atas kertas

---

## 11. Estimasi Biaya

| Tahap | Layanan | Biaya |
|---|---|---|
| **Development** | Oracle A1 (free) + Vercel Hobby (free) + Resend/Sentry free tier | **$0/bulan** |
| **Saat launch (ada transaksi nyata)** | Oracle A1 (masih free, dengan risiko §4) + Vercel **Pro wajib** ($20) | **~$20/bulan** |
| **Jika kena Out of Capacity / idle reclaim** | + VPS fallback (Contabo/Hetzner ~$6) | **~$26/bulan** |
| **Skala lebih besar** (§4.5 terpenuhi) | + managed Postgres bila perlu (~$25) | **~$45-50/bulan** |

Lebih murah dari estimasi spec v1.0 ($45-50 di launch) — **selama Oracle A1 tetap stabil**. Ketidakpastian kapasitas Oracle adalah harga yang dibayar untuk biaya lebih rendah; §4.3 dan §7 sudah menyiapkan jalan keluar kalau itu terjadi.

---

## 12. Urutan Setup (semua dari HP)

| # | Langkah | Di mana |
|---|---|---|
| 1 | Buat 2 repo GitHub: `tokospace-api`, `tokospace-web` | GitHub mobile |
| 2 | Hubungkan `tokospace-web` ke Vercel | Vercel app |
| 3 | Daftar Oracle Cloud, pilih home region **Singapore** | Browser HP |
| 4 | Buat instance Ampere A1 (2 OCPU/12GB) dengan cloud-init script (§6.1) | OCI Console via browser HP |
| 5 | Beli domain tokospace.com, arahkan nameserver ke Vercel | Registrar |
| 6 | Tambahkan `*.tokospace.com` sebagai wildcard domain di Vercel | Vercel dashboard |
| 7 | Tambahkan record `api.tokospace.com` → IP Oracle A1 | Vercel DNS panel |
| 8 | Setup GitHub Secret (SSH private key) untuk deploy `tokospace-api` | GitHub repo settings (browser HP) |
| 9 | Setup struktur folder + CLAUDE.md + CI di kedua repo | Claude Code |
| 10 | Mulai bangun modul, urutan: tenant → auth → catalog → order | Claude Code |

---

## 13. Dokumen Terkait

- `tokospace-PRD.md` v1.1 — cakupan fitur & logika bisnis (stack Laravel sudah konsisten, tidak perlu revisi)
- `tokospace-design-brief.md` v2.0 — sistem desain & breakdown halaman
- `tokospace-prompt-bertahap.md` — prompt eksekusi desain
