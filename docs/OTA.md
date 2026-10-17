# Pembaruan otomatis Seller Center

## Status integrasi

Kode aplikasi sudah mendukung Shorebird: pemeriksaan setelah frame pertama dan
saat kembali ke aplikasi, unduhan di latar belakang, pemeriksaan manual dari
**Toko → Pembaruan aplikasi**, serta pemberitahuan saat pembaruan siap.
Pemeriksaan otomatis dibatasi setiap 15 menit; permintaan bersamaan memakai satu
operasi. Gangguan layanan pembaruan tidak menghalangi login atau aktivitas toko.
Aplikasi tidak melakukan restart paksa, tidak menghapus sesi, dan tidak mereset
form untuk menerapkan patch.

**Integrasi kode tidak sama dengan aktivasi layanan.** OTA baru berfungsi setelah
akun Shorebird dikonfigurasi, baseline dibuat dengan `shorebird release`, dan APK
baseline itu dipasang pada perangkat. APK dari workflow **Android CI** tetap APK
debug Flutter biasa dan tidak menerima OTA. Jangan membagikannya sebagai APK OTA.

## Aktivasi satu kali

1. Masuk atau buat akun di https://console.shorebird.dev. Instal CLI sesuai
   https://docs.shorebird.dev lalu jalankan `shorebird login` dan
   `shorebird init --display-name "Nalaro Seller Center"` di repository ini.
   Jika memiliki beberapa organisasi, pilih organisasi Nalaro yang benar.
2. Ambil `app_id` yang terdaftar dari `shorebird.yaml`. Simpan sebagai repository
   variable **SHOREBIRD_APP_ID** pada
   https://github.com/khoirulzz/seller-center/settings/variables/actions.
   App ID bersifat publik. Jangan membuat UUID sendiri dan jangan menjalankan
   `init --force` setiap rilis karena itu akan membuat identitas aplikasi baru.
3. Buat API key pada akun Shorebird dengan izin untuk membuat release dan patch.
   Simpan sebagai repository secret **SHOREBIRD_TOKEN** di
   https://github.com/khoirulzz/seller-center/settings/secrets/actions.
   Gunakan API key saat ini, bukan token lama dari `shorebird login:ci`.
   Jangan kirim token melalui chat atau commit ke git.
4. Siapkan satu keystore Android yang disimpan aman dan dipakai terus untuk setiap
   rilis. Tambahkan secrets berikut pada halaman yang sama:

   | Secret | Nilai |
   | --- | --- |
   | ANDROID_KEYSTORE_BASE64 | Isi keystore dalam base64 satu baris |
   | ANDROID_KEYSTORE_PASSWORD | Password keystore |
   | ANDROID_KEY_ALIAS | Alias kunci penandatanganan |
   | ANDROID_KEY_PASSWORD | Password kunci |

   Jika belum memiliki keystore, buat secara lokal dengan `keytool -genkeypair
   -v -keystore nalaro-seller-release.jks -alias nalaro-seller -keyalg RSA
   -keysize 2048 -validity 10000`. Ikuti prompt password lalu backup keystore dan
   password di tempat privat. Untuk menyalin base64 ke secret pada Linux dengan
   GitHub CLI, jalankan `base64 -w0 nalaro-seller-release.jks | gh secret set
   ANDROID_KEYSTORE_BASE64 --repo khoirulzz/seller-center`.
5. Buka Actions → **Android OTA** → Run workflow → branch **main**, operation
   **release**. Workflow membuat baseline versi `1.1.0+3` dan artifact
   **nalaro-seller-center-ota-release-apk**. Unduh dan pasang APK tersebut sekali.
   Nomor versi mengikuti `pubspec.yaml`, jadi baca nomor di commit yang dirilis.

Workflow berhenti sebelum build jika app ID, API key, atau konfigurasi signing
belum tersedia. Ia tidak diam-diam mengganti build OTA dengan APK Flutter biasa.
Keystore hanya ditulis ke direktori sementara runner dengan izin 0600, tidak
di-upload sebagai artifact, dan dibersihkan sesudah job.

APK debug lama dapat memiliki sertifikat berbeda dari keystore rilis. Android
dapat menolak instalasi di atas APK lama. Simpan pekerjaan/draft lokal sebelum
mengganti instalasi; penghapusan aplikasi menghapus data lokal. Data toko yang
sudah tersimpan di server tidak bergantung pada instalasi APK.

## Menerbitkan perbaikan berikutnya

1. Ubah kode Dart dan jalankan pemeriksaan biasa lewat PR. Merge perubahan yang
   lulus pemeriksaan ke `main`.
2. Jalankan **Android OTA**, operation **patch**, `release_version` diisi **versi
   baseline yang benar-benar terpasang**, misalnya `1.1.0+3`. Awali dengan
   **dry_run = true**. Workflow tidak memakai target ambigu `latest`.
3. Setelah validasi berhasil, ulangi dengan **dry_run = false** untuk menerbitkan
   patch ke track `stable`. Ini adalah tindakan publikasi; merge saja tidak
   menerbitkan patch otomatis.
4. Di APK OTA pada perangkat, buka **Pembaruan aplikasi → Periksa pembaruan**.
   Setelah tertulis siap, simpan pekerjaan, tutup aplikasi sepenuhnya, dan buka
   kembali. Periksa nomor pembaruan yang aktif dan uji alur yang berubah.

Pertahankan versi baseline di `pubspec.yaml` untuk patch pada baseline tersebut.
Ubah nomor versi/build ketika membuat APK baseline berikutnya. Jangan mematikan
validasi native/asset memakai `--allow-native-diffs` atau `--allow-asset-diffs`.

Jika perlu rollback, gunakan console Shorebird untuk menonaktifkan patch pada
release/track yang benar. Pada pemeriksaan berikutnya runtime menjadwalkan kode
pengganti; pengguna tetap perlu membuka ulang aplikasi. Uji rollback pada
perangkat sebelum mengandalkannya untuk insiden produksi.

## Cakupan OTA

| Perubahan | Cara distribusi |
| --- | --- |
| Layout Flutter, label, routing, validasi, logika Dart | Patch OTA |
| Data paket dan aturan backend | Deploy backend, tidak membutuhkan patch APK |
| Permission Android, Kotlin/Java, native plugin, signing | APK baseline baru |
| Gambar/font/aset terbundel, konfigurasi native, upgrade engine | APK baseline baru |

Jangan mengganti aset atau versi toolchain di antara baseline dan patch. Workflow
menyiapkan native project dan ikon dengan versi Flutter yang dipin; Shorebird
memakai versi engine baseline saat menyusun patch. Saat mengubah versi Flutter di
workflow, buat baseline baru dan audit template signing yang dihasilkan.
`pubspec.lock` disimpan sebelum `flutter create` dan dipulihkan setelahnya karena
perintah tersebut menulis ulang lockfile meski memakai `--no-pub`. Resolusi paket
berikutnya wajib lulus `--enforce-lockfile`.

## Build lokal

Setelah login, isi environment `SHOREBIRD_APP_ID` dengan app ID terdaftar lalu
jalankan `python3 tool/prepare_ota.py`. Perintah ini membuat `shorebird.yaml` dan
mendaftarkannya sebagai aset Flutter; file lokal tersebut diabaikan git karena
konfigurasi deploy berasal dari repository variable. `auto_update: false`
memastikan controller aplikasi menjadi satu pengendali unduhan.

Build OTA harus memakai `shorebird release android --flutter-version=3.47.7
--artifact=apk` dengan signing rilis yang benar. `flutter build apk` biasa tidak
menanam engine OTA. Jangan commit perubahan aset `shorebird.yaml` hasil persiapan
lokal karena workflow menyiapkannya kembali dengan app ID yang sama.

## Validasi dan batas yang belum teruji

Unit/widget test mencakup unduhan sukses, kegagalan dan retry, pembatasan check,
request ganda, pembuangan controller ketika operasi masih berjalan, status pada
APK biasa, serta layout 320dp dengan skala teks besar. Test tersebut memakai
service palsu dan bukan bukti patch sudah terkirim ke perangkat.

Aktivasi akun, build baseline Shorebird, distribusi patch sungguhan, restart
proses Android, dan rollback harus diverifikasi setelah konfigurasi akun dan
signing tersedia. Tidak ada token, app ID terdaftar, atau keystore rilis yang
disertakan dalam perubahan ini.

Referensi resmi:
- https://docs.shorebird.dev/code-push/initialize/
- https://docs.shorebird.dev/code-push/ci/github/
- https://docs.shorebird.dev/code-push/release/
- https://docs.shorebird.dev/code-push/patch/
- https://pub.dev/packages/shorebird_code_push
