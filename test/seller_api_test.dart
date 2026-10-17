import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalaro_seller_center/data/services/seller_api_service.dart';

void main() {
  test(
    'payment review sends exact backend decision with tenant-scoped path',
    () async {
      late Uri target;
      late Map<String, dynamic> payload;
      final api = SellerApiService(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          target = request.url;
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response(
            '{"ok":true}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await api.reviewOrderPayment(
        bearerToken: 'token',
        storeId: 'store-a',
        orderId: 'order-b',
        decision: 'verified',
        note: 'Dana diterima',
      );
      expect(
        target.path,
        '/api/merchant/stores/store-a/orders/order-b/payment',
      );
      expect(payload['decision'], 'verified');
      expect(payload['note'], 'Dana diterima');
    },
  );
  test('subscription replacement requires explicit consent in the request', () async {
    final sent = <Map<String, dynamic>>[];
    final api = SellerApiService(baseUrl: 'https://example.test',httpClient: MockClient((request) async {
      expect(request.url.path, '/api/merchant/stores/shop-1/billing');
      sent.add(jsonDecode(request.body) as Map<String,dynamic>);
      return http.Response('{"ok":true}',201);
    }));
    await api.selectSubscriptionPlan(bearerToken:'token',storeId:'shop-1',planPriceId:'price-1');
    await api.selectSubscriptionPlan(bearerToken:'token',storeId:'shop-1',planPriceId:'price-2',confirmReplace:true);
    expect(sent[0]['confirm_replace'],false);
    expect(sent[1]['confirm_replace'],true);
  });
  test(
    'billing keeps active and pending package identities separate',
    () async {
      final api = SellerApiService(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/public/plans')
            return http.Response('{"plans":[]}', 200);
          return http.Response(
            jsonEncode({
              'accessAvailable': true,
              'currentSubscriptionId': 'current-1',
              'entitlements': [
                {
                  'feature_code': 'products',
                  'allowed': true,
                  'limit_value': '0',
                },
              ],
              'pilotUntil': null,
              'subscriptions': [
                {
                  'id': 'pending-2',
                  'name': 'Paket Baru',
                  'status': 'pending',
                  'plan_price_id': 'price-2',
                },
                {
                  'id': 'current-1',
                  'name': 'Paket Aktif',
                  'status': 'active',
                  'plan_price_id': 'price-1',
                },
              ],
              'invoices': <Object?>[],
              'usage': <Object?>[],
              'paymentInstructions': 'Bank Uji',
            }),
            200,
          );
        }),
      );
      final data = await api.fetchBilling(
        bearerToken: 'token',
        storeId: 'shop-1',
      );
      expect(data.accessAvailable, true);
      expect(data.currentSubscriptionId, 'current-1');
      expect(data.entitlements.single.limitValue, 0);
      expect(data.subscriptions.first.status, 'pending');
      expect(data.subscriptions.last.planPriceId, 'price-1');
      expect(data.pilotUntil, isNull);
    },
  );
  test('overview reads tenant ID and correct 30-day summary', () async {
    final api = SellerApiService(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/merchant/stores/shop-1/overview');
        return http.Response(
          '{"summary":{"orders":3,"pending":1,"revenue":"250000"},"lowStock":[]}',
          200,
        );
      }),
    );
    final data = await api.fetchOverview(
      bearerToken: 'token',
      storeId: 'shop-1',
    );
    expect(data.ordersCount, 3);
    expect(data.pendingOrdersCount, 1);
    expect(data.verifiedRevenueIdr, 250000);
  });
}
