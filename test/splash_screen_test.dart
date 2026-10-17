import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/app/router.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/data/repositories/seller_repository.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';
import 'package:nalaro_seller_center/ui/features/auth/seller_splash_screen.dart';
import 'package:nalaro_seller_center/ui/state/seller_app_state.dart';

class PendingSessionRepository extends SellerRepository {
  final restored = Completer<UserIdentity?>();

  @override
  Future<UserIdentity?> restoreSession() => restored.future;
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

  for (final layout in [
    (size: Size(320, 568), scale: 1.0),
    (size: Size(390, 844), scale: 1.0),
    (size: Size(430, 932), scale: 1.0),
    (size: Size(844, 390), scale: 1.0),
    (size: Size(320, 568), scale: 2.0),
    (size: Size(600, 960), scale: 1.0),
  ]) {
    testWidgets('splash fits ${layout.size} at text ${layout.scale}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = layout.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: NsTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(layout.scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundaryKey, child: child!),
          ),
          home: const SellerSplashScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nalaro'), findsOneWidget);
      expect(find.text('Seller Center'), findsOneWidget);
      final headline = find.byWidgetPredicate(
        (widget) => widget is Text &&
            widget.semanticsLabel == 'Kelola toko dari genggaman tanganmu.',
      );
      expect(headline, findsOneWidget);
      expect(tester.getRect(headline).left, greaterThanOrEqualTo(24));
      expect(tester.getRect(headline).right,
          lessThanOrEqualTo(layout.size.width - 24));
      expect(tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator)).value, 0.5);
      expect(tester.getBottomRight(find.text('Menyiapkan tokomu…')).dy,
          lessThanOrEqualTo(layout.size.height - 24));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ui-qa');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/splash-${layout.size.width.toInt()}-'
          '${layout.size.height.toInt()}-${layout.scale}.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('session loading leaves splash when restore finishes',
      (tester) async {
    final repository = PendingSessionRepository();
    final state = SellerAppState(repository: repository);
    final router = createSellerRouter(state);
    final initialization = state.initializeApp();
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SellerSplashScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/launch');

    repository.restored.complete(null);
    await initialization;
    await tester.pumpAndSettle();
    expect(find.byType(SellerSplashScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Masuk ke Nalaro Seller'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    state.dispose();
  });

  testWidgets('fast session restoration keeps the opening visible briefly',
      (tester) async {
    final repository = PendingSessionRepository();
    final state = SellerAppState(repository: repository);
    final router = createSellerRouter(state);
    final initialization = state.initializeApp(
      minimumSplashDuration: const Duration(milliseconds: 900),
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    repository.restored.complete(null);
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.lifecycle, AuthLifecycleState.initializing);
    expect(find.byType(SellerSplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await initialization;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(SellerSplashScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    state.dispose();
  });

  testWidgets('slow restoration overlaps the opening duration',
      (tester) async {
    final repository = PendingSessionRepository();
    final state = SellerAppState(repository: repository);
    final router = createSellerRouter(state);
    final initialization = state.initializeApp(
      minimumSplashDuration: const Duration(milliseconds: 900),
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    expect(state.lifecycle, AuthLifecycleState.initializing);
    repository.restored.complete(null);
    await tester.pump();
    await initialization;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    state.dispose();
  });
}
