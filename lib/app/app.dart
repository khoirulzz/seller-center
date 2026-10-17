import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/ns_theme.dart';
import '../data/services/app_update_service.dart';
import '../ui/features/updates/app_update_screen.dart';
import '../ui/state/app_update_controller.dart';
import '../ui/state/seller_app_state.dart';
import 'router.dart';

class NalaroSellerApp extends StatefulWidget {
  const NalaroSellerApp(
      {super.key, required this.appState, this.updateController});

  final SellerAppState appState;
  final AppUpdateController? updateController;

  @override
  State<NalaroSellerApp> createState() => _NalaroSellerAppState();
}

class _NalaroSellerAppState extends State<NalaroSellerApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AppUpdateController _updates;

  @override
  void initState() {
    super.initState();
    _router = createSellerRouter(widget.appState);
    _updates = widget.updateController ??
        AppUpdateController(service: ShorebirdAppUpdateService());
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_updates.checkForUpdates());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_updates.checkForUpdates());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.updateController == null) _updates.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: NsTheme.light,
      routerConfig: _router,
      builder: (context, child) => AppUpdateScope(
        controller: _updates,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
