import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class StoreHubScreen extends StatelessWidget{
 const StoreHubScreen({super.key,required this.appState});final SellerAppState appState;
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Text('Toko',style:Theme.of(context).textTheme.headlineSmall),
 ListTile(title:Text(appState.activeStore?.name??'Belum ada toko'),subtitle:Text(appState.activeStore?.slug??'')),
 ListTile(leading:const Icon(Icons.settings_outlined),title:const Text('Pengaturan toko'),onTap:()=>context.push('/toko/settings')),
 ListTile(leading:const Icon(Icons.fact_check_outlined),title:const Text('Kesiapan publikasi'),onTap:()=>context.push('/toko/readiness')),
 if(appState.activeRole.canViewCustomersAndAnalytics)ListTile(leading:const Icon(Icons.people_outline),title:const Text('Pelanggan'),onTap:()=>context.push('/toko/customers')),
 if(appState.activeRole.canChooseBillingPlan)ListTile(leading:const Icon(Icons.receipt_long_outlined),title:const Text('Paket & tagihan'),onTap:()=>context.push('/toko/billing')),
 ListTile(leading:const Icon(Icons.lock_outline),title:const Text('Keamanan akun'),onTap:()=>context.push('/toko/account')),
 const Divider(),ListTile(leading:const Icon(Icons.logout),title:const Text('Keluar'),onTap:appState.signOut),
 ]);
}
class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}
class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  late Future<StoreSettings> future;
  final names = <String, TextEditingController>{
    'name': TextEditingController(), 'description': TextEditingController(),
    'phone': TextEditingController(), 'address': TextEditingController(),
    'shipping': TextEditingController(), 'bank': TextEditingController(),
    'policies': TextEditingController(), 'hero': TextEditingController(),
    'accent': TextEditingController(), 'hours': TextEditingController(),
    'threshold': TextEditingController(),
  };
  StoreSettings? current;
  bool pickup = true, delivery = false, busy = false, dirty = false;
  String? error;
  String? logoUrl, heroUrl, qrisKey;
  String get storeId => widget.appState.activeStore!.id;
  @override void initState() {
    super.initState();
    for (final c in names.values) { c.addListener(onDirty); }
    future = widget.appState.repository.fetchSettings(storeId: storeId, store: widget.appState.activeStore!);
    future.then((d) {
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
      pickup = d.pickupEnabled; delivery = d.deliveryEnabled;
      logoUrl = d.logoUrl; heroUrl = d.heroImageUrl; qrisKey = d.qrisMediaKey;
      setState(() => dirty = false);
      widget.appState.setHasUnsavedFormDraft(false);
    }).catchError((Object _) {});
  }
  void onDirty() {
    if (current == null || !mounted) return;
    if (!dirty) setState(() => dirty = true);
    widget.appState.setHasUnsavedFormDraft(true);
  }
  @override void dispose() {
    widget.appState.setHasUnsavedFormDraft(false);
    for (final c in names.values) { c.dispose(); }
    super.dispose();
  }
  Future<bool> confirmExit() async {
    if (!dirty) return true;
    final discard = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Perubahan belum disimpan'),
      content: const Text('Keluar dari halaman ini akan membuang perubahan pengaturan.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tetap edit')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang perubahan')),
      ],
    ));
    if (discard == true && mounted) { setState(() => dirty = false); return true; }
    return false;
  }
  Future<void> upload(String target) async {
    final source = await showModalBottomSheet<ImageSource>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('Pilih gambar'), leading: const Icon(Icons.photo_library_outlined), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ListTile(title: const Text('Ambil foto'), leading: const Icon(Icons.camera_alt_outlined), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
    ])));
    if (source == null || !mounted) return;
    final image = await ImagePicker().pickImage(source: source, maxWidth: 1800, maxHeight: 1800, imageQuality: 82);
    if (image == null || !mounted) return;
    setState(() => busy = true);
    try {
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw const FormatException('Maksimum 5 MB.');
      String mime;
      if (bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216) {
        mime = 'image/jpeg';
      } else if (bytes.length > 7 && bytes[0] == 137 && bytes[1] == 80) {
        mime = 'image/png';
      } else if (bytes.length > 11 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        mime = 'image/webp';
      } else { throw const FormatException('Gunakan gambar JPG, PNG atau WebP.'); }
      final media = await widget.appState.repository.uploadMediaBytes(storeId: storeId, bytes: bytes, mimeType: mime);
      if (!mounted) return;
      setState(() {
        if (target == 'logo') logoUrl = media.url;
        if (target == 'hero') heroUrl = media.url;
        if (target == 'qris') qrisKey = media.key;
      });
      onDirty();
    } catch (e) {
      if (mounted) setState(() => error = 'Gambar gagal diunggah: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> save() async {
    if (current == null || busy || widget.appState.isOffline) return;
    final amount = int.tryParse(names['shipping']!.text), threshold = int.tryParse(names['threshold']!.text);
    if (names['name']!.text.trim().length < 2 || amount == null || amount < 0 || threshold == null || threshold < 0 || threshold > 1000 ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(names['accent']!.text.trim()) ||
        (pickup && names['address']!.text.trim().isEmpty) || (delivery && names['phone']!.text.trim().length < 8)) {
      setState(() => error = 'Periksa nama toko, ongkir, warna (#RRGGBB), alamat pickup, kontak pengiriman, dan ambang stok.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      await widget.appState.repository.saveSettings(storeId: storeId, settings: current!.copyWith(
        storeName: names['name']!.text.trim(), storeDescription: names['description']!.text,
        contactPhone: names['phone']!.text.trim(), pickupAddress: names['address']!.text,
        shippingFeeIdr: amount, pickupEnabled: pickup, deliveryEnabled: delivery,
        bankDetails: names['bank']!.text, policies: names['policies']!.text,
        heroTitle: names['hero']!.text, accent: names['accent']!.text,
        openingHours: names['hours']!.text, lowStockThreshold: threshold,
        logoUrl: logoUrl, heroImageUrl: heroUrl, qrisMediaKey: qrisKey, clearQris: qrisKey == null,
      ), role: widget.appState.activeRole);
      if (!mounted) return;
      setState(() => dirty = false);
      widget.appState.setHasUnsavedFormDraft(false);
      await widget.appState.refreshStoresMetadata();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan.')));
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Widget field(String id, String label, {int lines = 1, TextInputType? type}) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: names[id], maxLines: lines, keyboardType: type, decoration: InputDecoration(labelText: label)));
  Widget section(String title, List<Widget> children) => ExpansionTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    childrenPadding: const EdgeInsets.fromLTRB(8, 12, 8, 12), children: children);
  @override Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await confirmExit() && context.mounted) context.pop();
    },
    child: Scaffold(appBar: AppBar(title: const Text('Pengaturan toko')),
      bottomNavigationBar: SafeArea(minimum: const EdgeInsets.all(16), child: FilledButton(
        onPressed: dirty && !busy && !widget.appState.isOffline && widget.appState.activeRole.canManageSettings ? save : null,
        child: Text(busy ? 'Menyimpan...' : 'Simpan perubahan'),
      )),
      body: FutureBuilder<StoreSettings>(future: future, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Pengaturan belum dapat dibuka: ${snap.error}'));
        return ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), children: [
          section('Identitas toko', [
            field('name', 'Nama toko'), field('description', 'Deskripsi', lines: 3),
            field('phone', 'Kontak toko', type: TextInputType.phone), field('hours', 'Jam operasional'),
          ]),
          section('Tampilan toko', [
            field('hero', 'Judul utama toko'), field('accent', 'Warna toko (contoh #171715)'),
            ListTile(title: const Text('Logo toko'), subtitle: Text(logoUrl == null ? 'Belum ada logo' : 'Logo terpilih'), trailing: const Icon(Icons.upload_outlined), onTap: busy ? null : () => upload('logo')),
            ListTile(title: const Text('Foto hero'), subtitle: Text(heroUrl == null ? 'Belum ada foto' : 'Foto terpilih'), trailing: const Icon(Icons.upload_outlined), onTap: busy ? null : () => upload('hero')),
          ]),
          section('Pengiriman', [
            SwitchListTile(title: const Text('Ambil di tempat'), value: pickup, onChanged: (v) { setState(() => pickup = v); onDirty(); }),
            SwitchListTile(title: const Text('Kurir toko'), value: delivery, onChanged: (v) { setState(() => delivery = v); onDirty(); }),
            field('address', 'Alamat pengambilan', lines: 3), field('shipping', 'Biaya pengiriman (Rp)', type: TextInputType.number),
          ]),
          section('Pembayaran', [
            field('bank', 'Informasi rekening / transfer', lines: 3),
            ListTile(title: const Text('Gambar QRIS'), subtitle: Text(qrisKey == null ? 'Belum diunggah' : 'QRIS tersimpan'), trailing: const Icon(Icons.upload_outlined), onTap: busy ? null : () => upload('qris')),
            if (qrisKey != null) TextButton(onPressed: () { setState(() => qrisKey = null); onDirty(); }, child: const Text('Hapus QRIS dari pengaturan')),
          ]),
          section('Kebijakan dan lainnya', [field('policies', 'Pengiriman dan pengembalian', lines: 5), field('threshold', 'Peringatan stok menipis', type: TextInputType.number)]),
          const SizedBox(height: 12),
          const Text('Domain dan status verifikasinya dikelola oleh dashboard Nalaro Store. Perubahan yang belum disimpan tidak akan diterapkan ke server.'),
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24),
        ]);
      }),
    ),
  );
}
class StoreReadinessScreen extends StatefulWidget {
  const StoreReadinessScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override State<StoreReadinessScreen> createState() => _StoreReadinessScreenState();
}
class _StoreReadinessScreenState extends State<StoreReadinessScreen> {
  late Future<({StoreSettings settings, List<Product> products})> future;
  bool busy = false;
  void load() {
    final id = widget.appState.activeStore!.id, store = widget.appState.activeStore!;
    future = () async {
      final settings = await widget.appState.repository.fetchSettings(storeId: id, store: store);
      final products = await widget.appState.repository.fetchProducts(id);
      return (settings: settings, products: products);
    }();
  }
  @override void initState() { super.initState(); load(); }
  Future<void> publish(bool next) async {
    final allowed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(next ? 'Publikasikan toko?' : 'Jeda toko?'),
      content: Text(next ? 'Toko akan dapat dikunjungi pembeli setelah semua persyaratan diverifikasi server.' : 'Toko tidak lagi menerima pesanan baru selama dijeda.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(next ? 'Publikasikan' : 'Jeda toko')),
      ],
    ));
    if (allowed != true || !mounted || widget.appState.isOffline) return;
    setState(() => busy = true);
    try {
      await widget.appState.repository.setStorePublished(storeId: widget.appState.activeStore!.id, publish: next, role: widget.appState.activeRole);
      await widget.appState.refreshStoresMetadata();
      if (mounted) { setState(load); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status toko diperbarui.'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server menolak perubahan: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kesiapan toko'), actions: [IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: () => setState(load))]),
    body: FutureBuilder<({StoreSettings settings, List<Product> products})>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Kesiapan belum dapat dimuat: ${snap.error}'));
      final d = snap.data!.settings, products = snap.data!.products;
      final checks = <String, bool>{
        'Ada produk aktif dengan stok': products.any((p) => p.status == 'active' && p.totalAvailableStock > 0),
        'Rekening atau QRIS': d.hasPaymentConfigured,
        'Nomor kontak minimal 8 karakter': d.contactPhone.trim().length >= 8,
        'Kebijakan toko minimal 20 karakter': d.policies.trim().length >= 20,
        'Metode pengiriman atau pengambilan': d.hasFulfillmentConfigured,
        'Alamat pengambilan jika diaktifkan': d.hasValidPickupAddress,
        'Kontak pengiriman jika diaktifkan': d.hasValidDeliveryContact,
      };
      final ready = checks.values.every((v) => v);
      final published = widget.appState.activeStore?.isPublished ?? false;
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(published ? 'Toko sedang terbit' : 'Siapkan toko sebelum terbit', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final check in checks.entries) ListTile(
          contentPadding: EdgeInsets.zero, leading: Icon(check.value ? Icons.check_circle_outline : Icons.error_outline, color: check.value ? Colors.green.shade700 : Colors.orange.shade700),
          title: Text(check.key),
          onTap: check.value ? null : () => context.push(check.key.contains('produk') ? '/produk' : '/toko/settings'),
        ),
        const SizedBox(height: 8),
        const Text('Pemeriksaan ini membantu persiapan. Server tetap memverifikasi izin, kuota, dan kelayakan final.'),
        const SizedBox(height: 24),
        FilledButton(onPressed: busy || widget.appState.isOffline || !widget.appState.activeRole.canManageSettings || (!published && !ready)
          ? null : () => publish(!published), child: Text(busy ? 'Memproses...' : published ? 'Jeda publikasi' : 'Publikasikan toko')),
      ]);
    }),
  );
}
class CustomersScreen extends StatefulWidget{
 const CustomersScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<CustomersScreen> createState()=>_CustomersScreenState();
}
class _CustomersScreenState extends State<CustomersScreen>{
 late Future<({List<CustomerSummary> customers,bool hasMore})> future;
 @override void initState(){super.initState();future=widget.appState.repository.fetchCustomers(storeId:widget.appState.activeStore!.id);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pelanggan')),body:FutureBuilder<({List<CustomerSummary> customers,bool hasMore})>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return Center(child:Text(s.error.toString()));
 if(!widget.appState.activeRole.canViewCustomersAndAnalytics)return const Center(child:Text('Akses tidak diizinkan.'));
 final customers=s.data?.customers??[];
 return ListView(children:customers.isEmpty?[const ListTile(title:Text('Belum ada pelanggan'))]:customers.map((c)=>ListTile(title:Text(c.name),subtitle:Text(c.email),trailing:Text(NsFormatters.rupiah(c.paidTotalIdr)))).toList());
 }));
}
class BillingScreen extends StatefulWidget{
 const BillingScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<BillingScreen> createState()=>_BillingScreenState();
}
class _BillingScreenState extends State<BillingScreen>{
 late Future<BillingBundle> future;
 @override void initState(){super.initState();future=widget.appState.repository.fetchBilling(widget.appState.activeStore!.id);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Paket & tagihan')),body:FutureBuilder<BillingBundle>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return Center(child:Text(s.error.toString()));
 final d=s.data!;
 return ListView(padding:const EdgeInsets.all(20),children:[
 Text('Langganan',style:Theme.of(context).textTheme.titleLarge),
 ...d.subscriptions.map((v)=>ListTile(title:Text(v.name),subtitle:Text(v.status))),
 Text('Tagihan',style:Theme.of(context).textTheme.titleLarge),
 ...d.invoices.map((v)=>ListTile(title:Text(v.invoiceNumber),subtitle:Text(v.status),trailing:Text(NsFormatters.rupiah(v.amountIdr)))),
 Text('Paket tersedia',style:Theme.of(context).textTheme.titleLarge),
 ...d.publicPlans.map((p)=>ExpansionTile(title:Text(p.name),subtitle:Text(p.description),children:p.prices.map((price)=>ListTile(title:Text(NsFormatters.rupiah(price.amountIdr)),subtitle:Text(price.billingInterval),onTap:price.id==null||!widget.appState.activeRole.canChooseBillingPlan?null:()async{try{await widget.appState.repository.selectSubscriptionPlan(storeId:widget.appState.activeStore!.id,planPriceId:price.id!,role:widget.appState.activeRole);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Paket berhasil dipilih')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}})).toList())),
 if(d.paymentInstructions.isNotEmpty)Text(d.paymentInstructions),
 ]);
 }));
}
class AccountSecurityScreen extends StatefulWidget{
 const AccountSecurityScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<AccountSecurityScreen> createState()=>_AccountSecurityScreenState();
}
class _AccountSecurityScreenState extends State<AccountSecurityScreen>{
 final current=TextEditingController(),next=TextEditingController();String? message;bool busy=false;
 @override void dispose(){current.dispose();next.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Keamanan akun')),body:ListView(padding:const EdgeInsets.all(20),children:[
 Text(widget.appState.user?.email??''),
 TextField(controller:current,obscureText:true,decoration:const InputDecoration(labelText:'Kata sandi saat ini')),
 TextField(controller:next,obscureText:true,decoration:const InputDecoration(labelText:'Kata sandi baru')),
 if(message!=null)Text(message!),
 FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.appState.repository.changePassword(currentPassword:current.text,newPassword:next.text);await widget.appState.signOut();}catch(e){if(mounted)setState(()=>message=e.toString());}finally{if(mounted)setState(()=>busy=false);}},child:const Text('Ganti kata sandi')),
 ]));
}
class NotificationsScreen extends StatelessWidget{
 const NotificationsScreen({super.key,required this.appState});final SellerAppState appState;
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Notifikasi')),body:ListView(children:[
 if(appState.repository.getNotificationsForUser().isEmpty)const ListTile(title:Text('Belum ada notifikasi'),subtitle:Text('Notifikasi server belum terhubung.')),
 ...appState.repository.getNotificationsForUser().map((n)=>ListTile(title:Text(n.title),subtitle:Text(n.summary))),
 ]));
}
