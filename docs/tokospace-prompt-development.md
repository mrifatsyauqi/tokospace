# Tokospace — Prompt Development (Claude Code)

Pasangan dokumen `tokospace-master-plan.md`. Setiap blok di bawah siap ditempel ke Claude Code, satu tahap per sesi. Kerjakan berurutan — jangan lompat ke tahap N+1 sebelum DoD tahap N (lihat master plan §4) tercentang.

**Cara pakai**: buka repo yang relevan (`tokospace-api` atau `tokospace-web`, beberapa tahap butuh dua-duanya) di Claude Code, tempel prompt, biarkan Claude Code kerja sampai selesai, lalu verifikasi DoD sebelum lanjut.

**Model AI (hemat kuota Pro)**: tiap tahap di bawah diberi label 🧠 model yang direkomendasikan (lihat alasan lengkap di master plan §6a). Tiga tahap berlabel **"Opus → Sonnet"** artinya: jalankan `/model opus` khusus untuk bagian rencana/keputusan sulit di awal prompt (biasanya ditandai eksplisit di teks prompt), lalu `/model sonnet` untuk sisa eksekusi menulis kode. Tahap lain langsung pakai Sonnet dari awal. Cek `/model` di Claude Code untuk daftar model yang aktif tersedia saat ini, karena nama/versi bisa berubah.

---

## Tahap -1 — Menghubungkan Claude Code ke Repo yang Sudah Dibuat

Dikerjakan sekali di awal, sebelum Tahap 0. Ada dua mode, dan keduanya bisa dipakai bersamaan (tidak saling menggantikan):

### Mode A — Claude Code bekerja langsung di repo (dipakai untuk semua prompt Tahap 0-9 di bawah)

Ini mode utama yang diasumsikan seluruh dokumen ini. Karena repo `tokospace-api` dan `tokospace-web` sudah kamu buat (bukan dibuat dari kosong oleh Claude Code), langkah pertama di tiap sesi adalah **membuka repo yang sudah ada**, bukan menyuruh Claude Code membuat repo baru:

1. Clone repo yang relevan (kalau sesi belum punya salinannya): `git clone https://github.com/<username>/tokospace-api.git`, sama untuk `tokospace-web`
2. Buka/jalankan Claude Code **di dalam folder repo itu** — Claude Code otomatis mendeteksi git repo yang sudah ada, tidak butuh setup tambahan untuk mulai membaca & mengedit kode
3. Pastikan autentikasi git sudah aktif di environment tempat Claude Code jalan (SSH key atau `gh auth login`) — ini yang menentukan Claude Code **bisa** `git push`, bukan cuma commit lokal
4. Karena repomu sudah ada (mungkin masih kosong atau sudah ada README default dari GitHub), **beri tahu itu secara eksplisit** di awal prompt supaya Claude Code tidak mencoba `git init` ulang atau bikin struktur yang bentrok dengan apa yang sudah ada — semua prompt di Tahap 0 dst. di bawah sudah disesuaikan untuk asumsi ini

### Mode B — Trigger Claude Code dari GitHub lewat komentar `@claude` (untuk momen tidak sedang buka sesi Claude Code aktif)

Ini pelengkap, berguna kalau kamu mau minta perubahan kecil langsung dari GitHub mobile app tanpa membuka aplikasi Claude terpisah:

1. Buka Claude Code sekali di repo (`tokospace-api` dulu, ulangi untuk `tokospace-web`), jalankan: `/install-github-app`
2. Ikuti instruksinya — ini akan memasang **Claude GitHub App** di repo tersebut, menyimpan kredensial sebagai secret (`ANTHROPIC_API_KEY` atau `CLAUDE_CODE_OAUTH_TOKEN`), menambahkan file workflow, lalu membuka pull request berisi perubahan itu untuk kamu setujui
3. Setelah ter-install, dari GitHub app di HP kamu bisa buka issue atau komentar PR dan tulis **"@claude tolong perbaiki X"** — Claude Code jalan sebagai GitHub Action, membaca konteksnya, lalu push branch baru + buka PR, semua tanpa kamu perlu membuka sesi Claude Code sama sekali

**Kapan pakai yang mana**: Mode A untuk mengerjakan tahap-tahap besar di dokumen ini (Tahap 0-9), karena butuh konteks panjang & kontrol penuh. Mode B untuk perbaikan kecil dadakan (fix typo, ubah teks, perbaikan bug kecil yang dilaporkan) saat kamu cuma pegang HP dan tidak sedang dalam sesi kerja aktif.

---

## Tahap 0 — Fondasi Infrastruktur

🧠 **Model: Sonnet**

**Repo**: keduanya — **repo sudah ada** (kamu sudah membuatnya di GitHub), Claude Code bekerja di dalamnya, bukan membuat repo baru. Ikuti Mode A di Tahap -1 sebelum menempel prompt ini.

```
Repo ini SUDAH ADA di GitHub (bukan folder kosong yang perlu di-init dari nol) — cek dulu isi repo saat ini (mungkin cuma ada README default, atau sudah ada sedikit file), lalu bangun fondasi infrastruktur Tokospace DI DALAM repo yang sudah ada ini, mengikuti tokospace-tech-spec.md §12 persis. JANGAN jalankan `git init` kalau repo sudah punya riwayat commit. Ini BUKAN tahap membangun fitur — fokus murni ke skeleton yang bisa di-deploy.

REPO tokospace-api (Laravel 11):
1. Setup project Laravel 11 + PHP 8.3 di dalam repo yang sudah ada, struktur folder app/Modules/ (kosong dulu, cuma folder + README menjelaskan aturan modular dari tech-spec §9.1)
2. Docker Compose: Nginx + PHP-FPM + PostgreSQL 16 + Redis + Supervisor (Horizon), SEMUA parameter resource (shared_buffers, max_children, dst) dibaca dari environment variable, JANGAN hardcode angka — buat scripts/tune.sh yang menghitung nilai-nilai ini dari RAM/CPU yang terdeteksi di container/host
3. Dua disk filesystem di config/filesystems.php: 'local' (temp/log/cache saja) dan 'r2' (S3-compatible, jadi default untuk semua upload) — sesuai tech-spec §1.1
4. Endpoint GET /health yang return 200 + status koneksi DB & Redis
5. Setup Pest, termasuk grup 'arch' untuk architecture testing (aturan: modul tidak boleh saling import langsung, harus lewat Services/) — buat 1 test placeholder dulu, isi aturannya nanti seiring modul bertambah
6. GitHub Actions: ci.yml (test + lint + pest --group=arch di setiap PR), main.yml (migrate + deploy SSH ke Oracle A1 pakai pola release-folder + symlink dari tech-spec §6.3, ZERO DOWNTIME)
7. Cron backup: pg_dump harian terkompresi, upload ke Cloudflare R2, retensi 30 hari

REPO tokospace-web (Next.js 15 App Router + TypeScript):
1. Setup project di dalam repo yang sudah ada, struktur src/app/(marketing|dashboard|storefront|admin)/, src/modules/, src/shared/ui/, src/shared/types/ sesuai tech-spec §9.2
2. Setup Tailwind dengan design tokens dari tokospace-design-brief.md §2 (warna, tipografi, radius, spacing) sebagai tailwind.config
3. Halaman placeholder di tiap route group supaya bisa di-deploy dan diverifikasi routingnya jalan
4. Deploy ke Vercel (auto-deploy bawaan, tidak perlu GitHub Action tambahan)

DOKUMENTASI (kedua repo):
1. CLAUDE.md sesuai contoh di tech-spec §9.5, sesuaikan untuk masing-masing repo
2. docs/CODEMAP.md — buat skrip generate otomatis (baca README.md tiap modul, tulis ulang CODEMAP.md), jalankan sekali sekarang meski masih kosong
3. docs/adr/0001-stack-laravel-oracle-nextjs-vercel.md — ringkas keputusan dari tech-spec §0

Kerjakan semua ini di branch baru, commit dengan pesan jelas per langkah besar, lalu buka Pull Request ke main (jangan push langsung ke main) supaya bisa direview lewat GitHub app di HP sebelum di-merge.

Setelah selesai, verifikasi: curl ke api.tokospace.com/health harus 200, tokospace.com harus menampilkan halaman placeholder, push ke main di kedua repo harus trigger deploy tanpa error.
```

---

## Tahap 1 — Tenant, Auth, Onboarding

🧠 **Model: Opus → Sonnet** — pakai `/model opus` untuk merancang strategi isolasi tenant (poin 2-4 di bagian BACKEND), lalu `/model sonnet` untuk sisanya

**Repo**: keduanya

```
Bangun modul Tenant dan Auth di tokospace-api, plus halaman terkait di tokospace-web. Ini fondasi — SEMUA modul berikutnya bergantung pada ini, jadi jangan terburu-buru terutama di bagian isolasi data.

BACKEND (tokospace-api):
1. Migrasi tabel sesuai tokospace-PRD.md §6.4: tenants, users (WAJIB constraint UNIQUE(tenant_id, email) — akun customer per-toko sesuai keputusan D3, BUKAN unique email global), otp_codes, password_resets
2. Modul app/Modules/Tenant/: resolusi tenant dari subdomain (untuk request publik) dan dari user terautentikasi (untuk dashboard) — dua jalur berbeda sesuai tech-spec §3
3. Global Scope tenant di base Model — WAJIB, tidak boleh ada Model yang query tanpa scope ini kecuali eksplisit ditandai untuk konteks Super Admin
4. Row Level Security (RLS) di PostgreSQL sebagai lapis kedua, sesuai PRD §5.1
5. Endpoint cek ketersediaan subdomain real-time (debounce-friendly, response cepat)
6. Buat daftar reserved words untuk subdomain (admin, api, www, app, mail, ftp, ns1, ns2, dan kata kasar/ofensif umum dalam Bahasa Indonesia) sebagai config, bukan hardcode di controller
7. Modul app/Modules/Auth/: registrasi + login email/password via Sanctum, verifikasi email, reset password, rate limit 5x gagal login per 15 menit per akun
8. Pest test WAJIB: test yang membuktikan Tenant A tidak bisa membaca/mengubah data Tenant B lewat API manapun — ini gerbang CI, PR yang menghapus proteksi ini harus gagal build

FRONTEND (tokospace-web):
1. Handoff desain Login/Register/Lupa Password dari Claude Design (pola halaman terpisah split-screen, BUKAN tab — sesuai revisi design brief §8.1) ke src/app/(marketing)/
2. Halaman /verify-email dengan countdown kirim ulang
3. Onboarding wizard 4 step di src/app/(dashboard)/onboarding/ — step nama toko (dengan live check subdomain ke backend), kategori bisnis, pilih tema starter, upload logo (skip opsional)
4. Semua form pakai Zod schema yang sama dengan validasi backend (definisikan skema bersama di src/shared/types/, jangan duplikasi aturan validasi)

Verifikasi DoD: seller baru bisa daftar → verifikasi → pilih subdomain → toko live di namatoko.tokospace.com dalam <15 menit, dan test isolasi tenant lolos di CI.
```

---

## Tahap 2 — Katalog Produk

🧠 **Model: Sonnet**

**Repo**: keduanya

```
Bangun modul Catalog di tokospace-api dan UI terkait di tokospace-web, meneruskan dari Tenant+Auth yang sudah ada.

BACKEND (tokospace-api):
1. Migrasi: categories, products (WAJIB kolom weight_gram sejak sekarang meski belum dipakai sampai Tahap 6 — PRD menegaskan ini supaya seller tidak isi ulang katalog nanti), product_variants — semua dengan tenant_id + scope aktif
2. app/Modules/Catalog/: Service + Repository standar (tidak perlu pola Provider di modul ini, tidak ada integrasi eksternal)
3. CRUD produk lengkap: nama, deskripsi, harga, stok, kategori, hingga 8 gambar (WAJIB tersimpan ke disk 'r2', resize otomatis ke WebP saat upload — tech-spec §1.1)
4. Import CSV dengan preview mapping kolom + validasi error per baris sebelum commit
5. Endpoint publik (tanpa auth) untuk storefront: list produk per tenant, detail produk per slug — scoping tenant dari parameter subdomain yang divalidasi, BUKAN dari auth

FRONTEND (tokospace-web):
1. Dashboard Produk: list (tabel/stacked card sesuai breakpoint dari design brief), form tambah/edit multi-section, halaman import CSV
2. Storefront: halaman katalog (grid produk, ISR dengan next: { revalidate: 60 }) dan detail produk — ini pemakaian PERTAMA dari strategi caching tech-spec §10, terapkan tag `product:{slug}` dan `tenant:{subdomain}` di setiap fetch meski invalidasi on-demand belum aktif (itu Tahap 5)
3. Handoff desain dari Claude Design kalau sudah tersedia untuk halaman-halaman ini; kalau belum, buat sesuai component library di design brief §7

Verifikasi DoD: seller tambah produk lengkap dengan foto, foto tersimpan di R2 (cek langsung, bukan asumsi), produk muncul di storefront publik dalam hitungan menit.
```

---

## Tahap 3 — Pesanan & Transaksi Manual

🧠 **Model: Opus → Sonnet** — pakai `/model opus` untuk merancang reservasi stok & row-locking (poin 2 di bagian BACKEND), lalu `/model sonnet` untuk sisanya

**Repo**: keduanya

```
Ini tahap paling kritis secara bisnis — begitu selesai, toko bisa jualan sungguhan. Ambil waktu ekstra khususnya di bagian reservasi stok, ini yang paling sering jadi bug produksi kalau terburu-buru.

BACKEND (tokospace-api):
1. Migrasi sesuai PRD §6.4: carts, orders (dengan shipping_address_snapshot, customer_contact_snapshot, expires_at), order_items (dengan variant_id, product_name_snapshot, variant_name_snapshot — WAJIB snapshot, jangan referensi live ke produk), payments, shipments
2. app/Modules/Order/: reservasi stok saat pesanan dibuat (BUKAN saat pembayaran dikonfirmasi), pakai row-level lock (SELECT ... FOR UPDATE) dalam transaksi database — ini yang mencegah overselling
3. Generate nomor pesanan format [KODE-TOKO]-[YYYYMMDD]-[urutan], KODE-TOKO dari 4 huruf pertama subdomain
4. Job terjadwal: expire pesanan belum dibayar (24 jam untuk transfer manual), kembalikan stok otomatis
5. app/Modules/Payment/: HANYA metode manual_transfer dulu — seller input rekening bank, customer upload bukti transfer (ke R2), seller verifikasi manual via dashboard
6. app/Modules/Shipping/: HANYA metode manual dulu — seller input nama kurir bebas + nomor resi
7. Interface ShippingProviderInterface dan PaymentProviderInterface WAJIB dibuat sekarang meski baru ada 1 implementasi masing-masing (ManualProvider) — supaya Tahap 6 tinggal nambah provider baru tanpa ubah modul Order

FRONTEND (tokospace-web):
1. Storefront: keranjang (edit qty, hapus), checkout (form alamat, upload bukti transfer, ringkasan sticky di desktop/collapsible di mobile sesuai design brief)
2. Dashboard: Pesanan list (badge status + metode) dan detail (timeline status, tombol konfirmasi bukti transfer, form input resi manual)
3. Halaman konfirmasi pesanan dan tracking (input nomor pesanan/email)

TEST WAJIB: tulis test yang mensimulasikan 2 request checkout bersamaan untuk produk dengan stok=1 — pastikan hanya SATU yang berhasil, yang lain dapat pesan "stok tidak mencukupi". Ini bukti nyata reservasi stok bekerja, bukan cuma diklik manual sekali.

Verifikasi DoD: alur lengkap customer beli → transfer manual → seller konfirmasi → input resi → pesanan selesai, semua lewat UI tanpa akses database manual.
```

---

## Tahap 4 — Billing Platform & Tema Toko

🧠 **Model: Sonnet**

**Repo**: keduanya

```
Bangun modul Billing (gateway platform, BUKAN gateway tenant — lihat tech-spec §1 tabel perbedaan keduanya) dan Theme dasar.

BACKEND (tokospace-api):
1. Migrasi: subscriptions, plans (kuota & fitur sebagai kolom features JSON — data, BUKAN hardcode di kode, supaya Super Admin bisa ubah tanpa deploy)
2. app/Modules/Billing/: integrasi SATU akun gateway platform (Tripay atau Midtrans, milik Tokospace, kredensial di .env bukan per-tenant) untuk menagih langganan seller
3. Trial 14 hari untuk Pro/Business, Starter gratis permanen dengan kuota terbatas
4. Middleware/Policy penegakan kuota: cek sebelum aksi yang menambah data (tambah produk, dst), tampilkan pesan jelas + CTA upgrade saat kuota tercapai — BUKAN error generik
5. Grace period 3 hari gagal bayar → 14 hari read-only (checkout dimatikan, data tetap bisa diekspor) → suspend
6. app/Modules/Theme/: simpan theme_config sebagai JSON per tenant (warna aksen, logo, banner, pilihan tema starter)
7. Pengaman kontras warna: tolak warna aksen dengan kontras <4.5:1 terhadap putih (design brief §4), hitung otomatis warna teks (putih/hitam) di atas warna aksen berdasarkan luminansi

FRONTEND (tokospace-web):
1. Dashboard Billing: pilih/upgrade paket, riwayat invoice, indikator kuota terpakai
2. Theme Editor versi dasar: pilih tema starter, ganti logo/banner/warna aksen dengan live preview + validasi kontras real-time
3. Halaman statis toko: Tentang, Kontak, FAQ, Kebijakan Retur (editor konten sederhana)
4. Banner sistem untuk mode read-only (design brief §7, komponen "Banner Sistem")

Verifikasi DoD: seller bisa upgrade Starter→Pro dan benar-benar bayar lewat gateway platform; begitu kuota tercapai, UI menampilkan CTA upgrade bukan error.
```

---

## Tahap 5 — SEO & Pengerasan MVP

🧠 **Model: Sonnet** (Haiku boleh untuk sub-tugas mekanis seperti generate meta tag berulang)

**Repo**: keduanya

```
Tidak ada modul baru di tahap ini — ini gerbang penutup sebelum MVP dianggap selesai. Kerjakan semua poin berikut, jangan lewati satupun.

BACKEND (tokospace-api):
1. Endpoint revalidasi yang dipanggil Laravel setiap kali produk/toko berubah:
   POST ke tokospace.com/api/revalidate dengan tag terkait (product:{slug}, tenant:{subdomain})
   — pasang di model event 'saved'/'deleted' pada Catalog dan Theme
2. sitemap.xml dan robots.txt digenerate otomatis per tenant/domain
3. Audit ulang SEMUA endpoint yang bisa gagal (cek ongkir, gateway, dst — meski belum aktif di MVP, siapkan pola error response yang konsisten untuk dipakai Tahap 6 nanti)
4. Jalankan spatie/laravel-query-detector di environment testing, perbaiki semua N+1 query yang terdeteksi di endpoint katalog & pesanan

FRONTEND (tokospace-web):
1. Route handler /api/revalidate yang menerima panggilan dari Laravel di atas, panggil revalidateTag()
2. Meta title & description per produk (fallback otomatis dari nama produk + nama toko kalau seller tidak isi)
3. Structured data JSON-LD (Product, Offer) di halaman detail produk
4. Open Graph tag untuk preview link di WhatsApp/medsos (krusial — mayoritas distribusi UMKM lewat WhatsApp)
5. Lighthouse CI: pasang di pipeline, gagalkan build kalau LCP storefront >2,5 detik
6. Cek ulang SEMUA halaman yang sudah dibangun Tahap 1-4 terhadap checklist penyerahan desain (design brief §10) — terutama kontras warna dan touch target di mobile, ini sering terlewat waktu buru-buru ngoding fitur

Setelah ini selesai, jalankan seluruh checklist di tokospace-master-plan.md §6 sebelum mulai Tahap 6.
```

---

## Tahap 6 — Payment & Shipping Otomatis

🧠 **Model: Opus → Sonnet** — pakai `/model opus` untuk merancang verifikasi signature & idempotency webhook (poin 6 di bagian BACKEND), lalu `/model sonnet` untuk sisanya

**Repo**: tokospace-api utama, tokospace-web untuk pengaturan

**Prasyarat**: mapping kode wilayah J&T sudah selesai dengan pihak J&T (proses administratif eksternal — kalau belum, mulai proses itu SEKARANG sebelum lanjut prompt ini, karena ini bottleneck di luar kendali coding)

```
Aktifkan pola Provider penuh di modul Payment dan Shipping — inti tahap ini adalah menambah implementasi baru TANPA mengubah modul Order yang sudah ada, buktikan pola arsitektur dari Tahap 3 memang berfungsi.

BACKEND (tokospace-api):
1. app/Modules/Shipping/Providers/JntProvider.php — implementasi ShippingProviderInterface, 4 endpoint J&T (Order/buat AWB, Tracking, Tariff Check, Cancel Order), signature MD5+base64 sesuai spesifikasi J&T, helper signature terpusat (jangan duplikasi di 4 tempat)
2. app/Modules/Shipping/Providers/KiriminAjaProvider.php — implementasi interface yang sama, termasuk dukungan COD
3. Tariff Check WAJIB sinkron dengan timeout 5 detik, hasil di-cache 24 jam per kombinasi origin+destination+berat, fallback ke ongkir flat kalau gagal/timeout (PRD §4.13) — JANGAN blokir checkout
4. Create AWB dan polling Tracking WAJIB asinkron lewat queue (Horizon), BUKAN sinkron
5. app/Modules/Payment/Providers/TripayProvider.php dan MidtransProvider.php — implementasi kontrak yang sama dengan ManualProvider dari Tahap 3
6. Webhook handler kedua gateway: verifikasi signature WAJIB sebelum proses apapun, idempotency check via gateway_ref (UNIQUE constraint sudah ada dari migrasi), proses lewat queue job bukan langsung di controller
7. Job rekonsiliasi harian untuk COD KiriminAja

FRONTEND (tokospace-web):
1. Dashboard Pengaturan Pembayaran: toggle metode, form connect API key per gateway + tombol "Tes Koneksi", badge "Fitur Paket Pro/Business" untuk seller yang belum upgrade (design brief §7, komponen Badge Fitur Terkunci)
2. Dashboard Pengaturan Pengiriman: sama polanya untuk J&T/KiriminAja
3. Checkout storefront: ongkir terhitung otomatis, tampilkan state "menghitung..." lalu hasil, fallback message kalau gagal

Verifikasi DoD: seller Pro connect J&T, ongkir muncul otomatis di checkout customer, resi terbuat otomatis saat seller proses pesanan — TANPA ada baris kode yang diubah di app/Modules/Order/.
```

---

## Tahap 7 — Custom Domain & WhatsApp Gateway

🧠 **Model: Sonnet**

**Repo**: keduanya

```
Bangun onboarding custom domain otomatis (lewat Vercel Domains API, BUKAN cron DNS-check manual) dan integrasi WhatsApp.

BACKEND (tokospace-api):
1. app/Modules/Domain/VercelDomainService.php: add() panggil POST /v10/projects/{id}/domains, checkStatus() panggil GET /v9/projects/{id}/domains/{domain} lewat job terjadwal, remove() untuk hapus/ganti domain — persis alur di tech-spec §5.2 dan §5.5
2. UI harus bisa membedakan instruksi DNS untuk domain apex vs subdomain (tech-spec §5.3)
3. app/Modules/Notification/: integrasi api.co.id untuk kirim OTP WhatsApp (registrasi/login) dan notifikasi transaksi (konfirmasi pesanan, update pengiriman, reminder bayar)
4. OTP valid 5 menit, maksimum 3x kirim ulang per 15 menit
5. Fallback WAJIB: kalau kirim WA gagal, fallback ke email (PRD §4.7) — jangan biarkan customer tidak dapat info sama sekali
6. Semua notifikasi tercatat di notification_logs dengan status dari webhook HMAC-signed api.co.id

FRONTEND (tokospace-web):
1. Dashboard Domain: form tambah custom domain, instruksi CNAME step-by-step (menyesuaikan apex/subdomain), status real-time ("Menunggu propagasi DNS" → "Aktif") — JUJUR soal waktu tunggu 24-48 jam, jangan terlihat seperti error
2. Toggle "Masuk dengan kode WhatsApp" di halaman Login/Register (pola swap-in-form, sudah didesain sebelumnya di Claude Design — handoff, bukan desain ulang)
3. Dashboard Notifikasi WhatsApp: log riwayat, filter by tipe & status

Verifikasi DoD: seller pasang custom domain sendiri (domain sungguhan, uji nyata bukan simulasi), status berubah ke Aktif tanpa intervensi manual tim Tokospace. Customer bisa login pakai OTP WA end-to-end.
```

---

## Tahap 8 — Fitur Penunjang Seller

🧠 **Model: Sonnet** (Haiku boleh untuk laporan/format sederhana)

**Repo**: keduanya

```
Bangun 3 modul yang relatif independen satu sama lain — Diskon & Promo, Analitik, dan Retur & Refund. Bisa dikerjakan berurutan dalam satu sesi atau dipisah per modul tergantung preferensi.

BACKEND (tokospace-api):
1. app/Modules/Discount/: migrasi coupons + coupon_usages (dengan used_count dan usage_limit_per_customer — PRD menegaskan ini sering terlewat), flash sale dengan jendela waktu
2. app/Modules/Analytics/: migrasi analytics_daily, job terjadwal agregasi harian (JANGAN query berat real-time ke tabel orders/order_items langsung dari dashboard — itu yang bikin dashboard lambat seiring data bertambah)
3. app/Modules/Return/: migrasi returns, alur berbeda per metode pembayaran (manual = pencatatan status saja, gateway = panggil API refund kalau didukung, COD = dikecualikan dari rekonsiliasi) — sesuai PRD §4.12, stok dikembalikan HANYA setelah seller konfirmasi barang diterima kembali, bukan otomatis saat pengajuan

FRONTEND (tokospace-web):
1. Dashboard Diskon & Promo: list kupon, form buat kupon, flash sale scheduler
2. Dashboard Analitik: grafik penjualan, produk terlaris, nilai rata-rata pesanan, funnel checkout — dari data analytics_daily, bukan query live
3. Dashboard Retur: list pengajuan, detail (alasan + foto customer), aksi setujui/tolak
4. Storefront: form ajukan retur dari halaman detail pesanan customer

Verifikasi DoD: seller buat kupon dan berhasil dipakai customer sesuai syarat; dashboard analitik menampilkan data tanpa query lambat meski data pesanan sudah ribuan baris (uji dengan data dummy sebanyak itu, bukan cuma 5 baris).
```

---

## Tahap 9 — Super Admin Lengkap

🧠 **Model: Sonnet**

**Repo**: tokospace-web utama (halaman admin), tokospace-api untuk endpoint pendukung

```
Lengkapi panel Super Admin dari versi minimal (approve/suspend seller, sudah ada sejak Tahap 1) jadi panel penuh.

BACKEND (tokospace-api):
1. Endpoint monitoring status integrasi pihak ketiga per toko (J&T/KiriminAja/Tripay/Midtrans/WA), sumber datanya dari log yang sudah ada (integration_logs) bukan query baru yang mahal
2. CRUD paket & fitur terkunci (plans.features) dari sisi admin — perubahan di sini harus langsung berlaku ke seller tanpa deploy
3. Endpoint laporan pendapatan langganan platform (BUKAN pendapatan+fee — Tokospace tidak memegang dana seller sesuai keputusan D1, jangan tampilkan angka yang menyiratkan sebaliknya)

FRONTEND (tokospace-web):
1. src/app/(admin)/: dashboard overview, manajemen seller, manajemen domain, manajemen paket, monitoring integrasi (badge merah untuk toko bermasalah), billing platform, support/tiket
2. Layout paling flat & data-dense dibanding area lain (design brief §9) — prioritaskan tabel jelas dibanding elemen visual besar

Verifikasi DoD: admin bisa melihat toko mana yang integrasinya bermasalah tanpa harus cek satu-satu secara manual, dan bisa mengubah fitur paket tanpa minta developer deploy ulang.
```

---

## Catatan Eksekusi

- **Satu tahap = idealnya satu sesi Claude Code yang fokus**, jangan gabung beberapa tahap sekaligus dalam satu prompt panjang — sulit di-review dan sulit tahu di mana letak bug kalau sesuatu salah
- **Jalankan DoD di master plan §4 setelah tiap tahap**, bukan cuma percaya laporan "sudah selesai" dari Claude Code — terutama test reservasi stok (Tahap 3) dan test isolasi tenant (Tahap 1), keduanya harus benar-benar dijalankan dan dilihat hasilnya
- Kalau sebuah tahap butuh desain yang belum dibuat di Claude Design, **berhenti, desain dulu**, baru lanjut coding — lihat master plan §5 untuk status desain per tahap
- Dokumen ini akan terasa ketinggalan seiring project berjalan — kalau ada modul baru yang tidak tercakup di sini, tambahkan sebagai Tahap 10+ mengikuti pola yang sama (Backend/Frontend/Verifikasi DoD), jangan improvisasi struktur baru di tengah jalan
