import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/config/app_config.dart';
import '../core/theme/ns_theme.dart';
import '../ui/state/seller_app_state.dart';
import 'router.dart';

class NalaroSellerApp extends StatefulWidget {
  const NalaroSellerApp({
    super.key,
    required this.appState,
  });

  final SellerAppState appState;

  @override
  State<NalaroSellerApp> createState() => _NalaroSellerAppState();
}

class _NalaroSellerAppState extends State<NalaroSellerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createSellerRouter(widget.appState);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: NsTheme.light,
      routerConfig: _router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
