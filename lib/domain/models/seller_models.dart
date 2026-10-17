import 'dart:convert';

/// Identitas pengguna terautentikasi (`/api/auth/me`).
class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.email,
    required this.verified,
    required this.admin,
  });

  final String id;
  final String email;
  final bool verified;
  final bool admin;

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      verified: json['verified'] == true,
      admin: json['admin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'verified': verified,
    'admin': admin,
  };
}

/// Hak akses peran per toko (`PRD` Bab 5.3).
enum StoreRole {
  owner,
  manager,
  fulfillment,
  unknown;

  static StoreRole fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'owner':
        return StoreRole.owner;
      case 'manager':
        return StoreRole.manager;
      case 'fulfillment':
        return StoreRole.fulfillment;
      default:
        // Fail closed: unknown roles never inherit owner permissions.
        return StoreRole.unknown;
    }
  }

  bool get canVerifyPayment =>
      this == StoreRole.owner || this == StoreRole.manager;
  bool get canCancelOrder =>
      this == StoreRole.owner || this == StoreRole.manager;
  bool get canManageCatalog =>
      this == StoreRole.owner || this == StoreRole.manager;
  bool get canManageSettings =>
      this == StoreRole.owner || this == StoreRole.manager;
  bool get canViewCustomersAndAnalytics =>
      this == StoreRole.owner || this == StoreRole.manager;
  bool get canChooseBillingPlan => this == StoreRole.owner;
  bool get canProcessFulfillment => this != StoreRole.unknown;
}

/// Data toko tenant (`/api/merchant/stores`).
class MerchantStore {
  const MerchantStore({
    required this.id,
    required this.slug,
    required this.name,
    required this.status,
    required this.description,
    required this.role,
    this.pilotUntil,
  });

  final String id;
  final String slug;
  final String name;
  final String status;
  final String description;
  final String role;
  final String? pilotUntil;

  StoreRole get storeRole => StoreRole.fromString(role);
  bool get isPublished => status == 'published';

  factory MerchantStore.fromJson(Map<String, dynamic> json) {
    return MerchantStore(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? 'draft').toString(),
      description: (json['description'] ?? '').toString(),
      role: (json['role'] ?? 'unknown').toString(),
      pilotUntil: json['pilot_until']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'status': status,
    'description': description,
    'role': role,
    if (pilotUntil != null) 'pilot_until': pilotUntil,
  };

  MerchantStore copyWith({
    String? name,
    String? status,
    String? description,
    String? pilotUntil,
  }) {
    return MerchantStore(
      id: id,
      slug: slug,
      name: name ?? this.name,
      status: status ?? this.status,
      description: description ?? this.description,
      role: role,
      pilotUntil: pilotUntil ?? this.pilotUntil,
    );
  }
}

/// Varian stok rendah pada ringkasan Beranda (`/api/merchant/stores/{sid}/overview`).
class LowStockAlert {
  const LowStockAlert({
    required this.name,
    required this.optionLabel,
    required this.availableStock,
  });

  final String name;
  final String optionLabel;
  final int availableStock;

  factory LowStockAlert.fromJson(Map<String, dynamic> json) {
    return LowStockAlert(
      name: (json['name'] ?? '').toString(),
      optionLabel: (json['option_label'] ?? 'Default').toString(),
      availableStock: (json['available_stock'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ringkasan 30 hari Beranda (`/api/merchant/stores/{sid}/overview`).
class StoreOverview {
  const StoreOverview({
    required this.ordersCount,
    required this.verifiedRevenueIdr,
    required this.pendingOrdersCount,
    required this.lowStockAlerts,
    required this.fetchedAt,
  });

  final int ordersCount;
  final int verifiedRevenueIdr;
  final int pendingOrdersCount;
  final List<LowStockAlert> lowStockAlerts;
  final DateTime fetchedAt;

  factory StoreOverview.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final rawLowStock = (json['lowStock'] as List<dynamic>?) ?? const [];
    return StoreOverview(
      ordersCount: (summary['orders'] as num?)?.toInt() ?? 0,
      verifiedRevenueIdr:
          int.tryParse((summary['revenue'] ?? '0').toString()) ?? 0,
      pendingOrdersCount: (summary['pending'] as num?)?.toInt() ?? 0,
      lowStockAlerts: rawLowStock
          .whereType<Map<String, dynamic>>()
          .map(LowStockAlert.fromJson)
          .toList(),
      fetchedAt: DateTime.now(),
    );
  }
}

/// Foto tambahan galeri produk.
class GalleryPhoto {
  const GalleryPhoto({required this.url, this.alt = ''});

  final String url;
  final String alt;

  factory GalleryPhoto.fromJson(Map<String, dynamic> json) {
    return GalleryPhoto(
      url: (json['url'] ?? '').toString(),
      alt: (json['alt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'alt': alt};

  GalleryPhoto copyWith({String? url, String? alt}) {
    return GalleryPhoto(url: url ?? this.url, alt: alt ?? this.alt);
  }
}

/// Varian produk (`product_variants`).
class ProductVariant {
  const ProductVariant({
    this.id,
    required this.sku,
    required this.optionLabel,
    this.priceOverrideIdr,
    required this.stockQty,
    this.reservedQty = 0,
    this.status = 'active',
    this.imageUrl,
  });

  final String? id;
  final String sku;
  final String optionLabel;
  final int? priceOverrideIdr;
  final int stockQty;
  final int reservedQty;
  final String status;
  final String? imageUrl;

  int get availableStock => (stockQty - reservedQty).clamp(0, 1000000);

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id']?.toString(),
      sku: (json['sku'] ?? '').toString(),
      optionLabel: (json['option_label'] ?? 'Default').toString(),
      priceOverrideIdr: json['price_override_idr'] == null
          ? null
          : int.tryParse(json['price_override_idr'].toString()),
      stockQty: (json['stock_qty'] as num?)?.toInt() ?? 0,
      reservedQty: (json['reserved_qty'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'active').toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'sku': sku.trim(),
    'option_label': optionLabel.trim(),
    'price_override_idr': priceOverrideIdr,
    'stock_qty': stockQty,
    'status': status,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
  };

  ProductVariant copyWith({
    String? id,
    String? sku,
    String? optionLabel,
    int? priceOverrideIdr,
    bool clearPriceOverride = false,
    int? stockQty,
    int? reservedQty,
    String? status,
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      optionLabel: optionLabel ?? this.optionLabel,
      priceOverrideIdr: clearPriceOverride
          ? null
          : (priceOverrideIdr ?? this.priceOverrideIdr),
      stockQty: stockQty ?? this.stockQty,
      reservedQty: reservedQty ?? this.reservedQty,
      status: status ?? this.status,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
    );
  }
}

/// Produk katalog (`/api/merchant/stores/{sid}/products`).
class Product {
  const Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.priceIdr,
    required this.category,
    this.primaryImageUrl,
    this.gallery = const [],
    required this.status,
    required this.variants,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final int priceIdr;
  final String category;
  final String? primaryImageUrl;
  final List<GalleryPhoto> gallery;
  final String status;
  final List<ProductVariant> variants;

  int get totalAvailableStock {
    return variants
        .where((v) => v.status == 'active')
        .fold<int>(0, (sum, v) => sum + v.availableStock);
  }

  int get totalReservedStock {
    return variants.fold<int>(0, (sum, v) => sum + v.reservedQty);
  }

  int get effectiveCatalogPriceIdr {
    final activePrices = variants
        .where((v) => v.status == 'active')
        .map((v) => v.priceOverrideIdr ?? priceIdr)
        .toList();
    if (activePrices.isEmpty) return priceIdr;
    activePrices.sort();
    return activePrices.first;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawVariants = (json['variants'] as List<dynamic>?) ?? const [];
    final rawGallery = (json['gallery'] as List<dynamic>?) ?? const [];
    return Product(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priceIdr: int.tryParse((json['price_idr'] ?? '0').toString()) ?? 0,
      category: (json['category'] ?? 'Produk').toString(),
      primaryImageUrl: json['primary_image_url']?.toString(),
      gallery: rawGallery
          .whereType<Map<String, dynamic>>()
          .map(GalleryPhoto.fromJson)
          .toList(),
      status: (json['status'] ?? 'draft').toString(),
      variants: rawVariants
          .whereType<Map<String, dynamic>>()
          .map(ProductVariant.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toPayloadJson() => {
    'slug': slug,
    'name': name,
    'description': description,
    'price_idr': priceIdr,
    'category': category,
    'primary_image_url': (primaryImageUrl == null || primaryImageUrl!.isEmpty)
        ? null
        : primaryImageUrl,
    'gallery': gallery.map((g) => g.toJson()).toList(),
    'status': status,
    'variants': variants.map((v) => v.toJson()).toList(),
  };

  Product copyWith({
    String? slug,
    String? name,
    String? description,
    int? priceIdr,
    String? category,
    String? primaryImageUrl,
    List<GalleryPhoto>? gallery,
    String? status,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      priceIdr: priceIdr ?? this.priceIdr,
      category: category ?? this.category,
      primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
      gallery: gallery ?? this.gallery,
      status: status ?? this.status,
      variants: variants ?? this.variants,
    );
  }
}

/// Top-level isolate parser untuk daftar produk besar (`compute()`).
List<Product> parseProductsIsolate(String responseBody) {
  final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
  final list = (decoded['products'] as List<dynamic>?) ?? const [];
  return list.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
}

/// Item pada detail pesanan.
class OrderItem {
  const OrderItem({
    this.id,
    required this.nameSnapshot,
    required this.variantSnapshot,
    this.skuSnapshot = '',
    required this.quantity,
    required this.unitPriceIdr,
    required this.lineTotalIdr,
  });

  final String? id;
  final String nameSnapshot;
  final String variantSnapshot;
  final String skuSnapshot;
  final int quantity;
  final int unitPriceIdr;
  final int lineTotalIdr;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString(),
      nameSnapshot: (json['name_snapshot'] ?? '').toString(),
      variantSnapshot: (json['variant_snapshot'] ?? 'Default').toString(),
      skuSnapshot: (json['sku_snapshot'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceIdr:
          int.tryParse((json['unit_price_idr'] ?? '0').toString()) ?? 0,
      lineTotalIdr:
          int.tryParse((json['line_total_idr'] ?? '0').toString()) ?? 0,
    );
  }
}

/// Riwayat audit / timeline pesanan.
class OrderTimelineEvent {
  const OrderTimelineEvent({required this.action, required this.createdAt});

  final String action;
  final String createdAt;

  factory OrderTimelineEvent.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEvent(
      action: (json['action'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

/// Model pesanan (`/api/merchant/stores/{sid}/orders`).
class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    this.contactEmail = '',
    this.contactPhone = '',
    required this.totalIdr,
    this.subtotalIdr = 0,
    this.shippingIdr = 0,
    required this.orderStatus,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    this.shippingMethod = 'pickup',
    required this.createdAt,
    this.updatedAt = '',
    this.reservationExpiresAt = '',
    this.shippingAddress = '',
    this.shipmentReference = '',
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String contactEmail;
  final String contactPhone;
  final int totalIdr;
  final int subtotalIdr;
  final int shippingIdr;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String shippingMethod;
  final String createdAt;
  final String updatedAt;
  final String reservationExpiresAt;
  final String shippingAddress;
  final String shipmentReference;

  bool get isReservationExpired {
    if (reservationExpiresAt.isEmpty) return false;
    final exp = DateTime.tryParse(reservationExpiresAt);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Menentukan apakah pembayaran pesanan dapat diperiksa sesuai state machine Worker.
  bool canVerifyPayment(StoreRole role) {
    return role.canVerifyPayment &&
        orderStatus == 'pending' &&
        paymentStatus != 'paid' &&
        !isReservationExpired;
  }

  /// Menentukan apakah pesanan dapat dibatalkan sesuai state machine Worker.
  bool canCancel(StoreRole role) {
    return role.canCancelOrder &&
        paymentStatus != 'paid' &&
        orderStatus != 'canceled' &&
        orderStatus != 'expired' &&
        orderStatus != 'completed';
  }

  /// Daftar status fulfillment berikutnya yang diizinkan oleh state machine Worker (`worker/lib/commerce.ts`).
  List<String> allowedNextFulfillmentStates(StoreRole role) {
    if (!role.canProcessFulfillment) return const [];
    if (paymentStatus != 'paid') return const [];
    if (orderStatus == 'canceled' || orderStatus == 'expired') return const [];

    if (shippingMethod == 'pickup') {
      switch (fulfillmentStatus) {
        case 'unfulfilled':
          return const ['packing', 'pickup_ready'];
        case 'packing':
          return const ['pickup_ready'];
        case 'pickup_ready':
          return const ['picked_up'];
        default:
          return const [];
      }
    } else {
      switch (fulfillmentStatus) {
        case 'unfulfilled':
          return const ['packing'];
        case 'packing':
          return const ['shipped'];
        case 'shipped':
          return const ['delivered'];
        default:
          return const [];
      }
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String parsedAddress = '';
    final addrRaw = json['address_json'];
    if (addrRaw is Map<String, dynamic>) {
      parsedAddress = (addrRaw['address'] ?? '').toString();
    } else if (addrRaw is String && addrRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(addrRaw) as Map<String, dynamic>;
        parsedAddress = (decoded['address'] ?? '').toString();
      } catch (_) {
        parsedAddress = addrRaw;
      }
    }

    final total = int.tryParse((json['total_idr'] ?? '0').toString()) ?? 0;
    final subtotal =
        int.tryParse((json['subtotal_idr'] ?? total.toString()).toString()) ??
        total;
    final shipping =
        int.tryParse((json['shipping_idr'] ?? '0').toString()) ?? 0;

    return OrderModel(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      totalIdr: total,
      subtotalIdr: subtotal,
      shippingIdr: shipping,
      orderStatus: (json['order_status'] ?? 'pending').toString(),
      paymentStatus: (json['payment_status'] ?? 'unpaid').toString(),
      fulfillmentStatus: (json['fulfillment_status'] ?? 'unfulfilled')
          .toString(),
      shippingMethod: (json['shipping_method'] ?? 'pickup').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      reservationExpiresAt: (json['reservation_expires_at'] ?? '').toString(),
      shippingAddress: parsedAddress,
      shipmentReference: (json['shipment_reference'] ?? '').toString(),
    );
  }
}

/// Detail lengkap pesanan beserta item dan timeline.
class OrderDetailBundle {
  const OrderDetailBundle({
    required this.order,
    required this.items,
    required this.timeline,
  });

  final OrderModel order;
  final List<OrderItem> items;
  final List<OrderTimelineEvent> timeline;

  factory OrderDetailBundle.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    final rawTimeline = (json['timeline'] as List<dynamic>?) ?? const [];
    return OrderDetailBundle(
      order: OrderModel.fromJson(
        (json['order'] as Map<String, dynamic>?) ?? const {},
      ),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(),
      timeline: rawTimeline
          .whereType<Map<String, dynamic>>()
          .map(OrderTimelineEvent.fromJson)
          .toList(),
    );
  }
}

/// Pergerakan stok pada buku besar (`/api/merchant/stores/{sid}/inventory`).
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.variantId,
    required this.productName,
    required this.optionLabel,
    required this.kind,
    required this.quantityDelta,
    required this.createdAt,
    this.reason,
  });

  final String id;
  final String variantId;
  final String productName;
  final String optionLabel;
  final String kind;
  final int quantityDelta;
  final String createdAt;
  final String? reason;

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: (json['id'] ?? '').toString(),
      variantId: (json['variant_id'] ?? '').toString(),
      productName: (json['name'] ?? '').toString(),
      optionLabel: (json['option_label'] ?? 'Default').toString(),
      kind: (json['kind'] ?? 'adjustment').toString(),
      quantityDelta: (json['quantity_delta'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
      reason: json['reason']?.toString(),
    );
  }
}

/// Titik penjualan harian pada Analitik.
class DailySalesPoint {
  const DailySalesPoint({
    required this.day,
    required this.orders,
    required this.revenueIdr,
  });

  final String day;
  final int orders;
  final int revenueIdr;

  factory DailySalesPoint.fromJson(Map<String, dynamic> json) {
    return DailySalesPoint(
      day: (json['day'] ?? '').toString(),
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenueIdr: int.tryParse((json['revenue'] ?? '0').toString()) ?? 0,
    );
  }
}

/// Ringkasan Analitik penjualan (`/api/merchant/stores/{sid}/analytics`).
class SalesAnalyticsBundle {
  const SalesAnalyticsBundle({
    required this.totalOrders,
    required this.paidOrders,
    required this.canceledOrders,
    required this.verifiedRevenueIdr,
    required this.dailyPoints,
  });

  final int totalOrders;
  final int paidOrders;
  final int canceledOrders;
  final int verifiedRevenueIdr;
  final List<DailySalesPoint> dailyPoints;

  int get averagePaidOrderIdr =>
      paidOrders > 0 ? (verifiedRevenueIdr / paidOrders).round() : 0;

  factory SalesAnalyticsBundle.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final rawDaily = (json['daily'] as List<dynamic>?) ?? const [];
    return SalesAnalyticsBundle(
      totalOrders: (summary['orders'] as num?)?.toInt() ?? 0,
      paidOrders: (summary['paid_orders'] as num?)?.toInt() ?? 0,
      canceledOrders: (summary['canceled_orders'] as num?)?.toInt() ?? 0,
      verifiedRevenueIdr:
          int.tryParse((summary['revenue'] ?? '0').toString()) ?? 0,
      dailyPoints: rawDaily
          .whereType<Map<String, dynamic>>()
          .map(DailySalesPoint.fromJson)
          .toList(),
    );
  }
}

/// Ringkasan pelanggan (`/api/merchant/stores/{sid}/customers`).
class CustomerSummary {
  const CustomerSummary({
    required this.name,
    required this.email,
    required this.contactPhone,
    required this.ordersCount,
    required this.paidTotalIdr,
    required this.lastOrderAt,
  });

  final String name;
  final String email;
  final String contactPhone;
  final int ordersCount;
  final int paidTotalIdr;
  final String lastOrderAt;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      ordersCount: (json['orders'] as num?)?.toInt() ?? 0,
      paidTotalIdr: int.tryParse((json['paid_total'] ?? '0').toString()) ?? 0,
      lastOrderAt: (json['last_order'] ?? '').toString(),
    );
  }
}

/// Pengaturan toko (`/api/merchant/stores/{sid}/settings`).
class StoreSettings {
  const StoreSettings({
    this.storeName = '',
    this.storeDescription = '',
    required this.contactPhone,
    required this.pickupAddress,
    required this.shippingFeeIdr,
    required this.pickupEnabled,
    required this.deliveryEnabled,
    required this.bankDetails,
    this.qrisMediaKey,
    required this.policies,
    required this.accent,
    required this.heroTitle,
    this.heroImageUrl,
    this.logoUrl,
    required this.openingHours,
    required this.lowStockThreshold,
  });

  final String storeName;
  final String storeDescription;
  final String contactPhone;
  final String pickupAddress;
  final int shippingFeeIdr;
  final bool pickupEnabled;
  final bool deliveryEnabled;
  final String bankDetails;
  final String? qrisMediaKey;
  final String policies;
  final String accent;
  final String heroTitle;
  final String? heroImageUrl;
  final String? logoUrl;
  final String openingHours;
  final int lowStockThreshold;

  bool get hasPaymentConfigured =>
      bankDetails.trim().isNotEmpty ||
      (qrisMediaKey != null && qrisMediaKey!.trim().isNotEmpty);

  bool get hasFulfillmentConfigured => pickupEnabled || deliveryEnabled;

  bool get hasValidPickupAddress =>
      !pickupEnabled || pickupAddress.trim().isNotEmpty;

  bool get hasValidDeliveryContact =>
      !deliveryEnabled || contactPhone.trim().isNotEmpty;

  bool get hasPolicies => policies.trim().isNotEmpty;

  bool get hasContactPhone => contactPhone.trim().isNotEmpty;

  factory StoreSettings.fromJson(
    Map<String, dynamic> json, {
    String fallbackStoreName = '',
    String fallbackStoreDescription = '',
  }) {
    return StoreSettings(
      storeName: (json['store_name'] ?? fallbackStoreName).toString(),
      storeDescription: (json['store_description'] ?? fallbackStoreDescription)
          .toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      pickupAddress: (json['pickup_address'] ?? '').toString(),
      shippingFeeIdr:
          int.tryParse((json['shipping_fee_idr'] ?? '0').toString()) ?? 0,
      pickupEnabled: json['pickup_enabled'] != false,
      deliveryEnabled: json['delivery_enabled'] == true,
      bankDetails: (json['bank_details'] ?? '').toString(),
      qrisMediaKey: json['qris_media_key']?.toString(),
      policies: (json['policies'] ?? '').toString(),
      accent: (json['accent'] ?? '#171715').toString(),
      heroTitle: (json['hero_title'] ?? '').toString(),
      heroImageUrl: json['hero_image_url']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      openingHours: (json['opening_hours'] ?? '').toString(),
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
    if (storeName.trim().isNotEmpty) 'store_name': storeName.trim(),
    'store_description': storeDescription,
    'contact_phone': contactPhone.trim(),
    'pickup_address': pickupAddress.trim(),
    'shipping_fee_idr': shippingFeeIdr,
    'pickup_enabled': pickupEnabled,
    'delivery_enabled': deliveryEnabled,
    'bank_details': bankDetails.trim(),
    'qris_media_key': (qrisMediaKey == null || qrisMediaKey!.isEmpty)
        ? null
        : qrisMediaKey,
    'policies': policies.trim(),
    'accent': accent,
    'hero_title': heroTitle.trim(),
    'hero_image_url': (heroImageUrl == null || heroImageUrl!.isEmpty)
        ? null
        : heroImageUrl,
    'logo_url': (logoUrl == null || logoUrl!.isEmpty) ? null : logoUrl,
    'opening_hours': openingHours.trim(),
    'low_stock_threshold': lowStockThreshold,
  };

  StoreSettings copyWith({
    String? storeName,
    String? storeDescription,
    String? contactPhone,
    String? pickupAddress,
    int? shippingFeeIdr,
    bool? pickupEnabled,
    bool? deliveryEnabled,
    String? bankDetails,
    String? qrisMediaKey,
    bool clearQris = false,
    String? policies,
    String? accent,
    String? heroTitle,
    String? heroImageUrl,
    String? logoUrl,
    String? openingHours,
    int? lowStockThreshold,
  }) {
    return StoreSettings(
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      contactPhone: contactPhone ?? this.contactPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      shippingFeeIdr: shippingFeeIdr ?? this.shippingFeeIdr,
      pickupEnabled: pickupEnabled ?? this.pickupEnabled,
      deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
      bankDetails: bankDetails ?? this.bankDetails,
      qrisMediaKey: clearQris ? null : (qrisMediaKey ?? this.qrisMediaKey),
      policies: policies ?? this.policies,
      accent: accent ?? this.accent,
      heroTitle: heroTitle ?? this.heroTitle,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      openingHours: openingHours ?? this.openingHours,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}

/// Paket harga dan langganan toko (`/api/merchant/stores/{sid}/billing` & `/api/public/plans`).
class PlanPrice {
  const PlanPrice({
    this.id,
    required this.billingInterval,
    required this.amountIdr,
  });

  final String? id;
  final String billingInterval;
  final int amountIdr;

  factory PlanPrice.fromJson(Map<String, dynamic> json) {
    return PlanPrice(
      id: json['id']?.toString(),
      billingInterval: (json['billing_interval'] ?? 'monthly').toString(),
      amountIdr: int.tryParse((json['amount_idr'] ?? '0').toString()) ?? 0,
    );
  }
}

class PlanEntitlement {
  const PlanEntitlement({
    required this.featureCode,
    required this.allowed,
    this.limitValue,
  });
  final String featureCode;
  final bool allowed;
  final int? limitValue;
  factory PlanEntitlement.fromJson(Map<String, dynamic> json) =>
      PlanEntitlement(
        featureCode: (json['feature_code'] ?? '').toString(),
        allowed: json['allowed'] != false,
        limitValue: json['limit_value'] == null
            ? null
            : int.tryParse(json['limit_value'].toString()),
      );
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.prices,
    this.entitlements = const [],
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final List<PlanPrice> prices;
  final List<PlanEntitlement> entitlements;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawPrices = (json['prices'] as List<dynamic>?) ?? const [];
    return SubscriptionPlan(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      entitlements: ((json['entitlements'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlanEntitlement.fromJson)
          .toList(),
      prices: rawPrices
          .whereType<Map<String, dynamic>>()
          .map(PlanPrice.fromJson)
          .toList(),
    );
  }
}

class StoreSubscription {
  const StoreSubscription({
    required this.id,
    required this.name,
    required this.status,
    required this.billingInterval,
    required this.currentPeriodEnd,
    this.planPriceId,
  });

  final String id;
  final String name;
  final String status;
  final String billingInterval;
  final String currentPeriodEnd;
  final String? planPriceId;

  factory StoreSubscription.fromJson(Map<String, dynamic> json) {
    return StoreSubscription(
      id: (json['id'] ?? '').toString(),
      planPriceId: json['plan_price_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? 'trial').toString(),
      billingInterval: (json['billing_interval'] ?? 'monthly').toString(),
      currentPeriodEnd: (json['current_period_end'] ?? '').toString(),
    );
  }
}

class SubscriptionInvoice {
  const SubscriptionInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.amountIdr,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
  });

  final String id;
  final String invoiceNumber;
  final int amountIdr;
  final String status;
  final String periodStart;
  final String periodEnd;

  factory SubscriptionInvoice.fromJson(Map<String, dynamic> json) {
    return SubscriptionInvoice(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      amountIdr: int.tryParse((json['amount_idr'] ?? '0').toString()) ?? 0,
      status: (json['status'] ?? 'unpaid').toString(),
      periodStart: (json['period_start'] ?? '').toString(),
      periodEnd: (json['period_end'] ?? '').toString(),
    );
  }
}

class UsageCounter {
  const UsageCounter({
    required this.featureCode,
    required this.periodKey,
    required this.value,
  });

  final String featureCode;
  final String periodKey;
  final int value;

  factory UsageCounter.fromJson(Map<String, dynamic> json) {
    return UsageCounter(
      featureCode: (json['feature_code'] ?? '').toString(),
      periodKey: (json['period_key'] ?? '').toString(),
      value: int.tryParse((json['value'] ?? '0').toString()) ?? 0,
    );
  }
}

class BillingBundle {
  const BillingBundle({
    required this.subscriptions,
    required this.invoices,
    required this.usage,
    required this.publicPlans,
    required this.paymentInstructions,
    this.entitlements = const [],
    this.accessAvailable = false,
    this.currentSubscriptionId,
    this.pilotUntil,
  });

  final List<StoreSubscription> subscriptions;
  final List<SubscriptionInvoice> invoices;
  final List<UsageCounter> usage;
  final List<SubscriptionPlan> publicPlans;
  final String paymentInstructions;
  final List<PlanEntitlement> entitlements;
  final bool accessAvailable;
  final String? currentSubscriptionId;
  final String? pilotUntil;
}

/// Item pusat notifikasi (`PRD` Bab 8.1 & `desain.md` Bab 5.3 / 8.15).
class SellerNotification {
  const SellerNotification({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.eventType,
    required this.title,
    required this.summary,
    required this.resourceType,
    required this.resourceId,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String eventType;
  final String title;
  final String summary;
  final String resourceType;
  final String resourceId;
  final String createdAt;
  final bool isRead;

  SellerNotification copyWith({bool? isRead}) {
    return SellerNotification(
      id: id,
      storeId: storeId,
      storeName: storeName,
      eventType: eventType,
      title: title,
      summary: summary,
      resourceType: resourceType,
      resourceId: resourceId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
