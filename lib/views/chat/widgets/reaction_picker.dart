import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const ReactionPicker({
    super.key,
    required this.onEmojiSelected,
  });

  static const List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
