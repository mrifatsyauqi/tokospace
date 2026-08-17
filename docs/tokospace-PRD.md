# Product Requirements Document (PRD) — Tokospace.com

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain produksi** | tokospace.com |
| **Versi dokumen** | 1.1 (revisi pasca-audit) |
| **Tanggal** | 17 Agustus 2026 |
| **Status** | Draft untuk review — siap breakdown ke sprint development setelah 3 keputusan di §0 difinalkan |
| **Sumber** | Disusun dari `tokospace-konsep-produk.md`, direvisi berdasarkan `tokospace-PRD-audit-report.md` |

### Changelog v1.1
Perubahan dari v1.0 berdasarkan hasil audit:
- **Ditambah §0** — 3 keputusan blocker yang wajib difinalkan sebelum development
- **Model monetisasi diluruskan** (§4.4, §4.11) — fee transaksi & saldo/payout dikeluarkan dari scope; gateway platform dipisah dari gateway tenant
- **Identitas customer ditetapkan** per-toko (§4.12), berikut konsekuensi skema DB
- **Aturan sinkron vs asinkron** untuk API pihak ketiga diperjelas (§5.4, §6.3)
- **Ditambah** reservasi stok (§4.3), error path integrasi (§4.13), alur retur/refund (§4.14), analitik (§4.15), SEO (§4.16), penegakan kuota paket (§4.11)
- **Skema DB diperbaiki** (§6.4) — tambah `categories`, `coupon_usages`, `otp_codes`, snapshot di `order_items`/`orders`, `tenant_id` konsisten
- **Ditambah §5.8** testing, environment, backup & DR; **§6.1** email provider

---

## 0. Keputusan Blocker (wajib difinalkan sebelum baris kode pertama)

Tiga hal ini memengaruhi skema database dan arsitektur inti — mengubahnya setelah development berjalan berarti migrasi besar. PRD ini sudah mengambil posisi default untuk masing-masing supaya tim bisa mulai, tapi **wajib dikonfirmasi eksplisit**.

| # | Keputusan | Posisi default PRD v1.1 | Konsekuensi jika berubah |
|---|---|---|---|
| **D1** | Siapa pemegang dana transaksi customer? | **Seller** — seller connect gateway miliknya sendiri, dana langsung ke seller. Tokospace monetisasi murni dari langganan. **Tidak ada** fee transaksi, saldo seller, maupun payout. | Jika Tokospace ingin pegang dana & potong fee, dibutuhkan akun gateway atas nama Tokospace, modul saldo + payout, rekonsiliasi, dan kemungkinan izin PJP dari Bank Indonesia — ini menambah scope besar dan risiko regulasi |
| **D2** | Bagaimana seller membayar langganan di MVP? | **Gateway platform terpisah** (satu akun Midtrans/Tripay milik Tokospace, hardcode di config, bukan per-tenant) — aktif sejak MVP | Jika ditunda, MVP harus jalan sebagai closed beta gratis penuh, dan seluruh modul billing mundur ke Fase 1 |
| **D3** | Akun customer: per-toko atau lintas-toko? | **Per-toko** — `users.email` unik per `tenant_id` (composite unique), customer daftar ulang di tiap toko | Jika lintas-toko, butuh tabel pivot `customer_tenant`, email unik global, dan kebijakan privasi lintas-tenant (Toko A tidak boleh melihat riwayat customer di Toko B) |

Catatan: D1 adalah perubahan dari konsep produk awal, yang menyebut fee transaksi 1-2% dan fitur saldo/payout. Konsep itu mengasumsikan Tokospace memegang dana, sementara desain "seller connect gateway sendiri" tidak memungkinkan hal tersebut — dua hal itu tidak bisa jalan bersamaan, jadi PRD ini memilih yang paling sederhana dan paling rendah risiko regulasinya untuk tahap awal.

---

## 1. Latar Belakang & Tujuan Produk

Tokospace adalah platform SaaS yang memungkinkan seller UMKM di Indonesia membuat toko online sendiri tanpa coding — mendaftar, mendapat sub-domain otomatis (`namatoko.tokospace.com`), lalu mengatur produk, tema, pembayaran, dan pengiriman dari satu dashboard. Model bisnis: langganan bulanan bertingkat (Starter/Pro/Business) dengan fitur integrasi pembayaran & pengiriman terkunci di paket berbayar.

**Masalah yang diselesaikan**: UMKM Indonesia butuh toko online sendiri (bukan cuma lapak di marketplace) tapi tidak punya kapasitas teknis untuk membangun dan mengelola infrastruktur e-commerce, integrasi pembayaran, dan pengiriman sendiri.

**Tujuan V1 (MVP)**: seller bisa mendaftar, punya toko live dengan sub-domain, jual produk, terima pembayaran (minimal transfer manual), dan kirim pesanan (minimal resi manual) — dalam waktu <15 menit dari pendaftaran ke toko pertama live.

### 1.1 Metrik Keberhasilan (Success Metrics)
Belum ada di dokumen sumber — ini usulan awal yang perlu disepakati bersama sebelum development:

| Metrik | Definisi | Target Awal (usulan) |
|---|---|---|
| Waktu pendaftaran → toko live | Dari submit registrasi sampai storefront dapat diakses publik | < 15 menit |
| Seller aktif | Toko dengan ≥1 produk terpublikasi **dan** ≥1 login dalam 30 hari terakhir | 100 toko di bulan pertama |
| Konversi Starter → berbayar | Seller Starter yang upgrade ke Pro/Business dalam 60 hari | ≥ 10% |
| Toko bertransaksi | Toko dengan ≥1 pesanan berstatus selesai per bulan | ≥ 40% dari seller aktif |
| Uptime platform | Storefront + dashboard | ≥ 99.5% |
| Waktu render storefront (LCP) | Halaman produk, koneksi 4G | < 2.5 detik |

Metrik "konversi trial" di v1.0 dihapus karena tidak konsisten dengan model Starter gratis permanen (§4.11) — diganti dengan konversi Starter → berbayar.

---

## 2. Ruang Lingkup (Scope)

### 2.1 In-Scope — V1 (MVP)
- Registrasi & onboarding seller, sub-domain otomatis
- Manajemen produk (CRUD, varian, stok, kategori, gambar)
- Manajemen pesanan (status, riwayat)
- Pembayaran: Transfer Bank Manual (built-in, semua paket)
- Pengiriman: Resi Manual (built-in, semua paket)
- Kustomisasi toko dasar (pilih tema, logo, banner, warna)
- Storefront publik (katalog, keranjang, checkout, tracking manual)
- Login/registrasi email+password
- Billing langganan via **gateway platform** (akun Tokospace, bukan per-tenant) — lihat D2
- Super Admin dasar (approve seller, monitoring toko)
- SEO dasar storefront (meta tag, slug, sitemap)

### 2.2 In-Scope — Fase 1 (paska-MVP, prioritas berikutnya)
- Integrasi J&T Express API (Order, Tracking, Tariff Check, Cancel Order)
- Integrasi KiriminAja (aggregator + COD)
- Integrasi Payment Gateway Tripay & Midtrans
- Integrasi WhatsApp Gateway (api.co.id) — OTP login & notifikasi transaksi
- Diskon & promo (kupon, flash sale)
- Custom domain + auto SSL
- Analitik penjualan

### 2.3 In-Scope — Fase 2+
- Staff toko multi-role
- Marketplace tema pihak ketiga
- API publik untuk integrasi eksternal (akuntansi/POS)
- App mobile seller

### 2.4 Out of Scope (khusus V1 & Fase 1 — eksplisit TIDAK dikerjakan)

*Catatan: sebagian item di sini muncul kembali di Fase 2+ (§2.3). "Out of scope" berlaku untuk V1 dan Fase 1 saja, bukan selamanya.*

- **Tokospace sebagai pemegang dana** — tidak ada saldo seller, payout, maupun fee transaksi (lihat D1). Dana customer masuk langsung ke akun gateway/rekening seller
- Multi-currency / penjualan lintas negara
- Marketplace terpusat (customer belanja lintas-toko dalam satu checkout)
- Akun customer lintas-toko (lihat D3 — customer daftar per toko)
- Native mobile app (iOS/Android) — web-only, mobile-first responsive (app seller baru dipertimbangkan di Fase 3)
- Integrasi kurir selain J&T & KiriminAja (mis. JNE API langsung, SiCepat API langsung)
- Payment gateway selain Tripay & Midtrans (mis. Xendit, Duitku)
- Fitur akuntansi/pembukuan otomatis (laporan pajak, faktur pajak resmi)
- Live chat real-time terintegrasi (chat ke seller di V1 cukup via WhatsApp link, bukan built-in chat widget)
- Dukungan multi-bahasa (Bahasa Indonesia saja di V1)

---

## 3. Persona & Peran Pengguna

| Peran | Deskripsi | Kebutuhan Utama |
|---|---|---|
| **Super Admin** | Tim internal Tokospace | Kontrol penuh platform, monitoring kesehatan sistem & integrasi |
| **Seller (Owner)** | Pemilik UMKM, kemampuan teknis rendah-menengah, mayoritas akses dari HP | Setup toko cepat, kelola pesanan tanpa ribet, tidak perlu paham coding |
| **Staff Toko** *(Fase 2)* | Diundang seller, akses terbatas | Kelola pesanan/produk sesuai izin yang diberikan |
| **Customer** | Pembeli, mayoritas akses dari HP | Belanja cepat, checkout mudah, kepercayaan pada toko kecil/individu |

---

## 4. Functional Requirements

Setiap modul berikut ditulis sebagai user story + acceptance criteria, siap dipecah jadi ticket. Prioritas: **P0** = wajib MVP, **P1** = Fase 1, **P2** = Fase 2+.

### 4.1 Autentikasi & Onboarding Seller — P0

**User story**: Sebagai calon seller, saya ingin mendaftar dan langsung punya toko live dengan sub-domain, supaya saya bisa mulai jualan cepat.

**Acceptance criteria**:
- [ ] Registrasi via email/HP + password; validasi email unik, password minimum 8 karakter
- [ ] Setelah registrasi, sistem cek ketersediaan sub-domain secara real-time (debounce 400ms) saat seller mengetik nama toko
- [ ] Nama sub-domain: lowercase, alfanumerik + strip, 3-30 karakter, tidak boleh pakai kata terlarang (daftar blacklist: admin, api, www, app, mail, dst.) — **perlu didefinisikan daftar reserved words sebelum development**
- [ ] Setelah onboarding selesai, toko berstatus "live" dengan tema default, dapat diakses di `namatoko.tokospace.com`
- [ ] Login mendukung email/HP + password; sesi disimpan via Sanctum token (SPA/mobile-friendly)
- [ ] Rate limit percobaan login: maksimum 5x gagal per 15 menit per akun (mencegah brute force)

**Catatan Fase 1**: tambah opsi login/registrasi via OTP WhatsApp (lihat 4.7).

### 4.2 Manajemen Produk — P0

**Acceptance criteria**:
- [ ] Seller dapat CRUD produk dengan: nama, deskripsi, harga, stok, kategori, hingga 8 gambar per produk
- [ ] Varian produk (mis. ukuran/warna) dengan harga & stok independen per varian
- [ ] Bulk import via CSV dengan preview mapping kolom & validasi error per baris sebelum commit
- [ ] Produk dengan stok 0 otomatis berstatus "Habis" di storefront, tombol beli nonaktif
- [ ] Gambar produk di-resize/optimize otomatis saat upload (mis. max 2000px, convert ke WebP) untuk performa storefront

### 4.3 Manajemen Pesanan — P0

**Acceptance criteria**:
- [ ] Status pesanan: `baru → diproses → dikirim → selesai`, plus status alternatif `dibatalkan` dan `diretur`
- [ ] Setiap perubahan status tercatat di riwayat (timeline) dengan timestamp
- [ ] Nomor pesanan unik per tenant, format `[KODE-TOKO]-[YYYYMMDD]-[urutan]`, di mana KODE-TOKO adalah 4 huruf pertama subdomain di-uppercase (mis. subdomain `kopienak` → `KOPI-20260817-001`)
- [ ] Seller dapat melihat & filter pesanan by status, tanggal, metode pembayaran, metode pengiriman

**Reservasi stok (mencegah overselling)**:
- [ ] Stok dikurangi (di-*reserve*) saat pesanan dibuat, **bukan** saat pembayaran dikonfirmasi — supaya dua customer tidak bisa membeli item terakhir yang sama
- [ ] Pengurangan stok dilakukan dalam transaksi database dengan row-level lock (`SELECT ... FOR UPDATE`) untuk mencegah race condition
- [ ] Jika stok tidak mencukupi saat checkout, tampilkan pesan jelas ("Stok tersisa hanya 2") dan blokir pembuatan pesanan
- [ ] Pesanan belum dibayar akan **kedaluwarsa otomatis** setelah batas waktu (usulan: 24 jam untuk transfer manual, mengikuti masa berlaku VA untuk gateway) → stok dikembalikan otomatis via scheduled job
- [ ] Pesanan yang dibatalkan/ditolak mengembalikan stok

**Snapshot data pesanan (integritas riwayat)**:
- [ ] Saat pesanan dibuat, sistem menyimpan salinan nama produk, harga satuan, nama varian, dan alamat pengiriman ke dalam record pesanan — sehingga jika seller mengubah harga atau menghapus produk nanti, riwayat pesanan lama tetap akurat

### 4.4 Pembayaran — P0 (Transfer Manual + Gateway Platform), P1 (Gateway Tenant)

**Penting — dua jenis gateway yang berbeda peruntukannya (lihat D1 & D2):**

| | Gateway Platform | Gateway Tenant |
|---|---|---|
| Untuk apa | Seller bayar langganan ke Tokospace | Customer bayar pesanan ke seller |
| Kredensial | Satu akun milik Tokospace, di `.env` | Milik masing-masing seller, di `payment_settings` (terenkripsi) |
| Dana masuk ke | Rekening Tokospace | Rekening seller |
| Fase | P0 (MVP) | P1 |

Tokospace **tidak memotong fee** dari transaksi customer↔seller dan **tidak memegang dana seller** — karenanya tidak ada modul saldo maupun payout dalam scope ini.

**P0 — Transfer Bank Manual**:
- [ ] Seller input 1+ rekening bank (nama bank, no. rekening, atas nama) di Pengaturan Pembayaran
- [ ] Saat checkout, customer melihat info rekening + upload bukti transfer (gambar, max 5MB)
- [ ] Pesanan berstatus "Menunggu Konfirmasi" sampai seller verifikasi manual bukti transfer
- [ ] Seller punya tombol "Konfirmasi Pembayaran" / "Tolak" di halaman detail pesanan

**P1 — Payment Gateway Tenant (Tripay & Midtrans)**:
- [ ] Seller connect API key/merchant code milik akun gateway-nya sendiri, dengan tombol "Tes Koneksi"
- [ ] Kredensial disimpan terenkripsi (Laravel `encrypted` cast), tidak pernah ditampilkan penuh di UI (mask sebagian)
- [ ] Checkout customer generate transaksi via API gateway terpilih, redirect/tampilkan instruksi bayar (VA/QRIS/e-wallet/kartu)
- [ ] Webhook dari gateway **wajib diverifikasi signature-nya** sebelum update status (lihat 6.3) — mencegah spoofing status "lunas" palsu
- [ ] Idempotency: webhook yang diterima ganda (retry dari gateway) tidak boleh memproses pesanan dua kali — gunakan `gateway_ref` sebagai idempotency key
- [ ] **COD (fase 1, jika KiriminAja aktif)**: pesanan dengan metode pengiriman KiriminAja dapat menawarkan opsi bayar COD ke customer; status pembayaran berubah otomatis saat KiriminAja melaporkan dana cair (webhook/polling harian)

### 4.5 Pengiriman — P0 (Resi Manual), P1 (J&T API & KiriminAja)

**P0 — Resi Manual**:
- [ ] Seller input nama kurir bebas (teks) + nomor resi per pesanan
- [ ] Ongkir untuk metode manual: seller set flat rate atau gratis ongkir dengan syarat minimum belanja (per toko, bukan per produk di V1)

**P1 — J&T Express API**:
- [ ] Seller connect `username` + `api_key` J&T di Pengaturan Pengiriman
- [ ] Saat checkout: panggil **Tariff Check API** (endpoint `data`+`sign` MD5+base64) berdasarkan berat total keranjang & kode area tujuan → tampilkan ongkir real-time. Panggilan ini **sinkron** (customer menunggu) dengan timeout maksimum 5 detik dan hasil di-cache per kombinasi origin+destination+berat selama 24 jam. Jika gagal/timeout → fallback ke ongkir flat yang diset seller, sertai catatan "ongkir final dikonfirmasi seller" (lihat §4.13)
- [ ] Saat seller proses pesanan: panggil **Order API** → dapatkan `awb_no` otomatis, simpan ke `shipments.tracking_number`
- [ ] Job terjadwal (queue, interval disarankan 30-60 menit) memanggil **Tracking API** per resi aktif → update `shipments.status` & `history`
- [ ] Jika pesanan dibatalkan sebelum diambil kurir → panggil **Cancel Order API**
- [ ] Mapping kode wilayah (origin_code/destination_code/receiver_area) J&T **wajib disiapkan sebagai data referensi** sebelum go-live (proses "Mapping" di alur integrasi J&T — lihat dokumentasi resmi) — ini prasyarat teknis, bukan sekadar konfigurasi
- [ ] Signature request: `base64_encode(md5(data_param + key))` sesuai spesifikasi J&T — implementasikan sebagai helper terpusat, jangan duplikasi di banyak tempat

**P1 — KiriminAja**:
- [ ] Seller connect API key KiriminAja
- [ ] Tracking terpadu lintas kurir yang didukung KiriminAja
- [ ] Dukungan COD dengan pencairan dana harian — perlu job rekonsiliasi harian untuk mencocokkan dana cair dengan pesanan terkait

### 4.6 Kustomisasi Toko (Theme Editor) — P0 dasar, P1 lengkap

**Acceptance criteria (P0)**:
- [ ] Seller dapat memilih dari minimal 3 tema starter saat onboarding
- [ ] Seller dapat mengubah logo, banner hero, warna aksen toko
- [ ] Perubahan tersimpan sebagai `theme_config` (JSON) per tenant, di-fetch storefront saat render (SSR/ISR)

**P1**:
- [ ] Editor drag-and-drop untuk susunan section homepage
- [ ] Live preview desktop/mobile di dalam editor
- [ ] Custom domain: seller input domain, sistem beri instruksi CNAME, verifikasi via cron job DNS check, auto-provision SSL

### 4.7 WhatsApp Gateway (OTP & Notifikasi) — P1

**Acceptance criteria**:
- [ ] Registrasi/login dapat pilih verifikasi OTP WhatsApp sebagai alternatif password (lihat konsep desain login terpisah, bukan tab)
- [ ] Sistem panggil api.co.id `POST /api/v1/public/messages/send` dengan template OTP "Copy Code"
- [ ] Kode OTP valid 5 menit, maksimum 3x kirim ulang per 15 menit (mencegah abuse biaya WA)
- [ ] Notifikasi transaksional otomatis: konfirmasi pesanan, update status pengiriman, reminder pembayaran (ke customer); pesanan baru masuk (ke seller)
- [ ] Setiap notifikasi tercatat di `notification_logs` dengan status (terkirim/dibaca/gagal) dari webhook HMAC-signed api.co.id
- [ ] **Fallback**: jika pengiriman WA gagal (nomor tidak valid, API down), sistem fallback kirim notifikasi via email jika tersedia — jangan biarkan customer tidak dapat info sama sekali

### 4.8 Diskon & Promo — P1
- [ ] Kupon: persentase/nominal, syarat minimum belanja, tanggal mulai/berakhir, batas pemakaian (total & per customer)
- [ ] Flash sale: produk + harga diskon + jendela waktu, tampil otomatis di storefront saat aktif

### 4.9 Billing & Langganan — P0

**Model** (default, konfirmasi via D2): Starter **gratis permanen** dengan batasan kuota; Pro & Business punya trial 14 hari lalu wajib bayar via gateway platform.

**Acceptance criteria**:
- [ ] Seller pilih paket saat onboarding (Starter default, langsung aktif tanpa kartu)
- [ ] Upgrade ke Pro/Business memicu trial 14 hari; H-3 sebelum trial berakhir kirim notifikasi
- [ ] Invoice bulanan otomatis, pembayaran via gateway platform
- [ ] Gagal bayar → grace period 3 hari (toko normal, banner peringatan di dashboard) → 14 hari mode **read-only** (storefront tetap tampil, checkout dimatikan, seller masih bisa export data) → setelah itu toko **suspend** (storefront tidak dapat diakses, data tetap disimpan minimal 90 hari sebelum kandidat penghapusan)
- [ ] Downgrade paket: jika data melebihi kuota paket baru (mis. 120 produk turun ke Starter yang batas 50), produk kelebihan **tidak dihapus** melainkan otomatis di-*unpublish*, seller memilih mana yang tetap aktif

### 4.10 Penegakan Kuota & Fitur per Paket — P0

Konsep menyebut batasan per paket (mis. Starter maksimum 50 produk) tapi belum ada mekanisme penegakannya.

- [ ] Definisi kuota & fitur disimpan sebagai data di tabel `plans.features` (JSON), **bukan** hardcode di kode — supaya Super Admin bisa mengubah tanpa deploy
- [ ] Middleware/policy memeriksa kuota sebelum aksi yang menambah data (tambah produk, tambah staff, connect gateway)
- [ ] Saat kuota tercapai, UI menampilkan pesan jelas + CTA upgrade, bukan error generik
- [ ] Fitur terkunci (J&T API, KiriminAja, Tripay, Midtrans, custom domain) ditampilkan di UI dengan badge "Paket Pro/Business" + gembok — terlihat tapi tidak bisa diaktifkan (lihat design breakdown)

### 4.11 Identitas & Akun Customer — P0

Sesuai keputusan **D3**: akun customer bersifat **per-toko**.

- [ ] `users.email` unik per `tenant_id` (composite unique index), bukan unik global — customer yang belanja di dua toko punya dua akun terpisah
- [ ] Guest checkout tetap didukung (tanpa akun), data pesanan disimpan dengan email/HP sebagai identifier
- [ ] Data customer Toko A **tidak boleh** terlihat oleh Toko B dalam bentuk apapun — termasuk pencarian, laporan, dan export

### 4.12 Retur & Refund — P1

Status `diretur` sudah didefinisikan di §4.3 tapi alurnya belum — ini melengkapinya.

- [ ] Customer mengajukan retur dari halaman detail pesanan (alasan + foto opsional), dalam jendela waktu yang diset seller (default 3 hari sejak diterima)
- [ ] Seller menyetujui/menolak pengajuan; jika disetujui, status pesanan → `diretur`
- [ ] Proses refund berbeda per metode pembayaran:
  - **Transfer manual**: Tokospace hanya mencatat status; transfer balik dilakukan seller secara manual di luar sistem, seller menandai "Refund Selesai"
  - **Gateway (Tripay/Midtrans)**: jika API provider mendukung refund, sediakan tombol refund yang memanggil API; jika tidak, jatuh kembali ke proses manual dengan pencatatan status
  - **COD**: dana belum tentu sudah cair; sistem menandai pesanan agar dikecualikan dari rekonsiliasi COD
- [ ] Stok produk yang diretur dikembalikan hanya setelah seller mengonfirmasi barang diterima kembali (bukan otomatis saat pengajuan)

### 4.13 Penanganan Kegagalan Integrasi (Error Path) — P1

Semua modul di atas hanya menulis skenario sukses. Berikut perilaku wajib saat integrasi gagal:

| Skenario gagal | Perilaku yang diharapkan |
|---|---|
| Cek ongkir (J&T/KiriminAja) timeout/gagal saat checkout | Tampilkan ongkir flat fallback milik seller + catatan "ongkir final dikonfirmasi seller". **Jangan** blokir checkout |
| Create AWB gagal setelah customer bayar | Pesanan tetap valid & tercatat; masuk antrian retry; seller mendapat notifikasi "Perlu buat resi manual"; **jangan** batalkan pesanan customer |
| Webhook pembayaran tidak kunjung datang | Job rekonsiliasi terjadwal memanggil API status transaksi provider untuk sinkronisasi (jangan hanya bergantung webhook) |
| Notifikasi WhatsApp gagal terkirim | Fallback ke email; jika keduanya gagal, catat di `notification_logs` dan tampilkan status pesanan tetap akurat di halaman tracking |
| Kredensial gateway/kurir seller kedaluwarsa atau salah | Tandai integrasi "Bermasalah" di dashboard seller + notifikasi; metode pembayaran/pengiriman terkait otomatis disembunyikan dari checkout agar customer tidak menemui error |

### 4.14 Analitik Seller — P1

Disebut di scope tapi belum punya requirement.

- [ ] Metrik yang ditampilkan: total penjualan (harian/mingguan/bulanan), jumlah pesanan per status, produk terlaris (top 10), nilai rata-rata pesanan, tingkat penyelesaian checkout
- [ ] Sumber data: agregasi dari tabel `orders`/`order_items`, dihitung via job terjadwal ke tabel ringkasan harian (bukan query berat real-time ke tabel transaksi)
- [ ] Rentang waktu dapat difilter; data ditampilkan maksimal 12 bulan ke belakang di V1
- [ ] Sumber trafik (referrer) hanya jika analytics pihak ketiga terpasang — **tidak** membangun sistem tracking sendiri di Fase 1

### 4.15 SEO Storefront — P0

Untuk toko online, SEO adalah fungsi bisnis inti, bukan tambahan teknis.

- [ ] Setiap produk & halaman toko punya URL slug yang dapat dibaca (mis. `/produk/kaos-polos-hitam`)
- [ ] Meta title & description dapat diisi seller per produk; jika kosong, sistem generate otomatis dari nama produk + nama toko
- [ ] `sitemap.xml` dan `robots.txt` di-generate otomatis per tenant/domain
- [ ] Structured data (JSON-LD schema.org `Product`, `Offer`, `AggregateRating`) di halaman produk
- [ ] Open Graph tag untuk preview saat link toko dibagikan di WhatsApp/media sosial — penting karena mayoritas distribusi UMKM lewat WhatsApp

### 4.16 Super Admin — P0 dasar, P1 lengkap
- [ ] Dashboard overview: jumlah seller aktif, transaksi platform, pendapatan langganan
- [ ] Approve/suspend seller
- [ ] Monitoring status integrasi pihak ketiga per toko (P1)
- [ ] Manajemen paket, kuota, & fitur terkunci per paket (mengedit `plans.features`)

---

## 5. Non-Functional Requirements (NFR)

*(Tidak ada di dokumen sumber — ditambahkan sebagai bagian dari audit, wajib disepakati sebelum development dimulai)*

### 5.1 Keamanan
- Semua kredensial pihak ketiga (J&T, KiriminAja, Tripay, Midtrans, WA Gateway) disimpan **terenkripsi** di database (Laravel encrypted cast / KMS jika skala besar)
- Semua webhook masuk (payment gateway, WA gateway) **wajib diverifikasi signature** sebelum diproses — tolak request tanpa signature valid
- Isolasi data tenant: setiap query wajib melalui global scope `tenant_id` — audit rutin untuk memastikan tidak ada query yang bocor lintas tenant
- Password di-hash dengan bcrypt/argon2 (default Laravel), tidak pernah disimpan/di-log plaintext
- HTTPS wajib di semua endpoint (termasuk custom domain via auto-SSL)
- Rate limiting di endpoint publik (login, OTP, checkout) untuk mencegah abuse

### 5.2 Kepatuhan Data (UU PDP Indonesia)
- Data pribadi customer (nama, alamat, no. HP) diproses sesuai UU No. 27/2022 tentang Pelindungan Data Pribadi — perlu kebijakan privasi eksplisit di tiap toko, consent saat checkout, dan mekanisme penghapusan data atas permintaan
- **Ini perlu review lebih lanjut dengan konsultan legal sebelum go-live** — di luar cakupan teknis PRD ini

### 5.3 Performa
- LCP storefront < 2.5 detik di koneksi 4G rata-rata Indonesia
- Gunakan ISR (Incremental Static Regeneration) per halaman produk/toko untuk mengurangi beban API saat trafik tinggi
- Image lazy-loading & CDN (Cloudflare R2/S3 + CDN) wajib untuk semua aset toko

### 5.4 Ketersediaan & Reliability
- Target uptime 99.5% (± 3.6 jam downtime/bulan) untuk V1
- Panggilan API pihak ketiga dibagi **dua kategori** (ini mengoreksi aturan v1.0 yang mewajibkan semuanya asinkron — tidak mungkin diterapkan pada cek ongkir):

| Kategori | Contoh | Aturan |
|---|---|---|
| **Sinkron** (customer menunggu hasilnya) | Cek ongkir, create transaksi gateway saat checkout | Timeout ketat maks 5 detik; hasil di-cache; **wajib** punya fallback jika gagal (§4.13); tidak boleh memblokir penyelesaian checkout |
| **Asinkron** (queue) | Create AWB, polling tracking, kirim notifikasi WA, rekonsiliasi COD, cek status DNS custom domain | Diproses via queue job; retry exponential backoff maks 3-5x; gagal permanen masuk failed queue + alert |

- Kegagalan API eksternal **tidak boleh** menyebabkan kehilangan pesanan yang sudah dibayar — pesanan selalu tercatat lebih dulu, integrasi menyusul

### 5.5 Skalabilitas
- Arsitektur single-DB multi-tenant harus siap migrasi ke sharding/DB terpisah per tenant jika jumlah toko mencapai skala tertentu (**perlu didefinisikan angka ambang, mis. >5.000 toko aktif** — dibahas ulang saat mendekati skala tersebut, bukan diputuskan sekarang)

### 5.6 Kompatibilitas
- Browser: 2 versi terbaru Chrome, Safari, Firefox, Edge; Safari iOS & Chrome Android sebagai prioritas (mayoritas trafik mobile Indonesia)
- Desain mobile-first & responsive di semua permukaan (storefront, dashboard, admin) — lihat `tokospace-design-breakdown.md`

### 5.7 Observability
- Logging terpusat untuk semua panggilan API pihak ketiga (request/response, exclude data sensitif) — memudahkan debug kegagalan integrasi
- Alerting jika error rate integrasi pihak ketiga melewati threshold (mis. >5% gagal dalam 15 menit)
- Error tracking aplikasi (mis. Sentry) untuk backend & frontend

### 5.8 Testing, Environment & Disaster Recovery

**Environment**:
- Minimal dua environment terpisah: **staging** (data dummy, kredensial sandbox semua provider) dan **production**
- Wildcard DNS staging terpisah (mis. `*.staging.tokospace.com`) supaya multi-tenancy benar-benar teruji sebelum rilis

**Testing**:
- Unit test wajib untuk business logic kritis: perhitungan total pesanan, reservasi stok, penegakan kuota paket, signature generator J&T
- Integration test untuk semua webhook handler (verifikasi signature + idempotency) menggunakan payload sandbox provider
- **Test isolasi tenant wajib ada dan dijalankan di CI** — minimal satu test yang membuktikan query dari Tenant A tidak dapat mengakses data Tenant B. Ini pengaman utama arsitektur single-DB
- E2E test untuk alur kritis: registrasi→onboarding→toko live, dan checkout→pembayaran→pesanan tercatat
- Semua integrasi pihak ketiga diuji di sandbox sebelum production; J&T mewajibkan tahap testing & mapping bersama tim mereka sebelum go-live (lihat §4.5)

**Backup & Disaster Recovery**:
- Backup database otomatis harian dengan retensi minimal 30 hari; backup file/media mengikuti kebijakan storage provider
- Target pemulihan: **RPO ≤ 24 jam** (kehilangan data maksimum 1 hari) dan **RTO ≤ 4 jam** untuk V1
- Uji restore backup minimal sekali per kuartal — backup yang tidak pernah diuji tidak bisa disebut backup

### 5.9 Aksesibilitas (a11y)
- Kontras teks memenuhi WCAG AA (rasio ≥4.5:1 untuk teks normal) — perlu diperhatikan karena design system memakai abu-abu terang untuk teks sekunder
- Semua elemen interaktif dapat diakses via keyboard; form punya label yang terasosiasi
- Touch target minimum 44×44px di mobile (sudah selaras dengan design breakdown)

---

## 6. Spesifikasi Teknis

### 6.1 Arsitektur (ringkasan, detail lihat dokumen konsep asli)
- **Frontend**: Next.js (App Router) + Tailwind, dua aplikasi terpisah — Storefront (per-tenant, `*.tokospace.com` + custom domain) dan Seller Dashboard (`app.tokospace.com`)
- **Backend**: Laravel + Sanctum + Horizon (queue), single-DB multi-tenant dengan `tenant_id` global scope
- **Database**: PostgreSQL
- **Cache/Queue**: Redis
- **Storage**: Cloudflare R2/S3
- **Email**: provider transaksional (Resend / Postmark / Amazon SES) — dibutuhkan untuk verifikasi akun, reset password, invoice langganan, dan fallback notifikasi saat WhatsApp gagal. *(Belum ada di v1.0 meski fiturnya sudah diminta)*
- **Gateway platform**: satu akun Midtrans atau Tripay milik Tokospace untuk menagih langganan seller (terpisah dari gateway tenant — lihat §4.4)
- **Domain/SSL**: Cloudflare for SaaS untuk custom domain multi-tenant
- **Error tracking**: Sentry (backend + frontend)

### 6.2 Strategi Domain
1. Wildcard DNS `*.tokospace.com` → aplikasi storefront
2. Middleware `ResolveTenant` baca `Host` header untuk resolve tenant aktif per request
3. Custom domain: seller arahkan CNAME → verifikasi via cron DNS check → auto-provision SSL

### 6.3 Prinsip API & Integrasi Pihak Ketiga
- Semua integrasi eksternal (J&T, KiriminAja, Tripay, Midtrans, api.co.id) diakses lewat **service class terpisah** per provider (mis. `JntShippingService`, `KiriminAjaService`, `TripayPaymentService`) — memudahkan swap/tambah provider baru tanpa mengubah business logic order
- Webhook handler tiap provider **wajib**: (1) verifikasi signature/HMAC, (2) idempotency check via reference ID, (3) proses via queue job (bukan langsung di controller) supaya response ke provider tetap cepat
- Kredensial per tenant disimpan di `shipping_settings`/`payment_settings` dengan kolom `credentials` terenkripsi

### 6.4 Skema Database (revisi — tambahan dari audit)

Tanda **[+]** = tabel/kolom yang ditambahkan di v1.1 hasil audit.

```
tenants            : id, name, subdomain, custom_domain, status, plan_id, theme_config(json), created_at
plans              : id, name, price, features(json)                            -- kuota & fitur sebagai DATA, bukan hardcode
subscriptions      : id, tenant_id, plan_id, status, trial_ends_at, current_period_end, grace_ends_at [+]

users              : id, tenant_id(nullable utk super admin), role, name, email, phone, password,
                     email_verified_at [+], created_at
                     UNIQUE(tenant_id, email) [+]  -- akun customer per-toko, sesuai D3
otp_codes          : id, tenant_id, identifier(phone/email), code_hash, purpose, expires_at, used_at [+]
password_resets    : id, tenant_id, email, token_hash, expires_at [+]
addresses          : id, user_id, tenant_id, label, recipient_name, phone, full_address,
                     province, city, district, postal_code, is_default

categories         : id, tenant_id, name, slug, parent_id(nullable), sort_order [+]  -- sebelumnya dirujuk tapi tak ada
products           : id, tenant_id, name, slug, description, price, stock, category_id,
                     weight_gram [+], images(json), status, meta_title [+], meta_description [+]
product_variants   : id, product_id, tenant_id [+], name, price_diff, stock, sku [+]

carts              : id, tenant_id, customer_id(nullable), session_id, items(json), updated_at
orders             : id, tenant_id, order_number, customer_id(nullable), status,
                     subtotal [+], shipping_cost [+], discount_amount [+], coupon_id [+], total,
                     shipping_address_snapshot(json) [+], customer_contact_snapshot(json) [+],
                     payment_status, shipping_status, expires_at [+], created_at
order_items        : id, order_id, tenant_id [+], product_id, variant_id [+], qty, price,
                     product_name_snapshot [+], variant_name_snapshot [+]

payments           : id, order_id, tenant_id [+], method(manual_transfer/tripay/midtrans/cod),
                     gateway_ref, status, amount, proof_image, paid_at
                     UNIQUE(gateway_ref) [+]  -- idempotency key webhook
shipments          : id, order_id, tenant_id [+], method(manual/jnt_api/kiriminaja), courier_name,
                     tracking_number, status, history(json), last_tracked_at
shipping_settings  : id, tenant_id, method, credentials(encrypted json), flat_rate [+],
                     free_shipping_min [+], is_active
payment_settings   : id, tenant_id, method, credentials(encrypted json), bank_account_info(json), is_active

coupons            : id, tenant_id, code, type(percent/fixed), value, min_purchase,
                     usage_limit, usage_limit_per_customer [+], used_count [+], starts_at, ends_at
coupon_usages      : id, coupon_id, tenant_id, customer_id, order_id, used_at [+]
reviews            : id, tenant_id, product_id, customer_id, order_id [+], rating, comment,
                     status(pending/approved/hidden) [+], created_at

returns            : id, order_id, tenant_id, reason, photos(json), status, refund_method,
                     resolved_at [+]  -- mendukung alur §4.12
notification_logs  : id, tenant_id, order_id(nullable), channel, type, recipient_phone,
                     status, error_message [+], sent_at
integration_logs   : id, tenant_id, provider, endpoint, status_code, duration_ms, error [+]  -- observability §5.7
analytics_daily    : id, tenant_id, date, orders_count, revenue, visitors [+]  -- agregasi §4.14

themes             : id, name, preview_url, config_schema(json)
domain_verifications : id, tenant_id, domain, status, verified_at
staff_roles        : id, tenant_id, user_id, permissions(json)                  -- Fase 2
```

**Aturan lintas tabel**:
- Semua tabel operasional wajib punya `tenant_id` + global scope Laravel — termasuk tabel turunan seperti `payments`, `shipments`, `order_items`, yang di v1.0 belum punya sehingga scope tidak bisa diterapkan konsisten
- Kolom `credentials` di `shipping_settings` & `payment_settings` wajib dienkripsi (Laravel encrypted cast)
- Kolom bertanda `_snapshot` diisi sekali saat pesanan dibuat dan **tidak pernah** diupdate — menjaga integritas riwayat pesanan (§4.3)
- `products.weight_gram` wajib ada sejak MVP meski cek ongkir baru di Fase 1 — J&T dan KiriminAja butuh berat untuk hitung tarif, dan menambahkannya belakangan berarti seller harus mengisi ulang seluruh katalog

---

## 7. Rencana Rilis (Phased Rollout)

| Fase | Fokus | Modul Utama |
|---|---|---|
| **MVP (Fase 0)** | Validasi konsep, toko bisa jualan end-to-end secara manual | Auth, Onboarding, Produk (+kategori, berat), Pesanan (+reservasi stok), Transfer Manual, Resi Manual, Theme dasar, SEO dasar, Billing via gateway platform, Kuota paket |
| **Fase 1** | Otomatisasi & monetisasi penuh | J&T API, KiriminAja, Tripay, Midtrans, WA Gateway, Custom Domain, Diskon, Analitik |
| **Fase 2** | Skalabilitas & kolaborasi tim | Staff multi-role, permission matrix, analitik lanjutan |
| **Fase 3** | Ekspansi ekosistem | Marketplace tema, API publik, app mobile |

Estimasi waktu per fase sengaja **tidak dicantumkan** di PRD ini karena bergantung ukuran tim development — sebaiknya diisi setelah breakdown ke sprint/story points bersama tim.

---

## 8. Risiko & Asumsi Terbuka

*(Perlu keputusan/konfirmasi sebelum atau selama development — bukan blocker untuk mulai, tapi wajib ditrack)*

| # | Item | Status di v1.1 |
|---|---|---|
| 1 | **D1 — Tokospace pegang dana + fee transaksi, atau tidak?** | **Blocker.** Default: tidak (§0). Wajib dikonfirmasi — memengaruhi seluruh modul pembayaran |
| 2 | **D2 — Cara seller bayar langganan di MVP** | **Blocker.** Default: gateway platform terpisah (§0) |
| 3 | **D3 — Akun customer per-toko atau lintas-toko** | **Blocker.** Default: per-toko (§0, §4.11) — memengaruhi index database |
| 4 | Model Starter: gratis permanen vs trial | ✅ Diputuskan di §4.9 — Starter gratis permanen, Pro/Business trial 14 hari |
| 5 | Grace period sebelum suspend | ✅ Diputuskan di §4.9 — 3 hari grace + 14 hari read-only |
| 6 | Kebijakan retur/refund per metode pembayaran | ✅ Didefinisikan di §4.12 |
| 7 | Biaya nomor WA Gateway dialokasikan ke paket mana | ⏳ Belum diputuskan — perlu hitung unit economics |
| 8 | Daftar reserved words untuk sub-domain | ⏳ Belum dibuat — dibutuhkan sebelum dev modul onboarding |
| 9 | Mapping kode wilayah J&T (kota/kecamatan/area) | ⏳ Prasyarat dari proses onboarding partner J&T — **mulai proses ini lebih awal**, karena bergantung jadwal pihak J&T, bukan tim internal |
| 10 | Kebijakan privasi & kepatuhan UU PDP per toko | ⏳ Perlu review legal terpisah sebelum go-live |
| 11 | Threshold jumlah toko untuk migrasi arsitektur DB | ⏳ Dibahas saat mendekati skala, bukan sekarang |
| 12 | Ongkir flat: apakah perlu berbeda per wilayah (Jawa vs luar Jawa)? | ⏳ Belum diputuskan — umum dipakai UMKM, pertimbangkan untuk V1 |

---

## 9. Lampiran

### 9.1 Dokumen Terkait
- `tokospace-konsep-produk.md` — konsep produk & arsitektur awal (sumber audit)
- `tokospace-design-breakdown.md` — breakdown halaman & design system (mobile+desktop)
- `tokospace-prompt-bertahap.md` — prompt eksekusi desain UI

### 9.2 Referensi API Pihak Ketiga
- J&T Express API: https://developer.jet.co.id/documentation
- KiriminAja: https://github.com/kiriminaja
- WhatsApp Gateway: api.co.id (Official WhatsApp Cloud API)

### 9.3 Glosarium Singkat
- **Tenant**: satu toko/seller dalam sistem multi-tenant
- **AWB**: Airway Bill / nomor resi pengiriman
- **COD**: Cash on Delivery
- **ISR**: Incremental Static Regeneration (Next.js)
