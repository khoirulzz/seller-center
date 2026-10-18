import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nalaro_seller_center/app/router.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/core/widgets/ns_product_image.dart';
import 'package:nalaro_seller_center/data/repositories/seller_repository.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';
import 'package:nalaro_seller_center/ui/features/products/product_variant_dialog.dart';
import 'package:nalaro_seller_center/ui/features/home/seller_quick_actions.dart';
import 'package:nalaro_seller_center/ui/features/engagement/engagement_screens.dart';
import 'package:nalaro_seller_center/ui/features/products/products_screens.dart';
import 'package:nalaro_seller_center/ui/state/seller_app_state.dart';

const store = MerchantStore(
  id: 'shop',
  slug: 'batik',
  name: 'Nalaro Batik',
  status: 'draft',
  description: '',
  role: 'owner',
);
const product = Product(
  id: 'p1',
  slug: 'kemeja-batik',
  name: 'Kemeja batik',
  description: '',
  priceIdr: 150000,
  category: 'Pakaian',
  primaryImageUrl: '/api/media/shop/photo.png',
  status: 'draft',
  variants: [ProductVariant(sku: 'UTAMA', optionLabel: 'Standar', stockQty: 5)],
);

class UiRepository extends SellerRepository {
  int saves = 0, imageReads = 0;
  bool delayOrders = false;
  final queries =
      <String, Completer<({List<OrderModel> orders, bool hasMore})>>{};
  @override
  Future<({List<OrderModel> orders, bool hasMore})> fetchOrders({
    required String storeId,
    String status = 'all',
    String query = '',
    int page = 1,
    String? fromDate,
    String? toDate,
  }) async {
    if (!delayOrders) return (orders: <OrderModel>[], hasMore: false);
    final result = Completer<({List<OrderModel> orders, bool hasMore})>();
    queries[query] = result;
    return result.future;
  }

  @override
  Future<StoreSettings> fetchSettings({
    required String storeId,
    required MerchantStore store,
  }) async =>
      StoreSettings.fromJson({
        'store_name': store.name,
        'contact_phone': '081234567890',
        'pickup_address': 'Jalan Batik 1',
        'bank_details': 'BCA 123',
        'policies': 'Pengiriman dilakukan setiap hari kerja.',
        'accent': '#FF154F',
      });
  Completer<Product>? saving;
  @override
  Future<UserIdentity?> restoreSession() async => const UserIdentity(
        id: 'user',
        email: 'seller@example.test',
        verified: true,
        admin: false,
      );
  @override
  Future<List<MerchantStore>> fetchStores() async => [store];
  @override
  Future<StoreOverview> fetchOverview(String storeId) async => StoreOverview(
        ordersCount: 0,
        verifiedRevenueIdr: 0,
        pendingOrdersCount: 0,
        lowStockAlerts: [],
        fetchedAt: DateTime.now(),
      );
  @override
  Future<List<Product>> fetchProducts(String storeId) async => [product];
  @override
  Future<List<InventoryMovement>> fetchInventoryLedger(String storeId) async =>
      [];
  @override
  Future<Product> saveProduct({
    required String storeId,
    required Product product,
    required bool isUpdate,
    required StoreRole role,
  }) async {
    saves++;
    return saving == null ? product : await saving!.future;
  }

  @override
  Future<Uint8List> fetchMediaBytes(String url, {bool refresh = false}) async {
    imageReads++;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=',
    );
  }
}

Future<({SellerAppState state, UiRepository repository})> setup() async {
  SharedPreferences.setMockInitialValues({'ns_feature_guide_v2_user': true});
  final repository = UiRepository();
  final state = SellerAppState(repository: repository);
  await state.initializeApp();
  return (state: state, repository: repository);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      (name: 'Manrope', file: 'Manrope'),
      (name: 'DM Sans', file: 'DMSans'),
    ]) {
      await (FontLoader(
        font.name,
      )..addFont(rootBundle.load('assets/fonts/${font.file}.ttf')))
          .load();
    }
  });
  testWidgets(
    'variant dialogs own controllers through dismissal and enforce reserved stock',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NsTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<ProductVariant>(
                  context: context,
                  builder: (_) => const ProductVariantDialog(
                    variant: ProductVariant(
                      sku: 'A',
                      optionLabel: 'Biru',
                      stockQty: 4,
                      reservedQty: 3,
                    ),
                    otherSkus: {'b'},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(2), '2');
        await tester.tap(find.text('Terapkan'));
        await tester.pumpAndSettle();
        expect(find.text('Stok minimal 3.'), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Android back returns from tab, protects editor draft, and confirms app exit',
    (tester) async {
      final fixture = await setup();
      final router = createSellerRouter(fixture.state);
      await tester.pumpWidget(
        MaterialApp.router(theme: NsTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      router.go('/produk');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/beranda');
      router.go('/produk');
      await tester.pumpAndSettle();
      router.push('/produk/editor');
      await tester.pumpAndSettle();
      expect(find.text('Tambah produk'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Batik baru');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Simpan perubahan dulu?'), findsOneWidget);
      await tester.tap(find.text('Tetap edit'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah produk'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buang'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/produk');
      expect(fixture.state.hasUnsavedFormDraft, false);
      final draft = await fixture.repository.drafts.loadDraft(
        userId: 'user',
        storeId: 'shop',
        resourceType: 'product',
        resourceId: 'new',
      );
      expect(draft, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Tutup aplikasi?'), findsOneWidget);
      await tester.tap(find.text('Tetap di sini'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      fixture.state.dispose();
    },
  );
  testWidgets(
    'save editor only submits once and closes without disposal exceptions',
    (tester) async {
      final fixture = await setup();
      final router = createSellerRouter(fixture.state);
      await tester.pumpWidget(
        MaterialApp.router(theme: NsTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      router.go('/produk');
      await tester.pumpAndSettle();
      router.push('/produk/editor?id=p1');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Batik diperbarui',
      );
      await tester.pump();
      fixture.repository.saving = Completer<Product>();
      await tester.tap(find.text('Simpan produk'));
      await tester.pump();
      expect(fixture.repository.saves, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Edit produk'), findsOneWidget);
      fixture.repository.saving!.complete(product);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/produk');
      expect(fixture.repository.saves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      fixture.state.dispose();
    },
  );
  testWidgets('product image loads via repository and opens full preview', (
    tester,
  ) async {
    final repository = UiRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: NsProductImage(
              repository: repository,
              url: '/api/media/shop/private.png',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.imageReads, 1);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'settings back guard preserves edits until discard is confirmed',
    (tester) async {
      final fixture = await setup();
      final router = createSellerRouter(fixture.state);
      await tester.pumpWidget(
        MaterialApp.router(theme: NsTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      router.go('/toko');
      await tester.pumpAndSettle();
      router.push('/toko/settings');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Nama toko baru',
      );
      await tester.pump();
      expect(fixture.state.hasUnsavedFormDraft, true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Perubahan belum disimpan'), findsOneWidget);
      await tester.tap(find.text('Tetap edit'));
      await tester.pumpAndSettle();
      expect(find.text('Nama toko baru'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buang perubahan'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/toko');
      expect(fixture.state.hasUnsavedFormDraft, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      fixture.state.dispose();
    },
  );
  testWidgets('slow older search cannot overwrite newer order results', (
    tester,
  ) async {
    final fixture = await setup();
    fixture.repository.delayOrders = true;
    final router = createSellerRouter(fixture.state);
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    router.go('/pesanan');
    await tester.pump();
    fixture.repository.queries['']!.complete((
      orders: <OrderModel>[],
      hasMore: false,
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'lama');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'baru');
    await tester.pump(const Duration(milliseconds: 350));
    fixture.repository.queries['baru']!.complete((
      orders: [
        OrderModel.fromJson({
          'id': 'new',
          'order_number': 'BARU',
          'customer_name': 'Pembeli baru',
        }),
      ],
      hasMore: false,
    ));
    await tester.pumpAndSettle();
    expect(find.text('BARU'), findsOneWidget);
    fixture.repository.queries['lama']!.complete((
      orders: [
        OrderModel.fromJson({'id': 'old', 'order_number': 'LAMA'}),
      ],
      hasMore: false,
    ));
    await tester.pumpAndSettle();
    expect(find.text('BARU'), findsOneWidget);
    expect(find.text('LAMA'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    fixture.state.dispose();
  });
  testWidgets('seller header paints behind status bar and opens chat', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 820);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await setup();
    final router = createSellerRouter(fixture.state);
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(const Key('seller-header-surface'));
    expect(header, findsOneWidget);
    final surface = tester.widget<ColoredBox>(header);
    expect(surface.color, const Color(0xFFD30C3F));
    expect(
      find.descendant(of: header, matching: find.byType(SafeArea)),
      findsOneWidget,
    );
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(
        of: header,
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ).first,
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(find.byKey(const Key('seller-notification-action')), findsOneWidget);
    expect(find.byKey(const Key('seller-chat-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('seller-chat-action')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerChatScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    fixture.state.dispose();
  });

  testWidgets('home shortcuts retain sales summary and navigate to editor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 920);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await setup();
    final router = createSellerRouter(fixture.state);
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seller-quick-actions')), findsOneWidget);
    expect(find.text('Ringkasan penjualan'), findsOneWidget);
    expect(find.byKey(const Key('seller-shortcut-plus')), findsOneWidget);
    await tester.tap(find.byKey(const Key('seller-shortcut-plus')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    fixture.state.dispose();
  });

  testWidgets('home has no redundant title; store tab owns shop name and email', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 920);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await setup();
    final router = createSellerRouter(fixture.state);
    await tester.pumpWidget(
      MaterialApp.router(theme: NsTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pantau penjualan dan pekerjaan tokomu.'), findsNothing);
    expect(find.textContaining('Masuk sebagai'), findsNothing);
    expect(find.byKey(const Key('seller-quick-actions')), findsOneWidget);
    expect(find.text('Stok'), findsOneWidget);
    expect(find.text('Ringkasan penjualan'), findsOneWidget);
    router.go('/toko');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-hub-shop-name')), findsOneWidget);
    expect(find.text('Nalaro Batik'), findsWidgets);
    expect(
      find.byKey(const Key('store-hub-account-email')),
      findsOneWidget,
    );
    expect(find.text('seller@example.test'), findsOneWidget);
    expect(find.text('Masuk sebagai seller@example.test'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    fixture.state.dispose();
  });

  testWidgets('quick actions respect owner, manager and fulfillment roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SellerQuickActions(role: StoreRole.owner)),
      ),
    );
    expect(find.byKey(const Key('seller-shortcut-credit-card')), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SellerQuickActions(role: StoreRole.manager)),
      ),
    );
    expect(find.byKey(const Key('seller-shortcut-plus')), findsOneWidget);
    expect(find.byKey(const Key('seller-shortcut-credit-card')), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SellerQuickActions(role: StoreRole.fulfillment)),
      ),
    );
    expect(find.byKey(const Key('seller-quick-actions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('home and editor layout at $width dp / text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 920);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await setup();
        final key = GlobalKey();
        final router = createSellerRouter(fixture.state);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: NsTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: key, child: child!),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Future<void> capture(String screen) async {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/ui-qa');
            await directory.create(recursive: true);
            await File('${directory.path}/$screen-${width.toInt()}-$scale.png')
                .writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('home');
        router.go('/produk');
        await tester.pumpAndSettle();
        router.push('/produk/editor');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('editor');
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('editor-scrolled');
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        fixture.state.dispose();
      });
    }
  }
}
