import 'package:flutter/material.dart';
import 'ns_colors.dart';

/// Skala tipografi Nalaro Seller Center (`desain.md` Bab 3.1).
/// Headline dan metrik menggunakan keluarga Manrope (dengan tabular figures),
/// sedangkan body, label, dan kontrol menggunakan DM Sans.
abstract final class NsTypography {
  static const String headlineFamily = 'Manrope';
  static const String bodyFamily = 'DM Sans';

  static const TextStyle display = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 32,
    height: 39 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: NsColors.textPrimary,
  );

  static const TextStyle titleLg = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 25,
    height: 32 / 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: NsColors.textPrimary,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 20,
    height: 27 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: NsColors.textPrimary,
  );

  static const TextStyle titleSm = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 16,
    height: 23 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: NsColors.textPrimary,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    height: 23 / 15,
    fontWeight: FontWeight.w500,
    color: NsColors.textPrimary,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w400,
    color: NsColors.textPrimary,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
    color: NsColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    color: NsColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    color: NsColors.textMuted,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: headlineFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    color: NsColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
