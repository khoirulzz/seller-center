import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nalaro_seller_center/app/app.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/data/services/app_update_service.dart';
import 'package:nalaro_seller_center/ui/features/updates/app_update_screen.dart';
import 'package:nalaro_seller_center/ui/state/app_update_controller.dart';
import 'package:nalaro_seller_center/ui/state/seller_app_state.dart';

class LoggedOutAppState extends SellerAppState {
  @override
  AuthLifecycleState get lifecycle => AuthLifecycleState.unauthenticated;
}

void backgroundAndResume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

class FakeUpdateService implements AppUpdateService {
  @override
  bool isAvailable = true;
  int checks = 0, downloads = 0, reads = 0;
  int? patch = 2;
  AppPatchStatus result = AppPatchStatus.current;
  Completer<AppPatchStatus>? pendingCheck;
  Completer<void>? pendingDownload;
  bool failCheck = false, failDownload = false;

  @override
  Future<int?> currentPatch() async {
    reads++;
    return patch;
  }

  @override
  Future<AppPatchStatus> check() async {
    checks++;
    if (failCheck) throw StateError('Private SDK/network diagnostic');
    return pendingCheck == null ? result : await pendingCheck!.future;
  }

  @override
  Future<void> download() async {
    downloads++;
    if (failDownload) throw StateError('Private download diagnostic');
    if (pendingDownload != null) await pendingDownload!.future;
  }
}

void main() {
  testWidgets(
      'login renders before OTA completes and resume checks are throttled',
      (tester) async {
    var now = DateTime(2026, 10, 17, 12);
    final service = FakeUpdateService()
      ..pendingCheck = Completer<AppPatchStatus>();
    final updates = AppUpdateController(service: service, now: () => now);
    final state = LoggedOutAppState();
    addTearDown(updates.dispose);
    addTearDown(state.dispose);
    await tester.pumpWidget(
        NalaroSellerApp(appState: state, updateController: updates));
    await tester.pump();
    expect(find.text('Masuk ke Nalaro Seller'), findsOneWidget);
    expect(service.checks, 1);
    backgroundAndResume(tester);
    await tester.pump();
    expect(service.checks, 1);
    service.pendingCheck!.complete(AppPatchStatus.current);
    await tester.pump();
    now = now.add(const Duration(minutes: 16));
    backgroundAndResume(tester);
    await tester.pump();
    expect(service.checks, 2);
    expect(find.text('Masuk ke Nalaro Seller'), findsOneWidget);
    // Maintenance is accessible without an account/store, and can return to login.
    GoRouter.of(tester.element(find.text('Masuk ke Nalaro Seller')))
        .push('/app-update');
    await tester.pumpAndSettle();
    expect(find.text('Pembaruan aplikasi'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Nalaro Seller'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('ordinary Flutter APK skips network and never reports up to date',
      () async {
    final service = FakeUpdateService()..isAvailable = false;
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.unavailable);
    expect(service.checks, 0);
    expect(service.reads, 0);
    expect(updates.lastChecked, isNull);
  });

  test('reads current patch and confirms a successful check', () async {
    final updates = AppUpdateController(service: FakeUpdateService());
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.current);
    expect(updates.currentPatch, 2);
    expect(updates.lastChecked, isNotNull);
  });

  test('a synchronous state listener cannot start a second check', () async {
    final service = FakeUpdateService();
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    updates.addListener(() {
      if (updates.phase == AppUpdatePhase.checking) {
        unawaited(updates.checkForUpdates(userInitiated: true));
      }
    });
    await updates.checkForUpdates();
    expect(service.checks, 1);
  });

  test('concurrent resume and repeated taps share one check/download',
      () async {
    final service = FakeUpdateService()
      ..pendingCheck = Completer<AppPatchStatus>()
      ..pendingDownload = Completer<void>();
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    final phases = <AppUpdatePhase>[];
    updates.addListener(() => phases.add(updates.phase));
    final first = updates.checkForUpdates();
    final second = updates.checkForUpdates(userInitiated: true);
    await Future<void>.delayed(Duration.zero);
    expect(service.checks, 1);
    service.pendingCheck!.complete(AppPatchStatus.available);
    await Future<void>.delayed(Duration.zero);
    expect(updates.phase, AppUpdatePhase.downloading);
    final third = updates.checkForUpdates(userInitiated: true);
    expect(service.downloads, 1);
    service.pendingDownload!.complete();
    await Future.wait([first, second, third]);
    expect(phases, [
      AppUpdatePhase.checking,
      AppUpdatePhase.downloading,
      AppUpdatePhase.restartRequired,
    ]);
    expect(updates.currentPatch, 2); // Downloaded is not yet running.
    await updates.checkForUpdates(userInitiated: true);
    expect(service.checks, 1);
    expect(service.downloads, 1);
  });

  test('automatic checks are throttled; explicit retry bypasses interval',
      () async {
    var now = DateTime(2026, 10, 17, 12);
    final service = FakeUpdateService();
    final updates = AppUpdateController(service: service, now: () => now);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    now = now.add(const Duration(minutes: 10));
    await updates.checkForUpdates();
    expect(service.checks, 1);
    await updates.checkForUpdates(userInitiated: true);
    expect(service.checks, 2);
    now = now.add(const Duration(minutes: 16));
    await updates.checkForUpdates();
    expect(service.checks, 3);
  });

  test('network failure permits retry and does not claim a successful check',
      () async {
    final service = FakeUpdateService()..failCheck = true;
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.failed);
    expect(updates.lastChecked, isNull);
    await updates.checkForUpdates();
    expect(service.checks, 1);
    service.failCheck = false;
    await updates.checkForUpdates(userInitiated: true);
    expect(updates.phase, AppUpdatePhase.current);
  });

  test('a failed download can be retried without showing ready early',
      () async {
    final service = FakeUpdateService()
      ..result = AppPatchStatus.available
      ..failDownload = true;
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.failed);
    service.failDownload = false;
    await updates.checkForUpdates(userInitiated: true);
    expect(updates.phase, AppUpdatePhase.restartRequired);
    expect(service.downloads, 2);
  });

  test('pending patch or rollback requires restart without downloading twice',
      () async {
    final service = FakeUpdateService()
      ..result = AppPatchStatus.restartRequired;
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.restartRequired);
    expect(service.downloads, 0);
  });

  test('runtime status unavailable never claims current', () async {
    final service = FakeUpdateService()..result = AppPatchStatus.unavailable;
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await updates.checkForUpdates();
    expect(updates.phase, AppUpdatePhase.unavailable);
  });

  test('disposing during check stops notifications and subsequent download',
      () async {
    final service = FakeUpdateService()
      ..pendingCheck = Completer<AppPatchStatus>();
    final updates = AppUpdateController(service: service);
    final operation = updates.checkForUpdates();
    await Future<void>.delayed(Duration.zero);
    updates.dispose();
    service.pendingCheck!.complete(AppPatchStatus.available);
    await operation;
    expect(service.downloads, 0);
  });

  test('disposing during download safely consumes a late failure', () async {
    final service = FakeUpdateService()
      ..result = AppPatchStatus.available
      ..pendingDownload = Completer<void>();
    final updates = AppUpdateController(service: service);
    final operation = updates.checkForUpdates();
    await Future<void>.delayed(Duration.zero);
    updates.dispose();
    service.pendingDownload!.completeError(StateError('Network failed'));
    await operation;
  });

  for (final status in AppPatchStatus.values) {
    testWidgets('update screen is readable at 320dp for ${status.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final updates =
          AppUpdateController(service: FakeUpdateService()..result = status);
      addTearDown(updates.dispose);
      await updates.checkForUpdates();
      await tester.pumpWidget(MaterialApp(
        theme: NsTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: AppUpdateScope(controller: updates, child: child!),
        ),
        home: const AppUpdateScreen(),
      ));
      expect(find.text('Pembaruan aplikasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (status == AppPatchStatus.restartRequired ||
          status == AppPatchStatus.available) {
        expect(find.text('Periksa pembaruan'), findsNothing);
        expect(find.text('Pembaruan siap digunakan'), findsOneWidget);
      }
    });
  }

  testWidgets('manual check disables duplicate taps while downloading',
      (tester) async {
    final service = FakeUpdateService()
      ..result = AppPatchStatus.available
      ..pendingDownload = Completer<void>();
    final updates = AppUpdateController(service: service);
    addTearDown(updates.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          AppUpdateScope(controller: updates, child: child!),
      home: const AppUpdateScreen(),
    ));
    await tester.tap(find.text('Periksa pembaruan'));
    await tester.pump();
    expect(find.text('Mengunduh pembaruan'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(service.downloads, 1);
    service.pendingDownload!.complete();
    await tester.pump();
    expect(find.text('Pembaruan siap digunakan'), findsOneWidget);
  });

  testWidgets('ready notice preserves in-progress form contents',
      (tester) async {
    final updates = AppUpdateController(
      service: FakeUpdateService()..result = AppPatchStatus.available,
    );
    final draft = TextEditingController(text: 'Draft produk belum disimpan');
    addTearDown(updates.dispose);
    addTearDown(draft.dispose);
    await tester.pumpWidget(MaterialApp(
      home: AppUpdateScope(
        controller: updates,
        child: Scaffold(
            body: Column(children: [
          TextField(controller: draft),
          const AppUpdateNotice(),
        ])),
      ),
    ));
    await updates.checkForUpdates();
    await tester.pump();
    expect(find.text('Pembaruan siap untuk pembukaan aplikasi berikutnya.'),
        findsOneWidget);
    expect(draft.text, 'Draft produk belum disimpan');
  });
}
