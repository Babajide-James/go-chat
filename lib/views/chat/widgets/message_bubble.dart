import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMine;

  const MessageBubble({
    super.key,
    required this.data,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primaryOrange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textDark.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          data['text'] ?? '',
          style: TextStyle(
            color: isMine ? Colors.white : AppTheme.textDark,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
