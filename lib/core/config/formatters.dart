import 'package:intl/intl.dart';

/// Utilitas pemformatan mata uang Rupiah, angka, dan tanggal lokal `id-ID`.
abstract final class NsFormatters {
  static final NumberFormat _rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _decimalFormatter =
      NumberFormat.decimalPattern('id_ID');

  /// Format integer IDR menjadi `Rp120.000` (tanpa desimal).
  static String rupiah(num? value) {
    final safeValue = (value ?? 0).round();
    return _rupiahFormatter.format(safeValue);
  }

  /// Format angka ribuan `1.250`.
  static String number(num? value) {
    return _decimalFormatter.format((value ?? 0).round());
  }

  /// Parse input teks uang menjadi integer IDR murni.
  static int parseRupiah(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  /// Format tanggal ISO 8601 ke tampilan singkat Indonesia (misal `16 Okt 2026`).
  static String shortDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) return isoString;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  /// Format tanggal & waktu lokal Indonesia (misal `16 Okt 2026, 14.30`).
  static String dateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) return isoString;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '${shortDate(isoString)}, $hh.$mm';
  }

  /// Format tanggal kalender `YYYY-MM-DD` untuk filter query API.
  static String calendarDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
