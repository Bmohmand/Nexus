import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    const ProviderScope(
      child: ManifestApp(),
    ),
  );
}

class ManifestApp extends StatelessWidget {
  const ManifestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Manifest',
      theme: manifestLightTheme(),
      darkTheme: manifestDarkTheme(),
      themeMode: ThemeMode.dark, // Dark-first tactical aesthetic
      routerConfig: manifestRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
