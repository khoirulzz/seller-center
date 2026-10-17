/// Konfigurasi environment & identitas proyek Firebase publik Nalaro Store.
/// Selaras dengan `.env.production` pada `khoirulzz/nalarostore`.
abstract final class AppConfig {
  static const String appName = 'Nalaro Seller';
  static const String appVersion = '1.1.0';
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'NALARO_API_BASE_URL',
    defaultValue: 'https://store.nalaro.digital',
  );
  static const String rootDomain = String.fromEnvironment(
    'NALARO_ROOT_DOMAIN',
    defaultValue: 'store.nalaro.digital',
  );

  /// Konfigurasi publik Firebase Auth proyek `nalarostore` (bukan secret backend).
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyAymTQU-0lwS_p7yLe0JgsFlNkZPpUo8ow',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'nalarostore',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'nalarostore.firebaseapp.com',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'nalarostore.firebasestorage.app',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '195576574363',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:195576574363:web:8eb7987abfbbd4cb8d313e',
  );

  /// Maksimal ukuran unggah gambar sesuai kontrak Worker `/api/merchant/stores/{sid}/media`.
  static const int maxMediaUploadBytes = 5 * 1024 * 1024;

  /// Maksimal foto tambahan di galeri produk.
  static const int maxGalleryPhotos = 12;

  /// Maksimal toko per akun sesuai kontrak Worker.
  static const int maxStoresPerAccount = 10;
}
