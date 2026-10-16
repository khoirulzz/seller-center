/// Skala jarak (spacing scale) resmi Nalaro Seller Center (`desain.md` Bab 3.2).
/// Menggunakan kelipatan terstruktur tanpa jarak acak.
abstract final class NsSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  /// Horizontal padding responsif sesuai lebar layar (`desain.md` Bab 3.2).
  static double horizontalPaddingForWidth(double width) {
    if (width >= 390) return lg;
    return md;
  }

  /// Lebar maksimum konten untuk tablet / layar lebar (`desain.md` Bab 3.2).
  static const double maxTabletContentWidth = 840.0;

  /// Touch target minimum aksesibilitas (48x48 dp).
  static const double minTouchTarget = 48.0;
}
