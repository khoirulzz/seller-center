import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nalaro_seller_center/app/router.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/core/widgets/ns_product_image.dart';
import 'package:nalaro_seller_center/data/repositories/seller_repository.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';
import 'package:nalaro_seller_center/ui/features/products/product_variant_dialog.dart';
import 'package:nalaro_seller_center/ui/features/home/home_screen.dart';
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
  SharedPreferences.setMockInitialValues({});
  final repository = UiRepository();
  final state = SellerAppState(repository: repository);
  await state.initializeApp();
  return (state: state, repository: repository);
}

void main() {
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
        await tester.pumpWidget(
          MaterialApp(
            theme: NsTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 920),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: HomeScreen(appState: fixture.state),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await tester.runAsync(() async {
          final directory = Directory('build/ui-qa');
          await directory.create(recursive: true);
          await File('${directory.path}/home-${width.toInt()}-$scale.png')
              .writeAsBytes(png!.buffer.asUint8List());
        });
        image.dispose();
        await tester.pumpWidget(
          MaterialApp(
            theme: NsTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 920),
                textScaler: TextScaler.linear(scale),
              ),
              child: ProductEditorScreen(appState: fixture.state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        fixture.state.dispose();
      });
    }
  }
}
