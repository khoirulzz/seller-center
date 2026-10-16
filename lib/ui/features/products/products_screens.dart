import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../core/config/slug_utils.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';
class ProductsAndInventoryScreen extends StatefulWidget{
 const ProductsAndInventoryScreen({super.key,required this.appState,required this.initialSubTab});
 final SellerAppState appState;final String initialSubTab;
 @override State<ProductsAndInventoryScreen> createState()=>_ProductsAndInventoryScreenState();
}
class _ProductsAndInventoryScreenState extends State<ProductsAndInventoryScreen>{
 Future<List<Product>>? future;String? store;int revision=-1;
 void load(){store=widget.appState.activeStore?.id;revision=widget.appState.storeDataRevision;future=store==null?null:widget.appState.repository.fetchProducts(store!);}
 @override void initState(){super.initState();load();widget.appState.addListener(changed);}
 void changed(){if(store!=widget.appState.activeStore?.id||revision!=widget.appState.storeDataRevision)setState(load);}
 @override void dispose(){widget.appState.removeListener(changed);super.dispose();}
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(load);try{await future;}catch(_){}},child:ListView(padding:const EdgeInsets.all(16),children:[
 Row(children:[Expanded(child:Text('Produk & Stok',style:Theme.of(context).textTheme.headlineSmall)),if(widget.appState.activeRole.canManageCatalog)IconButton(onPressed:()=>context.push('/produk/editor'),icon:const Icon(Icons.add))]),
 FutureBuilder<List<Product>>(future:future,builder:(context,s){
 if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
 if(s.hasError)return ListTile(title:const Text('Gagal memuat produk'),subtitle:Text(s.error.toString()),trailing:IconButton(onPressed:()=>setState(load),icon:const Icon(Icons.refresh)));
 final items=s.data??[];
 if(items.isEmpty)return const Padding(padding:EdgeInsets.all(32),child:Text('Belum ada produk.'));
 return Column(children:items.map((p)=>Card(child:ListTile(title:Text(p.name),subtitle:Text(p.status+' · Stok '+p.totalAvailableStock.toString()),trailing:Text(NsFormatters.rupiah(p.priceIdr)),onTap:()=>context.push('/produk/editor?id='+Uri.encodeQueryComponent(p.id))))).toList());
 }),
 ]));
}
class ProductEditorScreen extends StatefulWidget{
 const ProductEditorScreen({super.key,required this.appState,this.productId});final SellerAppState appState;final String? productId;
 @override State<ProductEditorScreen> createState()=>_ProductEditorScreenState();
}
class _ProductEditorScreenState extends State<ProductEditorScreen>{
 final name=TextEditingController(),slug=TextEditingController(),description=TextEditingController(),price=TextEditingController(),sku=TextEditingController(),stock=TextEditingController(text:'0');
 Product? original;String? error;bool busy=false;
 @override void initState(){super.initState();if(widget.productId!=null)load();}
 Future<void> load()async{try{final list=await widget.appState.repository.fetchProducts(widget.appState.activeStore!.id);final p=list.firstWhere((p)=>p.id==widget.productId);if(!mounted)return;setState((){original=p;name.text=p.name;slug.text=p.slug;description.text=p.description;price.text=p.priceIdr.toString();sku.text=p.variants.isEmpty?'':p.variants.first.sku;stock.text=p.variants.isEmpty?'0':p.variants.first.stockQty.toString();});}catch(e){if(mounted)setState(()=>error=e.toString());}}
 @override void dispose(){for(final c in [name,slug,description,price,sku,stock]){c.dispose();}super.dispose();}
 Future<void> save()async{
 final safe=NsSlugUtils.normalize(slug.text),amount=int.tryParse(price.text),qty=int.tryParse(stock.text);
 if(name.text.trim().isEmpty||NsSlugUtils.validate(safe)!=null||amount==null||amount<0||qty==null||qty<0||sku.text.trim().isEmpty){setState(()=>error='Periksa nama, link, harga, SKU dan stok');return;}
 setState(()=>busy=true);
 try{
 final variant=ProductVariant(id:original?.variants.isNotEmpty==true?original!.variants.first.id:null,sku:sku.text.trim(),optionLabel:'Default',stockQty:qty,reservedQty:original?.variants.isNotEmpty==true?original!.variants.first.reservedQty:0);
 final p=Product(id:original?.id??'',slug:safe,name:name.text.trim(),description:description.text,priceIdr:amount,category:original?.category??'Produk',primaryImageUrl:original?.primaryImageUrl,gallery:original?.gallery??[],status:original?.status??'draft',variants:[variant]);
 await widget.appState.repository.saveProduct(storeId:widget.appState.activeStore!.id,product:p,isUpdate:widget.productId!=null,role:widget.appState.activeRole);
 widget.appState.notifyStoreDataMutated();if(mounted)context.pop();
 }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.productId==null?'Tambah produk':'Edit produk')),body:ListView(padding:const EdgeInsets.all(20),children:[
 TextField(controller:name,decoration:const InputDecoration(labelText:'Nama produk')),TextField(controller:slug,decoration:const InputDecoration(labelText:'Slug')),
 TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Deskripsi')),
 TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Harga Rp')),
 TextField(controller:sku,decoration:const InputDecoration(labelText:'SKU varian utama')),
 TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stok')),
 if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
 FilledButton(onPressed:busy||!widget.appState.activeRole.canManageCatalog?null:save,child:Text(busy?'Menyimpan...':'Simpan produk')),
 ]));
}
