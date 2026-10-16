import 'package:flutter/widgets.dart';

/// Token durasi dan kurva animasi sesuai `desain.md` Bab 6.1 & 12.2.
abstract final class NsMotion {
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration tab = Duration(milliseconds: 190);
  static const Duration route = Duration(milliseconds: 260);
  static const Duration sheet = Duration(milliseconds: 290);
  static const Duration success = Duration(milliseconds: 220);
  static const Duration chartEntrance = Duration(milliseconds: 420);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve decelerateCurve = Curves.decelerate;

  /// Menghormati pengaturan aksesibilitas OS (`MediaQuery.disableAnimations`).
  static Duration resolve(BuildContext context, Duration normal) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduceMotion ? Duration.zero : normal;
  }

  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }
}
