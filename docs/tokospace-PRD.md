# Product Requirements Document (PRD) — Tokospace.com

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Domain produksi** | tokospace.com |
| **Versi** | 1.2 |
| **Tanggal** | 17 Agustus 2026 |
| **Status** | **Approved — Development Baseline** |
| **Sumber** | Disusun dari `tokospace-konsep-produk.md`, direvisi berdasarkan audit dan final architecture review |

### Changelog v1.2
- **D1–D3 difinalkan**; tidak lagi berstatus blocker.
- D1: dana transaksi customer → seller; Tokospace tidak memegang dana seller, tidak memiliki seller wallet/payout/transaction fee pada baseline.
- D2: seller membayar subscription Tokospace melalui gateway platform Tokospace.
- D3: customer account bersifat per-toko/tenant.
- Payment tenant tetap **seller-owned gateway** (Midtrans/Tripay), terpisah dari gateway subscription Tokospace.
- Fondasi tenant/domain menjadi P0; custom-domain onboarding/management menjadi P1.

---

## 0. Keputusan Final

| # | Keputusan | Keputusan final | Konsekuensi arsitektur |
|---|---|---|---|
| **D1** | Siapa pemegang dana transaksi customer? | **Seller.** Seller menggunakan gateway miliknya sendiri. Dana customer disettle oleh provider ke seller. Tokospace tidak memegang dana seller dan tidak memiliki seller wallet/payout/withdrawal pada baseline ini. | Tidak perlu modul saldo seller, payout platform, atau rekonsiliasi dana seller. Tokospace tetap menyimpan transaction record untuk order dan audit. |
| **D2** | Bagaimana seller membayar langganan di MVP? | **Gateway platform Tokospace.** Satu akun payment milik Tokospace digunakan untuk subscription seller; credential server-side dan tidak per-tenant. | Billing platform menjadi P0 dan dipisahkan total dari payment customer→seller. |
| **D3** | Akun customer: per-toko atau lintas-toko? | **Per-toko.** Identitas customer terikat tenant; email unik pada kombinasi `tenant_id + email`. | Tidak ada customer account lintas toko; data customer/order tidak boleh terlihat antar-tenant. |

> **Architecture rule:** Tokospace tidak menjadi pemegang dana customer untuk transaksi seller pada baseline ini. Jangan menambahkan wallet, payout, atau transaction-fee ledger tanpa ADR dan perubahan PRD resmi.

---

## 1. Latar Belakang & Tujuan

Tokospace memungkinkan seller UMKM membuat toko online sendiri tanpa coding — mendaftar, mendapat sub-domain (`namatoko.tokospace.com`), lalu mengatur produk, tema, pembayaran, dan pengiriman dari satu dashboard. Model bisnis: subscription bertingkat Starter/Pro/Business.

**Tujuan V1:** seller dapat mendaftar, punya toko live, menjual produk, menerima pembayaran minimal transfer manual, dan mengirim order dengan resi manual — target onboarding <15 menit.

### 1.1 Success Metrics

| Metrik | Target Awal |
|---|---:|
| Pendaftaran → toko live | < 15 menit |
| Seller aktif | 100 toko bulan pertama |
| Starter → berbayar | ≥ 10% dalam 60 hari |
| Toko bertransaksi | ≥ 40% seller aktif |
| Uptime | ≥ 99.5% |
| LCP storefront | < 2.5 detik pada 4G |

---

## 2. Scope

### 2.1 V1 / MVP — P0
- Registrasi & onboarding seller, sub-domain otomatis
- Produk: CRUD, varian, stok, kategori, gambar
- Pesanan: status dan riwayat
- Pembayaran transfer bank manual
- Pengiriman resi manual
- Kustomisasi tema, logo, banner, warna
- Storefront: katalog, detail, cart, checkout, tracking manual
- Login/registrasi email + password
- Billing subscription melalui gateway platform Tokospace
- Super Admin dasar
- SEO dasar storefront

### 2.2 Fase 1 — P1
- Payment gateway tenant: Tripay & Midtrans
- J&T Express API
- KiriminAja
- WhatsApp Gateway
- Diskon & promo
- Custom domain + auto SSL
- Analitik penjualan

### 2.3 Fase 2+
- Staff toko multi-role
- Marketplace tema pihak ketiga
- Public API
- App mobile seller

### 2.4 Out of Scope V1 & Fase 1
- Tokospace memegang dana transaksi seller
- Seller wallet/payout/withdrawal Tokospace atau transaction fee seller
- Multi-currency
- Marketplace checkout lintas-toko
- Customer account lintas-toko
- Native mobile app
- Kurir selain J&T/KiriminAja
- Gateway tenant selain Tripay/Midtrans
- Akuntansi otomatis
- Live chat built-in
- Multi-bahasa

---

## 3. Persona

| Peran | Fokus |
|---|---|
| Super Admin | Kontrol platform, seller, monitoring |
| Seller / Owner | Setup toko, produk, order, billing |
| Staff Toko | Fase 2, permission terbatas |
| Customer | Belanja dan checkout cepat |

---

## 4. Functional Requirements

### 4.1 Auth & Onboarding Seller — P0
- Registrasi email/HP + password.
- Availability subdomain realtime dengan debounce.
- Subdomain lowercase, alfanumerik + hyphen, 3–30 karakter, reserved words ditolak.
- **Fondasi domain tenant dibuat saat onboarding:** tenant memiliki canonical subdomain dan record domain internal untuk `TenantResolver`.
- Toko live di `namatoko.tokospace.com` setelah onboarding.
- Login menggunakan Sanctum.
- Rate limit login maksimum 5 kegagalan/15 menit/akun.

### 4.2 Produk — P0
- CRUD produk: nama, deskripsi, harga, stok, kategori, hingga 8 gambar.
- Varian dengan harga/stok independen.
- CSV import dengan preview + validasi per baris.
- Stok 0 → habis dan pembelian dinonaktifkan.
- Semua media production disimpan di disk object-storage produksi (target Google Cloud Storage; saat ini masih R2 — lihat Tech Spec §1.1 / ADR-0001).

### 4.3 Pesanan — P0
- Status: `baru → diproses → dikirim → selesai`, plus `dibatalkan` dan `diretur`.
- Timeline status.
- Nomor order unik per tenant.
- Filter status/tanggal/payment/shipping.
- Reservasi stok saat order dibuat dengan transaksi + row-level lock.
- Order belum dibayar expire otomatis; stok dikembalikan scheduled job.
- Snapshot produk, harga, varian, alamat dan kontak customer saat order dibuat.

### 4.4 Pembayaran — P0 Manual, P1 Gateway Tenant

Tokospace memiliki dua payment context yang **tidak boleh dicampur**:

| | Gateway Platform | Gateway Tenant |
|---|---|---|
| Untuk | Seller membayar subscription Tokospace | Customer membayar order seller |
| Kepemilikan | Tokospace | Seller/tenant |
| Credential | Server-side Tokospace | Encrypted per tenant |
| Dana | Tokospace | Seller |
| Fase | P0 | P1 |

**P0 — Manual Transfer**
- Seller dapat menyimpan rekening bank toko.
- Customer melihat instruksi transfer + upload bukti.
- Seller verifikasi manual.

**P1 — Midtrans & Tripay**
- Seller menghubungkan credential akun sendiri melalui dashboard.
- Credential terenkripsi dan tidak pernah dikirim ke browser.
- Tombol Tes Koneksi.
- Semua provider implement `PaymentProviderInterface`.
- Order module tidak boleh bergantung langsung pada SDK/provider tertentu.
- Webhook diverifikasi signature dan diproses idempotent.
- Transaction record menyimpan provider reference, status, amount, method, timestamp.

### 4.5 Pengiriman — P0 Manual, P1 API
- P0: seller input kurir + resi manual.
- P1: J&T + KiriminAja melalui provider abstraction.
- Integrasi eksternal mengikuti timeout/retry/idempotency policy Tech Spec.

### 4.6 Theme & Storefront — P0
- Starter theme, logo, banner, warna aksen.
- Catalog/detail, cart, checkout, tracking manual.
- Loading/empty/error/partial states sesuai Design Brief.

### 4.7 WhatsApp — P1
OTP WhatsApp dan notifikasi transaksi dengan fallback email bila provider gagal.

### 4.8 Domain & Tenant Routing — Fondasi P0, Custom Domain P1

**P0 — Tahap 1**
- Tenant memiliki canonical subdomain.
- Tabel `domains` menjadi sumber mapping domain → tenant.
- `TenantResolver` adalah abstraction tunggal untuk resolusi domain tenant.
- Public storefront memvalidasi hostname/domain di Laravel, bukan mempercayai tenant id dari client.
- Reserved domains/words difinalkan sebelum Tahap 1 selesai.

**P1 — fitur custom domain**
- Seller menambahkan custom domain.
- Verifikasi/SSL dikelola melalui Vercel Domains API sesuai Tech Spec.

### 4.9 Error Handling — P0
API/integrasi memiliki response error konsisten, UI tidak blank screen, dan error dicatat dengan context tenant/request.

### 4.10 Billing Subscription — P0
- Starter gratis permanen dengan quota terbatas.
- Pro/Business berbayar.
- Subscription menggunakan gateway platform Tokospace.
- Grace period/read-only/suspend mengikuti Master Plan.
- Quota/feature sebagai data, bukan hardcode.

### 4.11 Tenant Isolation — P0
- Semua tabel tenant-aware memiliki `tenant_id`.
- Laravel Global Scope + Policy.
- PostgreSQL RLS sebagai pertahanan kedua.
- Cross-tenant test wajib di CI.
- Tenant context untuk RLS tidak boleh berasal dari input client mentah dan mengikuti ADR/Tech Spec.

### 4.12 Customer Identity — P0
Customer terikat satu tenant; customer/cart/order/history tidak boleh bocor lintas tenant.

### 4.13 Integration Error Path — P1
Timeout, retry, fallback bila relevan, structured logging, dan idempotency key untuk operasi berisiko duplikasi.

### 4.14 Analytics — P1
Sales periodik, order per status, best sellers, AOV; agregasi melalui scheduled job.

### 4.15 SEO Storefront — P0
Slug, meta title/description, sitemap, robots, JSON-LD, Open Graph.

### 4.16 Super Admin — P0 dasar, P1 lengkap
Approve/suspend seller, monitoring toko, paket/feature/quota, monitoring integrasi P1.

---

## 5. Non-Functional Requirements

### 5.1 Security
- Credentials pihak ketiga encrypted.
- Webhook signature-verified + idempotent.
- Tenant isolation: Global Scope + RLS + Policy + CI tests.
- Password Laravel hash.
- HTTPS wajib.
- Rate limiting untuk login, OTP, checkout, dan endpoint berisiko.
- Payment credential tenant tidak pernah dikirim ke browser.

### 5.2 Performance
- LCP storefront <2.5 detik pada target 4G.
- Catalog/storefront memakai caching Tech Spec.
- Cart/checkout/account/order tidak memakai stale cache.
- Tidak ada N+1 endpoint kritis.

### 5.3 Reliability
- Queue failure dapat di-retry.
- Scheduled jobs idempotent.
- Payment webhook idempotent.
- Backup terjadwal dan restore diuji.
- Object storage produksi menjadi persistent media store (target Google Cloud Storage; saat ini R2 — lihat Tech Spec §1.1 / ADR-0001).

### 5.4 API Contract
Laravel menghasilkan OpenAPI; Next.js generate types dari OpenAPI pada CI.

### 5.5 Portability
Tidak ada hard dependency pada spesifikasi VM/compute provider tertentu (Google Compute Engine); infrastructure settings melalui environment/configuration.

---

## 6. Global Definition of Done
- Acceptance criteria terpenuhi.
- Test relevan tersedia.
- Tenant isolation + Policy diuji.
- Error/loading/empty/partial states tersedia.
- API contract terdokumentasi.
- Tidak ada secret di source code.
- Media production di disk object-storage produksi (target GCS; saat ini R2).
- CI lulus.
- Preview/target deployment berhasil.

## 7. Release Gates

**Core Sellable** = Tenant + Auth + Catalog + Order + Manual Payment + Manual Shipping. Pada titik ini seller sudah bisa berjualan end-to-end secara manual.

**MVP Release** = Core Sellable + Billing + Theme dasar + SEO + Security/Performance hardening. Ini adalah gerbang resmi sebelum Fase 1.

**Fase 1** = Payment Gateway Tenant + Shipping API + Custom Domain + WhatsApp + Discount + Analytics.

---

## 8. Authority antar Dokumen

- **PRD** = apa/business requirements.
- **Tech Spec** = bagaimana secara teknis/infrastructure.
- **Design Brief** = visual dan interaction.
- **Master Plan** = urutan/dependency pembangunan.
- **Prompt Development** = instruksi eksekusi AI.

Jika terdapat konflik, masing-masing dokumen mengikuti authority area di atas; perubahan lintas-area harus dicatat sebagai keputusan/ADR sebelum coding dilanjutkan.

## 9. Technical Authority

Detail technical implementation mengikuti `tokospace-tech-spec.md` sebagai technical authority.
