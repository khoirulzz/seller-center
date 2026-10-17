import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Branded session-loading screen. Routing remains driven by the auth lifecycle.
class SellerSplashScreen extends StatelessWidget {
  const SellerSplashScreen({super.key});

  static const _background = Color(0xFF10090D);
  static const _accent = Color(0xFFFF8BAE);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: CustomPaint(painter: _SplashBackdrop()),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final inset = constraints.maxWidth < 360 ? 24.0 : 32.0;
                        final headlineSize =
                            (constraints.maxWidth * .09).clamp(30.0, 42.0);
                        return Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: inset,
                              vertical: 32,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: SizedBox(
                                width: double.infinity,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 450),
                                  curve: Curves.easeOut,
                                  builder: (context, opacity, child) =>
                                      Opacity(opacity: opacity, child: child),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _SplashBrand(),
                                      const SizedBox(height: 36),
                                      Text.rich(
                                        const TextSpan(
                                          children: [
                                            TextSpan(text: 'Kelola toko\ndari '),
                                            TextSpan(
                                              text: 'genggaman',
                                              style: TextStyle(color: _accent),
                                            ),
                                            TextSpan(text: '\ntanganmu.'),
                                          ],
                                        ),
                                        semanticsLabel:
                                            'Kelola toko dari genggaman tanganmu.',
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: headlineSize,
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                          letterSpacing: -1.3,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Semantics(
                      label: 'Menyiapkan tokomu',
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                value: reduceMotion ? 0.5 : null,
                                color: _accent,
                                backgroundColor: Color(0xFF44212E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Menyiapkan tokomu…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                color: Color(0xFFCCBFC5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Nalaro Seller Center',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Image.asset(
            'assets/brand/nalarostore-mark.png',
            width: 48,
            height: 56,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nalaro',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Seller Center',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    height: 1.3,
                    color: Color(0xFFCCBFC5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Static vector ornament keeps startup light and scales without a bitmap.
class _SplashBackdrop extends CustomPainter {
  const _SplashBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.25, -1.1),
          radius: 1,
          colors: [Color(0xFF650C2A), Color(0x0010090D)],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.95, 1.12),
          radius: .85,
          colors: [Color(0xFFB80C3F), Color(0x0010090D)],
          stops: [0, 1],
        ).createShader(bounds),
    );
    final line = Paint()
      ..color = const Color(0x12FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 62.0;
    canvas.save();
    canvas.clipRect(bounds);
    for (double y = -12; y < size.height + step; y += step) {
      for (double x = -6; x < size.width + step; x += step) {
        final center = Offset(x, y);
        canvas.drawOval(
          Rect.fromCenter(center: center, width: step, height: 22),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: 22, height: step),
          line,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashBackdrop oldDelegate) => false;
}
