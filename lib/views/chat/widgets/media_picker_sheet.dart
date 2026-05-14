import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

/// A bottom sheet for picking an image or video from gallery or camera.
/// Returns the picked [File] and its [type] ('image' or 'video'), or null.
Future<({File file, String type})?> showMediaPickerSheet(
    BuildContext context) async {
  return await showModalBottomSheet<({File file, String type})?>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MediaPickerSheet(),
  );
}

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Send Media',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: AppTheme.primaryOrange,
                onTap: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 100,
                  );
                  if (xfile != null && context.mounted) {
                    Navigator.pop(
                      context,
                      (file: File(xfile.path), type: 'image'),
                    );
                  }
                },
              ),
              _PickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: AppTheme.darkOrange,
                onTap: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 100,
                  );
                  if (xfile != null && context.mounted) {
                    Navigator.pop(
                      context,
                      (file: File(xfile.path), type: 'image'),
                    );
                  }
                },
              ),
              _PickerOption(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: Colors.deepPurple,
                onTap: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickVideo(
                    source: ImageSource.gallery,
                    maxDuration: const Duration(minutes: 2),
                  );
                  if (xfile != null && context.mounted) {
                    Navigator.pop(
                      context,
                      (file: File(xfile.path), type: 'video'),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
