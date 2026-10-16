import 'package:flutter/services.dart';

/// Kebijakan umpan balik taktil (haptic) sesuai `desain.md` Bab 6.3.
/// Digunakan hemat untuk pindah tab, pilih toko, mulai drag reorder, dan aksi sukses.
abstract final class NsHaptics {
  static bool enabled = true;

  static Future<void> selection() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> lightImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
