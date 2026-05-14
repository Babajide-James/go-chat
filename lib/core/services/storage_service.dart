import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'media';
  final _uuid = const Uuid();

  Future<String> uploadFile(File file, String folder) async {
    try {
      final fileName = '${_uuid.v4()}_${file.path.split('/').last}';
      final path = '$folder/$fileName';
      
      await _supabase.storage.from(_bucketName).upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final url = _supabase.storage.from(_bucketName).getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('Failed to upload file to Supabase: $e');
    }
  }

  /// Convenience wrapper for audio uploads
  Future<String> uploadAudio(File file) => uploadFile(file, 'audio');
}
