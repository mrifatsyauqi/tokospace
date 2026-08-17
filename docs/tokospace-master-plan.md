# Tokospace — Master Plan Development

| | |
|---|---|
| **Produk** | Tokospace — SaaS Multi-Tenant E-Commerce Builder |
| **Versi** | 1.0 |
| **Tanggal** | 17 Agustus 2026 |
| **Mengikat** | `tokospace-PRD.md` v1.1 · `tokospace-design-brief.md` v2.0 · `tokospace-tech-spec.md` v2.1 |
| **Pasangan dokumen** | `tokospace-prompt-development.md` — prompt siap pakai per tahap di bawah |

> Dokumen ini menjawab satu pertanyaan: **"Bangun apa dulu, dan kenapa urutannya begitu?"** PRD menjawab *apa* yang dibangun, design brief menjawab *bagaimana rupanya*, tech spec menjawab *dengan apa*. Dokumen ini yang mengurutkan semuanya jadi langkah kerja.

---

## 1. Prinsip Eksekusi

1. **Urutan mengikuti ketergantungan data, bukan ketergantungan fitur yang terlihat menarik.** Modul `tenant` dan `auth` duluan bukan karena paling penting secara bisnis, tapi karena modul lain tidak bisa diuji tanpa keduanya — tidak ada produk tanpa toko, tidak ada toko tanpa tenant.
2. **Backend Laravel dan frontend Next.js dibangun berpasangan per tahap**, bukan "semua backend dulu baru semua frontend". Setiap tahap menghasilkan sesuatu yang **bisa diklik dan dicoba**, bukan API kosong yang baru terasa gunanya 2 bulan kemudian.
3. **Setiap tahap punya Definition of Done (DoD) yang bisa diverifikasi**, mengacu ke acceptance criteria di PRD §4 — bukan "kelihatannya sudah selesai".
4. **Desain UI mengikuti apa yang sudah ada.** Tahap 0-2 di `tokospace-prompt-bertahap.md` (Marketing, Dashboard onboarding+core) sudah dieksekusi di Claude Design — tahap development di bawah men-*deploy* desain itu jadi kode nyata via handoff (lihat panduan sebelumnya), bukan mendesain ulang dari nol. Tahap yang desainnya belum dibuat (§3 dst. di prompt-bertahap) diberi catatan agar didesain dulu sebelum dikodekan.
5. **P0 dulu, P1 menyusul** — persis urutan prioritas di PRD §4. Fitur berbayar (payment gateway tenant, shipping API, custom domain, WA gateway) sengaja **ditunda** sampai fondasi P0 selesai dan teruji, supaya toko sudah bisa jualan (dengan cara manual) sebelum kompleksitas integrasi pihak ketiga ditambahkan.

---

## 2. Peta Ketergantungan Modul

```
                         ┌──────────┐
                         │  Tenant   │  ← fondasi mutlak, semua bergantung ini
                         └────┬─────┘
                              │
                         ┌────▼─────┐
                         │   Auth    │  ← perlu tenant untuk scoping dashboard
                         └────┬─────┘
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼             ▼
           ┌──────────┐ ┌──────────┐ ┌──────────┐
           │ Catalog   │ │ Billing   │ │  Theme    │  ← ketiganya bisa paralel
           │ (produk)  │ │ (langgan) │ │ (tampilan)│     setelah Auth siap
           └────┬─────┘ └──────────┘ └──────────┘
                │
           ┌────▼─────┐
           │  Order    │  ← perlu Catalog (produk & stok)
           │ (+ cart)  │
           └────┬─────┘
                │
      ┌─────────┼─────────┐
      ▼                   ▼
┌──────────┐        ┌──────────┐
│ Payment   │        │ Shipping  │  ← keduanya perlu Order,
│ (manual)  │        │ (manual)  │     versi manual dulu (P0)
└────┬─────┘        └────┬─────┘
     │                   │
     └─────────┬─────────┘
               ▼
        ═══════════════
         MVP SELESAI —
        toko bisa jualan
        end-to-end secara
        manual
        ═══════════════
               │
      ┌────────┼────────┬─────────────┐
      ▼        ▼         ▼             ▼
 ┌─────────┐┌─────────┐┌─────────┐┌──────────┐
 │ Payment  ││Shipping  ││ Custom   ││   WA      │  ← Fase 1, P1,
 │ Gateway  ││   API    ││ Domain   ││  Gateway  │     bisa paralel
 │ (tenant) ││(J&T/KA)  ││ (Vercel) ││(OTP+notif)│
 └─────────┘└─────────┘└─────────┘└──────────┘
               │
      ┌────────┼────────┬─────────────┐
      ▼        ▼         ▼             ▼
   Diskon    Analitik   Retur/      Super Admin
   & Promo               Refund      lengkap
```

Bagian di atas garis "MVP SELESAI" adalah **P0** — kalau semua itu jalan, seller sudah bisa berjualan nyata (bayar manual, kirim manual). Bagian di bawahnya adalah **P1**, otomatisasi yang membuat operasional lebih ringan tapi bukan syarat toko bisa hidup.

---

## 3. Tahapan Development

| Tahap | Fokus | Modul Backend | Modul Frontend | Prioritas | Model AI |
|---|---|---|---|---|---|
| **0** | Fondasi infrastruktur | — (setup, bukan fitur) | — | Prasyarat | Sonnet |
| **1** | Tenant, Auth, Onboarding | `tenant`, `auth` | Marketing auth pages, onboarding wizard | P0 | **Opus** (rencana isolasi) → Sonnet (eksekusi) |
| **2** | Katalog produk | `catalog` | Dashboard produk, storefront katalog & detail | P0 | Sonnet |
| **3** | Pesanan & transaksi manual | `order`, `payment` (manual), `shipping` (manual) | Keranjang, checkout, dashboard pesanan | P0 | **Opus** (rencana konkurensi) → Sonnet (eksekusi) |
| **4** | Billing platform & tema toko | `billing`, `theme` | Dashboard billing, theme editor dasar, halaman statis toko | P0 | Sonnet |
| **5** | SEO & pengerasan MVP | — (lintas modul) | — (lintas halaman) | P0 | Sonnet, Haiku untuk sub-tugas mekanis |
| **6** | Payment & Shipping otomatis | `payment` (gateway tenant), `shipping` (J&T, KiriminAja) | Pengaturan pembayaran & pengiriman lengkap | P1 | **Opus** (webhook & signature) → Sonnet (eksekusi) |
| **7** | Custom domain & WhatsApp | `domain`, `notification` | Pengaturan domain, notifikasi WA | P1 | Sonnet |
| **8** | Fitur penunjang seller | `discount`, `analytics`, `return` | Diskon, analitik, retur | P1 | Sonnet, Haiku untuk laporan sederhana |
| **9** | Super Admin lengkap | `admin` | Panel admin penuh | P1 | Sonnet |

Alasan pemilihan model dijelaskan di §6a. Detail tiap tahap ada di §4. Prompt siap pakai untuk masing-masing ada di `tokospace-prompt-development.md`.

---

## 4. Detail per Tahap

### Tahap 0 — Fondasi Infrastruktur

**Tidak menghasilkan fitur** — menghasilkan tempat fitur dibangun. Mengikuti `tokospace-tech-spec.md` §12 persis: dua repo (`tokospace-api`, `tokospace-web`), Docker Compose di Oracle A1, wildcard domain Vercel, CI/CD dasar (test + lint + Pest arch test berjalan tapi belum ada modul untuk diuji).

**DoD**: `curl api.tokospace.com/health` mengembalikan 200, `tokospace.com` menampilkan halaman placeholder dari Vercel, push ke `main` di kedua repo memicu deploy otomatis tanpa error, backup `pg_dump` harian sudah terjadwal meski database masih kosong.

### Tahap 1 — Tenant, Auth, Onboarding

**Kenapa ini duluan**: setiap tabel lain punya `tenant_id`. Tanpa modul ini, tidak ada yang bisa diuji secara realistis — bahkan tabel `products` butuh tenant yang valid untuk diisi data uji.

**Backend**: skema `tenants`, `users` (dengan `UNIQUE(tenant_id, email)` sesuai keputusan D3), `otp_codes`, `password_resets`. Global Scope tenant di base Model + RLS Postgres (PRD §5.1, §4.11). Endpoint cek ketersediaan subdomain real-time, daftar reserved words (PRD §8 item 8 — **harus dibuat di tahap ini**, bukan ditunda). Sanctum untuk auth token.

**Frontend**: halaman `/login`, `/register`, `/forgot-password`, `/verify-email` (pola halaman terpisah, bukan tab — sesuai revisi design brief §8.1), onboarding wizard 4 step. Ini pemakaian pertama dari desain Tahap 1 & 2 yang sudah dibuat di Claude Design — di-handoff ke Claude Code, bukan didesain ulang.

**DoD**: seller baru bisa daftar → verifikasi → pilih subdomain → toko live di `namatoko.tokospace.com` (halaman kosong tapi bisa diakses) dalam <15 menit (metrik PRD §1.1). Test isolasi tenant (PRD §5.8) pertama kali ditulis dan lolos di CI.

### Tahap 2 — Katalog Produk

**Backend**: `categories`, `products` (dengan `weight_gram` sejak awal — PRD menegaskan ini wajib di MVP meski ongkir otomatis baru Fase 1, supaya seller tidak perlu isi ulang katalog nanti), `product_variants`. Import CSV. Modul `catalog` dengan pola provider **tidak diperlukan** di sini (tidak ada provider eksternal untuk katalog) — cukup Service + Repository standar.

**Frontend**: Dashboard Produk (list, tambah/edit, import CSV) dan storefront (katalog + detail produk) — storefront pertama kali pakai ISR sungguhan (tech spec §10.2), meski invalidasi on-demand belum aktif sampai Tahap 5.

**DoD**: seller bisa tambah produk lengkap dengan foto (tersimpan di R2, bukan disk lokal — tech spec §1.1), produk muncul di storefront publik dalam hitungan menit. Reservasi stok belum relevan di tahap ini (belum ada order).

### Tahap 3 — Pesanan & Transaksi Manual (Inti Bisnis)

**Ini tahap paling penting secara bisnis** — begitu tahap ini selesai, Tokospace sudah jadi produk yang bisa dipakai jualan sungguhan, meski masih serba manual.

**Backend**: `carts`, `orders`, `order_items` (dengan snapshot data — PRD §4.3), reservasi stok dengan row-lock (PRD §4.3, ini bagian yang paling gampang salah kalau terburu-buru, uji dengan concurrent request bukan cuma manual click), `payments` (metode `manual_transfer` saja dulu), `shipments` (metode `manual` saja dulu). Auto-expire pesanan belum dibayar (job terjadwal).

**Frontend**: keranjang, checkout (form alamat + upload bukti transfer), dashboard Pesanan (list + detail + konfirmasi bukti transfer + input resi manual).

**DoD**: alur lengkap customer beli produk → transfer manual → seller konfirmasi → seller input resi → pesanan selesai, semua lewat UI, tanpa akses database manual. Load test dua browser checkout produk stok=1 secara bersamaan — hanya satu yang berhasil (verifikasi reservasi stok, PRD §4.3).

### Tahap 4 — Billing Platform & Tema Toko

**Backend**: `subscriptions`, `plans` (kuota & fitur sebagai data, bukan hardcode — PRD §4.10), integrasi gateway platform (satu akun Tokospace, bukan per-tenant — keputusan D2/D1). Penegakan kuota (mis. batas produk Starter) mulai aktif di tahap ini juga, karena baru sekarang ada konsep "paket" yang nyata.

**Frontend**: dashboard Billing (pilih paket, upgrade, riwayat invoice), Theme Editor versi dasar (pilih tema starter, ganti logo/warna/banner — belum drag-and-drop penuh, itu P1), halaman statis toko (Tentang/Kontak/FAQ).

**DoD**: seller bisa upgrade dari Starter ke Pro dan benar-benar membayar lewat gateway platform; begitu kuota Starter (mis. 50 produk) tercapai, UI menampilkan CTA upgrade (bukan error) sesuai PRD §4.10.

### Tahap 5 — SEO & Pengerasan MVP

Tidak ada modul baru — tahap ini murni **menutup celah** sebelum disebut "MVP selesai": SEO storefront (slug, meta tag, sitemap.xml, JSON-LD, Open Graph — PRD §4.15, berstatus P0 dan sering terlewat karena tidak terasa seperti "fitur"), invalidasi cache on-demand (tech spec §10.2, `revalidateTag` dipicu Laravel), error path (PRD §4.13 — pastikan checkout tidak pernah blank screen saat sesuatu gagal), dan seluruh checklist §6 di bawah.

**DoD**: checklist di §6 lolos semua. Ini gerbang sebelum Fase 1 dimulai.

### Tahap 6 — Payment & Shipping Otomatis (awal Fase 1)

**Backend**: pola Provider diaktifkan penuh (tech spec §9.1) — `JntProvider`, `KiriminAjaProvider` implementasi `ShippingProviderInterface`; `TripayProvider`, `MidtransProvider` implementasi kontrak setara di modul `payment`. Mapping kode wilayah J&T (PRD §8 item 9 — **ini bergantung jadwal pihak J&T, mulai proses administratifnya idealnya jauh sebelum tahap ini dimulai secara koding**, bukan saat sampai di tahap ini).

**Frontend**: dashboard Pengaturan Pembayaran & Pengiriman versi lengkap (form connect API key, tes koneksi, badge fitur terkunci sesuai paket — design brief §8.2), checkout storefront menghitung ongkir real-time.

**DoD**: seller Pro/Business bisa connect J&T/KiriminAja dan Tripay/Midtrans, ongkir muncul otomatis di checkout dengan fallback yang layak kalau API timeout (PRD §4.13).

### Tahap 7 — Custom Domain & WhatsApp Gateway

**Backend**: `VercelDomainService` (tech spec §5.5) untuk onboarding custom domain otomatis, integrasi api.co.id untuk OTP & notifikasi (PRD §4.7, dengan fallback email kalau WA gagal).

**Frontend**: halaman Domain (instruksi CNAME step-by-step, status polling), toggle OTP WhatsApp di Login/Register (desain sudah ada dari revisi sebelumnya), halaman Notifikasi WhatsApp (log riwayat).

**DoD**: seller pasang custom domain sendiri, status berubah dari "Menunggu propagasi DNS" ke "Aktif" tanpa intervensi manual dari tim Tokospace. Customer bisa login pakai OTP WA.

### Tahap 8 — Fitur Penunjang Seller

Diskon & Promo, Analitik (agregasi harian — PRD §4.14), Retur & Refund (PRD §4.12, dengan alur berbeda per metode bayar). Ketiganya relatif independen satu sama lain, bisa dikerjakan berurutan atau interleaved tergantung mana yang lebih sering diminta seller awal.

### Tahap 9 — Super Admin Lengkap

Monitoring integrasi pihak ketiga per toko, manajemen paket & tema dari sisi admin, billing platform reporting. Modul `admin` P0 dasarnya (approve/suspend seller) sebenarnya sudah perlu ada sejak Tahap 1 dalam bentuk minimal (supaya ada cara menonaktifkan toko spam) — tahap ini melengkapinya jadi panel penuh.

---

## 5. Sinkronisasi dengan Desain UI

| Tahap development | Status desain di `tokospace-prompt-bertahap.md` |
|---|---|
| Tahap 1 (Marketing + Onboarding) | ✅ Sudah didesain (Tahap 0-2, termasuk revisi login/register) — tinggal handoff |
| Tahap 2 (Katalog) | ✅ Sudah didesain (bagian dari Tahap 2) |
| Tahap 3 (Pesanan, checkout) | ⚠️ Sebagian di Tahap 2 (list/detail pesanan) — checkout storefront perlu dicek ulang apakah sudah tercakup di Tahap 4 desain |
| Tahap 4 (Billing, Theme Editor) | ❌ Ada di Tahap 3 desain, **belum dieksekusi** — kerjakan Tahap 3 di Claude Design dulu sebelum mulai coding Tahap 4 development |
| Tahap 6-9 | ❌ Ada di Tahap 3-5 desain, **belum dieksekusi** — sama, desain dulu baru kode |

**Aturan kerja**: jangan mulai coding sebuah halaman kalau desainnya belum ada di Claude Design. Urutan yang benar selalu *desain → handoff → development*, meski dua-duanya kamu kerjakan sendiri — melompati desain untuk "cepat-cepat coding" biasanya berujung bongkar-pasang UI dua kali.

---

## 6. Checklist Gerbang MVP (akhir Tahap 5)

Sebelum menyatakan MVP selesai dan mulai Tahap 6 (Fase 1):

- [ ] Seluruh acceptance criteria P0 di PRD §4 tercentang
- [ ] Test isolasi tenant lolos di CI (tech spec §3.3, PRD §5.8)
- [ ] Reservasi stok teruji dengan concurrent request, bukan cuma manual click
- [ ] Semua upload media lewat R2, nol file production di disk lokal Oracle (tech spec §1.1)
- [ ] Backup `pg_dump` berjalan, **sudah diuji restore minimal sekali** (bukan cuma terjadwal)
- [ ] SEO dasar aktif: sitemap, meta tag, JSON-LD di semua halaman produk
- [ ] Lighthouse CI lolos target LCP <2,5 detik di halaman storefront
- [ ] Checklist penyerahan desain (design brief §10) sudah dicek ulang untuk semua halaman yang sudah di-development
- [ ] Reserved words subdomain sudah final, bukan draft
- [ ] Rollback dari HP (tech spec §6.3) pernah dicoba minimal sekali, bukan cuma teori

---

## 6a. Strategi Model AI per Tahap (hemat kuota Pro)

Ini jawaban atas kekhawatiran paling praktis buat solo developer: jangan sampai kuota Claude Pro habis di tengah tahap penting. Prinsipnya sederhana dan sesuai panduan resmi Anthropic — **Sonnet sebagai default kerja harian, Opus dipakai sempit untuk momen berpikir yang mahal kalau salah, Haiku untuk tugas paling mekanis.**

### Kenapa bukan "pakai Opus terus supaya hasilnya paling bagus"

Karena limit Pro dibagi bersama antara Claude chat dan Claude Code, dan biaya token Opus jauh lebih tinggi dari Sonnet untuk pekerjaan yang sebenarnya tidak butuh level itu — kebanyakan tugas CRUD, styling, dan boilerplate di Tokospace **tidak butuh** kedalaman reasoning Opus, dan memaksakannya cuma mempercepat kuota habis tanpa hasil yang lebih baik.

### Pola kerja yang direkomendasikan: "rencanakan mahal, eksekusi murah"

Anthropic sendiri menyarankan pola ini untuk Claude Code — ganti model di tengah sesi tanpa kehilangan konteks percakapan:

```
/model opus     ← dipakai HANYA untuk sesi merancang: strategi isolasi tenant,
                   desain locking konkurensi stok, aturan verifikasi signature
                   webhook — keputusan yang mahal kalau salah dan susah
                   dibongkar setelah banyak kode ditulis di atasnya

[diskusikan & sepakati rencana]

/model sonnet   ← dipakai untuk SEMUA eksekusi: menulis migrasi, controller,
                   komponen React, test — pekerjaan bervolume besar yang
                   Sonnet tangani dengan baik di ongkos jauh lebih rendah
```

**Tiga tahap yang layak pakai pola ini** (ditandai di tabel §3): Tahap 1 (isolasi data tenant — kalau ini salah, semua tahap berikutnya ikut cacat), Tahap 3 (reservasi stok dengan row-lock — bug konkurensi yang baru ketahuan saat ada 2 pembeli bersamaan), dan Tahap 6 (verifikasi signature webhook pembayaran — celah keamanan kalau keliru). Tahap lain cukup Sonnet dari awal sampai akhir.

**Haiku** dipakai untuk sub-tugas yang benar-benar sempit dan mekanis — merapikan format file, menulis test sederhana yang polanya sudah jelas, generate boilerplate berulang (mis. field form yang mirip satu sama lain). Jangan pakai Haiku untuk keputusan arsitektur atau debug lintas banyak file — di situ ia sering melewatkan hal yang sebenarnya penting.

### Kebiasaan yang sama-sama menghemat token, di luar pemilihan model

- **Satu tahap = satu sesi baru** (sudah ditekankan di catatan eksekusi prompt-development.md) — riwayat percakapan yang menumpuk adalah sumber pemakaian token terbesar, bukan cuma panjang prompt itu sendiri. Sesi debugging panjang yang sudah membaca puluhan file akan membawa semua itu di setiap pesan berikutnya
- **CLAUDE.md tetap ringkas** (sudah ada di tech spec §9.5) — supaya aturan modul tidak perlu dijelaskan ulang tiap sesi
- **Jangan gabung banyak tahap dalam satu prompt panjang** — selain sulit di-review, juga bikin satu sesi menumpuk konteks dari banyak topik sekaligus
- Kalau kuota tetap sering habis meski sudah pakai pola di atas, pertimbangkan mengaktifkan **usage credits** (bayar sesuai pemakaian setelah limit tercapai) di Settings, khusus untuk sesi tahap yang memang berat

### Catatan penting

Nama & versi model resmi berubah dari waktu ke waktu — istilah "Opus/Sonnet/Haiku" di atas merujuk ke *tier* (level kemampuan/harga), bukan versi spesifik yang dikunci selamanya. Jalankan `/model` di Claude Code untuk melihat daftar model yang aktif tersedia di akunmu saat ini — itu sumber kebenaran yang paling akurat, lebih baik daripada mengandalkan nama versi yang tertulis di dokumen manapun termasuk ini.

---

Diringkas dari PRD §8, dipetakan ke tahap mana yang tidak boleh mulai sebelum keputusan ini final:

| Keputusan terbuka | Menghambat tahap | Aksi |
|---|---|---|
| Daftar reserved words subdomain | Tahap 1 | Buat sebelum coding modul `tenant` |
| Mapping kode wilayah J&T | Tahap 6 | Mulai proses administratif dengan J&T jauh sebelum Tahap 6 — ini bottleneck eksternal |
| Biaya nomor WA dialokasikan ke paket mana | Tahap 7 | Putuskan sebelum desain pricing final di-lock |
| Kebijakan privasi & UU PDP | Sebelum go-live production | Review legal terpisah, tidak menghambat coding tapi menghambat launch |

---

## 8. Dokumen Terkait

- `tokospace-PRD.md` v1.1 — cakupan fitur, acceptance criteria per tahap
- `tokospace-design-brief.md` v2.0 — sistem desain, breakdown halaman
- `tokospace-tech-spec.md` v2.1 — arsitektur, struktur modul, deployment
- `tokospace-prompt-bertahap.md` — prompt desain UI (Claude Design)
- `tokospace-prompt-development.md` — prompt development (Claude Code), satu blok per tahap di atas
