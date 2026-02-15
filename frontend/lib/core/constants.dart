// Nexus — App-wide constants.
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'platform_utils.dart';

/// Supabase Storage bucket for item images. Must be created in Dashboard → Storage.
const String kStorageBucketName = 'manifest-assets';

const String _kLocalhostBase = 'http://localhost:8000';
const String _kAndroidEmulatorBase = 'http://10.0.2.2:8000';

/// Base URL for the FastAPI backend. On Android emulator, localhost is replaced with 10.0.2.2 so the app can reach the host.
String get apiBaseUrl {
  final fromEnv = dotenv.env['API_BASE_URL']?.trim();
  final effective = fromEnv ?? _kLocalhostBase;
  final isLocalhost = effective.isEmpty ||
      effective == _kLocalhostBase ||
      effective.contains('localhost');
  if (isAndroid && isLocalhost) return _kAndroidEmulatorBase;
  return effective.isEmpty ? _kLocalhostBase : effective;
}
