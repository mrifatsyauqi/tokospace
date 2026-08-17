# Tokospace — Design Brief

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain** | tokospace.com |
| **Versi** | 2.0 — dokumen utama brief desain |
| **Tanggal** | 17 Agustus 2026 |
| **Menggantikan** | `tokospace-design-breakdown.md` v1.x |
| **Selaras dengan** | `tokospace-PRD.md` v1.1 |

> **Dokumen ini adalah sumber kebenaran untuk semua keputusan desain Tokospace.** Jika ada konflik dengan dokumen lain, dokumen ini yang berlaku untuk hal-hal visual & interaksi; `tokospace-PRD.md` yang berlaku untuk cakupan fitur & logika bisnis.

---

## Changelog v2.0 (hasil audit v1.x)

**Diperbaiki:**
- Domain diseragamkan `tokospace.id` → `tokospace.com` (3 tempat)
- **Halaman Pembayaran**: elemen "Saldo tersedia / riwayat penarikan / ajukan payout" **dihapus** — bertentangan dengan PRD v1.1 D1 (Tokospace tidak memegang dana seller)
- **Admin Dashboard**: "pendapatan (subscription + fee)" → "pendapatan langganan" (fee transaksi keluar dari scope)
- **Halaman Billing**: dipisah jelas antara bayar langganan (gateway platform) vs terima bayaran customer (gateway tenant)
- `ink-400` diperbaiki dari `#8A8A8A` → `#6E6E6E` karena gagal kontras WCAG AA yang diwajibkan PRD §5.9
- Heading kosong "Aturan Teknis Lain" dirapikan

**Ditambahkan:**
- §3 Sistem State (loading, empty, error, disabled, skeleton) — sebelumnya tidak ada sama sekali
- §4 Batasan kustomisasi warna seller — mencegah seller merusak keterbacaan tokonya sendiri
- §5 Ikonografi, motion, dan aturan gambar produk
- 11 halaman/state yang hilang: retur, verifikasi email, toko suspended, mode read-only, kuota tercapai, stok habis, pesanan kedaluwarsa, integrasi bermasalah, 404/500, hasil pencarian kosong
- §9 Checklist penyerahan desain

---

## 1. Arah Desain

**Konsep**: *Monochrome Confidence* — putih sebagai kanvas kosong yang tenang, hitam sebagai satu-satunya "suara" tegas untuk menandai apa yang penting: aksi utama, elemen aktif, dan data kunci. Tidak ada warna yang bersaing dengan konten milik seller (foto produk, angka penjualan) — Tokospace adalah panggung, bukan bintangnya.

**Prinsip**: *hitam = perhatian, putih = ruang, abu-abu = struktur.* Kalau semua di-highlight, tidak ada yang benar-benar ter-highlight — hitam dipakai selektif (CTA utama, status aktif, elemen terpilih), bukan dekorasi.

**Tiga hal yang harus terasa oleh pengguna:**
1. **Cepat dimengerti** — seller UMKM dengan kemampuan teknis rendah harus bisa pakai tanpa tutorial
2. **Bisa dipercaya** — customer sedang menyerahkan uang ke toko kecil yang tidak dikenalnya; UI harus terasa aman dan rapi
3. **Tidak mengambil panggung** — toko seller yang harus terlihat, bukan Tokospace

---

## 2. Design Tokens

### 2.1 Warna

| Token | Hex | Fungsi | Kontras di atas putih |
|---|---|---|---|
| `bg-base` | `#FFFFFF` | Background utama semua halaman | — |
| `bg-subtle` | `#F7F7F5` | Background section sekunder, sidebar, card berlapis | — |
| `ink-900` | `#0A0A0A` | Teks utama, komponen highlight (tombol primer, nav aktif) | 19.8:1 ✅ |
| `ink-600` | `#525252` | Teks sekunder/deskripsi | 7.9:1 ✅ |
| `ink-400` | `#6E6E6E` | Placeholder, label kecil, teks tersier | 5.2:1 ✅ |
| `ink-300` | `#9A9A9A` | **Hanya** untuk elemen disabled & ikon dekoratif — tidak untuk teks yang harus dibaca | 2.9:1 ⚠️ |
| `line-200` | `#E5E5E2` | Border/hairline, pemisah section | — |
| `line-100` | `#EFEFED` | Border sangat halus (table row, card) | — |
| `success` | `#1A7F37` | Status berhasil/aktif | 4.8:1 ✅ |
| `danger` | `#C22E2E` | Status gagal/error/stok habis | 5.1:1 ✅ |
| `warning` | `#8A6410` | Status pending/menunggu | 5.4:1 ✅ |

**Catatan perubahan dari v1.x**: `ink-400` sebelumnya `#8A8A8A` (kontras 3.5:1) dan `warning` sebelumnya `#B8860B` (3.3:1) — keduanya **gagal WCAG AA** untuk teks normal, padahal PRD §5.9 mewajibkannya. Nilai baru sudah lolos. Token `ink-300` ditambahkan khusus untuk elemen disabled, karena elemen disabled memang dikecualikan dari syarat kontras.

`success`, `danger`, `warning` **hanya** untuk status semantik (badge, alert, pesan validasi) — tidak untuk dekorasi UI.

### 2.2 Tipografi

| Peran | Font | Fallback | Penggunaan |
|---|---|---|---|
| **Display** | *General Sans* | `Inter, system-ui, sans-serif` | H1, hero, judul section. Weight 600–700, tracking rapat |
| **Body/UI** | *Inter* | `system-ui, -apple-system, sans-serif` | Semua teks UI, form, deskripsi. Weight 400/500 |
| **Data** | *IBM Plex Mono* | `ui-monospace, monospace` | Harga, no. pesanan, resi, SKU, invoice ID |

**Catatan lisensi**: General Sans (Fontshare) dan IBM Plex Mono gratis untuk komersial. Neue Montreal (disebut sebagai alternatif di v1.x) **berbayar** — dikeluarkan dari brief ini untuk menghindari masalah lisensi.

**Skala dan pemetaan konkret:**

| Ukuran | Desktop | Mobile | Dipakai untuk |
|---|---|---|---|
| Display XL | 64px | 32px | Hero landing page |
| Display L | 48px | 28px | H1 halaman |
| H2 | 32px | 24px | Judul section |
| H3 | 24px | 20px | Judul card, judul modal |
| Body L | 18px | 16px | Paragraf marketing |
| Body | 16px | 16px | Teks UI default, isi form |
| Small | 14px | 14px | Label, teks sekunder, teks tabel |
| Caption | 12px | 12px | Timestamp, helper text, badge |

Line-height: 1.5–1.6 untuk body, 1.1–1.2 untuk display. **Ukuran teks tidak boleh di bawah 12px** di mana pun.

### 2.3 Layout & Bentuk

- **Grid**: 12 kolom desktop (max-width 1280px untuk marketing), 4 kolom mobile
- **Radius**: `4px` input/button, `8px` card, `12px` modal/bottom sheet. Tidak ada radius besar (kesan tegas, bukan playful)
- **Border**: hairline 1px `line-200` sebagai pengganti shadow di sebagian besar tempat; shadow tipis hanya untuk elevasi modal/dropdown/bottom sheet
- **Spacing**: kelipatan 4px (4/8/12/16/24/32/48/64/96). Padding halaman 16px mobile, 32–64px desktop
- **Elemen signature**: garis hitam solid 2px di titik transisi penting (di atas tombol checkout, di bawah harga produk, di header dashboard) — penekanan visual pengganti warna

### 2.4 Mode Gelap

**Tidak ada dark mode di V1 dan Fase 1.** Ini keputusan sadar, bukan kelalaian — identitas produk bertumpu pada kontras putih-hitam, dan mendukung dark mode berarti mendefinisikan ulang seluruh sistem token plus perilaku tema kustom seller. Ditinjau ulang di Fase 2. Desain tidak perlu menyediakan varian gelap.

---

## 3. Sistem State (wajib untuk setiap komponen & halaman)

Bagian ini tidak ada di dokumen sebelumnya, padahal state adalah penyebab paling umum desain terlihat "belum jadi" saat masuk development.

**Setiap halaman yang menampilkan data wajib punya 5 state:**

| State | Perlakuan |
|---|---|
| **Loading** | Skeleton placeholder mengikuti bentuk konten akhir (`bg-subtle`, animasi shimmer halus) — bukan spinner di tengah layar kosong |
| **Empty (belum ada data)** | Ilustrasi line-art hitam-putih + judul singkat + 1 kalimat penjelas + 1 tombol aksi utama. Nada mengajak, bukan meminta maaf ("Tambah produk pertama", bukan "Belum ada data") |
| **Empty (hasil filter/pencarian kosong)** | Berbeda dari empty di atas — tanpa ilustrasi, cukup teks + tombol "Hapus filter" |
| **Error** | Pesan jelas apa yang terjadi + apa yang bisa dilakukan + tombol "Coba lagi". Jangan tampilkan kode error mentah ke seller/customer |
| **Partial / degraded** | Saat sebagian data gagal dimuat (mis. ongkir gagal dihitung), tampilkan bagian yang berhasil + catatan inline pada bagian yang gagal — jangan gagalkan seluruh halaman |

**Setiap elemen interaktif wajib punya:** default, hover (desktop), focus (keyboard — ring hitam 2px, jangan hilangkan outline), active/pressed, disabled (`ink-300`, cursor not-allowed), loading (untuk tombol submit: spinner kecil + teks berubah, tombol non-aktif agar tidak double-submit).

**Validasi form:**
- Error muncul di bawah field, teks 12px `danger`, disertai ikon
- Validasi dijalankan saat blur (bukan saat mengetik huruf pertama), lalu real-time setelah error pertama muncul
- Error di level form (mis. gagal simpan) tampil di atas tombol submit, bukan sebagai toast yang hilang

---

## 4. Batasan Kustomisasi Seller

Seller bisa mengubah warna aksen, logo, dan banner tokonya. Tanpa batasan, seller bisa membuat tokonya sendiri tidak terbaca — ini merugikan seller dan reputasi Tokospace.

**Yang boleh diubah seller:** warna aksen (dipakai untuk tombol beli, link, highlight), logo, banner hero, susunan section homepage, font display (dari daftar terkurasi, bukan bebas).

**Yang tidak boleh diubah:** warna teks utama, warna background halaman, warna status semantik (success/danger/warning), radius, spacing, struktur navigasi.

**Pengaman wajib di theme editor:**
- Color picker menolak warna dengan kontras <4.5:1 terhadap putih, dengan pesan jelas ("Warna ini terlalu terang, teks di tombol akan sulit dibaca") — bukan sekadar peringatan yang bisa diabaikan
- Sistem menghitung otomatis warna teks di atas aksen (putih atau hitam) berdasarkan luminansi, seller tidak perlu memilih
- Logo dengan rasio ekstrem di-fit ke bounding box, tidak merusak layout header
- Preview real-time menampilkan hasil sebenarnya, termasuk saat warna ditolak

---

## 5. Ikonografi, Motion & Gambar

**Ikon**: satu library outline konsisten (rekomendasi: **Lucide** — gratis, MIT, cocok dengan estetika garis tipis). Stroke 1.5–2px, ukuran 16px (inline), 20px (tombol), 24px (nav). Tidak mencampur beberapa library. Tidak memakai emoji sebagai ikon UI.

**Motion**: fungsional, bukan dekoratif.
- Durasi: 150ms (mikro: hover, focus), 200–250ms (dropdown, tooltip), 300ms (bottom sheet, drawer, modal)
- Easing: `ease-out` untuk masuk, `ease-in` untuk keluar
- Hormati `prefers-reduced-motion` — matikan animasi non-esensial
- Tidak ada animasi loop, parallax, atau efek dekoratif di dashboard

**Gambar produk**:
- Rasio tampilan seragam **1:1** di grid katalog (crop otomatis, seller tidak perlu memikirkan ini)
- Detail produk boleh menampilkan rasio asli dalam galeri
- Placeholder saat gambar belum ada: kotak `bg-subtle` dengan ikon gambar `ink-300` di tengah — bukan kotak kosong putih yang terlihat rusak
- Lazy-load semua gambar di bawah lipatan; skeleton saat memuat

---

## 6. Pendekatan Responsif: Dua Tampilan Eksplisit

Setiap halaman dibuat sebagai **dua desain terpisah**, bukan satu layout yang menyusut:

1. **[Mobile]** — acuan 375–414px, **dibuat lebih dulu**. Mayoritas seller UMKM dan customer Indonesia mengakses lewat HP
2. **[Desktop]** — acuan 1440px, dibuat setelahnya, bebas menata ulang layout sepenuhnya

**Tablet** (768–1024px) tidak dibuat sebagai desain ketiga — cukup transisi responsif mengikuti struktur desktop dengan grid lebih ringkas, diatur lewat CSS breakpoint.

**Aturan:** konten & fungsi **setara** di kedua versi — tidak ada fitur hilang di mobile, hanya disusun ulang. Label penyerahan wajib eksplisit: `[Mobile]` / `[Desktop]`.

### Perbedaan Layout Kunci

| Elemen | [Mobile] | [Desktop] |
|---|---|---|
| Navigasi utama | Bottom nav (storefront, maks 5 item) / hamburger + drawer (dashboard, marketing) | Sidebar tetap (dashboard) / nav bar horizontal (marketing, storefront) |
| Grid produk | 2 kolom | 4 kolom |
| Tabel data | Stacked card, 1 baris = 1 card | Tabel dengan header & row |
| Form multi-section | 1 kolom, accordion/step | Multi-kolom berdampingan |
| Modal | Bottom sheet (drag handle di atas) | Modal center dengan overlay |
| Theme Editor | 2 tab: "Edit" & "Preview" | Panel kontrol & live preview berdampingan |
| Checkout | 1 kolom, ringkasan collapsible | 2 kolom, ringkasan sticky kanan |
| Touch target | Minimum 44×44px, tombol sering full-width | Ukuran standar, tombol sesuai lebar konten |

---

## 7. Komponen Inti

| Komponen | Spesifikasi |
|---|---|
| **Tombol Primer** | Background `ink-900`, teks putih, radius 4px. Hover: `#1A1A1A`. Focus: ring hitam 2px offset 2px. Loading: spinner + label berubah, non-aktif |
| **Tombol Sekunder** | Border 1px `ink-900`, background transparan, teks `ink-900` |
| **Tombol Ghost** | Tanpa border, teks `ink-600`, underline saat hover |
| **Tombol Destruktif** | Border/teks `danger`; versi solid hanya di dalam dialog konfirmasi |
| **Input Field** | Border `line-200`, focus: border `ink-900` + ring halus. Error: border `danger` + pesan di bawah. Tinggi minimum 44px di mobile |
| **Card** | Background putih, border `line-100`, tanpa shadow di state normal; shadow tipis saat hover (kartu produk, pricing) |
| **Badge Status** | Pill kecil, background solid warna semantik + teks putih. Badge netral: `bg-subtle` + teks `ink-900` |
| **Badge Fitur Terkunci** | Pill outline + ikon gembok, teks "Paket Pro/Business", klik → halaman upgrade |
| **Badge Metode** | Pill outline tipis untuk metode kirim/bayar di list pesanan — bobot lebih ringan dari badge status agar tidak bersaing |
| **Navigasi Aktif** | Desktop: garis vertikal/underline hitam + teks bold, non-aktif `ink-400`. Mobile: bottom nav (ikon aktif hitam solid) atau drawer |
| **Tabel** | Desktop: header 12px uppercase `ink-400`, row hairline `line-100`, hover `bg-subtle`. Mobile: stacked card (info utama bold di baris pertama, sekunder + badge di bawah) |
| **Empty state** | Ilustrasi line-art hitam-putih + judul + 1 kalimat + tombol aksi |
| **Modal/Dialog** | Desktop: modal center + overlay. Mobile: bottom sheet, drag handle di atas |
| **Toast** | Pojok atas (desktop) / atas layar (mobile), auto-dismiss 4 detik. **Tidak** untuk pesan error kritis — itu inline |
| **Banner Sistem** | Pita full-width di atas konten untuk kondisi persisten (mode read-only, integrasi bermasalah, trial akan habis) |

---

## 8. Breakdown Halaman

### 8.1 Marketing Site (`tokospace.com`)

| Halaman | Elemen |
|---|---|
| **Landing** | Hero (headline + CTA "Buat Toko Gratis"), demo interaktif nama toko → preview subdomain real-time, showcase tema, perbandingan paket, testimoni, FAQ, footer |
| **Pricing** | 3 paket, toggle bulanan/tahunan, tabel perbandingan termasuk baris "Integrasi Pengiriman" (Resi Manual / +J&T API / +KiriminAja) dan "Integrasi Pembayaran" (Transfer Manual / +Tripay / +Midtrans), plus baris kuota (jumlah produk, staff) |
| **Tema Gallery** | Grid preview tema, filter kategori, tombol "Pakai Tema Ini" |
| **/login** | Form Email/HP + Password + link "Lupa password?" + tombol primer "Masuk". Divider "atau" → 2 tombol sekunder sejajar: "Lanjutkan dengan Google", "Masuk dengan kode WhatsApp". Klik WhatsApp **mengganti isi form** jadi step nomor HP → 6 kotak OTP + link "← Kembali" + countdown. Footer: link ke /register |
| **/register** | Form Nama, Email/HP, Password + "Buat Akun". Pola tombol sekunder & swap sama seperti login. Footer: link ke /login |
| **/forgot-password** | Step 1: input email/HP. Step 2: set password baru |
| **/verify-email** *(baru)* | Layar tunggu verifikasi + tombol "Kirim ulang" dengan countdown + petunjuk cek folder spam |
| **404 / 500** *(baru)* | Halaman error dengan navigasi kembali, konsisten dengan sistem visual |

**Pola auth (penting)**: `/login`, `/register`, `/forgot-password` adalah **3 halaman terpisah**, berpindah lewat link teks di footer — bukan tab dalam satu card. Desktop: split-screen (panel kiri hitam solid untuk branding, panel kanan form max-width ±420px). Mobile: satu kolom, logo kecil di atas form.

### 8.2 Seller Dashboard (`app.tokospace.com`)

| Halaman | Elemen |
|---|---|
| **Onboarding Wizard** | Step 1: nama toko + cek subdomain real-time, Step 2: kategori bisnis, Step 3: pilih tema starter, Step 4: upload logo (bisa skip). Progress indicator hitam-putih |
| **Dashboard Home** | Ringkasan penjualan, pesanan baru, produk terlaris, grafik garis hitam, daftar aksi tertunda, banner sistem bila ada (trial habis, integrasi bermasalah) |
| **Produk — List** | Tabel/stacked card (foto, nama, harga, stok, status), filter, bulk action, tombol "Tambah Produk". Indikator kuota terpakai (mis. "38/50 produk") |
| **Produk — Tambah/Edit** | Form multi-section: info dasar, harga, **berat (gram)**, varian, stok, galeri foto drag-drop, SEO (meta title/desc dengan preview hasil di Google) |
| **Import CSV** | Upload, preview mapping kolom, validasi error per baris, ringkasan sebelum commit |
| **Pesanan — List** | Status badge + badge metode kirim/bayar (outline), filter tanggal/status/metode, search |
| **Pesanan — Detail** | Info customer, item, timeline status (+ indikator notifikasi WA terkirim/gagal per step), aksi: update status, input resi manual **atau** "Buat Resi Otomatis", cetak label, verifikasi bukti transfer |
| **Pembayaran** | Toggle metode: Transfer Bank Manual (input rekening — semua paket) / Payment Gateway Tripay & Midtrans (badge terkunci bila belum upgrade), form connect API key + "Tes Koneksi" + status koneksi. **Tidak ada saldo/payout** — dana masuk langsung ke rekening seller |
| **Pengiriman** | Pilih metode: Resi Manual / J&T Express API / KiriminAja (badge terkunci bila belum upgrade), form kredensial + tes koneksi, status & waktu sinkronisasi terakhir, pengaturan ongkir flat & gratis ongkir |
| **Retur** *(baru)* | List pengajuan retur, detail (alasan + foto customer), aksi setujui/tolak, status refund per metode bayar |
| **Notifikasi WhatsApp** | Status koneksi, log notifikasi (tipe, penerima, status, waktu), filter |
| **Diskon & Promo** | List kupon, form buat kupon, flash sale scheduler |
| **Theme Editor** | Kontrol (tema, warna aksen dengan pengaman kontras, logo, banner, section) + live preview. Toggle preview desktop/mobile |
| **Halaman Toko** | Editor konten statis: Tentang, Kontak, FAQ, Kebijakan Retur |
| **Domain** | Status subdomain, form custom domain, instruksi CNAME step-by-step, status verifikasi |
| **Analitik** | Grafik penjualan per periode, produk terlaris, nilai rata-rata pesanan, tingkat penyelesaian checkout. *(Sumber trafik dihapus dari v1.x — PRD tidak membangun tracking sendiri di Fase 1)* |
| **Staff & Akses** *(Fase 2)* | List staff, undang staff, atur permission |
| **Pengaturan Toko** | Identitas, kontak, metode aktif, preferensi notifikasi |
| **Langganan/Billing** | Paket aktif + kuota terpakai, riwayat invoice, upgrade/downgrade, metode pembayaran langganan (**gateway platform** — untuk membayar Tokospace, terpisah dari pengaturan Pembayaran toko) |

**State khusus dashboard yang wajib didesain:**
- **Mode read-only** (langganan gagal bayar): banner persisten di atas, tombol yang menambah data non-aktif dengan tooltip penjelas, ekspor data tetap bisa
- **Kuota tercapai**: pesan inline + CTA upgrade saat menekan "Tambah Produk", bukan error generik
- **Integrasi bermasalah**: banner + badge merah di menu terkait

### 8.3 Storefront (per-tenant)

| Halaman | Elemen |
|---|---|
| **Beranda Toko** | Banner hero (custom seller), produk unggulan, kategori, section promo |
| **Katalog** | Grid produk, filter (harga, kategori, varian), sort, pagination. Mobile: filter via bottom sheet |
| **Detail Produk** | Galeri, pilih varian, harga, deskripsi, tombol beli/keranjang (sticky di mobile), ulasan, produk terkait. **State stok habis**: tombol non-aktif + label jelas, produk tetap terlihat |
| **Keranjang** | List item, edit qty, hapus, ringkasan, tombol checkout |
| **Checkout** | Form alamat, ongkir otomatis sesuai metode toko, pilih metode bayar sesuai yang diaktifkan seller, upload bukti transfer (bila manual), ringkasan, konfirmasi. **State ongkir gagal dihitung**: tampilkan ongkir fallback + catatan "ongkir final dikonfirmasi penjual" |
| **Konfirmasi Pesanan** | Nomor pesanan, ringkasan, instruksi lanjutan sesuai metode bayar, batas waktu pembayaran |
| **Tracking Pesanan** | Input nomor pesanan/email → timeline status |
| **Ajukan Retur** *(baru)* | Form alasan + unggah foto, dari halaman detail pesanan |
| **Akun Customer** | Login/registrasi (OTP WhatsApp atau email), riwayat pesanan, alamat tersimpan, wishlist |
| **Tentang / Kontak / FAQ** | Konten statis dari editor seller |
| **Toko Suspended** *(baru)* | Halaman netral tanpa branding Tokospace yang mencolok, tanpa menjelekkan seller — cukup "Toko sedang tidak tersedia" |
| **404 toko / produk** *(baru)* | Konsisten dengan tema toko, dengan tautan kembali ke katalog |

### 8.4 Super Admin (`admin.tokospace.com`)

| Halaman | Elemen |
|---|---|
| **Dashboard Overview** | Seller aktif, transaksi platform, **pendapatan langganan** (bukan +fee), grafik pertumbuhan |
| **Manajemen Seller** | List seller (status, paket, tanggal daftar), detail toko, suspend/aktifkan |
| **Manajemen Domain** | List custom domain, status verifikasi, approve/revoke |
| **Manajemen Paket** | CRUD paket, harga, **kuota** (jumlah produk/staff), toggle fitur terkunci per paket |
| **Manajemen Tema** | Upload/kelola tema |
| **Monitoring Integrasi** | Status koneksi per toko (J&T/KiriminAja/Tripay/Midtrans/WA), log error, filter toko bermasalah |
| **Billing Platform** | Riwayat invoice semua seller, laporan pendapatan |
| **Support/Tiket** | List tiket, status penanganan |
| **Log Aktivitas** *(Fase 2)* | Audit log aksi penting |

---

## 9. Prinsip per Area

- **Marketing** → hitam-putih dipakai berani di hero (headline besar, CTA hitam solid) untuk kesan premium; di mobile keberanian dijaga lewat skala headline meski layout 1 kolom
- **Dashboard seller** → hitam dipakai fungsional: menandai status, aksi utama, dan angka penting, supaya seller cepat membaca tanpa lelah visual — dari HP di sela kerja maupun dari laptop
- **Storefront** → sistem hitam-putih jadi default netral agar foto produk seller jadi elemen paling menonjol
- **Admin** → paling flat dan data-dense; di mobile difokuskan untuk monitoring cepat, bukan pengerjaan tugas kompleks

---

## 10. Checklist Penyerahan Desain

Sebelum desain dianggap selesai untuk satu tahap:

- [ ] Versi `[Mobile]` (375px) dan `[Desktop]` (1440px) ada untuk **semua** halaman di tahap itu, diberi label
- [ ] Konten & fungsi setara di kedua versi — tidak ada fitur hilang di mobile
- [ ] Kelima state (loading, empty, empty-filter, error, partial) sudah didesain untuk halaman berdata
- [ ] State elemen interaktif lengkap: default, hover, focus, active, disabled, loading
- [ ] Semua touch target ≥44×44px di mobile
- [ ] Tidak ada tabel yang di-scroll horizontal di mobile — sudah jadi stacked card
- [ ] Semua warna teks memenuhi kontras ≥4.5:1 (cek dengan contrast checker, jangan mengira-ngira)
- [ ] Tidak ada teks di bawah 12px
- [ ] Tidak ada warna di luar token — termasuk warna "hampir sama"
- [ ] Alur kritis (checkout, buat resi, konfirmasi pembayaran) sudah diuji dari lebar 375px

---

## 11. Dokumen Terkait

- `tokospace-PRD.md` v1.1 — cakupan fitur, logika bisnis, acceptance criteria
- `tokospace-prompt-bertahap.md` — prompt eksekusi desain per tahap
- `tokospace-PRD-audit-report.md` — temuan audit PRD

**Terminologi**: [Mobile] = 375–414px · [Desktop] = 1440px · Tenant = satu toko/seller · Gateway platform = untuk seller bayar Tokospace · Gateway tenant = untuk customer bayar seller
