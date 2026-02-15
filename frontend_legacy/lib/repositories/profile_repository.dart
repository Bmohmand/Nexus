import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/profile.dart';

class ProfileRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Create a new profile
  Future<Profile> createProfile(Profile profile) async {
    try {
      final response = await _supabase
          .from('profiles')
          .insert(profile.toInsert())
          .select()
          .single();

      return Profile.fromJson(response);
    } on PostgrestException catch (e) {
      // Handle duplicate user_id constraint violation
      if (e.code == '23505' || e.message.contains('duplicate') || e.message.contains('unique')) {
        throw Exception('Profile already exists for this user');
      }
      throw Exception('Failed to create profile: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  // Get all profiles for a user
  Future<List<Profile>> getUserProfiles(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      return (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch profiles: $e');
    }
  }

  // Get default profile (first non-child profile, or first profile)
  Future<Profile?> getDefaultProfile(String userId) async {
    try {
      final profiles = await getUserProfiles(userId);
      
      if (profiles.isEmpty) {
        return null;
      }

      // Try to find a non-child profile first
      final adultProfile = profiles.firstWhere(
        (p) => !p.isChild,
        orElse: () => profiles.first,
      );

      return adultProfile;
    } catch (e) {
      throw Exception('Failed to fetch default profile: $e');
    }
  }

  // Update profile
  Future<Profile> updateProfile(Profile profile) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Delete profile
  Future<void> deleteProfile(String profileId) async {
    try {
      await _supabase.from('profiles').delete().eq('id', profileId);
    } catch (e) {
      throw Exception('Failed to delete profile: $e');
    }
  }
}
