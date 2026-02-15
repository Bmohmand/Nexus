import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'supabase_config.dart';

/// Upload image to Supabase Storage (manifest-assets bucket) and return public URL.
Future<String> uploadImageToStorage(String fileName, Uint8List bytes) async {
  final path = 'items/$fileName';
  await SupabaseConfig.client.storage
      .from(kStorageBucketName)
      .uploadBinary(path, bytes);
  return SupabaseConfig.client.storage
      .from(kStorageBucketName)
      .getPublicUrl(path);
}
