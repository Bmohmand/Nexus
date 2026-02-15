import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StorageService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String bucketName = 'closet-images';

  // Upload item image
  Future<String> uploadItemImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = '$userId/$timestamp.$fileExtension';

      // Upload to Supabase Storage
      await _supabase.storage.from(bucketName).upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Delete item image
  Future<void> deleteItemImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final path = uri.pathSegments.last;

      await _supabase.storage.from(bucketName).remove([path]);
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  // Create storage bucket (call this once from Supabase dashboard or SQL)
  // This is just for reference - you'll need to create the bucket manually
  // or via SQL in your Supabase dashboard
  /*
  SQL to create bucket and set RLS:
  
  -- Create bucket
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('closet-images', 'closet-images', true);
  
  -- Allow users to upload their own images
  CREATE POLICY "Users can upload their own images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'closet-images' AND auth.uid()::text = (storage.foldername(name))[1]);
  
  -- Allow users to view their own images
  CREATE POLICY "Users can view their own images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'closet-images' AND auth.uid()::text = (storage.foldername(name))[1]);
  
  -- Allow users to delete their own images
  CREATE POLICY "Users can delete their own images"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'closet-images' AND auth.uid()::text = (storage.foldername(name))[1]);
  */
}
