# Nalaro Seller Center — Mobile App (Flutter)

Aplikasi operasional toko multi-tenant untuk seller **Nalaro Store** (`https://store.nalaro.digital`), dirancang khusus untuk alur kerja mobile harian: memantau pesanan masuk, memeriksa pembayaran manual, memproses pengiriman/pengambilan, mengelola katalog produk & galeri foto, menyesuaikan stok varian secara cepat, serta memantau analitik penjualan.

- **Dokumen Kebutuhan Produk (PRD):** [`PRD-Nalaro-Seller-Center.md`](./PRD-Nalaro-Seller-Center.md)
- **Spesifikasi Desain & Sistem Interaksi:** [`desain.md`](./desain.md)
- **Backend & Web Repository:** [`khoirulzz/nalarostore`](https://github.com/khoirulzz/nalarostore)

---

## Arsitektur & Struktur Direktori

Aplikasi dibangun menggunakan **Flutter & Dart** dengan pemisahan berlapis (**UI / MVVM ViewModel / Repository / Service**) sesuai panduan arsitektur resmi Flutter:

```text
lib/
├── app/
│   ├── app.dart                  # Konfigurasi MaterialApp.router & lokalisasi id_ID
│   └── router.dart               # GoRouter 5-tab StatefulShellRoute & auth redirect guard
├── core/
│   ├── config/                   # AppConfig, Formatters (Rupiah/tanggal), SlugUtils, StatusDictionary
│   ├── errors/                   # ApiException & NsErrorMapper (terjemahan pesan teknis ke bahasa pengguna)
│   ├── motion/                   # NsMotion tokens (reduced-motion aware) & NsHaptics
│   ├── theme/                    # NsColors (Brave Pink #FF154F & #D30C3F), NsTypography, NsSpacing, NsRadius
│   └── widgets/                  # Komponen reusable Ns* (Buttons, Cards, Stepper, Chart, Sheets, Skeleton)
├── data/
│   ├── repositories/             # SellerRepository (isolasi cache per user_id + store_id & concurrency check)
│   └── services/                 # FirebaseAuthService, SellerApiService (Worker API), LocalDraftService
├── domain/
│   └── models/                   # Model domain immutable + JSON serialization & compute() isolate parser
├── ui/
│   ├── features/
│   │   ├── auth/                 # Splash/Session restore, Login, Register, Verify, Forgot Password
│   │   ├── stores/               # Store Switcher Bottom Sheet & 5-Step Create Store Wizard
│   │   ├── shell/                # SellerAppShell (5 tab bawah di ponsel, NavigationRail di tablet >=600dp)
│   │   ├── home/                 # Beranda operasional (30-day overview, prioritas, stok rendah, pesanan terbaru)
│   │   ├── orders/               # Daftar pesanan, filter tanggal/status, Detail pesanan, Payment & Fulfillment sheets
│   │   ├── products/             # Katalog produk, Editor produk & galeri 12 foto, Quick Stock Adjust & Ledger
│   │   ├── analytics/            # Analitik penjualan terverifikasi & grafik interaktif harian
│   │   ├── export/               # Ekspor CSV pesanan, produk, dan pelanggan
│   │   └── store_hub/            # Hub Toko, Pengaturan, Readiness Checklist, Pelanggan, Billing, Notifikasi, Keamanan
│   └── state/
│       └── seller_app_state.dart # ChangeNotifier ViewModel utama untuk sesi & perpindahan toko aktif
└── main.dart
```

---

## Fitur Utama yang Diimplementasikan

1. **Autentikasi & Multi-Toko (`AUTH-01` s/d `AUTH-09`)**:
   - Integrasi Firebase Authentication proyek `nalarostore` + verifikasi sesi `/api/auth/me`.
   - Pemilih toko (`Store Switcher`) dari header dan wizard pembuatan toko 5 langkah dengan normalisasi otomatis link toko (`NsSlugUtils`).
   - Isolasi penuh cache dan draft per `(user_id, store_id)` sehingga tidak ada kebocoran data saat berpindah toko.
   - Dukungan akun pratinjau multi-peran (`Pemilik`, `Manajer Toko`, `Staf Pengiriman`) untuk pengujian langsung di perangkat Android bahkan ketika database Aiven/Hyperdrive produksi sedang dalam status `503 setup-required`.
2. **Beranda Operasional (`HOME-01` s/d `HOME-05`)**:
   - Kartu prioritas *Perlu ditangani* (pesanan menunggu konfirmasi & varian stok menipis), ringkasan penjualan terverifikasi 30 hari terakhir, dan indikator kesiapan publikasi toko.
3. **Pesanan & Guarded Confirmations (`ORD-01` s/d `ORD-11`)**:
   - Pencarian nomor/pembeli, filter status horizontal, dan filter rentang tanggal.
   - Bottom sticky CTA pada detail pesanan yang mematuhi state machine Cloudflare Worker dan peran pengguna.
   - Konfirmasi pembayaran manual dan pembatalan pesanan melalui bottom sheet terproteksi (tidak pernah dieksekusi hanya dengan satu kali swipe).
4. **Produk, Galeri & Inventaris (`PROD-01` s/d `PROD-10`, `INV-01` s/d `INV-06`)**:
   - Editor produk dengan bagian terstruktur, pengurutan galeri foto (maksimal 12 foto tambahan) dilengkapi kontrol aksesibilitas, manajemen varian SKU unik, dan penyimpanan draft lokal otomatis.
   - Sub-tab **Stok & Riwayat** dengan *Quick Stock Adjust* (`NsInventoryStepper`), validasi batas `reserved_qty`, deteksi konflik `409`, dan buku besar pergerakan stok.
5. **Analitik, Pelanggan, Pengaturan Toko, Billing & Notifikasi**:
   - Grafik penjualan harian interaktif (`NsMetricChart`), direktori pelanggan, checklist kesiapan publikasi toko, pengelolaan langganan/invoice SaaS, ekspor CSV, dan pusat notifikasi lintas toko.

---

## Build Otomatis via GitHub Actions

Repository ini dilengkapi workflow [`.github/workflows/android-build.yml`](./.github/workflows/android-build.yml) yang secara otomatis menjalankan:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test` (unit test & widget test)
4. `flutter build apk --debug`, `flutter build apk --release`, dan `flutter build appbundle --release`
5. Mengunggah artifact APK/AAB dan menerbitkan **GitHub Release** otomatis pada setiap push ke branch `main`.
