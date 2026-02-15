// Nexus — App-wide constants.
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase Storage bucket for item images. Must be created in Dashboard → Storage.
const String kStorageBucketName = 'manifest-assets';

/// Base URL for the FastAPI backend. Read from .env (API_BASE_URL) or default.
String get apiBaseUrl =>
    dotenv.env['API_BASE_URL']?.trim() ?? 'http://localhost:8000';
