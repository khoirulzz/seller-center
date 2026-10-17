import 'dart:typed_data';

import '../../core/errors/api_exception.dart';
import '../../core/config/slug_utils.dart';
import '../../domain/models/seller_models.dart';
import '../services/firebase_auth_service.dart';
import '../services/local_draft_service.dart';
import '../services/seller_api_service.dart';

/// Coordinates Firebase authentication and Cloudflare merchant APIs.
/// All authenticated merchant operations are server-authorized; store roles
/// passed by UI widgets are never treated as an authorization boundary.
class SellerRepository {
  SellerRepository({
    FirebaseAuthService? authService,
    SellerApiService? apiService,
    LocalDraftService? draftService,
  }) : _auth = authService ?? FirebaseAuthService(),
       _api = apiService ?? SellerApiService(),
       _drafts = draftService ?? LocalDraftService();

  final FirebaseAuthService _auth;
  final SellerApiService _api;
  final LocalDraftService _drafts;
  final _mediaCache = <String, Future<Uint8List>>{};
  void clearMediaCache() => _mediaCache.clear();
  Future<Uint8List> fetchMediaBytes(
    String source, {
    bool refresh = false,
  }) async {
    final uri = _api.resolveMediaUri(source);
    final private = _api.isPrivateMedia(uri);
    final cacheKey = '${_currentUser?.id ?? "anonymous"}:$uri';
    if (refresh) _mediaCache.remove(cacheKey);
    final existing = _mediaCache[cacheKey];
    if (existing != null) return existing;
    if (_mediaCache.length >= 12) _mediaCache.remove(_mediaCache.keys.first);
    final request = () async {
      return _api.fetchMediaBytes(
        uri: uri,
        bearerToken: private ? await _validBearerToken() : null,
      );
    }();
    _mediaCache[cacheKey] = request;
    try {
      return await request;
    } catch (_) {
      _mediaCache.remove(cacheKey);
      rethrow;
    }
  }

  FirebaseSession? _session;
  UserIdentity? _currentUser;

  UserIdentity? get currentUser => _currentUser;
  FirebaseSession? get currentSession => _session;
  LocalDraftService get drafts => _drafts;

  Future<UserIdentity?> restoreSession() async {
    final saved = await _drafts.loadSessionJson();
    if (saved == null) return null;
    try {
      var session = FirebaseSession.fromJson(saved);
      if (session.isExpired) {
        session = await _auth.refreshSession(session);
        await _drafts.saveSessionJson(session.toJson());
      }
      final user = await _api.fetchCurrentUser(session.idToken);
      if (user == null) {
        await signOut();
        return null;
      }
      _session = session;
      _currentUser = user;
      return user;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  Future<UserIdentity> signIn({
    required String email,
    required String password,
  }) async {
    final session = await _auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = await _api.fetchCurrentUser(session.idToken);
    if (user == null) {
      throw const ApiException(
        message: 'Akun belum tersedia di server.',
        statusCode: 503,
      );
    }
    _session = session;
    _currentUser = user;
    await _drafts.saveSessionJson(session.toJson());
    return user;
  }

  Future<UserIdentity> register({
    required String email,
    required String password,
  }) async {
    final session = await _auth.signUpWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = UserIdentity(
      id: session.uid,
      email: session.email,
      verified: session.emailVerified,
      admin: false,
    );
    _session = session;
    _currentUser = user;
    await _drafts.saveSessionJson(session.toJson());
    return user;
  }

  Future<void> resendVerificationEmail() async {
    final token = await _validBearerToken();
    await _auth.sendEmailVerification(token);
  }

  Future<UserIdentity?> refreshVerificationStatus() async {
    final current = _session;
    if (current == null) return null;
    final session = await _auth.refreshSession(current);
    _session = session;
    await _drafts.saveSessionJson(session.toJson());
    final remoteUser = await _api.fetchCurrentUser(session.idToken);
    final updated =
        remoteUser ??
        UserIdentity(
          id: session.uid,
          email: session.email,
          verified: session.emailVerified,
          admin: false,
        );
    _currentUser = updated;
    return updated;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email.trim());

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _currentUser?.email ?? '';
    if (!FirebaseAuthService.isPasswordPolicySatisfied(newPassword)) {
      throw const ApiException(
        message: 'Kata sandi tidak memenuhi kebijakan.',
        statusCode: 400,
      );
    }
    await _auth.updatePassword(
      email: email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await signOut();
  }

  Future<void> signOut() async {
    clearMediaCache();
    _session = null;
    _currentUser = null;
    await _drafts.clearSession();
  }

  Future<String> _validBearerToken() async {
    final session = _session;
    if (session == null) {
      throw const ApiException(
        message: 'Sesi berakhir. Silakan masuk kembali.',
        statusCode: 401,
      );
    }
    if (!session.isExpired) return session.idToken;
    final refreshed = await _auth.refreshSession(session);
    _session = refreshed;
    await _drafts.saveSessionJson(refreshed.toJson());
    return refreshed.idToken;
  }

  Future<List<MerchantStore>> fetchStores() async =>
      _api.fetchStores(await _validBearerToken());

  Future<bool> checkSlugAvailable(String slug) async {
    if (!NsSlugUtils.isValid(slug)) return false;
    return _api.checkSlugAvailability(
      bearerToken: await _validBearerToken(),
      slug: slug,
    );
  }

  Future<MerchantStore> createStore({
    required String name,
    required String slug,
    String description = '',
  }) async {
    final safeSlug = NsSlugUtils.normalize(slug);
    final validation = NsSlugUtils.validate(safeSlug, entityLabel: 'Link toko');
    if (validation != null)
      throw ApiException(message: validation, statusCode: 400);
    final token = await _validBearerToken();
    final id = await _api.createStore(
      bearerToken: token,
      name: name.trim(),
      slug: safeSlug,
    );
    final stores = await _api.fetchStores(token);
    return stores.where((store) => store.id == id).firstOrNull ??
        MerchantStore(
          id: id,
          slug: safeSlug,
          name: name.trim(),
          status: 'draft',
          description: description.trim(),
          role: 'owner',
        );
  }

  Future<StoreOverview> fetchOverview(String storeId) async => _api
      .fetchOverview(bearerToken: await _validBearerToken(), storeId: storeId);

  Future<({List<OrderModel> orders, bool hasMore})> fetchOrders({
    required String storeId,
    String status = 'all',
    String query = '',
    int page = 1,
    String? fromDate,
    String? toDate,
  }) async => _api.fetchOrders(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
    status: status,
    query: query,
    page: page,
    fromDate: fromDate,
    toDate: toDate,
  );

  Future<OrderDetailBundle> fetchOrderDetail({
    required String storeId,
    required String orderId,
  }) async => _api.fetchOrderDetail(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
    orderId: orderId,
  );

  Future<void> reviewOrderPayment({
    required String storeId,
    required String orderId,
    required String decision,
    required StoreRole role,
    String note = '',
  }) async {
    if (!role.canVerifyPayment) {
      throw const ApiException(
        message: 'Tidak memiliki izin memverifikasi pembayaran.',
        statusCode: 403,
      );
    }
    await _api.reviewOrderPayment(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      orderId: orderId,
      decision: decision,
      note: note,
      idempotencyKey: 'payment:$storeId:$orderId:$decision',
    );
  }

  Future<void> updateOrderFulfillment({
    required String storeId,
    required String orderId,
    required String nextStatus,
    required StoreRole role,
    String reference = '',
  }) async {
    if (!role.canProcessFulfillment) {
      throw const ApiException(
        message: 'Tidak memiliki izin memperbarui pengiriman.',
        statusCode: 403,
      );
    }
    await _api.updateOrderFulfillment(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      orderId: orderId,
      status: nextStatus,
      reference: reference,
      idempotencyKey: 'fulfillment:$storeId:$orderId:$nextStatus',
    );
  }

  Future<void> cancelOrder({
    required String storeId,
    required String orderId,
    required StoreRole role,
  }) async {
    if (!role.canCancelOrder) {
      throw const ApiException(
        message: 'Tidak memiliki izin membatalkan pesanan.',
        statusCode: 403,
      );
    }
    await _api.cancelOrder(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      orderId: orderId,
      idempotencyKey: 'cancel:$storeId:$orderId',
    );
  }

  Future<List<Product>> fetchProducts(String storeId) async => _api
      .fetchProducts(bearerToken: await _validBearerToken(), storeId: storeId);

  Future<Product> saveProduct({
    required String storeId,
    required Product product,
    required bool isUpdate,
    required StoreRole role,
  }) async {
    if (!role.canManageCatalog) {
      throw const ApiException(
        message: 'Tidak memiliki izin mengelola katalog.',
        statusCode: 403,
      );
    }
    final slug = NsSlugUtils.normalize(product.slug);
    final validation = NsSlugUtils.validate(slug, entityLabel: 'Link produk');
    if (validation != null)
      throw ApiException(message: validation, statusCode: 400);
    final updated = product.copyWith(slug: slug);
    final skus = updated.variants
        .map((v) => v.sku.trim().toUpperCase())
        .toList();
    if (skus.any((s) => s.isEmpty) || skus.toSet().length != skus.length) {
      throw const ApiException(
        message: 'SKU tidak boleh kosong atau duplikat.',
        statusCode: 400,
      );
    }
    if (updated.variants.any((v) => v.stockQty < v.reservedQty)) {
      throw const ApiException(
        message: 'Stok tidak boleh di bawah jumlah yang dipesan.',
        statusCode: 409,
      );
    }
    final id = await _api.saveProduct(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      product: updated,
      isUpdate: isUpdate,
    );
    return Product(
      id: id,
      slug: updated.slug,
      name: updated.name,
      description: updated.description,
      priceIdr: updated.priceIdr,
      category: updated.category,
      primaryImageUrl: updated.primaryImageUrl,
      gallery: updated.gallery,
      status: updated.status,
      variants: updated.variants,
    );
  }

  Future<void> archiveProduct({
    required String storeId,
    required String productId,
    required StoreRole role,
  }) async {
    if (!role.canManageCatalog) {
      throw const ApiException(
        message: 'Tidak memiliki izin mengarsipkan produk.',
        statusCode: 403,
      );
    }
    await _api.archiveProduct(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      productId: productId,
    );
  }

  Future<void> adjustVariantStock({
    required String storeId,
    required String productId,
    required String variantSku,
    required int expectedOldStockQty,
    required int newStockQty,
    required String reason,
    required StoreRole role,
  }) async {
    if (!role.canManageCatalog) {
      throw const ApiException(
        message: 'Tidak memiliki izin mengubah stok.',
        statusCode: 403,
      );
    }
    final products = await fetchProducts(storeId);
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      throw const ApiException(
        message: 'Produk tidak ditemukan.',
        statusCode: 404,
      );
    }
    final variant = product.variants
        .where((v) => v.sku == variantSku)
        .firstOrNull;
    if (variant == null) {
      throw const ApiException(
        message: 'Varian tidak ditemukan.',
        statusCode: 404,
      );
    }
    if (variant.stockQty != expectedOldStockQty ||
        newStockQty < variant.reservedQty) {
      throw const ApiException(
        message: 'Stok berubah atau di bawah jumlah reservasi.',
        statusCode: 409,
      );
    }
    final revised = product.variants
        .map((v) => v.sku == variantSku ? v.copyWith(stockQty: newStockQty) : v)
        .toList();
    await saveProduct(
      storeId: storeId,
      product: product.copyWith(variants: revised),
      isUpdate: true,
      role: role,
    );
  }

  Future<List<InventoryMovement>> fetchInventoryLedger(String storeId) async =>
      _api.fetchInventoryLedger(
        bearerToken: await _validBearerToken(),
        storeId: storeId,
      );

  Future<SalesAnalyticsBundle> fetchAnalytics({
    required String storeId,
    required String fromDate,
    required String toDate,
  }) async => _api.fetchAnalytics(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
    fromDate: fromDate,
    toDate: toDate,
  );

  Future<({List<CustomerSummary> customers, bool hasMore})> fetchCustomers({
    required String storeId,
    String query = '',
    int page = 1,
  }) async => _api.fetchCustomers(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
    query: query,
    page: page,
  );

  Future<StoreSettings> fetchSettings({
    required String storeId,
    required MerchantStore store,
  }) async => _api.fetchSettings(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
    store: store,
  );

  Future<void> saveSettings({
    required String storeId,
    required StoreSettings settings,
    required StoreRole role,
  }) async {
    if (!role.canManageSettings) {
      throw const ApiException(
        message: 'Tidak memiliki izin mengubah pengaturan.',
        statusCode: 403,
      );
    }
    await _api.saveSettings(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      settings: settings,
    );
  }

  Future<void> setStorePublished({
    required String storeId,
    required bool publish,
    required StoreRole role,
  }) async {
    if (!role.canManageSettings) {
      throw const ApiException(
        message: 'Tidak memiliki izin publikasi toko.',
        statusCode: 403,
      );
    }
    await _api.setStorePublished(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      publish: publish,
    );
  }

  Future<BillingBundle> fetchBilling(String storeId) async => _api.fetchBilling(
    bearerToken: await _validBearerToken(),
    storeId: storeId,
  );

  Future<void> selectSubscriptionPlan({
    required String storeId,
    required String planPriceId,
    required StoreRole role,
    bool confirmReplace = false,
  }) async {
    if (!role.canChooseBillingPlan) {
      throw const ApiException(
        message: 'Hanya pemilik yang dapat memilih paket.',
        statusCode: 403,
      );
    }
    await _api.selectSubscriptionPlan(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      planPriceId: planPriceId,
      confirmReplace: confirmReplace,
    );
  }

  Future<String> exportCsv({
    required String storeId,
    required String resource,
    required StoreRole role,
  }) async {
    if (!role.canViewCustomersAndAnalytics) {
      throw const ApiException(
        message: 'Tidak memiliki izin ekspor.',
        statusCode: 403,
      );
    }
    return _api.exportCsv(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      resource: resource,
    );
  }

  Future<({String key, String url})> uploadMediaBytes({
    required String storeId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const ApiException(
        message: 'Ukuran foto terlalu besar.',
        statusCode: 413,
      );
    }
    return _api.uploadMedia(
      bearerToken: await _validBearerToken(),
      storeId: storeId,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  List<SellerNotification> getNotificationsForUser() => const [];
  void markNotificationRead(String notificationId) {}
  void markAllNotificationsRead() {}
}
