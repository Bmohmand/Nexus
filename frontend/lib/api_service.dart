import 'dart:convert';
import 'dart:io'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NexusApiService {
  // Supabase client headers
  static Map<String, String> get _supabaseHeaders => {
        'apikey': dotenv.env['SUPABASE_ANON_KEY'] ?? '',
        'Authorization': 'Bearer ${dotenv.env['SUPABASE_ANON_KEY'] ?? ''}',
        'Content-Type': 'application/json',
      };

  // Your FastAPI backend URL
  static String get backendUrl {
    final url = dotenv.env['API_BASE_URL'] ?? 'http://10.27.98.162:8000';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

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
        return List<Map<String, dynamic>>.from(data['selected_items'] ?? data['raw_results']);
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
        '${dotenv.env['SUPABASE_URL']}/rest/v1/manifest_items?user_id=eq.$userId&select=*',
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
      final uri = Uri.parse('${dotenv.env['SUPABASE_URL']}/rest/v1/manifest_items');

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
      final uri = Uri.parse('${dotenv.env['SUPABASE_URL']}/rest/v1/manifest_items?select=id&limit=1');
      final response = await http
          .get(uri, headers: _supabaseHeaders)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Supabase health check failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Storage Containers
  // ---------------------------------------------------------------------------

  /// List all storage containers for a user
  /// GET /api/v1/containers
  static Future<List<Map<String, dynamic>>?> getContainers({
    String? userId,
  }) async {
    try {
      String url = '$backendUrl/api/v1/containers';
      if (userId != null) url += '?user_id=$userId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['containers']);
      }
      return null;
    } catch (e) {
      print('Exception fetching containers: $e');
      return null;
    }
  }

  /// Create a new storage container
  /// POST /api/v1/containers
  static Future<Map<String, dynamic>?> createContainer({
    required Map<String, dynamic> containerData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/containers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(containerData),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      print('Error creating container: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Exception creating container: $e');
      return null;
    }
  }

  /// Update an existing storage container
  /// PATCH /api/v1/containers/{id}
  static Future<Map<String, dynamic>?> updateContainer({
    required String containerId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$backendUrl/api/v1/containers/$containerId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Exception updating container: $e');
      return null;
    }
  }

  /// Delete a storage container
  /// DELETE /api/v1/containers/{id}
  static Future<bool> deleteContainer({required String containerId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/api/v1/containers/$containerId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Exception deleting container: $e');
      return false;
    }
  }

  /// Multi-container pack — distribute items across selected containers
  /// POST /api/v1/pack/multi
  static Future<Map<String, dynamic>?> packMultiContainer({
    required String query,
    required List<String> containerIds,
    int topK = 30,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/pack/multi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'container_ids': containerIds,
          'top_k': topK,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error during multi-container pack: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Exception during multi-container pack: $e');
      return null;
    }
  }

  /// Upload image to Supabase Storage and return public URL
static Future<String?> uploadImageToStorage(String imagePath) async {
  try {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final response = await http.post(
      Uri.parse('${dotenv.env['SUPABASE_URL']}/storage/v1/object/manifest-assets/$fileName'),
      headers: {
        'apikey': dotenv.env['SUPABASE_ANON_KEY'] ?? '',  // ADD THIS LINE
        'Authorization': 'Bearer ${dotenv.env['SUPABASE_ANON_KEY'] ?? ''}',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    print('Upload response: ${response.statusCode} - ${response.body}');  // ADD DEBUG

    if (response.statusCode == 200 || response.statusCode == 201) {
      return '${dotenv.env['SUPABASE_URL']}/storage/v1/object/public/manifest-assets/$fileName';
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