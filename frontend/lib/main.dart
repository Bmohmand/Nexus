import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/supabase_config.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize();
  } catch (error) {
    runApp(_ConfigErrorApp(error: error));
    return;
  }

  runApp(const ProviderScope(child: ManifestApp()));
}

class ManifestApp extends StatelessWidget {
  const ManifestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Manifest',
      theme: manifestLightTheme(),
      darkTheme: manifestDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: manifestRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _ConfigErrorApp extends StatelessWidget {
  final Object error;

  const _ConfigErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your .env file and ensure '
                  'SUPABASE_URL and SUPABASE_ANON_KEY are set correctly.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
