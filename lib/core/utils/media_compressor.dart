import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

class MediaCompressor {
  /// Compress an image to max 1080px, JPEG quality ≤80, target ≤1MB.
  /// Handles HEIC → JPEG conversion automatically.
  static Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Image compression failed');
    }
    return File(result.path);
  }

  /// Compress a video to max 720p, H.264, target ≤10MB or ≤30s.
  static Future<File> compressVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.Res720hQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (info == null || info.file == null) {
      throw Exception('Video compression failed');
    }
    return info.file!;
  }

  /// Returns file size in MB, formatted to 2 decimal places.
  static String fileSizeMb(File file) {
    final bytes = file.lengthSync();
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
