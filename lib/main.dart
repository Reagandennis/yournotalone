import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'billing/purchases_service.dart';
import 'brand.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zpcfavemnvfhqaxqhmri.supabase.co',
    publishableKey: 'sb_publishable_yKBVrkk13Sm5hMZtrerdiw_uTrhlNd9',
  );
  await PurchasesService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Δεν είσαι μόνος',
      theme: buildAppTheme(),
      home: const SplashScreen(next: AuthGate()),
    );
  }
}
