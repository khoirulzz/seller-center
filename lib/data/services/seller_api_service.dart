import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/models/seller_models.dart';

/// Klien HTTP untuk Cloudflare Worker Nalaro Store (`PRD` Bab 11.3 & 12.1).
/// Selalu menyertakan `Authorization: Bearer <Firebase ID Token>` dan header origin yang aman.
class SellerApiService {
  SellerApiService({
    http.Client? httpClient,
    this.baseUrl = AppConfig.defaultApiBaseUrl,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;

  Uri resolveMediaUri(String source) {
    final base = Uri.parse(baseUrl);
    final uri = base.resolve(source.trim());
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw const ApiException(
        message: 'Link foto tidak valid.',
        statusCode: 400,
      );
    }
    return uri;
  }

  bool isPrivateMedia(Uri uri) =>
      uri.origin == Uri.parse(baseUrl).origin &&
      uri.path.startsWith('/api/media/');

  Future<Uint8List> fetchMediaBytes({
    required Uri uri,
    String? bearerToken,
  }) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw const ApiException(
        message: 'Link foto tidak valid.',
        statusCode: 400,
      );
    }
    final request = http.Request('GET', uri);
    // Never forward a token through a redirect or to an external image host.
    request.followRedirects = false;
    request.headers['Accept'] = 'image/*';
    if (isPrivateMedia(uri) && bearerToken != null)
      request.headers['Authorization'] = 'Bearer $bearerToken';
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw ApiException(
        message: 'Foto belum dapat dimuat. Ketuk untuk mencoba lagi.',
        statusCode: response.statusCode,
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.add(chunk);
      if (bytes.length > AppConfig.maxMediaUploadBytes) {
        throw const ApiException(
          message: 'Ukuran foto melebihi 5 MB.',
          statusCode: 413,
        );
      }
    }
    return bytes.takeBytes();
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final resolved = base.replace(
      path: path,
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    return resolved;
  }

  Map<String, String> _headers({
    String? bearerToken,
    String contentType = 'application/json',
    String? idempotencyKey,
  }) {
    return {
      'Accept': 'application/json',
      'Content-Type': contentType,
      'Origin': baseUrl,
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'X-Idempotency-Key': idempotencyKey,
    };
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) async {
    final uri = _buildUri(path, query);
    final headers = _headers(
      bearerToken: bearerToken,
      idempotencyKey: idempotencyKey,
    );
    final encodedBody = body != null ? jsonEncode(body) : null;

    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
        case 'POST':
          response = await _http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
        case 'PUT':
          response = await _http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
        case 'DELETE':
          response = await _http
              .delete(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
        default:
          throw ApiException(message: 'Metode HTTP $method tidak didukung.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(
        message: 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.',
        isOffline: true,
      );
    }

    Map<String, dynamic> decoded = const {};
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(
          message: 'Respons server belum dapat dibaca.',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errText = (decoded['error'] ?? 'Layanan belum tersedia.')
          .toString();
      throw ApiException(
        message: errText,
        statusCode: response.statusCode,
        machineCode: decoded['code']?.toString(),
      );
    }

    return decoded;
  }

  Future<UserIdentity?> fetchCurrentUser(String bearerToken) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/auth/me',
      bearerToken: bearerToken,
    );
    final userMap = json['user'];
    if (userMap is Map<String, dynamic>) {
      return UserIdentity.fromJson(userMap);
    }
    return null;
  }
  Future<Map<String,dynamic>> workspaceResource({required String bearerToken,required String storeId,required String resource,String method='GET',Object? body,Map<String,String>? query}) => _requestJson(method:method,path:'/api/merchant/stores/$storeId/$resource',bearerToken:bearerToken,body:body,query:query);

  Future<List<MerchantStore>> fetchStores(String bearerToken) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores',
      bearerToken: bearerToken,
    );
    final raw = (json['stores'] as List<dynamic>?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MerchantStore.fromJson)
        .toList();
  }

  Future<bool> checkSlugAvailability({
    required String bearerToken,
    required String slug,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/slug',
      bearerToken: bearerToken,
      query: {'slug': slug},
    );
    return json['available'] == true;
  }

  Future<String> createStore({
    required String bearerToken,
    required String name,
    required String slug,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores',
      bearerToken: bearerToken,
      body: {'name': name.trim(), 'slug': slug.trim()},
    );
    return (json['id'] ?? '').toString();
  }

  Future<StoreOverview> fetchOverview({
    required String bearerToken,
    required String storeId,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/overview',
      bearerToken: bearerToken,
    );
    return StoreOverview.fromJson(json);
  }

  Future<({List<OrderModel> orders, bool hasMore})> fetchOrders({
    required String bearerToken,
    required String storeId,
    String status = 'all',
    String query = '',
    int page = 1,
    String? fromDate,
    String? toDate,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/orders',
      bearerToken: bearerToken,
      query: {
        'status': status,
        'q': query,
        'page': '$page',
        if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      },
    );
    final raw = (json['orders'] as List<dynamic>?) ?? const [];
    return (
      orders: raw
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList(),
      hasMore: json['hasMore'] == true,
    );
  }

  Future<OrderDetailBundle> fetchOrderDetail({
    required String bearerToken,
    required String storeId,
    required String orderId,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/orders/$orderId',
      bearerToken: bearerToken,
    );
    return OrderDetailBundle.fromJson(json);
  }

  Future<void> reviewOrderPayment({
    required String bearerToken,
    required String storeId,
    required String orderId,
    required String decision,
    String note = '',
    String? idempotencyKey,
  }) async {
    await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores/$storeId/orders/$orderId/payment',
      bearerToken: bearerToken,
      idempotencyKey: idempotencyKey,
      body: {'decision': decision, 'note': note.trim()},
    );
  }

  Future<void> updateOrderFulfillment({
    required String bearerToken,
    required String storeId,
    required String orderId,
    required String status,
    String reference = '',
    String? idempotencyKey,
  }) async {
    await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores/$storeId/orders/$orderId/fulfillment',
      bearerToken: bearerToken,
      idempotencyKey: idempotencyKey,
      body: {'status': status, 'reference': reference.trim()},
    );
  }

  Future<void> cancelOrder({
    required String bearerToken,
    required String storeId,
    required String orderId,
    String? idempotencyKey,
  }) async {
    await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores/$storeId/orders/$orderId/cancel',
      bearerToken: bearerToken,
      idempotencyKey: idempotencyKey,
      body: const {},
    );
  }

  Future<List<Product>> fetchProducts({
    required String bearerToken,
    required String storeId,
  }) async {
    final uri = _buildUri('/api/merchant/stores/$storeId/products');
    final response = await _http
        .get(uri, headers: _headers(bearerToken: bearerToken))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        message: (decoded['error'] ?? 'Gagal memuat produk.').toString(),
        statusCode: response.statusCode,
      );
    }
    if (response.body.length > 16384) {
      return compute(parseProductsIsolate, response.body);
    }
    return parseProductsIsolate(response.body);
  }

  Future<String> saveProduct({
    required String bearerToken,
    required String storeId,
    required Product product,
    required bool isUpdate,
  }) async {
    final path = isUpdate
        ? '/api/merchant/stores/$storeId/products/${product.id}'
        : '/api/merchant/stores/$storeId/products';
    final json = await _requestJson(
      method: isUpdate ? 'PUT' : 'POST',
      path: path,
      bearerToken: bearerToken,
      body: product.toPayloadJson(),
    );
    return (json['id'] ?? product.id).toString();
  }

  Future<void> archiveProduct({
    required String bearerToken,
    required String storeId,
    required String productId,
  }) async {
    await _requestJson(
      method: 'DELETE',
      path: '/api/merchant/stores/$storeId/products/$productId',
      bearerToken: bearerToken,
    );
  }

  Future<({String key, String url})> uploadMedia({
    required String bearerToken,
    required String storeId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.lengthInBytes > AppConfig.maxMediaUploadBytes) {
      throw const ApiException(
        message: 'Ukuran foto terlalu besar. Pilih atau kecilkan gambar lalu coba lagi.',
        statusCode: 413,
      );
    }
    final uri = _buildUri('/api/merchant/stores/$storeId/media');
    final response = await _http
        .post(
          uri,
          headers: _headers(bearerToken: bearerToken, contentType: mimeType),
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(
        message: (decoded['error'] ?? 'Foto belum berhasil diunggah.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
    return (
      key: (decoded['key'] ?? '').toString(),
      url: (decoded['url'] ?? '').toString(),
    );
  }

  Future<List<InventoryMovement>> fetchInventoryLedger({
    required String bearerToken,
    required String storeId,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/inventory',
      bearerToken: bearerToken,
    );
    final raw = (json['movements'] as List<dynamic>?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(InventoryMovement.fromJson)
        .toList();
  }

  Future<SalesAnalyticsBundle> fetchAnalytics({
    required String bearerToken,
    required String storeId,
    required String fromDate,
    required String toDate,
    String timezone='Asia/Jakarta',
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/analytics',
      bearerToken: bearerToken,
      query: {'from': fromDate, 'to': toDate,'timezone':timezone},
    );
    return SalesAnalyticsBundle.fromJson(json);
  }

  Future<({List<CustomerSummary> customers, bool hasMore})> fetchCustomers({
    required String bearerToken,
    required String storeId,
    String query = '',
    int page = 1,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/customers',
      bearerToken: bearerToken,
      query: {'q': query, 'page': '$page'},
    );
    final raw = (json['customers'] as List<dynamic>?) ?? const [];
    return (
      customers: raw
          .whereType<Map<String, dynamic>>()
          .map(CustomerSummary.fromJson)
          .toList(),
      hasMore: json['hasMore'] == true,
    );
  }

  Future<StoreSettings> fetchSettings({
    required String bearerToken,
    required String storeId,
    required MerchantStore store,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: '/api/merchant/stores/$storeId/settings',
      bearerToken: bearerToken,
    );
    final settingsMap = (json['settings'] as Map<String, dynamic>?) ?? const {};
    return StoreSettings.fromJson(
      settingsMap,
      fallbackStoreName: store.name,
      fallbackStoreDescription: store.description,
    );
  }

  Future<void> saveSettings({
    required String bearerToken,
    required String storeId,
    required StoreSettings settings,
  }) async {
    await _requestJson(
      method: 'PUT',
      path: '/api/merchant/stores/$storeId/settings',
      bearerToken: bearerToken,
      body: settings.toJson(),
    );
  }

  Future<void> setStorePublished({
    required String bearerToken,
    required String storeId,
    required bool publish,
  }) async {
    await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores/$storeId/publish',
      bearerToken: bearerToken,
      body: {'publish': publish},
    );
  }

  Future<BillingBundle> fetchBilling({
    required String bearerToken,
    required String storeId,
  }) async {
    final results = await Future.wait([
      _requestJson(
        method: 'GET',
        path: '/api/merchant/stores/$storeId/billing',
        bearerToken: bearerToken,
      ),
      _requestJson(
        method: 'GET',
        path: '/api/public/plans',
        bearerToken: bearerToken,
      ),
    ]);
    final billingJson = results[0];
    final plansJson = results[1];

    final subs = (billingJson['subscriptions'] as List<dynamic>?) ?? const [];
    final invoices = (billingJson['invoices'] as List<dynamic>?) ?? const [];
    final usage = (billingJson['usage'] as List<dynamic>?) ?? const [];
    final plans = (plansJson['plans'] as List<dynamic>?) ?? const [];

    return BillingBundle(
      entitlements: ((billingJson['entitlements'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlanEntitlement.fromJson)
          .toList(),
      accessAvailable: billingJson['accessAvailable'] == true,
      currentSubscriptionId: billingJson['currentSubscriptionId']?.toString(),
      pilotUntil: billingJson['pilotUntil']?.toString(),
      subscriptions: subs
          .whereType<Map<String, dynamic>>()
          .map(StoreSubscription.fromJson)
          .toList(),
      invoices: invoices
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionInvoice.fromJson)
          .toList(),
      usage: usage
          .whereType<Map<String, dynamic>>()
          .map(UsageCounter.fromJson)
          .toList(),
      publicPlans: plans
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList(),
      paymentInstructions:
          (billingJson['paymentInstructions'] ??
                  'Instruksi pembayaran belum ditetapkan admin.')
              .toString(),
    );
  }

  Future<void> selectSubscriptionPlan({
    required String bearerToken,
    required String storeId,
    required String planPriceId,
    bool confirmReplace = false,
  }) async {
    await _requestJson(
      method: 'POST',
      path: '/api/merchant/stores/$storeId/billing',
      bearerToken: bearerToken,
      body: {'plan_price_id': planPriceId, 'confirm_replace': confirmReplace},
    );
  }

  Future<String> exportCsv({
    required String bearerToken,
    required String storeId,
    required String resource,
  }) async {
    final parts = <String>[];
    var totalBytes = 0;
    for (var page = 1; page <= 20; page++) {
      final uri = _buildUri('/api/merchant/stores/$storeId/export', {
        'resource': resource,
        'page': '$page',
      });
      final response = await _http
          .get(uri, headers: _headers(bearerToken: bearerToken))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Gagal menyiapkan ekspor CSV.',
          statusCode: response.statusCode,
        );
      }
      final rowCount =
          int.tryParse(response.headers['x-export-rows'] ?? '0') ?? 0;
      if (rowCount == 0 && page > 1) break;
      final text = response.body;
      totalBytes += text.length;
      if (totalBytes > 10 * 1024 * 1024) {
        throw const ApiException(
          message: 'Ukuran ekspor terlalu besar untuk perangkat.',
        );
      }
      if (page == 1) {
        parts.add(text);
      } else {
        final firstBreak = text.indexOf('\r\n');
        if (firstBreak != -1 && firstBreak + 2 < text.length) {
          parts.add('\r\n${text.substring(firstBreak + 2)}');
        }
      }
      if (rowCount < 500) break;
      if(page==20) throw const ApiException(message:'Ekspor melebihi 10.000 baris. Gunakan versi web atau hubungi dukungan untuk ekspor lengkap.');
    }
    return parts.join();
  }
}
