import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_config.dart';

class NexusApiService {
  // Supabase client headers
  static Map<String, String> get _supabaseHeaders => {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

  // Your FastAPI backend URL - update this with your actual backend URL
  static const String backendUrl = 'http://10.27.98.162:8000/api/v1'; // TODO: Update this

  /// Upload image to backend for ingestion
  /// POST /api/ingest
  static Future<Map<String, dynamic>?> ingestImage({
    required String imagePath,
    String? userId,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/ingest');
      
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        print('Error ingesting image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception during image ingest: $e');
      return null;
    }
  }

  /// Perform semantic search
  /// POST /api/search/semantic
  static Future<List<Map<String, dynamic>>?> semanticSearch({
    required String query,
    int topK = 10,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/search/semantic');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'top_k': topK,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      } else {
        print('Error performing search: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception during semantic search: $e');
      return null;
    }
  }

  /// Get all user items from Supabase
  static Future<List<Map<String, dynamic>>?> getUserItems({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${SupabaseConfig.supabaseUrl}/rest/v1/items?user_id=eq.$userId&select=*',
      );

      final response = await http.get(uri, headers: _supabaseHeaders);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        print('Error fetching items: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception fetching items: $e');
      return null;
    }
  }

  /// Store item metadata in Supabase
  static Future<bool> storeItemMetadata({
    required String userId,
    required String itemId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/items');

      final response = await http.post(
        uri,
        headers: _supabaseHeaders,
        body: json.encode({
          'id': itemId,
          'user_id': userId,
          'metadata': metadata,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Exception storing item metadata: $e');
      return false;
    }
  }

  /// Health check - verify backend is running
  static Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('http://10.27.98.162:8000/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }

  /// Supabase health check
  static Future<bool> supabaseHealthCheck() async {
    try {
      final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/');
      final response = await http
          .get(uri, headers: _supabaseHeaders)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      print('Supabase health check failed: $e');
      return false;
    }
  }
}
