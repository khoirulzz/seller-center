import 'package:flutter/material.dart';
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
class StoreSettingsScreen extends StatefulWidget{
 const StoreSettingsScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<StoreSettingsScreen> createState()=>_StoreSettingsScreenState();
}
class _StoreSettingsScreenState extends State<StoreSettingsScreen>{
 late Future<StoreSettings> future;bool busy=false;
 final phone=TextEditingController(),address=TextEditingController(),bank=TextEditingController(),policies=TextEditingController(),description=TextEditingController();
 StoreSettings? current;bool pickup=true,delivery=false;
 @override void initState(){super.initState();future=widget.appState.repository.fetchSettings(storeId:widget.appState.activeStore!.id,store:widget.appState.activeStore!);future.then((s){if(!mounted)return;setState((){current=s;phone.text=s.contactPhone;address.text=s.pickupAddress;bank.text=s.bankDetails;policies.text=s.policies;description.text=s.storeDescription;pickup=s.pickupEnabled;delivery=s.deliveryEnabled;});});}
 @override void dispose(){for(final c in [phone,address,bank,policies,description]){c.dispose();}super.dispose();}
 Future<void> save()async{if(current==null)return;setState(()=>busy=true);try{
 await widget.appState.repository.saveSettings(storeId:widget.appState.activeStore!.id,settings:current!.copyWith(contactPhone:phone.text,pickupAddress:address.text,bankDetails:bank.text,policies:policies.text,storeDescription:description.text,pickupEnabled:pickup,deliveryEnabled:delivery),role:widget.appState.activeRole);
 widget.appState.notifyStoreDataMutated();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pengaturan tersimpan')));
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pengaturan toko')),body:FutureBuilder<StoreSettings>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return Center(child:Text(s.error.toString()));
 return ListView(padding:const EdgeInsets.all(20),children:[
 TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Deskripsi toko')),
 TextField(controller:phone,decoration:const InputDecoration(labelText:'Nomor kontak')),
 TextField(controller:address,maxLines:2,decoration:const InputDecoration(labelText:'Alamat pengambilan')),
 TextField(controller:bank,maxLines:3,decoration:const InputDecoration(labelText:'Informasi rekening')),
 TextField(controller:policies,maxLines:3,decoration:const InputDecoration(labelText:'Kebijakan toko')),
 SwitchListTile(title:const Text('Ambil di tempat'),value:pickup,onChanged:(v)=>setState(()=>pickup=v)),
 SwitchListTile(title:const Text('Pengiriman'),value:delivery,onChanged:(v)=>setState(()=>delivery=v)),
 FilledButton(onPressed:busy||!widget.appState.activeRole.canManageSettings?null:save,child:Text(busy?'Menyimpan...':'Simpan pengaturan')),
 ]);
 }));
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
