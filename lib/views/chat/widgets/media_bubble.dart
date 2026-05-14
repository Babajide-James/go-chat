import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import 'fullscreen_image_view.dart';
import 'fullscreen_video_view.dart';

class MediaBubble extends StatelessWidget {
  final String mediaUrl;
  final String type; // 'image' or 'video'
  final String? thumbnailUrl;
  final bool isMine;
  final double? uploadProgress; // null = fully uploaded

  const MediaBubble({
    super.key,
    required this.mediaUrl,
    required this.type,
    this.thumbnailUrl,
    required this.isMine,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
      bottomRight: isMine ? Radius.zero : const Radius.circular(16),
    );

    return GestureDetector(
      onTap: uploadProgress == null
          ? () {
              if (type == 'image') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImageView(imageUrl: mediaUrl),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenVideoView(videoUrl: mediaUrl),
                  ),
                );
              }
            }
          : null,
      child: Container(
        width: 220,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppTheme.textDark.withValues(alpha: 0.08 * 255),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail / image
              CachedNetworkImage(
                imageUrl: thumbnailUrl ?? mediaUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.lightPeach,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryOrange),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.lightPeach,
                  child: const Icon(Icons.broken_image, color: AppTheme.darkOrange),
                ),
              ),
              // Play icon overlay for videos
              if (type == 'video' && uploadProgress == null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45 * 255),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              // Upload progress overlay
              if (uploadProgress != null)
                Container(
                  color: Colors.black.withValues(alpha: 0.45 * 255),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: uploadProgress,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
