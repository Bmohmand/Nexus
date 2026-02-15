import 'dart:convert';
import 'dart:io'; 
import 'package:http/http.dart' as http;
import 'supabase_config.dart';

class NexusApiService {
  // Supabase client headers
  static Map<String, String> get _supabaseHeaders => {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

  // Your FastAPI backend URL
  static const String backendUrl = 'http://10.27.98.162:8000';

  /// Upload image to backend for ingestion
  /// POST /api/v1/ingest
  /// Upload image to backend for ingestion
/// POST /api/v1/ingest (expects JSON with image_url)
static Future<Map<String, dynamic>?> ingestImage({
  required String imageUrl,  // Changed from imagePath to imageUrl
  String? userId,
}) async {
  try {
    final uri = Uri.parse('$backendUrl/api/v1/ingest');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image_url': imageUrl,  // Send URL, not file
        if (userId != null) 'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Error ingesting image: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    print('Exception during image ingest: $e');
    return null;
  }
}

  /// Perform semantic search
  /// POST /api/v1/search
  static Future<List<Map<String, dynamic>>?> semanticSearch({
    required String query,
    int topK = 10,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/v1/search');
      
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
        '${SupabaseConfig.supabaseUrl}/rest/v1/manifest_items?user_id=eq.$userId&select=*',
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
      final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/manifest_items');

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
      final uri = Uri.parse('$backendUrl/health');
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
      final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/manifest_items?select=id&limit=1');
      final response = await http
          .get(uri, headers: _supabaseHeaders)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Supabase health check failed: $e');
      return false;
    }
  }

  /// Upload image to Supabase Storage and return public URL
  /// Upload image to Supabase Storage and return public URL
static Future<String?> uploadImageToStorage(String imagePath) async {
  try {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final response = await http.post(
      Uri.parse('${SupabaseConfig.supabaseUrl}/storage/v1/object/manifest-assets/$fileName'),
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,  // ADD THIS LINE
        'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    print('Upload response: ${response.statusCode} - ${response.body}');  // ADD DEBUG

    if (response.statusCode == 200 || response.statusCode == 201) {
      return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/manifest-assets/$fileName';
    } else {
      print('Error uploading to storage: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    print('Exception uploading image: $e');
    return null;
  }
}
}