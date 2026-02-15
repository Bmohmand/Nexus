import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'core/constants.dart';

class NexusApiService {
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
  /// When synthesize=false (default), returns raw vector search results ranked
  /// by similarity — fast and never filtered to empty by the LLM.
  /// When synthesize=true, the backend runs an LLM to curate results into a
  /// mission plan (slower, may filter items out).
  static Future<List<Map<String, dynamic>>?> semanticSearch({
    required String query,
    int topK = 10,
    bool synthesize = false,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/v1/search');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'top_k': topK,
          'synthesize': synthesize,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Search response keys: ${data.keys.toList()}');

        // When synthesize=true, results are in selected_items.
        // When synthesize=false, results are in raw_results.
        // Prefer selected_items if it's non-empty, otherwise fall back to raw_results.
        final selected = data['selected_items'] as List<dynamic>?;
        final raw = data['raw_results'] as List<dynamic>?;

        final items = (selected != null && selected.isNotEmpty)
            ? selected
            : (raw ?? []);

        return List<Map<String, dynamic>>.from(items);
      } else {
        print('Error performing search: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during semantic search: $e');
      return null;
    }
  }

  /// Fetch all items from the backend (which reads from Supabase).
  /// GET /api/v1/items — returns { items: [...], count: int }
  static Future<Map<String, dynamic>?> getItems({
    int limit = 50,
    int offset = 0,
    String? domain,
    String? userId,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (domain != null) params['domain'] = domain;
      if (userId != null) params['user_id'] = userId;

      final uri = Uri.parse('$backendUrl/api/v1/items')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        print('Error fetching items: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception fetching items: $e');
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

  /// Weight-limited pack recommendation
  /// POST /api/v1/pack — returns subset of items that fit within max weight and maximize relevance
  static Future<Map<String, dynamic>?> packRecommendation({
    required String query,
    required double maxWeightKg,
    int topK = 50,
    Map<String, int>? categoryMinimums,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/api/v1/pack');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'top_k': topK,
          'constraints': {
            'max_weight_grams': maxWeightKg * 1000,
            'category_minimums': categoryMinimums ?? {},
            'tag_minimums': {},
            'max_per_item': null,
          },
        }),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
      print('Pack API error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Exception during pack recommendation: $e');
      return null;
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

  /// Delete an item from the manifest
  /// DELETE /api/v1/items/{id}
  static Future<bool> deleteItem({required String itemId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/api/v1/items/$itemId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Exception deleting item: $e');
      return false;
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
    bool explain = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/pack/multi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'container_ids': containerIds,
          'top_k': topK,
          'explain': explain,
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
static Future<List<Map<String, dynamic>>?> getManifestItems() async {
  try {
    final uri = Uri.parse(
      '${dotenv.env['SUPABASE_URL']}/rest/v1/manifest_items?select=*&order=created_at.desc',
    );

    final response = await http.get(uri, headers: _supabaseHeaders);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      print('Error fetching manifest items: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Exception fetching manifest items: $e');
    return null;
  }
}
}