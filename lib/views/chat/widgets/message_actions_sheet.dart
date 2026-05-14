import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodels/chat_viewmodel.dart';
import 'reaction_picker.dart';

class MessageActionsSheet extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMine;

  const MessageActionsSheet({
    super.key,
    required this.messageId,
    required this.data,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = context.read<ChatViewModel>();
    final type = data['type'] as String? ?? 'text';
    final text = data['text'] as String? ?? '';
    final isDeleted = data['deletedForEveryone'] == true;

    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (!isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ReactionPicker(
                onEmojiSelected: (emoji) {
                  Navigator.pop(context);
                  chatViewModel.toggleReaction(messageId, emoji);
                },
              ),
            ),
          if (!isDeleted) const Divider(),
          if (type == 'text' && !isDeleted)
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.textDark),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
                Navigator.pop(context);
              },
            ),
          if (isMine && type == 'text' && !isDeleted)
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textDark),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                chatViewModel.setEditingMessage(messageId, text);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete for me', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              chatViewModel.deleteMessageForMe(messageId);
            },
          ),
          if (isMine && !isDeleted)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                chatViewModel.deleteMessageForEveryone(messageId);
              },
            ),
        ],
      ),
    );
  }
}
