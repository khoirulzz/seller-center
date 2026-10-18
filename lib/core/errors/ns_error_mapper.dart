import 'dart:async';

import 'package:flutter/services.dart';

import 'api_exception.dart';

/// Penerjemah pesan teknis/error internal menjadi copy produksi ramah pengguna
/// sesuai tabel `desain.md` Bab 9.1 dan `src/lib/firebase.ts`.
abstract final class NsErrorMapper {
  static const Map<String, String> _firebaseMessages = {
    'INVALID_LOGIN_CREDENTIALS': 'Email atau kata sandi tidak cocok.',
    'INVALID_PASSWORD': 'Email atau kata sandi tidak cocok.',
    'EMAIL_NOT_FOUND': 'Email atau kata sandi tidak cocok.',
    'auth/invalid-credential': 'Email atau kata sandi tidak cocok.',
    'auth/wrong-password': 'Email atau kata sandi tidak cocok.',
    'auth/user-not-found': 'Email atau kata sandi tidak cocok.',
    'EMAIL_EXISTS':
        'Email belum dapat digunakan. Coba masuk atau pulihkan kata sandi.',
    'auth/email-already-in-use':
        'Email belum dapat digunakan. Coba masuk atau pulihkan kata sandi.',
    'INVALID_EMAIL': 'Periksa kembali alamat emailmu.',
    'auth/invalid-email': 'Periksa kembali alamat emailmu.',
    'WEAK_PASSWORD': 'Kata sandi belum memenuhi persyaratan.',
    'auth/weak-password': 'Kata sandi belum memenuhi persyaratan.',
    'TOO_MANY_ATTEMPTS_TRY_LATER':
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
    'auth/too-many-requests':
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
    'EXPIRED_OOB_CODE': 'Tautan sudah kedaluwarsa. Minta tautan baru.',
    'INVALID_OOB_CODE': 'Tautan tidak valid atau sudah digunakan.',
    'USER_DISABLED': 'Akun dinonaktifkan. Hubungi dukungan Nalaro.',
    'CREDENTIAL_TOO_OLD_LOGIN_AGAIN':
        'Masuk kembali sebelum mengubah keamanan akun.',
  };

  static String toUserMessage(Object error, {int? statusCode}) {
    if (error is ApiException) {
      if (error.isOffline) {
        return 'Tidak ada koneksi. Perubahan belum disimpan.';
      }
      if (error.machineCode != null &&
          _firebaseMessages.containsKey(error.machineCode)) {
        return _firebaseMessages[error.machineCode]!;
      }
      return _mapStatusAndMessage(
        error.message,
        error.statusCode ?? statusCode,
      );
    }

    if (error is PlatformException) {
      return 'Komponen perangkat sedang bermasalah. Perbarui aplikasi Nalaro Seller Center lalu coba lagi.';
    }
    if (error is TimeoutException)
      return 'Koneksi terlalu lama. Periksa jaringan lalu coba lagi.';
    final raw = error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
    for (final entry in _firebaseMessages.entries) {
      if (raw.contains(entry.key)) {
        return entry.value;
      }
    }
    return _mapStatusAndMessage(raw, statusCode);
  }

  static String _mapStatusAndMessage(String raw, int? statusCode) {
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.';
    }
    if (lower.contains('slug') &&
        (lower.contains('pattern') ||
            lower.contains('invalid') ||
            lower.contains('regex'))) {
      return 'Link produk belum sesuai. Gunakan huruf, angka, dan tanda hubung.';
    }
    if (statusCode == 401 || lower.contains('token expired')) {
      return 'Sesi berakhir. Masuk kembali untuk melanjutkan.';
    }
    if (statusCode == 403) {
      return raw.isNotEmpty && !lower.contains('forbidden')
          ? raw
          : 'Akun ini tidak memiliki izin untuk tindakan tersebut.';
    }
    if (statusCode == 404) {
      return raw.isNotEmpty && !lower.contains('not found')
          ? raw
          : 'Data tidak ditemukan atau sudah tidak tersedia.';
    }
    if (statusCode == 409) {
      if (lower.contains('stok')) {
        return 'Stok telah berubah. Periksa jumlah terbaru sebelum menyimpan.';
      }
      return raw.isNotEmpty
          ? raw
          : 'Data sudah berubah. Periksa versi terbaru sebelum melanjutkan.';
    }
    if (statusCode == 413 ||
        lower.contains('5 mb') ||
        lower.contains('terlalu besar')) {
      return 'Ukuran foto terlalu besar. Pilih atau kecilkan gambar lalu coba lagi.';
    }
    if (statusCode == 429) {
      return 'Terlalu banyak permintaan. Coba lagi sebentar.';
    }
    if (statusCode != null && statusCode >= 500) {
      if (raw.isNotEmpty && !lower.contains('internal server error')) {
        return raw;
      }
      return 'Belum berhasil memuat data. Coba lagi.';
    }
    return raw.isNotEmpty ? raw : 'Belum berhasil memuat data. Coba lagi.';
  }
}
