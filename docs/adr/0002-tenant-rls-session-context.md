# ADR-0002 — Tenant RLS Session Context Pattern

| | |
|---|---|
| **Status** | Accepted (not yet implemented) |
| **Tanggal** | 18 Agustus 2026 |
| **Terkait** | `tokospace-tech-spec.md` §4.4, §0.2 rule 2; `tokospace-master-plan.md` Tahap 1 |

## Konteks

Tech Spec §4.4 mensyaratkan PostgreSQL Row-Level Security (RLS) dengan
tenant context yang di-set server-side, tidak pernah berasal dari input
client mentah. Mekanisme konkret cara Laravel menetapkan context ini pada
koneksi/transaksi database belum pernah dicatat formal — hanya disebut
"harus dicatat dalam ADR" tanpa keputusan.

Modul Tenant (Tech Spec §10, Master Plan Tahap 1) **belum diimplementasikan**
pada saat ADR ini dibuat — Stage 0 murni infrastruktur. Ini bukan analisis
kompatibilitas kode yang sudah ada, melainkan keputusan arsitektur yang
mengikat implementasi modul Tenant mendatang.

Pertimbangan kunci: Laravel PHP-FPM request tidak memakai koneksi PDO
persisten (`config/database.php` tidak mengaktifkan
`PDO::ATTR_PERSISTENT`) — setiap request HTTP mendapat koneksi baru,
ditutup di akhir request. Namun Horizon adalah proses PHP long-running;
satu koneksi PDO bisa dipakai lintas banyak job berturut-turut sebelum
worker restart. Jika tenant context di-set dengan `SET` level-session
(bukan `SET LOCAL` dalam transaksi), context tenant job sebelumnya bisa
bocor ke job berikutnya pada koneksi yang sama.

Migrasi hosting ke Google Cloud SQL (ADR-0001) tidak mengubah
pertimbangan ini — Cloud SQL Auth Proxy adalah tunnel TCP transparan yang
tidak mengubah semantik session/transaction PostgreSQL.

## Keputusan

Gunakan `SET LOCAL app.tenant_id = ?` **di dalam transaksi eksplisit**
yang membungkus setiap request/job tenant-scoped — bukan `SET`
level-session.

Rasional: `SET LOCAL` otomatis ter-reset saat transaksi berakhir (commit
atau rollback), sehingga koneksi yang sama aman dipakai ulang oleh
request/job berikutnya tanpa perlu reset manual. Ini menghilangkan kelas
bug leak-tenant-context-lintas-job *by construction*, alih-alih
bergantung pada disiplin manual reset di setiap titik keluar (termasuk
exception path).

## Konsekuensi

- Setiap operasi tenant-scoped (baik HTTP request maupun queued job)
  wajib dibungkus transaksi eksplisit sebelum RLS-protected query
  dijalankan.
- Modul Tenant wajib menyertakan test wajib: dua job berurutan untuk dua
  tenant berbeda dijalankan pada worker Horizon yang sama, dibuktikan
  tidak saling bocor. Ini menjadi kriteria Definition-of-Done Tahap 1
  (Master Plan), bukan opsional.
- Detail teknis (nama helper/middleware yang membungkus transaksi,
  bagaimana `TenantResolver` memicu `SET LOCAL`) adalah implementation
  detail yang ditentukan saat modul Tenant dibangun — ADR ini mengikat
  *pola*-nya (`SET LOCAL` + transaksi eksplisit), bukan implementasi
  baris-per-baris.

## Alternatif yang dipertimbangkan dan ditolak

- **`SET` level-session tanpa pembungkus transaksi** — ditolak; berisiko
  leak context lintas job pada worker Horizon yang me-reuse koneksi, dan
  mensyaratkan reset manual yang mudah terlewat pada exception path.
- **Koneksi PDO baru per job/request untuk menghindari reuse** — tidak
  dipertimbangkan lebih lanjut karena menghilangkan manfaat performa
  connection reuse Horizon tanpa alasan, padahal `SET LOCAL` sudah
  menyelesaikan masalah leak tanpa trade-off ini.
