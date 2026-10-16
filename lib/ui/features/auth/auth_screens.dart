import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../state/seller_app_state.dart';

class SplashSessionScreen extends StatelessWidget {
 const SplashSessionScreen({super.key, required this.appState});
 final SellerAppState appState;
 @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
class LoginRegisterScreen extends StatefulWidget {
 const LoginRegisterScreen({super.key, required this.appState, required this.isRegister});
 final SellerAppState appState; final bool isRegister;
 @override State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}
class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
 final email = TextEditingController(), password = TextEditingController();
 final form = GlobalKey<FormState>(); bool hidden = true;
 @override void dispose(){email.dispose();password.dispose();super.dispose();}
 Future<void> submit() async {
  if (!form.currentState!.validate()) return;
  final ok = widget.isRegister ? await widget.appState.register(email.text,password.text) : await widget.appState.signIn(email.text,password.text);
  if (!mounted) return;
  if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.appState.globalError ?? 'Gagal memproses permintaan')));
 }
 @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isRegister?'Daftar Seller Center':'Masuk Seller Center')),
 body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:440),child:Form(key:form,child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
 const Icon(Icons.storefront_outlined,size:64),const SizedBox(height:20),
 TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email'),validator:(v)=>v==null||!v.contains('@')?'Email tidak valid':null),
 const SizedBox(height:12),
 TextFormField(controller:password,obscureText:hidden,decoration:InputDecoration(labelText:'Kata sandi',suffixIcon:IconButton(onPressed:()=>setState(()=>hidden=!hidden),icon:Icon(hidden?Icons.visibility:Icons.visibility_off))),validator:(v)=>(v?.length??0)<8?'Minimal 8 karakter':null),
 const SizedBox(height:20),
 ListenableBuilder(listenable:widget.appState,builder:(context,_)=>FilledButton(onPressed:widget.appState.isBusy?null:submit,child:Text(widget.appState.isBusy?'Memproses...':widget.isRegister?'Daftar':'Masuk'))),
 TextButton(onPressed:()=>context.go(widget.isRegister?'/login':'/register'),child:Text(widget.isRegister?'Sudah punya akun? Masuk':'Belum punya akun? Daftar')),
 if(!widget.isRegister)TextButton(onPressed:()=>context.go('/forgot-password'),child:const Text('Lupa kata sandi?')),
 ]))))); 
}
class VerifyEmailScreen extends StatefulWidget {
 const VerifyEmailScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<VerifyEmailScreen> createState()=>_VerifyEmailScreenState();
}
class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
 String? message;
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Verifikasi email')),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
 const Icon(Icons.mark_email_unread_outlined,size:72),const Text('Buka tautan verifikasi pada email Anda.',textAlign:TextAlign.center),
 if(message!=null)Text(message!,textAlign:TextAlign.center),
 FilledButton(onPressed:()async{await widget.appState.checkEmailVerified();if(mounted)setState(()=>message=widget.appState.globalError);},child:const Text('Saya sudah verifikasi')),
 TextButton(onPressed:()async{try{await widget.appState.repository.resendVerificationEmail();if(mounted)setState(()=>message='Email verifikasi dikirim kembali');}catch(e){if(mounted)setState(()=>message=e.toString());}},child:const Text('Kirim ulang')),
 TextButton(onPressed:widget.appState.signOut,child:const Text('Keluar')),
 ]))));
}
class ForgotPasswordScreen extends StatefulWidget {
 const ForgotPasswordScreen({super.key,required this.appState});final SellerAppState appState;
 @override State<ForgotPasswordScreen> createState()=>_ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>{
 final email=TextEditingController();String? message;
 @override void dispose(){email.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Lupa kata sandi')),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
 TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email akun')),
 const SizedBox(height:16),
 FilledButton(onPressed:()async{if(!email.text.contains('@')){setState(()=>message='Email tidak valid');return;}try{await widget.appState.repository.sendPasswordReset(email.text);if(mounted)setState(()=>message='Jika akun terdaftar, tautan pemulihan akan dikirim.');}catch(e){if(mounted)setState(()=>message=e.toString());}},child:const Text('Kirim tautan pemulihan')),
 if(message!=null)Text(message!),
 ]))));
}
