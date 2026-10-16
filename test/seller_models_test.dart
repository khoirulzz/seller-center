import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';

void main() {
  test('missing merchant role never grants owner permissions', () {
    final store = MerchantStore.fromJson({'id': 's', 'name': 'Toko'});
    expect(store.storeRole, StoreRole.unknown);
    expect(store.storeRole.canManageCatalog, false);
    expect(store.storeRole.canVerifyPayment, false);
  });

  group('Tenant roles', () {
    test('owner and manager can verify payments, fulfillment cannot', () {
      expect(StoreRole.owner.canVerifyPayment, true);
      expect(StoreRole.manager.canVerifyPayment, true);
      expect(StoreRole.fulfillment.canVerifyPayment, false);
      expect(StoreRole.fulfillment.canManageCatalog, false);
    });
    test('unknown roles must not grant owner privileges', () {
      expect(StoreRole.fromString('unknown').canChooseBillingPlan, false);
      expect(StoreRole.fromString(null).canManageSettings, false);
      expect(StoreRole.fromString('unrecognized').canProcessFulfillment, false);
    });
  });
  group('Orders state machine', () {
    OrderModel order({
      String payment = 'paid',
      String shipping = 'pickup',
      String fulfillment = 'unfulfilled',
    }) {
      return OrderModel(
        id: '1',
        orderNumber: 'O-1',
        customerName: 'Buyer',
        totalIdr: 10000,
        orderStatus: payment == 'paid' ? 'confirmed' : 'pending',
        paymentStatus: payment,
        fulfillmentStatus: fulfillment,
        shippingMethod: shipping,
        createdAt: '2026-10-17',
      );
    }

    test('unpaid cannot be fulfilled', () {
      expect(
        order(payment: 'unpaid').allowedNextFulfillmentStates(StoreRole.owner),
        isEmpty,
      );
    });
    test('pickup and shipping have distinct transitions', () {
      expect(
        order().allowedNextFulfillmentStates(StoreRole.owner),
        contains('pickup_ready'),
      );
      expect(
        order(shipping: 'delivery')
            .allowedNextFulfillmentStates(StoreRole.owner),
        ['packing'],
      );
      expect(
        order(
          shipping: 'delivery',
          fulfillment: 'shipped',
        ).allowedNextFulfillmentStates(StoreRole.owner),
        ['delivered'],
      );
    });
    test('cannot verify paid order a second time', () {
      expect(order().canVerifyPayment(StoreRole.owner), false);
    });
    test('fulfillment staff cannot cancel order', () {
      expect(order(payment: 'unpaid').canCancel(StoreRole.fulfillment), false);
    });
  });
  test('product reserved stock and gallery payload stay consistent', () {
    const v = ProductVariant(
      sku: 'BATIK-M',
      optionLabel: 'M',
      stockQty: 7,
      reservedQty: 3,
    );
    const p = Product(
      id: '',
      slug: 'batik-modern',
      name: 'Batik modern',
      description: '',
      priceIdr: 150000,
      category: 'Batik',
      status: 'active',
      variants: [v],
      gallery: [GalleryPhoto(url: '/api/media/123/test.jpg')],
    );
    expect(p.totalAvailableStock, 4);
    expect(p.totalReservedStock, 3);
    expect(p.toPayloadJson()['gallery'], isNotEmpty);
    expect((p.toPayloadJson()['variants'] as List).single['sku'], 'BATIK-M');
  });
  test('variant price overrides parse Postgres bigint strings', () {
    final variant = ProductVariant.fromJson({
      'sku': 'BATIK-L',
      'option_label': 'L',
      'stock_qty': 5,
      'price_override_idr': '175000',
    });
    expect(variant.priceOverrideIdr, 175000);
  });
  test('publishing requires valid pickup address and payment', () {
    const settings = StoreSettings(
      contactPhone: '0812345678',
      pickupAddress: '',
      shippingFeeIdr: 0,
      pickupEnabled: true,
      deliveryEnabled: false,
      bankDetails: '',
      policies: 'Pengiriman dan pengembalian diatur toko',
      accent: '#171715',
      heroTitle: '',
      openingHours: '',
      lowStockThreshold: 5,
    );
    expect(settings.hasPaymentConfigured, false);
    expect(settings.hasValidPickupAddress, false);
  });
}
