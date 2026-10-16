import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/slug_utils.dart';
import '../../state/seller_app_state.dart';

class CreateStoreWizardScreen extends StatefulWidget {
 const CreateStoreWizardScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<CreateStoreWizardScreen> createState()=>_CreateStoreWizardScreenState();
}
class _CreateStoreWizardScreenState extends State<CreateStoreWizardScreen>{
 final name=TextEditingController(),slug=TextEditingController(),description=TextEditingController();
 String? error;bool busy=false;
 @override void dispose(){name.dispose();slug.dispose();description.dispose();super.dispose();}
 Future<void> save()async{
 final safe=NsSlugUtils.normalize(slug.text),invalid=NsSlugUtils.validate(NsSlugUtils.normalize(slug.text));
 if(name.text.trim().length<3||invalid!=null){setState(()=>error=invalid??'Nama toko minimal 3 karakter');return;}
 setState((){busy=true;error=null;});
 try{if(!await widget.appState.repository.checkSlugAvailable(safe)){if(mounted)setState(()=>error='Link toko tidak tersedia');return;}
 final result=await widget.appState.createNewStore(name:name.text,slug:safe,description:description.text);
 if(result==null&&mounted)setState(()=>error=widget.appState.globalError??'Gagal membuat toko');
 }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Buat toko')),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:540),child:ListView(padding:const EdgeInsets.all(24),children:[
 const Text('Mulai berjualan dengan toko milikmu',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:20),
 TextField(controller:name,decoration:const InputDecoration(labelText:'Nama toko')),
 const SizedBox(height:12),TextField(controller:slug,decoration:const InputDecoration(labelText:'Link toko')),
 const SizedBox(height:12),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Deskripsi (opsional)')),
 if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
 const SizedBox(height:20),FilledButton(onPressed:busy?null:save,child:Text(busy?'Menyimpan...':'Buat toko')),
 if(widget.appState.stores.isNotEmpty)TextButton(onPressed:()=>context.go('/beranda'),child:const Text('Kembali')),
  ]))));
}
Future<void> showNsStoreSwitcherSheet({required BuildContext context,required SellerAppState appState})async{
 await showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(sheet)=>SafeArea(child:ListView(shrinkWrap:true,children:[
 const ListTile(title:Text('Pilih toko')),
 ...appState.stores.map((store)=>ListTile(title:Text(store.name),subtitle:Text(store.slug),trailing:appState.activeStore?.id==store.id?const Icon(Icons.check_circle):null,onTap:()async{await appState.selectActiveStore(store.id);if(sheet.mounted)Navigator.pop(sheet);})),
 ListTile(leading:const Icon(Icons.add),title:const Text('Buat toko baru'),onTap:(){Navigator.pop(sheet);context.push('/stores/create');}),
  ])));
}
