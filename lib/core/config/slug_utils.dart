/// Normalisasi dan validasi slug link toko/produk selaras dengan `src/live/Merchant.tsx`.
abstract final class NsSlugUtils {
  static final RegExp _validSlugRegex = RegExp(r'^[a-z0-9][a-z0-9-]{1,46}[a-z0-9]$');

  static const Set<String> reservedSlugs = {
    'admin',
    'api',
    'app',
    'auth',
    'www',
    'mail',
    'static',
    'assets',
    'preview',
    'demo',
    'login',
    'register',
    'verify',
  };

  /// Mengubah input nama/link menjadi slug bersih (huruf kecil, angka, tanda hubung, maks 48 karakter).
  static String normalize(String input) {
    final lowered = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final sliced = lowered.length > 48 ? lowered.substring(0, 48) : lowered;
    return sliced.replaceAll(RegExp(r'-+$'), '');
  }

  /// Memeriksa apakah slug memenuhi pola server (3-48 karakter, diawali & diakhiri alfanumerik, tidak reserved).
  static bool isValid(String slug) {
    if (slug.length < 3 || slug.length > 48) return false;
    if (reservedSlugs.contains(slug)) return false;
    return _validSlugRegex.hasMatch(slug);
  }

  /// Pesan validasi manusiawi sesuai `desain.md` Bab 9.1.
  static String? validate(String slug, {String entityLabel = 'Link'}) {
    if (slug.trim().isEmpty) {
      return '$entityLabel wajib diisi.';
    }
    if (reservedSlugs.contains(slug.trim().toLowerCase())) {
      return '$entityLabel ini dicadangkan sistem. Gunakan nama lain.';
    }
    if (!isValid(slug)) {
      return '$entityLabel belum sesuai. Gunakan 3–48 huruf kecil, angka, dan tanda hubung.';
    }
    return null;
  }
}
