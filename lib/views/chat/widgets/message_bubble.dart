import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodels/chat_viewmodel.dart';
import 'message_actions_sheet.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMine;
  final String? searchQuery;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.data,
    required this.isMine,
    this.searchQuery,
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

    final isDeleted = data['deletedForEveryone'] == true;
    final isEdited = data['editedAt'] != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          _showActionsSheet(context);
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
                    color: AppTheme.textDark.withValues(alpha: 0.05 * 255),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: isDeleted
                        ? Text(
                            '🚫 This message was deleted.',
                            style: TextStyle(
                              color: isMine ? Colors.white70 : Colors.grey,
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                            ),
                          )
                        : _buildMessageText(
                            data['text'] ?? '',
                            isMine ? Colors.white : AppTheme.textDark,
                            searchQuery,
                          ),
                  ),
                  const SizedBox(width: 8),
                  if (isEdited && !isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        '(edited)',
                        style: TextStyle(
                          color: isMine ? Colors.white70 : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (isMine) ...[
                    const SizedBox(width: 8),
                    _buildReadReceipt(data['status'] as String? ?? 'sent', data['readBy'] as Map? ?? {}),
                  ],
                ],
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

  Widget _buildMessageText(String text, Color textColor, String? query) {
    if (query == null || query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        style: TextStyle(color: textColor, fontSize: 16),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchStart = lowerText.indexOf(lowerQuery);
    final matchEnd = matchStart + query.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor, fontSize: 16),
        children: [
          TextSpan(text: text.substring(0, matchStart)),
          TextSpan(
            text: text.substring(matchStart, matchEnd),
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(matchEnd)),
        ],
      ),
    );
  }

  Widget _buildReadReceipt(String status, Map readBy) {
    IconData iconData;
    Color iconColor;

    if (status == 'seen' || readBy.isNotEmpty) {
      iconData = Icons.done_all_rounded;
      iconColor = Colors.blue.shade300;
    } else if (status == 'delivered') {
      iconData = Icons.done_all_rounded;
      iconColor = Colors.white70;
    } else {
      iconData = Icons.check_rounded;
      iconColor = Colors.white70;
    }

    return Icon(
      iconData,
      size: 16,
      color: iconColor,
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
            color: AppTheme.textDark.withValues(alpha: 0.1 * 255),
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

  void _showActionsSheet(BuildContext context) {
    final chatViewModel = context.read<ChatViewModel>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: chatViewModel,
        child: MessageActionsSheet(
          messageId: messageId,
          data: data,
          isMine: isMine,
        ),
      ),
    );
  }
}
