# Nalaro Seller Center

Aplikasi Flutter Android-first untuk mengelola toko pada **Nalaro Store**. Backend bisnis tetap Cloudflare Workers/PostgreSQL pada [khoirulzz/nalarostore](https://github.com/khoirulzz/nalarostore). Aplikasi ini bukan APK untuk pembeli atau admin platform.

Pembaruan kode Dart melalui Shorebird disiapkan lewat workflow **Android OTA**.
Lihat [aktivasi akun, APK baseline, patch, dan rollback](docs/OTA.md).
APK debug dari **Android CI** tidak menerima OTA; dukungan baru aktif setelah
konfigurasi akun/signing dan pemasangan APK baseline Shorebird.

## Status

**Beta pengembangan, bukan rilis produksi.** Lihat [audit PRD dan desain](docs/PRD_DESIGN_AUDIT_2026-10-17.md) untuk implementasi, ketergantungan API, dan langkah pengujian yang masih wajib.

### Sudah tersedia

- Login/registrasi Firebase Identity Toolkit, verifikasi email melalui browser, reset password dan pemulihan sesi menggunakan penyimpanan terenkripsi di perangkat.
- 5 tab navigasi: Beranda, Pesanan, Produk, Analitik, Toko; pemilihan toko aktif dan kontrol hak akses berdasarkan role backend.
- Beranda 30 hari terakhir, prioritas pesanan dan stok rendah.
- Pencarian, filter, pagination, detail, review pembayaran manual (verified/rejected), fulfillment sesuai urutan Worker, dan cancel dengan konfirmasi.
- Katalog produk, editor multi-varian, SKU unik, draft lokal per user/toko, unggah foto kamera/galeri ke Worker, galeri sampai 12 foto, pengurutan, arsip produk.
- Stok tersedia/dipesan, perubahan stok melalui update produk dengan validasi reservasi, dan riwayat stok Worker.
- Analitik, grafik penjualan, tanggal, pelanggan paginated, ekspor CSV dan system share sheet.
- Pengaturan toko, upload logo/hero/QRIS, checklist publikasi, billing/invoice/penggunaan, dan keamanan akun.
- Logo asli Nalaro Store pada aplikasi dan ikon launcher Android.

**Tidak tersedia atau belum tervalidasi:** push FCM dan notification center server, deep link verifikasi email yang terbukti melalui Android App Links, crop bebas (drag area), quick stock adjust transaksional dengan reason dan expected-version, persistensi foto varian di Worker, hasil domain verification, notifikasi latar, QA perangkat/visual, signing release. Lihat audit.

## Perbaikan UI/UX Android 1.0.1

Lihat [audit UI/UX dan Android](docs/UI_UX_ANDROID_AUDIT_2026-10-17.md) untuk temuan, perubahan, dan batas verifikasi. Foto toko draft dimuat terautentikasi, editor memiliki preview besar/zoom/retry/putar/crop tengah, draft dan kembali Android dilindungi, detail tidak bertumpuk dengan tab global, serta font Manrope/DM Sans dibundel. Tes regresi dan capture layout berjalan di CI.

## Konfigurasi

- Flutter stable; Dart SDK sesuai `pubspec.yaml`.
- API default: `https://store.nalaro.digital`.
- Gunakan `--dart-define=NALARO_API_BASE_URL=https://... ` jika backend berbeda.
- Firebase REST auth memakai konfigurasi publik dari `lib/core/config/app_config.dart`. **Jangan menyimpan API secret** di repo.
- Penyimpanan sesi menggunakan `flutter_secure_storage`, bukan preferensi biasa; draft lokal tetap `shared_preferences`.
- Tidak boleh menggunakan akun merchant produksi untuk seed data demo.

## Menjalankan

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

### CI / APK

[GitHub Actions](https://github.com/khoirulzz/seller-center/actions) menyiapkan proyek Android native, mengganti ikon launcher dari aset resmi, menguji, lalu membangun **APK debug** sebagai artifact. Workflow **tidak** menandatangani release APK/AAB, tidak menerbitkan GitHub Release otomatis, dan tidak menjanjikan kesiapan Google Play. Sebagian diagnostic lint kategori `info` belum diselesaikan sehingga analyzer dijalankan dengan `--no-fatal-infos`; error dan warning tetap menggagalkan CI.

## Kontrol data

Mutasi pembayaran, pembatalan, fulfillment, penerbitan toko, billing dan stok membutuhkan koneksi dan otorisasi Worker. Hak akses di Flutter hanya lapisan UX, bukan pengganti pemeriksaan membership/role server. Rekening/PII tidak boleh ditulis ke log. Tidak ada pembayaran otomatis melalui QRIS.

## Dokumen sumber

PRD `PRD-Nalaro-Seller-Center.md` dan desain `desain-nalaro-seller-center-REUPLOAD.md` adalah spesifikasi produk yang disimpan pada file Library proyek sebelumnya. **Kedua file tersebut belum dibundel dalam repo ini**; dokumen audit di sini mencatat kesenjangan aktual, bukan menggantikannya.
