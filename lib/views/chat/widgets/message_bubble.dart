import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodels/chat_viewmodel.dart';
import 'reaction_picker.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMine;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.data,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = context.read<ChatViewModel>();
    final reactionsMap = data['reactions'] as Map<String, dynamic>? ?? {};
    
    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    for (var emoji in reactionsMap.values) {
      final e = emoji.toString();
      reactionCounts[e] = (reactionCounts[e] ?? 0) + 1;
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          _showReactionPicker(context, chatViewModel);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            if (reactionCounts.isNotEmpty)
              Positioned(
                bottom: -4,
                right: isMine ? 24 : null,
                left: isMine ? null : 24,
                child: _buildReactionsWidget(reactionCounts, chatViewModel),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsWidget(Map<String, int> reactionCounts, ChatViewModel chatViewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightPeach, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionCounts.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${entry.key} ${entry.value > 1 ? entry.value : ""}'.trim(),
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, ChatViewModel chatViewModel) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: ReactionPicker(
                  onEmojiSelected: (emoji) {
                    Navigator.of(context).pop();
                    chatViewModel.toggleReaction(messageId, emoji);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
