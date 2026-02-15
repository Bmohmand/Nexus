// Supabase configuration from .env. Load .env before calling initialize().
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'Missing Supabase credentials. Please check your .env file and ensure '
        'SUPABASE_URL and SUPABASE_ANON_KEY are set.',
      );
    }

    if (supabaseUrl == 'your_project_url_here' ||
        supabaseAnonKey == 'your_anon_key_here') {
      throw Exception(
        'Please update your .env file with actual Supabase credentials.\n'
        'Get them from: Supabase Dashboard > Project Settings > API',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
