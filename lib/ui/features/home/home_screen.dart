import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class HomeScreen extends StatefulWidget {
 const HomeScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
 Future<StoreOverview>? future;String? store;int revision=-1;
 void load(){store=widget.appState.activeStore?.id;revision=widget.appState.storeDataRevision;future=store==null?null:widget.appState.repository.fetchOverview(store!);}
 @override void initState(){super.initState();load();widget.appState.addListener(changed);}
 void changed(){if(store!=widget.appState.activeStore?.id||revision!=widget.appState.storeDataRevision)setState(load);}
 @override void dispose(){widget.appState.removeListener(changed);super.dispose();}
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(load);try{await future;}catch(_){}},child:ListView(padding:const EdgeInsets.all(20),children:[
 Text('Selamat datang',style:Theme.of(context).textTheme.headlineSmall),
 Text(widget.appState.activeStore?.name??'Pilih toko'),const SizedBox(height:20),
 FutureBuilder<StoreOverview>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return ListTile(title:const Text('Ringkasan tidak tersedia'),subtitle:Text(s.error.toString()),trailing:IconButton(onPressed:()=>setState(load),icon:const Icon(Icons.refresh)));
 final d=s.data;if(d==null)return const Text('Belum ada toko aktif');
 return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Wrap(spacing:12,runSpacing:12,children:[metric('Pendapatan terverifikasi',NsFormatters.rupiah(d.verifiedRevenueIdr)),metric('Pesanan',NsFormatters.number(d.ordersCount)),metric('Menunggu tindakan',NsFormatters.number(d.pendingOrdersCount))]),
 const SizedBox(height:20),Text('Peringatan stok',style:Theme.of(context).textTheme.titleLarge),
 if(d.lowStockAlerts.isEmpty)const ListTile(title:Text('Tidak ada stok rendah')),
 ...d.lowStockAlerts.map((a)=>ListTile(title:Text(a.name),subtitle:Text(a.optionLabel),trailing:Text(a.availableStock.toString()))),
 ]);
 }),const SizedBox(height:20),
 ListTile(title:const Text('Kelola pesanan'),trailing:const Icon(Icons.chevron_right),onTap:()=>context.go('/pesanan')),
 ListTile(title:const Text('Kelola produk'),trailing:const Icon(Icons.chevron_right),onTap:()=>context.go('/produk')),
 ]));
 Widget metric(String title,String value)=>SizedBox(width:170,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))]))));
}
