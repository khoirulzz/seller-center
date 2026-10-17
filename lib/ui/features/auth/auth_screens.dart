import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/ns_error_mapper.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../state/seller_app_state.dart';
import 'seller_splash_screen.dart';

class SplashSessionScreen extends StatelessWidget {
  const SplashSessionScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  Widget build(BuildContext context) => const SellerSplashScreen();
}

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    super.key,
    required this.appState,
    required this.isRegister,
  });
  final SellerAppState appState;
  final bool isRegister;
  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool hidden = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || widget.appState.isBusy) return;
    TextInput.finishAutofillContext();
    final ok = widget.isRegister
        ? await widget.appState.register(email.text.trim(), password.text)
        : await widget.appState.signIn(email.text.trim(), password.text);
    if (!mounted) return;
    if (!ok)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.globalError ?? 'Permintaan belum dapat diproses.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.isRegister ? 'Daftar' : 'Masuk')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: NsBrandMark(size: 46, showLabel: true),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.isRegister
                            ? 'Buat akun seller'
                            : 'Masuk ke Nalaro Seller',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.isRegister
                            ? 'Kelola tokomu dari satu tempat.'
                            : 'Lanjutkan mengelola pesanan dan produk tokomu.',
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch((v ?? '').trim())
                            ? null
                            : 'Masukkan email yang valid.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: password,
                        obscureText: hidden,
                        autofillHints: [
                          widget.isRegister
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          suffixIcon: IconButton(
                            tooltip: hidden
                                ? 'Tampilkan kata sandi'
                                : 'Sembunyikan kata sandi',
                            onPressed: () => setState(() => hidden = !hidden),
                            icon: Icon(
                              hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (widget.isRegister &&
                              !FirebaseAuthService.isPasswordPolicySatisfied(
                                v ?? '',
                              )) {
                            return 'Minimal 8 karakter, huruf besar, kecil dan angka.';
                          }
                          if ((v?.length ?? 0) < 1)
                            return 'Kata sandi wajib diisi.';
                          return null;
                        },
                      ),
                      if (widget.isRegister) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Gunakan minimal 8 karakter, huruf besar, huruf kecil, dan angka.',
                        ),
                      ],
                      const SizedBox(height: 26),
                      ListenableBuilder(
                        listenable: widget.appState,
                        builder: (ctx, _) => FilledButton(
                          onPressed: widget.appState.isBusy ? null : submit,
                          child: Text(
                            widget.appState.isBusy
                                ? 'Memproses…'
                                : widget.isRegister
                                    ? 'Buat akun'
                                    : 'Masuk',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          if (widget.isRegister) {
                            context.canPop()
                                ? context.pop()
                                : context.go('/login');
                          } else {
                            context.push('/register');
                          }
                        },
                        child: Text(
                          widget.isRegister
                              ? 'Sudah punya akun? Masuk'
                              : 'Belum punya akun? Daftar',
                        ),
                      ),
                      if (!widget.isRegister)
                        TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: const Text('Lupa kata sandi?'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  String? message;
  bool busy = false;
  int countdown = 0;
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> resend() async {
    if (busy || countdown > 0) return;
    setState(() => busy = true);
    try {
      await widget.appState.repository.resendVerificationEmail();
      if (!mounted) return;
      timer?.cancel();
      setState(() {
        countdown = 60;
        message =
            'Email verifikasi telah dikirim. Periksa kotak masuk dan spam.';
      });
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (countdown <= 1) {
          timer.cancel();
          setState(() => countdown = 0);
        } else {
          setState(() => countdown--);
        }
      });
    } catch (e) {
      if (mounted) setState(() => message = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verifikasi email')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  const NsBrandMark(size: 56),
                  const SizedBox(height: 22),
                  Text(
                    'Periksa emailmu',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kami mengirim tautan verifikasi ke ${widget.appState.user?.email ?? 'email akunmu'}. Buka tautannya lalu kembali ke aplikasi.',
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(message!),
                    ),
                  const SizedBox(height: 20),
                  ListenableBuilder(
                    listenable: widget.appState,
                    builder: (ctx, _) => FilledButton(
                      onPressed: widget.appState.isBusy
                          ? null
                          : () async {
                              final ok =
                                  await widget.appState.checkEmailVerified();
                              if (mounted && !ok)
                                setState(
                                  () => message = widget.appState.globalError,
                                );
                            },
                      child: Text(
                        widget.appState.isBusy
                            ? 'Memeriksa…'
                            : 'Saya sudah verifikasi',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy || countdown > 0 ? null : resend,
                    child: Text(
                      countdown > 0
                          ? 'Kirim ulang dalam ${countdown} dtk'
                          : 'Kirim ulang email',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.appState.signOut,
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  String? message;
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      setState(() => message = 'Masukkan email yang valid.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.appState.repository.sendPasswordReset(email.text);
      if (mounted)
        setState(
          () => message =
              'Jika akun terdaftar, tautan pemulihan akan dikirim. Periksa juga spam.',
        );
    } catch (e) {
      if (mounted) setState(() => message = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pulihkan kata sandi')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Lupa kata sandi?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Masukkan alamat email akun agar kami dapat mengirim tautan pemulihan.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(labelText: 'Email akun'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Mengirim…' : 'Kirim tautan pemulihan'),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(message!),
                    ),
                  TextButton(
                    onPressed: () {
                      context.canPop() ? context.pop() : context.go('/login');
                    },
                    child: const Text('Kembali ke login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
