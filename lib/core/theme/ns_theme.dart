import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ns_colors.dart';
import 'ns_radius.dart';
import 'ns_typography.dart';

/// Konfigurasi `ThemeData` utama Nalaro Seller Center.
abstract final class NsTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: NsColors.brandPrimary,
      onPrimary: NsColors.brandOnPrimary,
      secondary: NsColors.brandAction,
      onSecondary: NsColors.brandOnPrimary,
      surface: NsColors.surfaceCanvas,
      onSurface: NsColors.textPrimary,
      error: NsColors.statusDangerText,
      onError: Colors.white,
      outline: NsColors.borderDefault,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NsColors.surfaceCanvas,
      canvasColor: NsColors.surfaceCanvas,
      dividerColor: NsColors.borderDefault,
      splashColor: NsColors.surfacePressed,
      highlightColor: NsColors.surfacePressed,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NsColors.brandAction,
          foregroundColor: NsColors.brandOnPrimary,
          disabledBackgroundColor: NsColors.borderDefault,
          disabledForegroundColor: NsColors.textSecondary,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: NsRadius.control),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NsColors.brandAction,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NsColors.textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: NsColors.borderDefault),
          shape: const RoundedRectangleBorder(borderRadius: NsRadius.control),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NsColors.surfaceCanvas,
        foregroundColor: NsColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: NsColors.surfaceCanvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: NsTypography.titleSm,
      ),
      textTheme: const TextTheme(
        displayLarge: NsTypography.display,
        headlineMedium: NsTypography.titleLg,
        titleLarge: NsTypography.titleMd,
        titleMedium: NsTypography.titleSm,
        bodyLarge: NsTypography.bodyLg,
        bodyMedium: NsTypography.bodyMd,
        bodySmall: NsTypography.bodySm,
        labelLarge: NsTypography.label,
        labelSmall: NsTypography.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperMaxLines: 3,
        errorMaxLines: 3,
        filled: true,
        fillColor: NsColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: NsTypography.bodyMd.copyWith(color: NsColors.textMuted),
        errorStyle: NsTypography.bodySm.copyWith(
          color: NsColors.statusDangerText,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: NsRadius.control,
          borderSide: const BorderSide(color: NsColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NsRadius.control,
          borderSide: const BorderSide(color: NsColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NsRadius.control,
          borderSide: const BorderSide(color: NsColors.borderFocus, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: NsRadius.control,
          borderSide: const BorderSide(
            color: NsColors.statusDangerText,
            width: 1.3,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: NsRadius.control,
          borderSide: const BorderSide(
            color: NsColors.statusDangerText,
            width: 1.6,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NsColors.surfaceCanvas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: NsColors.surfaceCanvas,
        modalBarrierColor: NsColors.overlayScrim,
        shape: RoundedRectangleBorder(borderRadius: NsRadius.sheetTop),
        showDragHandle: false,
      ),
      cardTheme: CardThemeData(
        color: NsColors.surfaceSubtle,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: NsColors.borderDefault),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NsColors.surfaceCanvas,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: NsColors.borderDefault,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NsColors.textPrimary,
        contentTextStyle: NsTypography.bodyMd.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NsRadius.control),
      ),
    );
  }
}
