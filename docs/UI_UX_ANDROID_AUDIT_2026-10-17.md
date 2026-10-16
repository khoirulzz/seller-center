# Audit UI/UX dan Android — 17 Oktober 2026

Basis: `main` d1eab6e, PRD v1.0 dan desain v1.0; kontrak backend `khoirulzz/nalarostore` 115fb6c8. Perubahan dikerjakan melalui PR #1. Dokumen ini melengkapi audit sebelumnya, bukan klaim seluruh roadmap selesai.

## Temuan dan perbaikan

| Prioritas | Temuan | Perubahan dan bukti |
|---|---|---|
| Tinggi | Foto toko draft memakai request publik, padahal GET `/api/media/...` memerlukan identitas anggota toko yang belum terbit | Fetch byte terautentikasi untuk origin API + path media saja; token tidak dikirim ke host luar atau redirect. Tes header privat/eksternal, URL tidak aman, gagal 404, dan preview penuh |
| Tinggi | Controller dialog varian/stok dan sheet aksi dibuang ketika route masih menjalankan animasi tutup | Controller dimiliki State dari dialog/sheet, dispose mengikuti unmount route. Tes buka/tutup berulang, edit stok reserved, save editor |
| Tinggi | Notifikasi status dirty memicu refresh router; dispose form juga memberi notifikasi ancestor | Router hanya mendengarkan perubahan lifecycle auth; flag dirty bersifat state guard. Tes navigasi saat edit/simpan/dismiss |
| Tinggi | Android back pada root tab mengakhiri aplikasi; up action dapat melewati guard | Back root tab kembali Beranda; root Beranda mengonfirmasi keluar. Detail dan editor berada di root navigator; back form memakai maybePop dan menunggu frame setelah konfirmasi |
| Tinggi | Timer autosave dapat menulis lagi setelah draft dibuang; save error lokal setelah POST sukses dapat mendorong submit ulang | Autosave diserialkan, timer dibatalkan, penulisan ditunggu sebelum hapus. Snapshot saat background/dispose; hasil server tetap sukses walau cleanup lokal gagal |
| Tinggi | Respons pesanan memakai revision toko untuk search/filter; request lama pada toko sama tetap dianggap valid | Generation terpisah per reset, debounce 300 ms, refresh menunggu request; tes hasil search lama selesai sesudah search baru |
| Tinggi | Data overview dari FutureBuilder dapat menampilkan tenant lama saat ganti toko | Cache dibersihkan per tenant dan snapshot lama tidak dipakai selama menunggu future baru |
| Sedang | Riwayat stok diminta saat katalog dibuka, meski belum ada FutureBuilder penangan error; analitik juga diminta oleh role tanpa akses | Fetch riwayat hanya di tab stok; analitik tidak diminta bila role tidak berhak |
| Sedang | SKU default kosong menyulitkan produk tanpa varian; label/harga/slug kurang jelas | Varian Standar dengan SKU UTAMA, input wajib dan contoh, link produk otomatis sampai diedit manual, harga angka dan batas nilai, error per-field |
| Sedang | Foto terlalu kecil, tidak ada preview proses, retry, atau alat orientasi | Preview besar contain, ketuk untuk zoom, preview byte lokal saat upload, retry sisa foto, putar 90° dan crop tengah 1:1/4:5 dengan konfirmasi; operasi di isolate dan tes piksel/alpha |
| Sedang | Beranda polos dan hierarchy tugas lemah | Panel kesiapan, kartu omzet, metrik actionable, tugas, state semua tertangani, skeleton, error/retry dan pull-to-refresh untuk konten pendek |
| Sedang | Font Manrope/DM Sans hanya deklarasi, berkas belum dibundel | Font variable dan lisensi OFL disertakan; pengujian capture memuat font yang sama |
| Sedang | Editor bertumpuk dengan global app bar dan bottom tabs | Editor/detail memenuhi layar dengan action bar sendiri; order actions berada di area sticky |
| Sedang | Pengaturan gambar hanya menyebut file terpilih; input bisa berubah ketika request save berjalan | Preview logo/banner/QRIS, field label+contoh+helper+validator, kontrol readOnly ketika busy; dirty guard diuji |
| Sedang | Role yang hilang dari respons dianggap owner | Default unknown/fail closed; unit test akses katalog/pembayaran |
| Rendah | Forgot/register mengganti stack login; create toko tambahan tidak selalu meninggalkan wizard | Push halaman auth, kembali ke login yang benar, create sukses mengarah ke Beranda, slug otomatis dan penjelasan link/alamat |

Screenshot hanya menampilkan assertion `_dependents.isEmpty`, tanpa stack trace lengkap. Perubahan memperbaiki sumber lifecycle yang ditemukan di alur terkait; tes membuktikan alur buka/edit/tutup/simpan tidak melempar exception pada lingkungan widget. Assertion persis dari perangkat pengguna belum direproduksi melalui stack trace perangkat.

## Validasi

- Flutter stable dipin ke 3.47.7 di Actions.
- Analyzer tetap menggagalkan error/warning; lint informasional lama bukan gerbang fatal.
- Tes model/API, media privat, keamanan role, transform foto, dialog, draft, back, save, settings dan stale order search.
- Layout shell/beranda/editor pada 320/360/390/430/600 dp, skala teks 1.0/1.6; capture di artifact `seller-ui-qa` dan review visual font nyata.
- APK debug dibangun oleh Actions setelah tes; build akhir harus dirujuk pada commit merge main.

## Kesenjangan yang tetap memerlukan pekerjaan terpisah

- FCM, notification center sinkron, App Links dengan assetlinks/signing, biometrik, Crashlytics, signing release dan distribusi Play.
- API stok transaksional + expected version/reason, persistensi foto varian, zona waktu laporan Jakarta, domain verification dan orphan media cleanup.
- Crop saat ini berpusat dengan rasio tetap; belum ada drag area crop bebas.
- Android process-death/lost-data recovery image picker belum lengkap; autosave teks/draft bukan jaminan pemulihan file kamera ketika OS membunuh proses.
- Uji kamera/galeri native, TalkBack, predictive-back perangkat fisik, offline/resume, memori perangkat entry-level, dan transaksi backend memakai akun beta masih perlu dilakukan. Widget test tidak menggantikannya.
