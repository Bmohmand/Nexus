import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'models/search_result.dart';
import 'supabase_config.dart';

/// API service for Nexus: FastAPI backend (ingest, search, health) and Supabase (items).
class NexusApiService {
  static Dio? _dio;
  static Dio get _backend {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: '$apiBaseUrl/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return _dio!;
  }

  /// Ingest by image URL (backend expects JSON body). Call after uploading image to Storage.
  static Future<Map<String, dynamic>?> ingestByUrl({
    required String imageUrl,
    String? userId,
  }) async {
    try {
      final response = await _backend.post('/ingest', data: {
        'image_url': imageUrl,
        if (userId != null) 'user_id': userId,
      });
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Exception during ingest: $e');
      return null;
    }
  }

  /// Semantic search — POST /api/v1/search. Returns backend SearchResponse.
  static Future<SearchResponse?> search({
    required String query,
    int topK = 15,
    bool synthesize = true,
  }) async {
    try {
      final response = await _backend.post('/search', data: {
        'query': query,
        'top_k': topK,
        'synthesize': synthesize,
      });
      final data = response.data;
      if (data == null) return null;
      return SearchResponse.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      print('Exception during search: $e');
      return null;
    }
  }

  /// Health check — GET /health (at base URL, not under /api/v1).
  static Future<bool> healthCheck() async {
    try {
      final response = await Dio().get('$apiBaseUrl/health').timeout(
            const Duration(seconds: 5),
          );
      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }

  /// Get all user items from Supabase (items table).
  static Future<List<Map<String, dynamic>>?> getUserItems({
    required String userId,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('items')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Exception fetching items: $e');
      return null;
    }
  }

  /// Store item metadata in Supabase (items table).
  static Future<bool> storeItemMetadata({
    required String userId,
    required String itemId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await SupabaseConfig.client.from('items').insert({
        'id': itemId,
        'user_id': userId,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Exception storing item metadata: $e');
      return false;
    }
  }

  /// Supabase health check.
  static Future<bool> supabaseHealthCheck() async {
    try {
      await SupabaseConfig.client.from('items').select().limit(1).maybeSingle();
      return true;
    } catch (_) {
      return false;
    }
  }
}
