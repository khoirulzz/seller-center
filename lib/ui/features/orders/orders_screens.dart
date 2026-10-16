import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';
class OrdersListScreen extends StatefulWidget {
 const OrdersListScreen({super.key,required this.appState}); final SellerAppState appState;
 @override State<OrdersListScreen> createState()=>_OrdersListScreenState();
}
class _OrdersListScreenState extends State<OrdersListScreen> {
 String filter='all';Future<({List<OrderModel> orders,bool hasMore})>? future;String? store;int revision=-1;
 void load(){store=widget.appState.activeStore?.id;revision=widget.appState.storeDataRevision;future=store==null?null:widget.appState.repository.fetchOrders(storeId:store!,status:filter);}
 @override void initState(){super.initState();load();widget.appState.addListener(changed);}
 void changed(){if(store!=widget.appState.activeStore?.id||revision!=widget.appState.storeDataRevision)setState(load);}
 @override void dispose(){widget.appState.removeListener(changed);super.dispose();}
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(load);try{await future;}catch(_){}},child:ListView(padding:const EdgeInsets.all(16),children:[
 Text('Pesanan',style:Theme.of(context).textTheme.headlineSmall),
 Wrap(spacing:8,children:['all','pending','paid','completed','canceled'].map((v)=>ChoiceChip(label:Text(v),selected:filter==v,onSelected:(_)=>setState((){filter=v;load();}))).toList()),
 FutureBuilder<({List<OrderModel> orders,bool hasMore})>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return ListTile(title:const Text('Gagal memuat pesanan'),subtitle:Text(s.error.toString()),trailing:IconButton(onPressed:()=>setState(load),icon:const Icon(Icons.refresh)));
 final orders=s.data?.orders??[];
 if(orders.isEmpty)return const Padding(padding:EdgeInsets.all(32),child:Text('Belum ada pesanan.'));
 return Column(children:orders.map((o)=>Card(child:ListTile(title:Text(o.orderNumber),subtitle:Text(o.customerName+' · '+o.paymentStatus),trailing:Text(NsFormatters.rupiah(o.totalIdr)),onTap:()=>context.push('/pesanan/'+Uri.encodeComponent(o.id))))).toList());
 }),
 ]));
}
class OrderDetailScreen extends StatefulWidget {
 const OrderDetailScreen({super.key,required this.appState,required this.orderId});
 final SellerAppState appState;final String orderId;
 @override State<OrderDetailScreen> createState()=>_OrderDetailScreenState();
}
class _OrderDetailScreenState extends State<OrderDetailScreen>{
 late Future<OrderDetailBundle> future;bool busy=false;
 void load(){future=widget.appState.repository.fetchOrderDetail(storeId:widget.appState.activeStore!.id,orderId:widget.orderId);}
 @override void initState(){super.initState();load();}
 Future<void> act(String action)async{
 final confirmed=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:const Text('Konfirmasi tindakan'),content:Text('Yakin ingin menjalankan tindakan '+action+' untuk pesanan ini? Perubahan akan dikirim ke server.'),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Kembali')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Konfirmasi'))]));
 if(confirmed!=true||!mounted)return;
 setState(()=>busy=true);
 try{
 final repo=widget.appState.repository,id=widget.appState.activeStore!.id,role=widget.appState.activeRole;
 if(action=='approve'||action=='reject')await repo.reviewOrderPayment(storeId:id,orderId:widget.orderId,decision:action,role:role);
 else if(action=='cancel')await repo.cancelOrder(storeId:id,orderId:widget.orderId,role:role);
 else await repo.updateOrderFulfillment(storeId:id,orderId:widget.orderId,nextStatus:action,role:role);
 widget.appState.notifyStoreDataMutated();if(mounted)setState(load);
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Detail pesanan')),body:FutureBuilder<OrderDetailBundle>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return Center(child:Text(s.error.toString()));
 final data=s.data!;final o=data.order;
 return ListView(padding:const EdgeInsets.all(20),children:[
 Text(o.orderNumber,style:Theme.of(context).textTheme.headlineSmall),
 ListTile(title:Text(o.customerName),subtitle:Text(o.contactEmail+' · '+o.contactPhone)),
 ListTile(title:const Text('Total'),trailing:Text(NsFormatters.rupiah(o.totalIdr))),
 ListTile(title:const Text('Pembayaran'),trailing:Text(o.paymentStatus)),
 ListTile(title:const Text('Pemenuhan'),trailing:Text(o.fulfillmentStatus)),
 if(o.shippingAddress.isNotEmpty)ListTile(title:const Text('Alamat'),subtitle:Text(o.shippingAddress)),
 const Divider(),Text('Item',style:Theme.of(context).textTheme.titleLarge),
 ...data.items.map((i)=>ListTile(title:Text(i.nameSnapshot),subtitle:Text(i.variantSnapshot+' · '+i.quantity.toString()),trailing:Text(NsFormatters.rupiah(i.lineTotalIdr)))),
 if(o.canVerifyPayment(widget.appState.activeRole))Wrap(spacing:8,children:[OutlinedButton(onPressed:busy?null:()=>act('reject'),child:const Text('Tolak pembayaran')),FilledButton(onPressed:busy?null:()=>act('approve'),child:const Text('Verifikasi pembayaran'))]),
 ...o.allowedNextFulfillmentStates(widget.appState.activeRole).map((v)=>OutlinedButton(onPressed:busy?null:()=>act(v),child:Text('Ubah status: '+v))),
 if(o.canCancel(widget.appState.activeRole))TextButton(onPressed:busy?null:()=>act('cancel'),child:const Text('Batalkan pesanan')),
 const Divider(),Text('Riwayat',style:Theme.of(context).textTheme.titleLarge),
 ...data.timeline.map((e)=>ListTile(title:Text(e.action),subtitle:Text(NsFormatters.dateTime(e.createdAt)))),
 ]);
 }));
}
