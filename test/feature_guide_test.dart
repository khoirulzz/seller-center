import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nalaro_seller_center/app/router.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/data/services/feature_guide_service.dart';
import 'package:nalaro_seller_center/ui/features/onboarding/seller_feature_guide.dart';

import 'ui_regression_test.dart' as fixtures;

Widget harness({
  String? userId = 'seller-a',
  bool eligible = true,
  bool analytics = true,
  VoidCallback? onStoreTap,
}) => MaterialApp(
  theme: NsTheme.light,
  home: SellerFeatureGuide(
    userId: userId,
    eligible: eligible,
    showAnalytics: analytics,
    builder: (context, anchors) => Scaffold(
      appBar: AppBar(
        title: TextButton(
          key: anchors.store,
          onPressed: onStoreTap,
          child: const Text('Toko contoh'),
        ),
      ),
      body: Center(
        child: TextButton(
          onPressed: SellerGuideScope.maybeOf(context)?.replay,
          child: const Text('Buka panduan'),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: List.generate(5, (index) => NavigationDestination(
          key: anchors.tabs[index],
          icon: const Icon(Icons.store_outlined),
          label: ['Beranda', 'Pesanan', 'Produk', 'Analitik', 'Toko'][index],
        )),
      ),
    ),
  ),
);

Future<void> next(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lanjut'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lanjut'));
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-qa');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final font in [
      ('Manrope', 'assets/fonts/Manrope.ttf'),
      ('DM Sans', 'assets/fonts/DMSans.ttf'),
    ]) {
      final loader = FontLoader(font.$1)
        ..addFont(rootBundle.load(font.$2));
      await loader.load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first visit spotlights controls, blocks taps and remembers skip',
      (tester) async {
    var storeTaps = 0;
    await tester.pumpWidget(harness(onStoreTap: () => storeTaps++));
    await tester.pumpAndSettle();
    expect(find.text('Kenali ruang tokomu'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('Toko contoh')));
    await tester.pumpAndSettle();
    expect(storeTaps, 0);
    await next(tester);
    expect(find.text('Mulai dari Beranda'), findsOneWidget);
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Kenali ruang tokomu'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    expect(await FeatureGuideService().hasSeen('seller-a'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    await tester.tap(find.text('Buka panduan'));
    await tester.pumpAndSettle();
    expect(find.text('Kenali ruang tokomu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all steps can finish and permissions omit analytics',
      (tester) async {
    await tester.pumpWidget(harness(analytics: false));
    await tester.pumpAndSettle();
    expect(find.text('KENALI FITUR  •  1/5'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await next(tester);
      expect(find.text('Baca perkembangan penjualan'), findsNothing);
    }
    expect(find.text('Pengaturan ada di Toko'), findsOneWidget);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    expect(await FeatureGuideService().hasSeen('seller-a'), isTrue);
  });

  testWidgets('acknowledgement belongs to each account', (tester) async {
    await FeatureGuideService().markSeen('seller-a');
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    await tester.pumpWidget(harness(userId: 'seller-b'));
    await tester.pumpAndSettle();
    expect(find.text('Kenali ruang tokomu'), findsOneWidget);
    expect(await FeatureGuideService().hasSeen('seller-b'), isFalse);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(await FeatureGuideService().hasSeen('seller-b'), isTrue);
  });

  testWidgets('auth and editor pages do not start a guide', (tester) async {
    await tester.pumpWidget(harness(eligible: false));
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    await tester.pumpWidget(harness(eligible: true));
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsOneWidget);
    await tester.pumpWidget(harness(userId: null, eligible: false));
    await tester.pumpAndSettle();
    expect(find.byType(SellerGuideOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (size: Size(320, 568), scale: 1.0),
    (size: Size(390, 844), scale: 1.0),
    (size: Size(320, 568), scale: 2.0),
    (size: Size(600, 960), scale: 1.0),
    (size: Size(844, 390), scale: 1.0),
  ]) {
    testWidgets('live shell guide fits ${layout.size} / ${layout.scale}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = layout.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await fixtures.setup();
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(FeatureGuideService.keyFor('user'));
      final router = createSellerRouter(fixture.state);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp.router(
          theme: NsTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(layout.scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: key, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kenali ruang tokomu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefix = 'guide-${layout.size.width.toInt()}-'
          '${layout.size.height.toInt()}-${layout.scale}';
      await capture(tester, key, '$prefix-store');
      for (var i = 0; i < 5; i++) {
        await next(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, key, '$prefix-step-${i + 2}');
      }
      await tester.ensureVisible(find.text('Selesai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      expect(find.byType(SellerGuideOverlay), findsNothing);
      expect(await FeatureGuideService().hasSeen('user'), isTrue);
      router.go('/toko');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Panduan fitur'), 300);
      await tester.tap(find.text('Panduan fitur'));
      await tester.pumpAndSettle();
      expect(find.text('Kenali ruang tokomu'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      fixture.state.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
