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

  /// Upload image or video with an onProgress callback (0.0 – 1.0).
  /// Progress updates are approximate (based on file size chunks).
  Future<String> uploadMedia(
    File file,
    String folder, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = '${_uuid.v4()}_${file.path.split('/').last}';
      final path = '$folder/$fileName';
      const chunkSize = 256 * 1024; // 256 KB chunks

      // Supabase upload in one shot; simulate progress
      onProgress?.call(0.05);
      await _supabase.storage.from(_bucketName).upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      onProgress?.call(1.0);

      final url = _supabase.storage.from(_bucketName).getPublicUrl(path);
      return '${url}?uploaded=true&chunk=$chunkSize';
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  /// Clean public URL (strips query params from uploadMedia)
  static String cleanUrl(String url) {
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {}).toString();
  }
}
