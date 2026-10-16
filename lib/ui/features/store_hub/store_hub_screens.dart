import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/formatters.dart';
import '../../../core/widgets/ns_product_image.dart';
import '../../../core/widgets/ns_form_exit_guard.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../core/errors/ns_error_mapper.dart';
import '../../../core/config/status_dictionary.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class StoreHubScreen extends StatelessWidget {
  const StoreHubScreen({super.key, required this.appState});
  final SellerAppState appState;
  Widget item(
    BuildContext context,
    String icon,
    String title,
    String subtitle,
    String route,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: NsIcon(icon, color: NsColors.brandAction),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const NsIcon('chevron-right', size: 18),
      onTap: () => context.push(route),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('store-hub'),
    padding: const EdgeInsets.all(20),
    children: [
      Text('Toko', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(
        appState.activeStore?.name ?? 'Pilih toko',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 20),
      Text('Pengelolaan toko', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      item(
        context,
        'settings',
        'Pengaturan toko',
        'Identitas, tampilan, pengiriman, dan pembayaran',
        '/toko/settings',
      ),
      if (appState.activeRole.canManageSettings)
        item(
          context,
          'check',
          'Kesiapan publikasi',
          'Periksa syarat dan terbitkan toko',
          '/toko/readiness',
        ),
      if (appState.activeRole.canViewCustomersAndAnalytics)
        item(
          context,
          'users',
          'Pelanggan',
          'Cari pelanggan dan ringkasan pembelian',
          '/toko/customers',
        ),
      if (appState.activeRole.canChooseBillingPlan)
        item(
          context,
          'credit-card',
          'Paket & tagihan',
          'Langganan aktif, invoice, dan penggunaan',
          '/toko/billing',
        ),
      const SizedBox(height: 16),
      Text('Akun', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      item(
        context,
        'shield',
        'Keamanan akun',
        'Ubah kata sandi akun seller',
        '/toko/account',
      ),
      TextButton.icon(
        icon: const NsIcon('logout', color: NsColors.brandAction),
        label: const Text('Keluar dari akun'),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Keluar dari akun?'),
              content: const Text('Sesi akan diakhiri pada perangkat ini.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Kembali'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) await appState.signOut();
        },
      ),
    ],
  );
}

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  late Future<StoreSettings> future;
  final names = <String, TextEditingController>{
    'name': TextEditingController(),
    'description': TextEditingController(),
    'phone': TextEditingController(),
    'address': TextEditingController(),
    'shipping': TextEditingController(),
    'bank': TextEditingController(),
    'policies': TextEditingController(),
    'hero': TextEditingController(),
    'accent': TextEditingController(),
    'hours': TextEditingController(),
    'threshold': TextEditingController(),
  };
  final form = GlobalKey<FormState>();
  late final MerchantStore boundStore;
  bool hydrating = true;
  StoreSettings? current;
  bool pickup = true, delivery = false, busy = false, dirty = false;
  String? error;
  String? logoUrl, heroUrl, qrisKey;
  String get storeId => boundStore.id;
  @override
  void initState() {
    super.initState();
    boundStore = widget.appState.activeStore!;
    for (final c in names.values) {
      c.addListener(onDirty);
    }
    future = widget.appState.repository.fetchSettings(
      storeId: storeId,
      store: widget.appState.activeStore!,
    );
    future
        .then((d) {
          if (!mounted) return;
          current = d;
          names['name']!.text = d.storeName;
          names['description']!.text = d.storeDescription;
          names['phone']!.text = d.contactPhone;
          names['address']!.text = d.pickupAddress;
          names['shipping']!.text = d.shippingFeeIdr.toString();
          names['bank']!.text = d.bankDetails;
          names['policies']!.text = d.policies;
          names['hero']!.text = d.heroTitle;
          names['accent']!.text = d.accent;
          names['hours']!.text = d.openingHours;
          names['threshold']!.text = d.lowStockThreshold.toString();
          pickup = d.pickupEnabled;
          delivery = d.deliveryEnabled;
          logoUrl = d.logoUrl;
          heroUrl = d.heroImageUrl;
          qrisKey = d.qrisMediaKey;
          hydrating = false;
          setState(() => dirty = false);
          widget.appState.setHasUnsavedFormDraft(false);
        })
        .catchError((Object _) {});
  }

  void onDirty() {
    if (hydrating || current == null || !mounted) return;
    if (!dirty) setState(() => dirty = true);
    widget.appState.setHasUnsavedFormDraft(true);
  }

  @override
  void dispose() {
    widget.appState.setHasUnsavedFormDraft(false);
    for (final c in names.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> confirmExit() async {
    if (!dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text(
          'Keluar dari halaman ini akan membuang perubahan pengaturan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buang perubahan'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => dirty = false);
      return true;
    }
    return false;
  }

  Future<void> upload(String target) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Pilih gambar'),
              leading: const Icon(Icons.photo_library_outlined),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              title: const Text('Ambil foto'),
              leading: const Icon(Icons.camera_alt_outlined),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024)
        throw const FormatException('Maksimum 5 MB.');
      String mime;
      if (bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216) {
        mime = 'image/jpeg';
      } else if (bytes.length > 7 && bytes[0] == 137 && bytes[1] == 80) {
        mime = 'image/png';
      } else if (bytes.length > 11 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        mime = 'image/webp';
      } else {
        throw const FormatException('Gunakan gambar JPG, PNG atau WebP.');
      }
      final media = await widget.appState.repository.uploadMediaBytes(
        storeId: storeId,
        bytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() {
        if (target == 'logo') logoUrl = media.url;
        if (target == 'hero') heroUrl = media.url;
        if (target == 'qris') qrisKey = media.key;
      });
      onDirty();
    } catch (e) {
      if (mounted) setState(() => error = 'Gambar gagal diunggah: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (current == null || busy || widget.appState.isOffline) return;
    if (!form.currentState!.validate()) {
      setState(() => error = 'Periksa kolom yang ditandai di setiap bagian.');
      return;
    }
    final amount = int.tryParse(names['shipping']!.text),
        threshold = int.tryParse(names['threshold']!.text);
    if (names['name']!.text.trim().length < 2 ||
        amount == null ||
        amount < 0 ||
        threshold == null ||
        threshold < 0 ||
        threshold > 1000 ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(names['accent']!.text.trim()) ||
        (pickup && names['address']!.text.trim().isEmpty) ||
        (delivery && names['phone']!.text.trim().length < 8)) {
      setState(
        () => error = 'Periksa nama toko, ongkir, warna (#RRGGBB), alamat pickup, kontak pengiriman, dan ambang stok.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.appState.repository.saveSettings(
        storeId: storeId,
        settings: current!.copyWith(
          storeName: names['name']!.text.trim(),
          storeDescription: names['description']!.text,
          contactPhone: names['phone']!.text.trim(),
          pickupAddress: names['address']!.text,
          shippingFeeIdr: amount,
          pickupEnabled: pickup,
          deliveryEnabled: delivery,
          bankDetails: names['bank']!.text,
          policies: names['policies']!.text,
          heroTitle: names['hero']!.text,
          accent: names['accent']!.text,
          openingHours: names['hours']!.text,
          lowStockThreshold: threshold,
          logoUrl: logoUrl,
          heroImageUrl: heroUrl,
          qrisMediaKey: qrisKey,
          clearQris: qrisKey == null,
        ),
        role: widget.appState.activeRole,
      );
      if (!mounted) return;
      setState(() => dirty = false);
      widget.appState.setHasUnsavedFormDraft(false);
      await widget.appState.refreshStoresMetadata();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan.')));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String id, String label, {int lines = 1, TextInputType? type}) {
    const hints = {
      'name': 'Nalaro Batik',
      'description': 'Produk yang dijual dan ciri khas tokomu.',
      'phone': '081234567890',
      'address': 'Jalan, nomor, kelurahan, kecamatan, kota, kode pos',
      'shipping': '10000',
      'bank': 'BCA • 1234567890 • a.n. Nama Pemilik',
      'policies': 'Ketentuan pengiriman, penukaran, dan pengembalian barang.',
      'hero': 'Batik pilihan untuk harimu',
      'accent': '#FF154F',
      'hours': 'Senin–Sabtu, 08.00–17.00 WIB',
      'threshold': '5',
    };
    const helpers = {
      'phone': 'Nomor yang dapat dihubungi pembeli.',
      'shipping': 'Biaya tetap per pesanan melalui kurir toko.',
      'threshold': 'Tampilkan peringatan jika stok tersedia sama dengan atau di bawah angka ini.',
      'accent': 'Kode warna enam digit, diawali #.',
      'bank': 'Nama bank, nomor rekening, dan nama pemilik rekening.',
      'policies': 'Minimal 20 karakter agar toko dapat diterbitkan.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: names[id],
        maxLines: lines,
        readOnly: !widget.appState.activeRole.canManageSettings,
        keyboardType: type,
        textInputAction: lines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hints[id],
          helperText: helpers[id],
        ),
        validator: (value) {
          final v = value?.trim() ?? '';
          if (id == 'name' && v.length < 2)
            return 'Nama toko minimal 2 karakter.';
          if (id == 'accent' && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v))
            return 'Contoh warna: #FF154F.';
          if (id == 'address' && pickup && v.isEmpty)
            return 'Isi alamat untuk ambil di tempat.';
          if (id == 'phone' && delivery && v.length < 8)
            return 'Isi nomor kontak pengiriman.';
          if (id == 'shipping' && (int.tryParse(v) == null || int.parse(v) < 0))
            return 'Isi biaya, atau 0 jika gratis.';
          if (id == 'threshold' &&
              (int.tryParse(v) == null || int.parse(v) > 1000))
            return 'Gunakan angka 0–1000.';
          return null;
        },
      ),
    );
  }

  Widget mediaTile(String title, String? url, String target) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 56,
      height: 56,
      child: NsProductImage(
        repository: widget.appState.repository,
        url: url,
        label: title,
      ),
    ),
    title: Text(title),
    subtitle: Text(
      url == null ? 'Belum ditambahkan' : 'Ketuk foto untuk memperbesar',
    ),
    trailing: IconButton(
      tooltip: 'Ganti $title',
      icon: const Icon(Icons.upload_outlined),
      onPressed: busy || !widget.appState.activeRole.canManageSettings
          ? null
          : () => upload(target),
    ),
  );
  Widget section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      maintainState: true,
      initiallyExpanded: title == 'Identitas toko',
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: children,
    ),
  );
  @override
  Widget build(BuildContext context) => NsFormExitGuard(
    dirty: dirty,
    busy: busy,
    confirmExit: confirmExit,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan toko'),
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed:
              dirty &&
                  !busy &&
                  !widget.appState.isOffline &&
                  widget.appState.activeRole.canManageSettings
              ? save
              : null,
          child: Text(busy ? 'Menyimpan...' : 'Simpan perubahan'),
        ),
      ),
      body: FutureBuilder<StoreSettings>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError)
            return Center(
              child: Text('Pengaturan belum dapat dibuka: ${snap.error}'),
            );
          return Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                section('Identitas toko', [
                  field('name', 'Nama toko'),
                  field('description', 'Deskripsi', lines: 3),
                  field('phone', 'Kontak toko', type: TextInputType.phone),
                  field('hours', 'Jam operasional'),
                ]),
                section('Tampilan toko', [
                  field('hero', 'Judul utama toko'),
                  field('accent', 'Warna toko (contoh #171715)'),
                  mediaTile('Logo toko', logoUrl, 'logo'),
                  mediaTile('Banner toko', heroUrl, 'hero'),
                ]),
                section('Pengiriman', [
                  SwitchListTile(
                    title: const Text('Ambil di tempat'),
                    value: pickup,
                    onChanged: (v) {
                      setState(() => pickup = v);
                      onDirty();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Kurir toko'),
                    value: delivery,
                    onChanged: (v) {
                      setState(() => delivery = v);
                      onDirty();
                    },
                  ),
                  field('address', 'Alamat pengambilan', lines: 3),
                  field(
                    'shipping',
                    'Biaya pengiriman (Rp)',
                    type: TextInputType.number,
                  ),
                ]),
                section('Pembayaran', [
                  field('bank', 'Informasi rekening / transfer', lines: 3),
                  mediaTile(
                    'Gambar QRIS',
                    qrisKey == null ? null : '/api/media/$qrisKey',
                    'qris',
                  ),
                  if (qrisKey != null)
                    TextButton(
                      onPressed: () {
                        setState(() => qrisKey = null);
                        onDirty();
                      },
                      child: const Text('Hapus QRIS dari pengaturan'),
                    ),
                ]),
                section('Kebijakan dan lainnya', [
                  field('policies', 'Pengiriman dan pengembalian', lines: 5),
                  field(
                    'threshold',
                    'Peringatan stok menipis',
                    type: TextInputType.number,
                  ),
                ]),
                const SizedBox(height: 12),
                const Text(
                  'Domain dan status verifikasinya dikelola oleh dashboard Nalaro Store. Perubahan diterapkan setelah kamu menyimpannya.',
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class StoreReadinessScreen extends StatefulWidget {
  const StoreReadinessScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<StoreReadinessScreen> createState() => _StoreReadinessScreenState();
}

class _StoreReadinessScreenState extends State<StoreReadinessScreen> {
  late Future<({StoreSettings settings, List<Product> products})> future;
  bool busy = false;
  void load() {
    final id = widget.appState.activeStore!.id,
        store = widget.appState.activeStore!;
    future = () async {
      final settings = await widget.appState.repository.fetchSettings(
        storeId: id,
        store: store,
      );
      final products = await widget.appState.repository.fetchProducts(id);
      return (settings: settings, products: products);
    }();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> publish(bool next) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(next ? 'Publikasikan toko?' : 'Jeda toko?'),
        content: Text(
          next
              ? 'Toko akan dapat dikunjungi pembeli setelah semua persyaratan diverifikasi server.'
              : 'Toko tidak lagi menerima pesanan baru selama dijeda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(next ? 'Publikasikan' : 'Jeda toko'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted || widget.appState.isOffline) return;
    setState(() => busy = true);
    try {
      await widget.appState.repository.setStorePublished(
        storeId: widget.appState.activeStore!.id,
        publish: next,
        role: widget.appState.activeRole,
      );
      await widget.appState.refreshStoresMetadata();
      if (mounted) {
        setState(load);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status toko diperbarui.')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Server menolak perubahan: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kesiapan toko'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(load),
        ),
      ],
    ),
    body: FutureBuilder<({StoreSettings settings, List<Product> products})>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
            child: Text('Kesiapan belum dapat dimuat: ${snap.error}'),
          );
        final d = snap.data!.settings, products = snap.data!.products;
        final checks = <String, bool>{
          'Ada produk aktif dengan stok': products.any(
            (p) => p.status == 'active' && p.totalAvailableStock > 0,
          ),
          'Rekening atau QRIS': d.hasPaymentConfigured,
          'Nomor kontak minimal 8 karakter': d.contactPhone.trim().length >= 8,
          'Kebijakan toko minimal 20 karakter': d.policies.trim().length >= 20,
          'Metode pengiriman atau pengambilan': d.hasFulfillmentConfigured,
          'Alamat pengambilan jika diaktifkan': d.hasValidPickupAddress,
          'Kontak pengiriman jika diaktifkan': d.hasValidDeliveryContact,
        };
        final ready = checks.values.every((v) => v);
        final published = widget.appState.activeStore?.isPublished ?? false;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              published ? 'Toko sedang terbit' : 'Siapkan toko sebelum terbit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final check in checks.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  check.value
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: check.value
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                title: Text(check.key),
                onTap: check.value
                    ? null
                    : () => context.push(
                        check.key.contains('produk')
                            ? '/produk'
                            : '/toko/settings',
                      ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Pemeriksaan ini membantu persiapan. Server tetap memverifikasi izin, kuota, dan kelayakan final.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  busy ||
                      widget.appState.isOffline ||
                      !widget.appState.activeRole.canManageSettings ||
                      (!published && !ready)
                  ? null
                  : () => publish(!published),
              child: Text(
                busy
                    ? 'Memproses...'
                    : published
                    ? 'Jeda publikasi'
                    : 'Publikasikan toko',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final search = TextEditingController();
  List<CustomerSummary> customers = [];
  int page = 0, epoch = 0;
  bool busy = false, hasMore = true;
  String? error;
  String? storeId;
  @override
  void initState() {
    super.initState();
    reset();
    widget.appState.addListener(onState);
  }

  void onState() {
    if (widget.appState.activeStore?.id != storeId) reset();
  }

  void reset() {
    epoch++;
    storeId = widget.appState.activeStore?.id;
    customers = [];
    page = 0;
    busy = false;
    hasMore = true;
    error = null;
    if (mounted) setState(() {});
    load();
  }

  Future<void> load() async {
    if (!hasMore ||
        busy ||
        storeId == null ||
        !widget.appState.activeRole.canViewCustomersAndAnalytics)
      return;
    final current = storeId!, marker = epoch, nextPage = page + 1;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.appState.repository.fetchCustomers(
        storeId: current,
        query: search.text.trim(),
        page: nextPage,
      );
      if (mounted && marker == epoch && current == storeId) {
        setState(() {
          customers = [...customers, ...result.customers];
          hasMore = result.hasMore;
          page = nextPage;
        });
      }
    } catch (e) {
      if (mounted && marker == epoch) setState(() => error = '$e');
    } finally {
      if (mounted && marker == epoch) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(onState);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pelanggan')),
    body: !widget.appState.activeRole.canViewCustomersAndAnalytics
        ? const Center(
            child: Text('Akun ini tidak memiliki akses ke data pelanggan.'),
          )
        : RefreshIndicator(
            onRefresh: () async {
              reset();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, email, atau telepon',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Cari pelanggan',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: reset,
                    ),
                  ),
                  onSubmitted: (_) => reset(),
                ),
                const SizedBox(height: 16),
                for (final item in customers) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.ordersCount} pesanan • Terakhir ${NsFormatters.shortDate(item.lastOrderAt)}',
                    ),
                    trailing: Text(NsFormatters.rupiah(item.paidTotalIdr)),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(item.email),
                              SelectableText(item.contactPhone),
                              const SizedBox(height: 12),
                              Text(
                                '${item.ordersCount} pesanan • ${NsFormatters.rupiah(item.paidTotalIdr)} dibayar',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Informasi kontak hanya ditampilkan saat Anda membuka pelanggan ini.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!busy && customers.isEmpty && error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada pelanggan yang sesuai.'),
                  ),
                if (error != null)
                  ListTile(
                    title: const Text('Pelanggan belum dapat dimuat'),
                    subtitle: Text(error!),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: load,
                    ),
                  ),
                if (hasMore && customers.isNotEmpty)
                  TextButton(
                    onPressed: busy ? null : load,
                    child: const Text('Muat pelanggan lainnya'),
                  ),
              ],
            ),
          ),
  );
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<BillingBundle> future;
  bool choosing = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = widget.appState.repository.fetchBilling(
      widget.appState.activeStore!.id,
    );
  }

  Future<void> choosePlan(PlanPrice price, String name) async {
    if (!widget.appState.activeRole.canChooseBillingPlan ||
        price.id == null ||
        choosing ||
        widget.appState.isOffline)
      return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pilih paket $name?'),
        content: Text(
          'Harga ${NsFormatters.rupiah(price.amountIdr)} / ${NsStatusDictionary.label(price.billingInterval)}. Aktivasi dan pembayaran mengikuti aturan server Nalaro Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() => choosing = true);
    try {
      await widget.appState.repository.selectSubscriptionPlan(
        storeId: widget.appState.activeStore!.id,
        planPriceId: price.id!,
        role: widget.appState.activeRole,
      );
      if (mounted) {
        setState(load);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan paket diterima. Periksa status tagihan.'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paket belum dapat dipilih: $e')),
        );
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Langganan & tagihan'),
      actions: [
        IconButton(
          tooltip: 'Segarkan',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(load),
        ),
      ],
    ),
    body: FutureBuilder<BillingBundle>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
            child: Text('Tagihan belum dapat dibuka: ${snap.error}'),
          );
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Langganan aktif',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (d.subscriptions.isEmpty)
              const ListTile(title: Text('Belum ada langganan aktif.')),
            for (final sub in d.subscriptions)
              ListTile(
                title: Text(sub.name),
                subtitle: Text(
                  '${NsStatusDictionary.label(sub.status)} • ${NsStatusDictionary.label(sub.billingInterval)}',
                ),
                trailing: Text(NsFormatters.shortDate(sub.currentPeriodEnd)),
              ),
            const SizedBox(height: 16),
            Text('Tagihan', style: Theme.of(context).textTheme.titleLarge),
            if (d.invoices.isEmpty)
              const ListTile(title: Text('Belum ada tagihan.')),
            for (final invoice in d.invoices)
              ListTile(
                title: Text(invoice.invoiceNumber),
                subtitle: Text(NsStatusDictionary.label(invoice.status)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(NsFormatters.rupiah(invoice.amountIdr)),
                    Text(
                      NsFormatters.shortDate(invoice.periodEnd),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: invoice.invoiceNumber),
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor tagihan disalin.')),
                    );
                },
              ),
            const SizedBox(height: 16),
            Text(
              'Paket tersedia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (d.publicPlans.isEmpty)
              const ListTile(title: Text('Pilihan paket belum tersedia.')),
            for (final plan in d.publicPlans)
              ExpansionTile(
                title: Text(plan.name),
                subtitle: Text(plan.description),
                children: [
                  for (final price in plan.prices)
                    ListTile(
                      title: Text(NsFormatters.rupiah(price.amountIdr)),
                      subtitle: Text(
                        NsStatusDictionary.label(price.billingInterval),
                      ),
                      trailing: widget.appState.activeRole.canChooseBillingPlan
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: choosing
                          ? null
                          : () => choosePlan(price, plan.name),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Text('Penggunaan', style: Theme.of(context).textTheme.titleLarge),
            if (d.usage.isEmpty)
              const ListTile(title: Text('Belum ada catatan penggunaan.')),
            for (final usage in d.usage)
              ListTile(
                title: Text(usage.featureCode),
                subtitle: Text(usage.periodKey),
                trailing: Text(NsFormatters.number(usage.value)),
              ),
            if (d.paymentInstructions.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Cara pembayaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SelectableText(d.paymentInstructions),
            ],
          ],
        );
      },
    ),
  );
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final current = TextEditingController(), next = TextEditingController();
  String? message;
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keamanan akun')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.appState.user?.email ?? ''),
        TextField(
          controller: current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kata sandi saat ini'),
        ),
        TextField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kata sandi baru'),
        ),
        if (message != null) Text(message!),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await widget.appState.repository.changePassword(
                      currentPassword: current.text,
                      newPassword: next.text,
                    );
                    await widget.appState.signOut();
                  } catch (e) {
                    if (mounted) setState(() => message = e.toString());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Ganti kata sandi'),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifikasi')),
    body: ListView(
      children: [
        if (appState.repository.getNotificationsForUser().isEmpty)
          const ListTile(
            title: Text('Belum ada notifikasi'),
            subtitle: Text(
              'Pembaruan pesanan dapat dilihat melalui tab Pesanan.',
            ),
          ),
        ...appState.repository.getNotificationsForUser().map(
          (n) => ListTile(title: Text(n.title), subtitle: Text(n.summary)),
        ),
      ],
    ),
  );
}
