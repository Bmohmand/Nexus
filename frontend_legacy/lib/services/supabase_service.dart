import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';
import '../core/constants.dart';

/// Thrown when the manifest schema (e.g. manifest_items) is not in the DB yet.
class NexusSchemaNotReadyException implements Exception {
  @override
  String toString() => 'NexusSchemaNotReady';
}

/// Direct Supabase SDK access for CRUD, auth, and storage.
/// AI operations go through [NexusApiClient] instead.
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  // ---- Auth ----
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  // ---- Items CRUD (manifest_items) ----
  Future<List<NexusItem>> fetchItems({
    AssetDomain? domain,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('manifest_items').select();

      if (domain != null && domain != AssetDomain.general) {
        query = query.eq('domain', domain.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((row) => NexusItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' ||
          (e.message.contains('manifest_items') && e.message.contains('schema cache'))) {
        throw NexusSchemaNotReadyException();
      }
      rethrow;
    }
  }

  Future<NexusItem?> fetchItem(String id) async {
    try {
      final response = await _client
          .from('manifest_items')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return NexusItem.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' ||
          (e.message.contains('manifest_items') && e.message.contains('schema cache'))) {
        throw NexusSchemaNotReadyException();
      }
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    await _client.from('manifest_items').delete().eq('id', id);
  }

  Future<int> itemCount() async {
    try {
      final response = await _client
          .from('manifest_items')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' ||
          (e.message.contains('manifest_items') && e.message.contains('schema cache'))) {
        throw NexusSchemaNotReadyException();
      }
      rethrow;
    }
  }

  // ---- Storage ----
  Future<String> uploadImage(String fileName, Uint8List bytes) async {
    final path = 'items/$fileName';
    await _client.storage.from(kStorageBucketName).uploadBinary(path, bytes);
    return _client.storage.from(kStorageBucketName).getPublicUrl(path);
  }
}
