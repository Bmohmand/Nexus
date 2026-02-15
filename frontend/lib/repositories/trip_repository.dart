import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/trip.dart';
import '../models/trip_item.dart';
import '../models/closet_item.dart';

class TripRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Create a new trip
  Future<Trip> createTrip(Trip trip) async {
    try {
      final response = await _supabase
          .from('trips')
          .insert(trip.toInsert())
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create trip: $e');
    }
  }

  // Get all trips for a user
  Future<List<Trip>> getUserTrips(String userId) async {
    try {
      final response = await _supabase
          .from('trips')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch trips: $e');
    }
  }

  // Get a single trip
  Future<Trip> getTrip(String tripId) async {
    try {
      final response = await _supabase
          .from('trips')
          .select()
          .eq('id', tripId)
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch trip: $e');
    }
  }

  // Update trip
  Future<Trip> updateTrip(Trip trip) async {
    try {
      final response = await _supabase
          .from('trips')
          .update(trip.toJson())
          .eq('id', trip.id)
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update trip: $e');
    }
  }

  // Delete trip
  Future<void> deleteTrip(String tripId) async {
    try {
      await _supabase.from('trips').delete().eq('id', tripId);
    } catch (e) {
      throw Exception('Failed to delete trip: $e');
    }
  }

  // Add item to trip
  Future<TripItem> addTripItem(
    String tripId,
    String itemId,
    String status, {
    double? scoreContribution,
  }) async {
    try {
      final tripItem = TripItem(
        id: '',
        tripId: tripId,
        itemId: itemId,
        status: status,
        scoreContribution: scoreContribution,
      );

      final response = await _supabase
          .from('trip_items')
          .insert(tripItem.toInsert())
          .select()
          .single();

      return TripItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add trip item: $e');
    }
  }

  // Get all trip items (with item details)
  Future<List<Map<String, dynamic>>> getTripItemsWithDetails(String tripId) async {
    try {
      final response = await _supabase
          .from('trip_items')
          .select('*, closet_items(*)')
          .eq('trip_id', tripId);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch trip items: $e');
    }
  }

  // Get trip items by status
  Future<List<TripItem>> getTripItemsByStatus(
    String tripId,
    String status,
  ) async {
    try {
      final response = await _supabase
          .from('trip_items')
          .select()
          .eq('trip_id', tripId)
          .eq('status', status);

      return (response as List).map((json) => TripItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch trip items by status: $e');
    }
  }

  // Update trip item status
  Future<TripItem> updateTripItemStatus(
    String tripItemId,
    String newStatus,
  ) async {
    try {
      final response = await _supabase
          .from('trip_items')
          .update({'status': newStatus})
          .eq('id', tripItemId)
          .select()
          .single();

      return TripItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update trip item status: $e');
    }
  }

  // Remove item from trip
  Future<void> removeTripItem(String tripItemId) async {
    try {
      await _supabase.from('trip_items').delete().eq('id', tripItemId);
    } catch (e) {
      throw Exception('Failed to remove trip item: $e');
    }
  }

  // Batch add multiple items to trip
  Future<void> addMultipleTripItems(
    String tripId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final tripItems = items.map((item) => {
        'trip_id': tripId,
        'item_id': item['item_id'],
        'status': item['status'] ?? 'suggested',
        'score_contribution': item['score_contribution'],
      }).toList();

      await _supabase.from('trip_items').insert(tripItems);
    } catch (e) {
      throw Exception('Failed to add multiple trip items: $e');
    }
  }
}
