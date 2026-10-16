import 'package:flutter/material.dart';
import '../../../core/config/formatters.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';
class AnalyticsScreen extends StatefulWidget{
 const AnalyticsScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<AnalyticsScreen> createState()=>_AnalyticsScreenState();
}
class _AnalyticsScreenState extends State<AnalyticsScreen>{
 Future<SalesAnalyticsBundle>? future;String? store;int revision=-1;int days=30;
 void load(){store=widget.appState.activeStore?.id;revision=widget.appState.storeDataRevision;final end=DateTime.now();future=store==null?null:widget.appState.repository.fetchAnalytics(storeId:store!,fromDate:NsFormatters.calendarDate(end.subtract(Duration(days:days))),toDate:NsFormatters.calendarDate(end));}
 @override void initState(){super.initState();load();widget.appState.addListener(changed);}
 void changed(){if(store!=widget.appState.activeStore?.id||revision!=widget.appState.storeDataRevision)setState(load);}
 @override void dispose(){widget.appState.removeListener(changed);super.dispose();}
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(load);try{await future;}catch(_){}},child:ListView(padding:const EdgeInsets.all(20),children:[
 Text('Analitik',style:Theme.of(context).textTheme.headlineSmall),
 if(!widget.appState.activeRole.canViewCustomersAndAnalytics)const Text('Tidak memiliki akses analitik.'),
 if(widget.appState.activeRole.canViewCustomersAndAnalytics)...[
 Wrap(spacing:8,children:[7,30,90].map((n)=>ChoiceChip(label:Text(n.toString()+' hari'),selected:days==n,onSelected:(_)=>setState((){days=n;load();}))).toList()),
 FutureBuilder<SalesAnalyticsBundle>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return ListTile(title:const Text('Gagal memuat analitik'),subtitle:Text(s.error.toString()),trailing:IconButton(onPressed:()=>setState(load),icon:const Icon(Icons.refresh)));
 final d=s.data;if(d==null)return const Text('Belum ada data.');
 return Column(children:[
 ListTile(title:const Text('Omzet terverifikasi'),trailing:Text(NsFormatters.rupiah(d.verifiedRevenueIdr))),
 ListTile(title:const Text('Total pesanan'),trailing:Text(d.totalOrders.toString())),
 ListTile(title:const Text('Pesanan dibayar'),trailing:Text(d.paidOrders.toString())),
 ListTile(title:const Text('Rata-rata pesanan'),trailing:Text(NsFormatters.rupiah(d.averagePaidOrderIdr))),
 const Divider(),...d.dailyPoints.map((p)=>ListTile(title:Text(p.day),subtitle:Text(p.orders.toString()+' pesanan'),trailing:Text(NsFormatters.rupiah(p.revenueIdr)))),
 ]);
 }),
 ],
 ]));
}
