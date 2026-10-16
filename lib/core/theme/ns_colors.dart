import 'package:flutter/material.dart';

/// Token warna resmi Nalaro Seller Center sesuai `desain.md` Bab 2.
/// Brand palette: Brave Pink (#FF154F) + Putih, dengan turunan CTA kontras (#D30C3F).
abstract final class NsColors {
  /// Identitas utama, selected nav, focused input, active indicator.
  static const Color brandPrimary = Color(0xFFFF154F);

  /// Turunan Brave Pink lebih gelap untuk CTA berlabel putih (rasio kontras ~5.39:1).
  static const Color brandAction = Color(0xFFD30C3F);

  /// Label/ikon di atas `brandAction`.
  static const Color brandOnPrimary = Color(0xFFFFFFFF);

  /// Kanvas utama mayoritas layar (light mode v1).
  static const Color surfaceCanvas = Color(0xFFFFFFFF);

  /// Permukaan kartu konten dengan border halus.
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Section yang memerlukan pemisahan lembut.
  static const Color surfaceSubtle = Color(0xFFF8F8F9);

  /// Pressed pink action atau active chip ringan.
  static const Color surfacePressed = Color(0xFFFFF0F4);

  /// Teks judul dan angka penting.
  static const Color textPrimary = Color(0xFF151515);

  /// Metadata dan penjelasan sekunder.
  static const Color textSecondary = Color(0xFF63636B);

  /// Placeholder dan caption.
  static const Color textMuted = Color(0xFF85858E);

  /// Border input, separator, dan card.
  static const Color borderDefault = Color(0xFFE8E8EC);

  /// Border fokus kontrol.
  static const Color borderFocus = Color(0xFFFF154F);

  /// Scrim modal / bottom sheet.
  static const Color overlayScrim = Color(0x66151515);

  /// Warna fungsional status (wajib selalu didampingi ikon dan label teks).
  static const Color statusSuccessText = Color(0xFF14532D);
  static const Color statusSuccessBg = Color(0xFFF0FDF4);
  static const Color statusSuccessBorder = Color(0xFFBBF7D0);

  static const Color statusWarningText = Color(0xFF7C2D12);
  static const Color statusWarningBg = Color(0xFFFFF7ED);
  static const Color statusWarningBorder = Color(0xFFFED7AA);

  static const Color statusDangerText = Color(0xFF881337);
  static const Color statusDangerBg = Color(0xFFFFF1F2);
  static const Color statusDangerBorder = Color(0xFFFECDD3);

  static const Color statusNeutralText = Color(0xFF3F3F46);
  static const Color statusNeutralBg = Color(0xFFF4F4F5);
  static const Color statusNeutralBorder = Color(0xFFE4E4E7);
}
