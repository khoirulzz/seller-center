import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/ns_product_image.dart';
import '../../../core/widgets/ns_form_exit_guard.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../core/errors/ns_error_mapper.dart';
import '../../../core/theme/ns_colors.dart';
import 'product_variant_dialog.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/formatters.dart';
import '../../../core/config/slug_utils.dart';
import '../../../core/config/status_dictionary.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class ProductsAndInventoryScreen extends StatefulWidget {
  const ProductsAndInventoryScreen({
    super.key,
    required this.appState,
    required this.initialSubTab,
  });
  final SellerAppState appState;
  final String initialSubTab;
  @override
  State<ProductsAndInventoryScreen> createState() =>
      _ProductsAndInventoryScreenState();
}

class _ProductsAndInventoryScreenState
    extends State<ProductsAndInventoryScreen> {
  String? store;
  int revision = -1;
  late String tab;
  String query = '', status = 'all';
  bool lowStock = false;
  Future<List<Product>>? products;
  Future<List<InventoryMovement>>? ledger;
  void load() {
    store = widget.appState.activeStore?.id;
    revision = widget.appState.storeDataRevision;
    products = store == null
        ? null
        : widget.appState.repository.fetchProducts(store!);
    ledger = store == null
        ? null
        : widget.appState.repository.fetchInventoryLedger(store!);
  }

  @override
  void initState() {
    super.initState();
    tab = widget.initialSubTab == 'stock' ? 'stock' : 'catalog';
    load();
    widget.appState.addListener(changed);
  }

  void changed() {
    if (store != widget.appState.activeStore?.id ||
        revision != widget.appState.storeDataRevision) {
      setState(load);
    }
  }

  @override
  void didUpdateWidget(covariant ProductsAndInventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(
        () => tab = widget.initialSubTab == 'stock' ? 'stock' : 'catalog',
      );
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(changed);
    super.dispose();
  }

  Future<void> archive(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan produk?'),
        content: Text(
          '${product.name} tidak akan tampil di toko. Pesanan yang sudah dibuat tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = store;
    if (id == null) return;
    try {
      await widget.appState.repository.archiveProduct(
        storeId: id,
        productId: product.id,
        role: widget.appState.activeRole,
      );
      widget.appState.notifyStoreDataMutated();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Produk diarsipkan.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> adjust(Product p, ProductVariant v) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => StockAmountDialog(product: p, variant: v),
    );
    if (amount == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan perubahan stok?'),
        content: Text(
          'Stok ${v.sku}: ${v.stockQty} → $amount. Pastikan jumlah terbaru benar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan stok'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.appState.repository.adjustVariantStock(
        storeId: store!,
        productId: p.id,
        variantSku: v.sku,
        expectedOldStockQty: v.stockQty,
        newStockQty: amount,
        reason: 'Penyesuaian stok manual',
        role: widget.appState.activeRole,
      );
      widget.appState.notifyStoreDataMutated();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e. Muat ulang untuk melihat stok terbaru.')),
        );
      setState(load);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(load);
      try {
        await products;
      } catch (_) {}
    },
    child: ListView(
      key: const PageStorageKey('products'),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Produk & stok',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.appState.activeRole.canManageCatalog)
              FilledButton.icon(
                onPressed: () => context.push('/produk/editor'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'catalog', label: Text('Katalog')),
            ButtonSegment(value: 'stock', label: Text('Stok & riwayat')),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cari produk atau SKU',
          ),
          onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (tab == 'catalog') ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in ['all', 'active', 'draft', 'archived'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        s == 'all' ? 'Semua' : NsStatusDictionary.label(s),
                      ),
                      selected: status == s,
                      onSelected: (_) => setState(() => status = s),
                    ),
                  ),
              ],
            ),
          ),
        ] else
          SwitchListTile.adaptive(
            title: const Text('Hanya stok menipis'),
            value: lowStock,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => lowStock = v),
          ),
        FutureBuilder<List<Product>>(
          future: products,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done)
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            if (snap.hasError)
              return ListTile(
                title: const Text('Produk belum dapat dimuat.'),
                subtitle: Text('${snap.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(load),
                ),
              );
            final items = (snap.data ?? [])
                .where(
                  (p) =>
                      (tab != 'catalog' ||
                          status == 'all' ||
                          p.status == status) &&
                      (p.name.toLowerCase().contains(query) ||
                          p.variants.any(
                            (v) => v.sku.toLowerCase().contains(query),
                          )) &&
                      (tab != 'stock' ||
                          !lowStock ||
                          p.variants.any((v) => v.availableStock <= 5)),
                )
                .toList();
            if (items.isEmpty)
              return NsEmptyState(
                iconName: 'box',
                title: query.isEmpty
                    ? 'Belum ada produk pada pilihan ini'
                    : 'Produk tidak ditemukan',
                description: query.isEmpty
                    ? 'Tambahkan produk, foto, dan stok agar pembeli dapat memilih barangmu.'
                    : 'Coba nama atau SKU lain, atau ubah filter status.',
                actionLabel:
                    widget.appState.activeRole.canManageCatalog && query.isEmpty
                    ? 'Tambah produk'
                    : null,
                onAction: () => context.push('/produk/editor'),
              );
            return Column(
              children: [
                for (final p in items) ...[
                  if (tab == 'catalog')
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: SizedBox(
                        width: 64,
                        height: 72,
                        child: NsProductImage(
                          repository: widget.appState.repository,
                          url: p.primaryImageUrl,
                          label: p.name,
                        ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${NsFormatters.rupiah(p.effectiveCatalogPriceIdr)}\n${NsStatusDictionary.label(p.status)} • ${p.totalAvailableStock} tersedia',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opsi produk',
                        onSelected: (action) {
                          if (action == 'edit')
                            context.push(
                              '/produk/editor?id=${Uri.encodeQueryComponent(p.id)}',
                            );
                          if (action == 'archive') archive(p);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Lihat / edit'),
                          ),
                          if (widget.appState.activeRole.canManageCatalog &&
                              p.status != 'archived')
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('Arsipkan'),
                            ),
                        ],
                      ),
                      onTap: () => context.push(
                        '/produk/editor?id=${Uri.encodeQueryComponent(p.id)}',
                      ),
                    )
                  else ...[
                    ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        'Tersedia ${p.totalAvailableStock} • Dipesan ${p.totalReservedStock}',
                      ),
                    ),
                    for (final v in p.variants)
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 22),
                        title: Text('${v.optionLabel} • ${v.sku}'),
                        subtitle: Text(
                          'Total ${v.stockQty} • Dipesan ${v.reservedQty}',
                        ),
                        trailing: TextButton(
                          onPressed: widget.appState.activeRole.canManageCatalog
                              ? () => adjust(p, v)
                              : null,
                          child: Text('${v.availableStock} tersedia'),
                        ),
                      ),
                  ],
                  const Divider(height: 1),
                ],
              ],
            );
          },
        ),
        if (tab == 'stock') ...[
          const SizedBox(height: 24),
          Text('Riwayat stok', style: Theme.of(context).textTheme.titleLarge),
          FutureBuilder<List<InventoryMovement>>(
            future: ledger,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done)
                return const LinearProgressIndicator();
              if (snap.hasError)
                return const Text('Riwayat belum dapat dimuat.');
              return Column(
                children: [
                  if ((snap.data ?? []).isEmpty)
                    const ListTile(title: Text('Belum ada perubahan stok.')),
                  for (final movement in (snap.data ?? []).take(50))
                    ListTile(
                      title: Text(movement.productName),
                      subtitle: Text(
                        '${NsStatusDictionary.label(movement.kind)} • ${NsFormatters.dateTime(movement.createdAt)}',
                      ),
                      trailing: Text(
                        '${movement.quantityDelta > 0 ? '+' : ''}${movement.quantityDelta}',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    super.key,
    required this.appState,
    this.productId,
  });
  final SellerAppState appState;
  final String? productId;
  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final name = TextEditingController(),
      slug = TextEditingController(),
      description = TextEditingController(),
      category = TextEditingController(),
      price = TextEditingController();
  final picker = ImagePicker();
  Timer? autosave;
  Future<void> draftWrite = Future.value();
  late final String storeId, userId;
  Product? original;
  List<ProductVariant> variants = [
    const ProductVariant(sku: 'UTAMA', optionLabel: 'Standar', stockQty: 0),
  ];
  List<GalleryPhoto> gallery = [];
  final previews = <String, Uint8List>{};
  String? primaryImage, error;
  Uint8List? pendingPreview;
  List<XFile> retryFiles = [];
  bool retryPrimary = false;
  String status = 'draft';
  bool initializing = true,
      saving = false,
      dirty = false,
      uploading = false,
      slugEdited = false;
  DateTime? draftSavedAt;
  int uploadDone = 0, uploadTotal = 0;
  String get resourceId => widget.productId ?? 'new';
  bool get busy => initializing || saving || uploading;
  @override
  void initState() {
    super.initState();
    storeId = widget.appState.activeStore!.id;
    userId = widget.appState.user!.id;
    WidgetsBinding.instance.addObserver(this);
    for (final c in [name, slug, description, category, price]) {
      c.addListener(changed);
    }
    init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused)
      unawaited(saveDraft());
  }

  Future<void> init() async {
    try {
      if (widget.productId != null) {
        final all = await widget.appState.repository.fetchProducts(storeId);
        if (!mounted) return;
        final p = all.firstWhere((p) => p.id == widget.productId);
        original = p;
        name.text = p.name;
        slug.text = p.slug;
        description.text = p.description;
        category.text = p.category;
        price.text = p.priceIdr.toString();
        status = p.status;
        variants = [...p.variants];
        gallery = [...p.gallery];
        primaryImage = p.primaryImageUrl;
        slugEdited = true;
      }
      final draft = await widget.appState.repository.drafts.loadDraft(
        userId: userId,
        storeId: storeId,
        resourceType: 'product',
        resourceId: resourceId,
      );
      if (!mounted) return;
      if (draft != null) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Lanjutkan draft?'),
            content: Text(
              'Perubahan terakhir ${NsFormatters.dateTime(draft.updatedAt.toIso8601String())}. Draft ini belum disimpan ke toko.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Buang draft'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (restore == true) {
          final d = draft.data;
          name.text = (d['name'] ?? '').toString();
          slug.text = (d['slug'] ?? '').toString();
          description.text = (d['description'] ?? '').toString();
          category.text = (d['category'] ?? '').toString();
          price.text = (d['price'] ?? '').toString();
          status = (d['status'] ?? 'draft').toString();
          primaryImage = d['primary']?.toString();
          gallery = ((d['gallery'] as List?) ?? [])
              .whereType<Map<String, dynamic>>()
              .map(GalleryPhoto.fromJson)
              .toList();
          variants = ((d['variants'] as List?) ?? [])
              .whereType<Map<String, dynamic>>()
              .map(ProductVariant.fromJson)
              .toList();
          dirty = true;
          draftSavedAt = draft.updatedAt;
          slugEdited = true;
        } else if (restore == false) {
          await deleteDraft();
        }
      }
      widget.appState.setHasUnsavedFormDraft(dirty);
    } catch (e) {
      error = NsErrorMapper.toUserMessage(e);
    } finally {
      if (mounted) setState(() => initializing = false);
    }
  }

  void changed() {
    if (initializing || !mounted) return;
    setState(() {
      dirty = true;
      draftSavedAt = null;
    });
    widget.appState.setHasUnsavedFormDraft(true);
    autosave?.cancel();
    autosave = Timer(
      const Duration(milliseconds: 850),
      () => unawaited(saveDraft()),
    );
  }

  Future<void> saveDraft() async {
    autosave?.cancel();
    if (!dirty) return;
    final payload = <String, dynamic>{
      'name': name.text,
      'slug': slug.text,
      'description': description.text,
      'category': category.text,
      'price': price.text,
      'status': status,
      'primary': primaryImage,
      'gallery': gallery.map((g) => g.toJson()).toList(),
      'variants': variants
          .map((v) => {...v.toJson(), 'reserved_qty': v.reservedQty})
          .toList(),
    };
    final repository = widget.appState.repository;
    draftWrite = draftWrite.then(
      (_) => repository.drafts.saveDraft(
        userId: userId,
        storeId: storeId,
        resourceType: 'product',
        resourceId: resourceId,
        payload: payload,
      ),
    );
    try {
      await draftWrite;
      if (mounted) setState(() => draftSavedAt = DateTime.now());
    } catch (_) {
      draftWrite = Future.value();
      if (mounted)
        setState(
          () => error = 'Draft belum tersimpan di perangkat. Coba simpan draft lagi sebelum keluar.',
        );
    }
  }

  Future<void> deleteDraft() async {
    autosave?.cancel();
    await draftWrite;
    await widget.appState.repository.drafts.deleteDraft(
      userId: userId,
      storeId: storeId,
      resourceType: 'product',
      resourceId: resourceId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    autosave?.cancel();
    // Snapshot before disposing controllers. All outstanding writes are serialized.
    if (dirty) unawaited(saveDraft());
    widget.appState.setHasUnsavedFormDraft(false);
    for (final c in [name, slug, description, category, price]) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  Future<bool> confirmExit() async {
    if (!dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan perubahan dulu?'),
        content: const Text(
          'Simpan draft untuk melanjutkan nanti. Produk belum akan tampil di toko.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Tetap edit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'draft'),
            child: const Text('Simpan draft'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (result == 'draft') {
      await saveDraft();
      if (draftSavedAt == null || !mounted) return false;
    } else if (result == 'discard') {
      try {
        await deleteDraft();
      } catch (_) {
        return false;
      }
    } else {
      return false;
    }
    if (!mounted) return false;
    setState(() => dirty = false);
    widget.appState.setHasUnsavedFormDraft(false);
    return true;
  }

  Future<void> choosePhoto({required bool primary}) async {
    if (busy || (!primary && gallery.length >= AppConfig.maxGalleryPhotos))
      return;
    FocusManager.instance.primaryFocus?.unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Foto produk'),
              subtitle: Text('JPG, PNG, atau WebP • maksimal 5 MB per foto'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      List<XFile> files;
      if (!primary && source == ImageSource.gallery) {
        files = await picker.pickMultiImage(
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
        );
      } else {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
        );
        files = file == null ? [] : [file];
      }
      if (!mounted || files.isEmpty) return;
      if (!primary &&
          files.length + gallery.length > AppConfig.maxGalleryPhotos) {
        setState(
          () => error =
              'Sisa galeri ${12 - gallery.length} foto. Pilih lebih sedikit foto.',
        );
        return;
      }
      await uploadPhotos(files, primary: primary);
    } catch (e) {
      if (mounted)
        setState(
          () => error = 'Foto belum dapat dibuka. Periksa izin kamera/galeri dan coba lagi.',
        );
    }
  }

  Future<void> uploadPhotos(List<XFile> files, {required bool primary}) async {
    setState(() {
      uploading = true;
      error = null;
      uploadDone = 0;
      uploadTotal = files.length;
      retryFiles = [];
    });
    for (var i = 0; i < files.length && mounted; i++) {
      try {
        final bytes = await files[i].readAsBytes();
        if (bytes.isEmpty ||
            bytes.lengthInBytes > AppConfig.maxMediaUploadBytes)
          throw const FormatException('Foto maksimal 5 MB.');
        String? mime;
        if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8)
          mime = 'image/jpeg';
        if (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47)
          mime = 'image/png';
        if (bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
          mime = 'image/webp';
        if (mime == null)
          throw const FormatException('Gunakan JPG, PNG, atau WebP.');
        if (!mounted) return;
        setState(() => pendingPreview = bytes);
        final result = await widget.appState.repository.uploadMediaBytes(
          storeId: storeId,
          bytes: bytes,
          mimeType: mime,
        );
        if (!mounted) return;
        if (result.url.isEmpty)
          throw const FormatException(
            'Alamat foto belum diterima. Coba unggah lagi.',
          );
        setState(() {
          if (primary) {
            previews.remove(primaryImage);
            primaryImage = result.url;
          } else {
            gallery.add(GalleryPhoto(url: result.url));
          }
          previews[result.url] = bytes;
          uploadDone++;
          pendingPreview = null;
        });
        changed();
      } catch (e) {
        if (mounted)
          setState(() {
            retryFiles = files.sublist(i);
            retryPrimary = primary;
            error =
                'Foto ${i + 1} belum diunggah. ${NsErrorMapper.toUserMessage(e)} Foto yang berhasil tetap ada.';
          });
        break;
      }
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> editVariant([int? index]) async {
    if (busy || !widget.appState.activeRole.canManageCatalog) return;
    final result = await showDialog<ProductVariant>(
      context: context,
      builder: (_) => ProductVariantDialog(
        variant: index == null ? null : variants[index],
        otherSkus: variants
            .asMap()
            .entries
            .where((e) => e.key != index)
            .map((e) => e.value.sku.toLowerCase())
            .toSet(),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          variants.add(result);
        } else {
          variants[index] = result;
        }
      });
      changed();
    }
  }

  Future<void> save() async {
    if (busy || !widget.appState.activeRole.canManageCatalog) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!form.currentState!.validate()) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    if (variants.isEmpty ||
        variants.any(
          (v) => v.sku.trim().isEmpty || v.stockQty < v.reservedQty,
        )) {
      setState(
        () => error = 'Lengkapi SKU dan stok pada bagian Varian & stok.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final product = Product(
        id: original?.id ?? '',
        slug: NsSlugUtils.normalize(slug.text),
        name: name.text.trim(),
        description: description.text.trim(),
        priceIdr: int.parse(price.text),
        category: category.text.trim(),
        primaryImageUrl: primaryImage,
        gallery: [...gallery],
        status: status,
        variants: [...variants],
      );
      await widget.appState.repository.saveProduct(
        storeId: storeId,
        product: product,
        isUpdate: original != null,
        role: widget.appState.activeRole,
      );
      autosave?.cancel();
      dirty = false;
      // Server success is authoritative; a local cleanup failure must not repeat POST.
      try {
        await deleteDraft();
      } catch (_) {}
      widget.appState.setHasUnsavedFormDraft(false);
      widget.appState.notifyStoreDataMutated();
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil disimpan.')),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => error = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget section(String title, String subtitle, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => NsFormExitGuard(
    dirty: dirty,
    busy: busy,
    confirmExit: confirmExit,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Tambah produk' : 'Edit produk'),
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        actions: [
          IconButton(
            tooltip: 'Simpan draft di perangkat',
            onPressed: busy
                ? null
                : () async {
                    await saveDraft();
                    if (mounted && draftSavedAt != null)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Draft disimpan di perangkat.'),
                        ),
                      );
                  },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: NsColors.statusDangerText),
                  ),
                ),
              ),
            if (dirty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  draftSavedAt == null
                      ? 'Perubahan belum disimpan ke toko'
                      : 'Draft aman di perangkat • belum disimpan ke toko',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    busy ||
                        !widget.appState.activeRole.canManageCatalog ||
                        (widget.productId != null && original == null)
                    ? null
                    : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 20),
                label: Text(saving ? 'Menyimpan…' : 'Simpan produk'),
              ),
            ),
          ],
        ),
      ),
      body: initializing
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: saving,
              child: Form(
                key: form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  controller: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    if (!widget.appState.activeRole.canManageCatalog)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('Akun ini hanya dapat melihat produk.'),
                      ),
                    section(
                      'Informasi produk',
                      'Kolom bertanda * wajib diisi.',
                      [
                        TextFormField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama produk *',
                            hintText: 'Kemeja batik lengan pendek',
                          ),
                          onChanged: (v) {
                            if (!slugEdited && widget.productId == null)
                              slug.text = NsSlugUtils.normalize(v);
                          },
                          validator: (v) => v!.trim().length < 2
                              ? 'Nama produk minimal 2 karakter.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: slug,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => slugEdited = true,
                          decoration: const InputDecoration(
                            labelText: 'Link produk *',
                            hintText: 'kemeja-batik',
                            helperText: 'Bagian akhir alamat produk. Gunakan huruf kecil, angka, dan tanda hubung.',
                          ),
                          validator: (v) => NsSlugUtils.validate(
                            v!.trim(),
                            entityLabel: 'Link produk',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: description,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Deskripsi (opsional)',
                            hintText:
                                'Bahan, ukuran, warna, dan cara perawatan.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: category,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            hintText: 'Pakaian pria',
                            helperText: 'Kelompok produk yang membantu pembeli mencari barang.',
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Isi kategori produk.' : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Harga dasar *',
                            prefixText: 'Rp ',
                            hintText: '150000',
                            helperText: 'Harga per barang. Harga khusus dapat diatur pada varian.',
                          ),
                          validator: (v) => int.tryParse(v ?? '') == null
                              ? 'Isi harga dalam rupiah.'
                              : int.parse(v!) > 1000000000
                              ? 'Harga maksimal Rp1.000.000.000.'
                              : null,
                        ),
                      ],
                    ),
                    section(
                      'Foto produk',
                      'Ketuk foto untuk memperbesar. Foto utama tampil pada katalog.',
                      [
                        AspectRatio(
                          aspectRatio: 1.3,
                          child: NsProductImage(
                            repository: widget.appState.repository,
                            url: primaryImage,
                            bytes: previews[primaryImage],
                            fit: BoxFit.contain,
                            label: 'Foto utama',
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => choosePhoto(primary: true),
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                primaryImage == null
                                    ? 'Tambah foto utama'
                                    : 'Ganti foto utama',
                              ),
                            ),
                            if (primaryImage != null)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        setState(() {
                                          previews.remove(primaryImage);
                                          primaryImage = null;
                                        });
                                        changed();
                                      },
                                child: const Text('Hapus foto utama'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Galeri tambahan (${gallery.length}/12)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tahan pegangan untuk mengurutkan atau gunakan menu foto.',
                        ),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: gallery.length,
                          onReorder: (old, next) {
                            if (busy) return;
                            setState(() {
                              if (next > old) next--;
                              final item = gallery.removeAt(old);
                              gallery.insert(next, item);
                            });
                            changed();
                          },
                          itemBuilder: (context, i) => ListTile(
                            key: ValueKey(gallery[i].url),
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 64,
                              height: 64,
                              child: NsProductImage(
                                repository: widget.appState.repository,
                                url: gallery[i].url,
                                bytes: previews[gallery[i].url],
                                label: 'Foto galeri ${i + 1}',
                              ),
                            ),
                            title: Text('Foto ${i + 1}'),
                            subtitle: ReorderableDragStartListener(
                              index: i,
                              enabled: !busy,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !busy,
                              tooltip: 'Atur foto ${i + 1}',
                              onSelected: (action) {
                                setState(() {
                                  if (action == 'remove') {
                                    previews.remove(gallery[i].url);
                                    gallery.removeAt(i);
                                  }
                                  if (action == 'up') {
                                    final item = gallery.removeAt(i);
                                    gallery.insert(i - 1, item);
                                  }
                                  if (action == 'down') {
                                    final item = gallery.removeAt(i);
                                    gallery.insert(i + 1, item);
                                  }
                                });
                                changed();
                              },
                              itemBuilder: (_) => [
                                if (i > 0)
                                  const PopupMenuItem(
                                    value: 'up',
                                    child: Text('Pindahkan ke atas'),
                                  ),
                                if (i < gallery.length - 1)
                                  const PopupMenuItem(
                                    value: 'down',
                                    child: Text('Pindahkan ke bawah'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Hapus dari galeri'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: busy || gallery.length >= 12
                              ? null
                              : () => choosePhoto(primary: false),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Tambah foto galeri'),
                        ),
                        if (pendingPreview != null)
                          SizedBox(
                            height: 120,
                            child: NsProductImage(
                              repository: widget.appState.repository,
                              bytes: pendingPreview,
                              fit: BoxFit.contain,
                              label: 'Foto yang sedang diunggah',
                            ),
                          ),
                        if (uploading) ...[
                          LinearProgressIndicator(
                            value: uploadTotal == 0
                                ? null
                                : uploadDone / uploadTotal,
                          ),
                          Text(
                            'Mengunggah foto ${uploadDone + 1} dari $uploadTotal…',
                          ),
                        ],
                        if (retryFiles.isNotEmpty && !uploading)
                          OutlinedButton.icon(
                            onPressed: () => uploadPhotos([
                              ...retryFiles,
                            ], primary: retryPrimary),
                            icon: const Icon(Icons.refresh),
                            label: Text('Coba lagi ${retryFiles.length} foto'),
                          ),
                      ],
                    ),
                    section(
                      'Varian & stok',
                      'Tanpa pilihan ukuran/warna? Gunakan varian Standar. Stok 0 berarti habis.',
                      [
                        for (var i = 0; i < variants.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(variants[i].optionLabel),
                              subtitle: Text(
                                'SKU ${variants[i].sku}\n${variants[i].availableStock} tersedia • ${variants[i].reservedQty} dipesan\n${variants[i].status == 'inactive' ? 'Nonaktif' : 'Aktif'}',
                              ),
                              isThreeLine: true,
                              onTap: () => editVariant(i),
                              trailing: PopupMenuButton<String>(
                                enabled: !busy,
                                tooltip:
                                    'Opsi varian ${variants[i].optionLabel}',
                                onSelected: (action) {
                                  if (action == 'edit') editVariant(i);
                                  if (action == 'remove') {
                                    setState(() => variants.removeAt(i));
                                    changed();
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit varian'),
                                  ),
                                  if (variants.length > 1 &&
                                      variants[i].reservedQty == 0)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Hapus varian'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => editVariant(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah varian'),
                        ),
                      ],
                    ),
                    section(
                      'Status produk',
                      'Aktif: dapat dijual jika toko terbit. Draft dan arsip disembunyikan dari pembeli.',
                      [
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status publikasi',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'draft',
                              child: Text('Draft — belum dijual'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Aktif — siap dijual'),
                            ),
                            DropdownMenuItem(
                              value: 'archived',
                              child: Text('Arsip — sembunyikan'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => status = v);
                                    changed();
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
