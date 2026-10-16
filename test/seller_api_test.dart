import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalaro_seller_center/data/services/seller_api_service.dart';

void main() {
  test('payment review sends exact backend decision with tenant-scoped path', () async {
    late Uri target;
    late Map<String, dynamic> payload;
    final api = SellerApiService(baseUrl: 'https://example.test', httpClient: MockClient((request) async {
      target = request.url;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.headers['authorization'], 'Bearer token');
      return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
    }));
    await api.reviewOrderPayment(bearerToken: 'token', storeId: 'store-a',
      orderId: 'order-b', decision: 'verified', note: 'Dana diterima');
    expect(target.path, '/api/merchant/stores/store-a/orders/order-b/payment');
    expect(payload['decision'], 'verified');
    expect(payload['note'], 'Dana diterima');
  });
  test('overview reads tenant ID and correct 30-day summary', () async {
    final api = SellerApiService(baseUrl: 'https://example.test', httpClient: MockClient((request) async {
      expect(request.url.path, '/api/merchant/stores/shop-1/overview');
      return http.Response('{"summary":{"orders":3,"pending":1,"revenue":"250000"},"lowStock":[]}', 200);
    }));
    final data = await api.fetchOverview(bearerToken: 'token', storeId: 'shop-1');
    expect(data.ordersCount, 3);
    expect(data.pendingOrdersCount, 1);
    expect(data.verifiedRevenueIdr, 250000);
  });
}
