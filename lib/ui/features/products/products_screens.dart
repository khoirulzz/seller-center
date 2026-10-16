import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/formatters.dart';
import '../../../core/config/slug_utils.dart';
import '../../../core/config/status_dictionary.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class ProductsAndInventoryScreen extends StatefulWidget {
  const ProductsAndInventoryScreen({super.key, required this.appState, required this.initialSubTab});
  final SellerAppState appState;
  final String initialSubTab;
  @override State<ProductsAndInventoryScreen> createState() => _ProductsAndInventoryScreenState();
}
class _ProductsAndInventoryScreenState extends State<ProductsAndInventoryScreen> {
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
    products = store == null ? null : widget.appState.repository.fetchProducts(store!);
    ledger = store == null ? null : widget.appState.repository.fetchInventoryLedger(store!);
  }
  @override void initState() {
    super.initState();
    tab = widget.initialSubTab == 'stock' ? 'stock' : 'catalog';
    load();
    widget.appState.addListener(changed);
  }
  void changed() {
    if (store != widget.appState.activeStore?.id || revision != widget.appState.storeDataRevision) {
      setState(load);
    }
  }
  @override void dispose() { widget.appState.removeListener(changed); super.dispose(); }
  Future<void> archive(Product product) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Arsipkan produk?'),
      content: Text('${product.name} tidak akan tampil di toko. Pesanan yang sudah dibuat tetap tersimpan.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arsipkan')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    final id = store;
    if (id == null) return;
    try {
      await widget.appState.repository.archiveProduct(storeId: id, productId: product.id, role: widget.appState.activeRole);
      widget.appState.notifyStoreDataMutated();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk diarsipkan.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  Future<void> adjust(Product p, ProductVariant v) async {
    final controller = TextEditingController(text: v.stockQty.toString());
    final amount = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Perbarui stok'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p.name} • ${v.optionLabel}'),
        Text('Total ${v.stockQty} • dipesan ${v.reservedQty} • tersedia ${v.availableStock}'),
        const SizedBox(height: 16),
        TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total stok baru')),
        const SizedBox(height: 12),
        const Text('Perubahan stok dicatat di riwayat server. Alasan terperinci menunggu dukungan API khusus.', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () {
          final n = int.tryParse(controller.text);
          if (n != null && n >= v.reservedQty) Navigator.pop(ctx, n);
        }, child: const Text('Tinjau')),
      ],
    ));
    controller.dispose();
    if (amount == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Simpan perubahan stok?'),
      content: Text('Stok ${v.sku}: ${v.stockQty} → $amount. Pastikan jumlah terbaru benar.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan stok')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await widget.appState.repository.adjustVariantStock(
        storeId: store!, productId: p.id, variantSku: v.sku,
        expectedOldStockQty: v.stockQty, newStockQty: amount,
        reason: 'Penyesuaian stok manual', role: widget.appState.activeRole,
      );
      widget.appState.notifyStoreDataMutated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e. Muat ulang untuk melihat stok terbaru.')));
      setState(load);
    }
  }
  @override Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { setState(load); try { await products; } catch (_) {} },
    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), children: [
      Row(children: [
        Expanded(child: Text('Produk & stok', style: Theme.of(context).textTheme.headlineSmall)),
        if (widget.appState.activeRole.canManageCatalog)
          IconButton(tooltip: 'Tambah produk', onPressed: () => context.push('/produk/editor'), icon: const Icon(Icons.add_circle_outline)),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'catalog', label: Text('Katalog')), ButtonSegment(value: 'stock', label: Text('Stok & riwayat'))],
        selected: {tab}, onSelectionChanged: (value) => setState(() => tab = value.first),
      ),
      const SizedBox(height: 14),
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari produk atau SKU'),
        onChanged: (v) => setState(() => query = v.trim().toLowerCase())),
      const SizedBox(height: 12),
      if (tab == 'catalog') ...[
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final s in ['all', 'active', 'draft', 'archived'])
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text(s == 'all' ? 'Semua' : NsStatusDictionary.label(s)),
              selected: status == s, onSelected: (_) => setState(() => status = s),
            )),
        ])),
      ] else SwitchListTile.adaptive(
        title: const Text('Hanya stok menipis'), value: lowStock,
        contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => lowStock = v),
      ),
      FutureBuilder<List<Product>>(future: products, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return ListTile(title: const Text('Produk belum dapat dimuat.'), subtitle: Text('${snap.error}'), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(load)));
        final items = (snap.data ?? []).where((p) =>
          (tab != 'catalog' || status == 'all' || p.status == status) &&
          (p.name.toLowerCase().contains(query) || p.variants.any((v) => v.sku.toLowerCase().contains(query))) &&
          (tab != 'stock' || !lowStock || p.variants.any((v) => v.availableStock <= 5))
        ).toList();
        if (items.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(query.isEmpty ? 'Belum ada produk.' : 'Produk tidak ditemukan.'));
        return Column(children: [
          for (final p in items) ...[
            if (tab == 'catalog') ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              leading: _ProductThumb(url: p.primaryImageUrl),
              title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${NsStatusDictionary.label(p.status)} • ${p.variants.length} varian • tersedia ${p.totalAvailableStock}'),
              trailing: PopupMenuButton<String>(tooltip: 'Opsi produk', onSelected: (action) {
                if (action == 'edit') context.push('/produk/editor?id=${Uri.encodeQueryComponent(p.id)}');
                if (action == 'archive') archive(p);
              }, itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Lihat / edit')),
                if (widget.appState.activeRole.canManageCatalog && p.status != 'archived')
                  const PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
              ]),
              onTap: () => context.push('/produk/editor?id=${Uri.encodeQueryComponent(p.id)}'),
            ) else ...[
              ListTile(title: Text(p.name), subtitle: Text('Tersedia ${p.totalAvailableStock} • Dipesan ${p.totalReservedStock}')),
              for (final v in p.variants) ListTile(
                contentPadding: const EdgeInsets.only(left: 22),
                title: Text('${v.optionLabel} • ${v.sku}'),
                subtitle: Text('Total ${v.stockQty} • Dipesan ${v.reservedQty}'),
                trailing: TextButton(onPressed: widget.appState.activeRole.canManageCatalog ? () => adjust(p, v) : null, child: Text('${v.availableStock} tersedia')),
              ),
            ],
            const Divider(height: 1),
          ],
        ]);
      }),
      if (tab == 'stock') ...[
        const SizedBox(height: 24), Text('Riwayat stok', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<InventoryMovement>>(future: ledger, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
          if (snap.hasError) return const Text('Riwayat belum dapat dimuat.');
          return Column(children: [
            if ((snap.data ?? []).isEmpty) const ListTile(title: Text('Belum ada perubahan stok.')),
            for (final movement in (snap.data ?? []).take(50))
              ListTile(title: Text(movement.productName),
                subtitle: Text('${NsStatusDictionary.label(movement.kind)} • ${NsFormatters.dateTime(movement.createdAt)}'),
                trailing: Text('${movement.quantityDelta > 0 ? '+' : ''}${movement.quantityDelta}')),
          ]);
        }),
      ],
    ]),
  );
}
class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String? url;
  @override Widget build(BuildContext context) {
    final src = url;
    return SizedBox(width: 58, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(9), child: src == null || src.isEmpty
      ? const ColoredBox(color: Color(0xFFF8F8F9), child: Icon(Icons.inventory_2_outlined))
      : Image.network(src.startsWith('/') ? '${AppConfig.defaultApiBaseUrl}$src' : src, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))));
  }
}
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, required this.appState, this.productId});
  final SellerAppState appState;
  final String? productId;
  @override State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}
class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final name = TextEditingController(), slug = TextEditingController(), description = TextEditingController(),
    category = TextEditingController(text: 'Produk'), price = TextEditingController();
  final picker = ImagePicker();
  Timer? autosave;
  Product? original;
  List<ProductVariant> variants = [];
  List<GalleryPhoto> gallery = [];
  String? primaryImage, error;
  String status = 'draft';
  bool loading = false, dirty = false, uploading = false;
  String get resourceId => widget.productId ?? 'new';
  String get storeId => widget.appState.activeStore!.id;
  String get userId => widget.appState.user!.id;
  @override void initState() {
    super.initState();
    for (final controller in [name, slug, description, category, price]) { controller.addListener(changed); }
    init();
  }
  Future<void> init() async {
    setState(() => loading = true);
    try {
      if (widget.productId != null) {
        final all = await widget.appState.repository.fetchProducts(storeId);
        final p = all.firstWhere((p) => p.id == widget.productId);
        original = p;
        name.text = p.name; slug.text = p.slug; description.text = p.description;
        category.text = p.category; price.text = p.priceIdr.toString(); status = p.status;
        variants = [...p.variants]; gallery = [...p.gallery]; primaryImage = p.primaryImageUrl;
      } else {
        variants = [const ProductVariant(sku: '', optionLabel: 'Default', stockQty: 0)];
      }
      final draft = await widget.appState.repository.drafts.loadDraft(
        userId: userId, storeId: storeId, resourceType: 'product', resourceId: resourceId);
      if (!mounted) return;
      if (draft != null) {
        final restore = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Lanjutkan draft?'),
          content: const Text('Ada perubahan tersimpan di perangkat ini. Draft belum dikirim ke toko.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Buang draft')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
          ]));
        if (!mounted) return;
        if (restore == true) {
          final d = draft.data;
          name.text = (d['name'] ?? name.text).toString();
          slug.text = (d['slug'] ?? slug.text).toString();
          description.text = (d['description'] ?? description.text).toString();
          category.text = (d['category'] ?? category.text).toString();
          price.text = (d['price'] ?? price.text).toString();
          status = (d['status'] ?? status).toString();
          primaryImage = d['primary']?.toString();
          gallery = ((d['gallery'] as List?) ?? []).whereType<Map<String, dynamic>>().map(GalleryPhoto.fromJson).toList();
          variants = ((d['variants'] as List?) ?? []).whereType<Map<String, dynamic>>().map(ProductVariant.fromJson).toList();
        } else {
          await widget.appState.repository.drafts.deleteDraft(userId: userId, storeId: storeId, resourceType: 'product', resourceId: resourceId);
        }
      }
      dirty = false;
      widget.appState.setHasUnsavedFormDraft(false);
    } catch (e) { error = '$e'; }
    finally { if (mounted) setState(() => loading = false); }
  }
  void changed() {
    if (loading || !mounted) return;
    if (!dirty) setState(() => dirty = true);
    widget.appState.setHasUnsavedFormDraft(true);
    autosave?.cancel();
    autosave = Timer(const Duration(milliseconds: 850), saveDraft);
  }
  Future<void> saveDraft() async {
    if (!dirty || !mounted) return;
    await widget.appState.repository.drafts.saveDraft(userId: userId, storeId: storeId,
      resourceType: 'product', resourceId: resourceId, payload: {
        'name': name.text, 'slug': slug.text, 'description': description.text,
        'category': category.text, 'price': price.text, 'status': status,
        'primary': primaryImage, 'gallery': gallery.map((g) => g.toJson()).toList(),
        'variants': variants.map((v) => {...v.toJson(), 'reserved_qty': v.reservedQty}).toList(),
      });
  }
  @override void dispose() {
    autosave?.cancel();
    if (dirty) { saveDraft(); }
    widget.appState.setHasUnsavedFormDraft(false);
    for (final c in [name, slug, description, category, price]) { c.dispose(); }
    super.dispose();
  }
  Future<bool> confirmExit() async {
    if (!dirty) return true;
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Perubahan belum disimpan'),
      content: const Text('Simpan draft di perangkat atau buang perubahan?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Tetap edit')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Buang')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'draft'), child: const Text('Simpan draft')),
      ]));
    if (result == 'draft') { await saveDraft(); if (mounted) setState(() => dirty = false); return true; }
    if (result == 'discard') {
      await widget.appState.repository.drafts.deleteDraft(userId: userId, storeId: storeId, resourceType: 'product', resourceId: resourceId);
      if (mounted) setState(() => dirty = false); return true;
    }
    return false;
  }
  int uploadDone = 0, uploadTotal = 0;
  Future<void> choosePhoto({required bool primary}) async {
    if (uploading || (gallery.length >= AppConfig.maxGalleryPhotos && !primary)) return;
    final source = await showModalBottomSheet<ImageSource>(context: context, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Pilih dari galeri'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Ambil foto'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera)),
      ])));
    if (source == null || !mounted) return;
    List<XFile> selected = [];
    try {
      if (!primary && source == ImageSource.gallery) {
        selected = await picker.pickMultiImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 82);
      } else {
        final file = await picker.pickImage(source: source, maxWidth: 1800, maxHeight: 1800, imageQuality: 82);
        if (file != null) selected = [file];
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Tidak dapat membuka foto. Coba lagi.');
      return;
    }
    if (selected.isEmpty || !mounted) return;
    if (!primary && selected.length + gallery.length > AppConfig.maxGalleryPhotos) {
      setState(() => error = 'Galeri maksimal 12 foto. Pilih lebih sedikit foto.');
      return;
    }
    setState(() { uploading = true; error = null; uploadDone = 0; uploadTotal = selected.length; });
    for (final file in selected) {
      if (!mounted) break;
      try {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty || bytes.lengthInBytes > AppConfig.maxMediaUploadBytes) {
          throw const FormatException('Foto harus berukuran kurang dari 5 MB.');
        }
        String? mime;
        if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
          mime = 'image/jpeg';
        } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) {
          mime = 'image/png';
        } else if (bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
          mime = 'image/webp';
        }
        if (mime == null) throw const FormatException('Gunakan JPG, PNG, atau WebP.');
        final result = await widget.appState.repository.uploadMediaBytes(
          storeId: storeId, bytes: bytes, mimeType: mime);
        if (!mounted) break;
        setState(() {
          if (primary) { primaryImage = result.url; }
          else { gallery.add(GalleryPhoto(url: result.url)); }
          uploadDone++;
        });
        changed();
      } catch (e) {
        if (mounted) setState(() => error = 'Foto ${uploadDone + 1} belum berhasil diunggah: $e. Foto lain yang berhasil tetap tersimpan dalam draft.');
        break;
      }
    }
    if (mounted) setState(() => uploading = false);
  }
  Future<void> editVariant([int? index]) async {
    final variant = index == null ? null : variants[index];
    final sku = TextEditingController(text: variant?.sku ?? '');
    final label = TextEditingController(text: variant?.optionLabel ?? '');
    final qty = TextEditingController(text: (variant?.stockQty ?? 0).toString());
    final override = TextEditingController(text: variant?.priceOverrideIdr?.toString() ?? '');
    var active = variant?.status != 'inactive';
    String? validation;
    final result = await showDialog<ProductVariant>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(index == null ? 'Tambah varian' : 'Edit varian'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: label, decoration: const InputDecoration(labelText: 'Nama pilihan, mis. Biru / L')),
        TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU unik')),
        TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Total stok', helperText: 'Dipesan: ${variant?.reservedQty ?? 0}')),
        TextField(controller: override, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga khusus (opsional)')),
        SwitchListTile(title: const Text('Varian aktif'), value: active, onChanged: (v) => update(() => active = v)),
        if (validation != null) Text(validation!, style: const TextStyle(color: Colors.red)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () {
          final q = int.tryParse(qty.text), custom = override.text.isEmpty ? null : NsFormatters.parseRupiah(override.text);
          final duplicate = variants.asMap().entries.any((e) => e.key != index && e.value.sku.toLowerCase() == sku.text.trim().toLowerCase());
          if (sku.text.trim().isEmpty || label.text.trim().isEmpty || q == null || q < (variant?.reservedQty ?? 0) || duplicate) {
            update(() => validation = 'Periksa SKU unik, pilihan, dan stok (minimal sesuai pesanan).'); return;
          }
          Navigator.pop(ctx, ProductVariant(id: variant?.id, sku: sku.text.trim(), optionLabel: label.text.trim(), stockQty: q, reservedQty: variant?.reservedQty ?? 0, priceOverrideIdr: custom, status: active ? 'active' : 'inactive', imageUrl: variant?.imageUrl));
        }, child: const Text('Terapkan')),
      ])));
    sku.dispose(); label.dispose(); qty.dispose(); override.dispose();
    if (result != null && mounted) { setState(() { if (index == null) { variants.add(result); } else { variants[index] = result; } }); changed(); }
  }
  Future<void> save() async {
    final safe = NsSlugUtils.normalize(slug.text);
    final amount = NsFormatters.parseRupiah(price.text);
    final skuSet = variants.map((v) => v.sku.trim().toLowerCase()).toSet();
    if (name.text.trim().length < 2 || NsSlugUtils.validate(safe) != null || price.text.trim().isEmpty ||
        category.text.trim().isEmpty || variants.isEmpty || skuSet.length != variants.length ||
        variants.any((v) => v.sku.trim().isEmpty || v.stockQty < v.reservedQty)) {
      setState(() => error = 'Periksa nama, link produk, harga, kategori, SKU dan stok varian.'); return;
    }
    setState(() { loading = true; error = null; });
    try {
      final product = Product(id: original?.id ?? '', slug: safe, name: name.text.trim(), description: description.text,
        priceIdr: amount, category: category.text.trim(), primaryImageUrl: primaryImage,
        gallery: gallery, status: status, variants: variants);
      await widget.appState.repository.saveProduct(storeId: storeId, product: product, isUpdate: original != null, role: widget.appState.activeRole);
      await widget.appState.repository.drafts.deleteDraft(userId: userId, storeId: storeId, resourceType: 'product', resourceId: resourceId);
      dirty = false;
      widget.appState.setHasUnsavedFormDraft(false);
      widget.appState.notifyStoreDataMutated();
      if (mounted) context.pop();
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, result) async { if (!didPop && await confirmExit() && context.mounted) context.pop(); },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.productId == null ? 'Tambah produk' : 'Edit produk'), actions: [
        IconButton(tooltip: 'Simpan draft lokal', onPressed: () async { await saveDraft(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft disimpan di perangkat.'))); }, icon: const Icon(Icons.save_outlined)),
      ]),
      bottomNavigationBar: SafeArea(minimum: const EdgeInsets.all(16), child: FilledButton(
        onPressed: loading || uploading || !widget.appState.activeRole.canManageCatalog ? null : save,
        child: Text(loading ? 'Menyimpan...' : 'Simpan produk'),
      )),
      body: loading && original == null && widget.productId != null
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(20), children: [
          Text('Informasi produk', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama produk')),
          const SizedBox(height: 12), TextField(controller: slug, decoration: const InputDecoration(labelText: 'Link produk')),
          const SizedBox(height: 12), TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Deskripsi')),
          const SizedBox(height: 12), TextField(controller: category, decoration: const InputDecoration(labelText: 'Kategori')),
          const SizedBox(height: 12), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga dasar (Rp)')),
          const SizedBox(height: 24), Text('Foto produk', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _ProductThumb(url: primaryImage),
          TextButton.icon(onPressed: uploading ? null : () => choosePhoto(primary: true), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Foto utama')),
          const SizedBox(height: 12),
          Text('Galeri tambahan (${gallery.length}/12)'),
          if (gallery.isNotEmpty) ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: gallery.length, onReorder: (old, next) {
              setState(() { if (next > old) next--; final entry = gallery.removeAt(old); gallery.insert(next, entry); }); changed();
            }, itemBuilder: (context, i) => ListTile(
              key: ValueKey(gallery[i].url), leading: _ProductThumb(url: gallery[i].url),
              title: Text('Foto ${i + 1}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Hapus foto', icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => gallery.removeAt(i)); changed(); }),
                const Icon(Icons.drag_handle),
              ]),
            )),
          TextButton.icon(onPressed: uploading || gallery.length >= 12 ? null : () => choosePhoto(primary: false),
            icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(uploading ? 'Mengunggah ${uploadDone + 1} dari $uploadTotal…' : 'Tambah foto galeri')),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: Text('Varian & stok', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(tooltip: 'Tambah varian', icon: const Icon(Icons.add_circle_outline), onPressed: () => editVariant())]),
          for (var i = 0; i < variants.length; i++) ListTile(
            title: Text(variants[i].optionLabel), subtitle: Text('${variants[i].sku} • Stok ${variants[i].stockQty} • Dipesan ${variants[i].reservedQty}'),
            trailing: const Icon(Icons.edit_outlined), onTap: () => editVariant(i),
          ),
          const SizedBox(height: 16), Text('Publikasi', style: Theme.of(context).textTheme.titleLarge),
          DropdownButtonFormField<String>(value: status, items: const [
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'active', child: Text('Aktif')),
            DropdownMenuItem(value: 'archived', child: Text('Diarsipkan')),
          ], onChanged: (value) { if (value != null) { setState(() => status = value); changed(); } }),
          if (error != null) Padding(padding: const EdgeInsets.all(14), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 40),
        ]),
    ),
  );
}
