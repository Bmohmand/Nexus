import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants.dart';
import '../models/search_result.dart';

/// Base URL for the FastAPI backend. Read from .env (API_BASE_URL) or default.
String get apiBaseUrl =>
    dotenv.env['API_BASE_URL']?.trim() ?? kApiBaseUrl;

/// HTTP client for the Manifest FastAPI middleware.
/// Handles AI operations: ingest, search, pack.
class ManifestApiClient {
  late final Dio _dio;

  ManifestApiClient() {
    final base = apiBaseUrl;
    _dio = Dio(
      BaseOptions(
        baseUrl: '$base/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60), // AI calls can be slow
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ---- Health ----
  Future<bool> healthCheck() async {
    try {
      final response = await Dio().get('$apiBaseUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---- Ingest ----
  Future<Map<String, dynamic>> ingestByUrl({
    required String imageUrl,
    String? userId,
  }) async {
    final response = await _dio.post('/ingest', data: {
      'image_url': imageUrl,
      if (userId != null) 'user_id': userId,
    });
    return response.data as Map<String, dynamic>;
  }

  // ---- Search ----
  Future<SearchResponse> search({
    required String query,
    int topK = 15,
    String? domainFilter,
    String? categoryFilter,
    bool synthesize = true,
    String? userId,
  }) async {
    final response = await _dio.post('/search', data: {
      'query': query,
      'top_k': topK,
      if (domainFilter != null) 'domain_filter': domainFilter,
      if (categoryFilter != null) 'category_filter': categoryFilter,
      'synthesize': synthesize,
      if (userId != null) 'user_id': userId,
    });
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ---- Pack ----
  Future<PackResponse> pack({
    required String query,
    required dynamic constraints, // String preset or Map
    int topK = 30,
    String? categoryFilter,
    String? userId,
  }) async {
    final response = await _dio.post('/pack', data: {
      'query': query,
      'constraints': constraints,
      'top_k': topK,
      if (categoryFilter != null) 'category_filter': categoryFilter,
      if (userId != null) 'user_id': userId,
    });
    return PackResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
