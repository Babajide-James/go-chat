import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import 'fullscreen_image_view.dart';
import 'fullscreen_video_view.dart';

class MediaBubble extends StatelessWidget {
  final String mediaUrl;
  final String? localFilePath;
  final String type; // 'image' or 'video'
  final String? thumbnailUrl;
  final bool isMine;
  final double? uploadProgress; // null = fully uploaded
  final String status; // 'sending', 'sent', 'delivered', 'seen', 'failed'

  const MediaBubble({
    super.key,
    required this.mediaUrl,
    this.localFilePath,
    required this.type,
    this.thumbnailUrl,
    required this.isMine,
    this.uploadProgress,
    this.status = 'sent',
  });

  bool get _isUploading => status == 'sending' && mediaUrl.isEmpty;
  bool get _isUploaded => mediaUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
      bottomRight: isMine ? Radius.zero : const Radius.circular(16),
    );

    return GestureDetector(
      onTap: _isUploaded
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
              color: AppTheme.textDark.withValues(alpha: 0.08),
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
              // Thumbnail / image — prefer local file when URL is not yet available
              _buildImageContent(),
              // Play icon overlay for videos (only when upload is complete)
              if (type == 'video' && _isUploaded)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              // Upload progress overlay
              if (_isUploading && uploadProgress != null)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
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
              // Sending state (queued, no progress yet)
              if (_isUploading && uploadProgress == null)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            color: Colors.white70, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Sending...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildImageContent() {
    // If we have a local file and the URL is not yet available, show from file
    if (mediaUrl.isEmpty && localFilePath != null && localFilePath!.isNotEmpty) {
      final file = File(localFilePath!);
      if (type == 'image') {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        // Video: show a dark placeholder with video icon
        return Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 40),
          ),
        );
      }
    }

    // Network image (uploaded)
    if (mediaUrl.isNotEmpty) {
      if (type == 'video') {
        // For videos, show poster-frame style
        return Container(
          color: Colors.black87,
          child: CachedNetworkImage(
            imageUrl: thumbnailUrl ?? mediaUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.black87,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryOrange),
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black87,
              child: const Center(
                child: Icon(Icons.videocam_rounded,
                    color: Colors.white54, size: 40),
              ),
            ),
          ),
        );
      }
      return CachedNetworkImage(
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
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.lightPeach,
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.darkOrange, size: 32),
      ),
    );
  }
}
