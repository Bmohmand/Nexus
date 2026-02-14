import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/closet_item.dart';

class ClosetRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get all items for a user
  Future<List<ClosetItem>> getUserItems(String userId) async {
    try {
      final response = await _supabase
          .from('closet_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => ClosetItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch closet items: $e');
    }
  }

  // Get items by category
  Future<List<ClosetItem>> getItemsByCategory(
    String userId,
    ItemCategory category,
  ) async {
    try {
      final response = await _supabase
          .from('closet_items')
          .select()
          .eq('user_id', userId)
          .eq('category', category.name)
          .order('created_at', ascending: false);

      return (response as List).map((json) => ClosetItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch items by category: $e');
    }
  }

  // Insert new item
  Future<ClosetItem> insertItem(ClosetItem item) async {
    try {
      final response = await _supabase
          .from('closet_items')
          .insert(item.toInsert())
          .select()
          .single();

      return ClosetItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to insert item: $e');
    }
  }

  // Update item
  Future<ClosetItem> updateItem(ClosetItem item) async {
    try {
      final response = await _supabase
          .from('closet_items')
          .update(item.toJson())
          .eq('id', item.id)
          .select()
          .single();

      return ClosetItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  // Delete item
  Future<void> deleteItem(String itemId) async {
    try {
      await _supabase.from('closet_items').delete().eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  // Get unworn items (not worn in X days)
  Future<List<ClosetItem>> getUnwornItems(String userId, int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      
      final response = await _supabase
          .from('closet_items')
          .select()
          .eq('user_id', userId)
          .or('last_worn.is.null,last_worn.lt.${cutoffDate.toIso8601String()}')
          .order('last_worn', ascending: true);

      return (response as List).map((json) => ClosetItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch unworn items: $e');
    }
  }

  // Get items by warmth rating range
  Future<List<ClosetItem>> getItemsByWarmth(
    String userId,
    int minWarmth,
    int maxWarmth,
  ) async {
    try {
      final response = await _supabase
          .from('closet_items')
          .select()
          .eq('user_id', userId)
          .gte('warmth_rating', minWarmth)
          .lte('warmth_rating', maxWarmth)
          .order('warmth_rating', ascending: false);

      return (response as List).map((json) => ClosetItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch items by warmth: $e');
    }
  }

  // Update last worn date
  Future<void> updateLastWorn(String itemId, DateTime date) async {
    try {
      await _supabase
          .from('closet_items')
          .update({'last_worn': date.toIso8601String()})
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to update last worn date: $e');
    }
  }
}
