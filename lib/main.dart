import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'ui/state/seller_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final appState = SellerAppState();
  // Mulai pemulihan sesi secara asinkron saat aplikasi dibuka
  appState.initializeApp();
  runApp(NalaroSellerApp(appState: appState));
}
