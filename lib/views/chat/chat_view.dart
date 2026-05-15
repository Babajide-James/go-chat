import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/audio_recorder_bar.dart';
import 'widgets/audio_bubble.dart';
import 'widgets/media_bubble.dart';
import 'widgets/media_picker_sheet.dart';

class ChatView extends StatelessWidget {
  final String conversationId;
  const ChatView({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(conversationId),
      child: const _ChatViewContent(),
    );
  }
}

class _ChatViewContent extends StatefulWidget {
  const _ChatViewContent();

  @override
  State<_ChatViewContent> createState() => _ChatViewContentState();
}

class _ChatViewContentState extends State<_ChatViewContent> {
  final _textController = TextEditingController();
  bool _showRecorder = false;
  CompressionResult? _lastShownCompression;
  String? _lastEditingMessageId;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _maybeShowCompressionSnackbar(ChatViewModel vm) {
    final result = vm.lastCompression;
    if (result == null || result == _lastShownCompression) return;
    _lastShownCompression = result;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.darkOrange, AppTheme.primaryOrange],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.35 * 255),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.compress_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Compressed & Sent!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        result.summary,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildReadReceipt(String status, Map readBy) {
    IconData iconData;
    Color iconColor;

    if (status == 'seen' || readBy.isNotEmpty) {
      iconData = Icons.done_all_rounded;
      iconColor = Colors.blue.shade300;
    } else if (status == 'delivered') {
      iconData = Icons.done_all_rounded;
      iconColor = Colors.grey;
    } else {
      iconData = Icons.check_rounded;
      iconColor = Colors.grey;
    }

    return Icon(iconData, size: 14, color: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    final chatViewModel = context.watch<ChatViewModel>();
    final uid = chatViewModel.currentUserId;

    // Auto-populate text field when edit is tapped
    if (chatViewModel.editingMessageId != null &&
        chatViewModel.editingMessageId != _lastEditingMessageId) {
      _lastEditingMessageId = chatViewModel.editingMessageId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textController.text = chatViewModel.editingMessageText ?? '';
      });
    } else if (chatViewModel.editingMessageId == null &&
        _lastEditingMessageId != null) {
      _lastEditingMessageId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textController.clear();
      });
    }

    _maybeShowCompressionSnackbar(chatViewModel);

    return Scaffold(
      appBar: AppBar(
        title: chatViewModel.isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search in chat...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                onChanged: chatViewModel.setSearchQuery,
              )
            : Text(chatViewModel.partnerName),
        actions: [
          IconButton(
            icon: Icon(chatViewModel.isSearching ? Icons.close : Icons.search),
            onPressed: chatViewModel.toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatViewModel.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }

                var docs = snapshot.data?.docs ?? [];

                // Filter out messages deleted for me
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedFor = List<String>.from(
                    data['deletedFor'] ?? [],
                  );
                  return !deletedFor.contains(uid);
                }).toList();

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.message,
                    title: 'No messages',
                    message: 'Be the first to say hi!',
                  );
                }

                return ListView.builder(
                  controller: chatViewModel.scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(top: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMine = data['senderId'] == uid;
                    final type = data['type'] as String? ?? 'text';

                    Widget content;

                    if (type == 'audio') {
                      content = Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AudioBubble(
                                audioUrl: data['mediaUrl'] ?? '',
                                durationSeconds: data['duration'] as int? ?? 0,
                                isMine: isMine,
                              ),
                              if (isMine) ...[
                                const SizedBox(height: 2),
                                _buildReadReceipt(
                                  data['status'] as String? ?? 'sent',
                                  data['readBy'] as Map? ?? {},
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    } else if (type == 'image' || type == 'video') {
                      content = Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MediaBubble(
                                mediaUrl: data['mediaUrl'] ?? '',
                                type: type,
                                isMine: isMine,
                              ),
                              if (isMine) ...[
                                const SizedBox(height: 4),
                                _buildReadReceipt(
                                  data['status'] as String? ?? 'sent',
                                  data['readBy'] as Map? ?? {},
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    } else {
                      content = MessageBubble(
                        messageId: doc.id,
                        data: data,
                        isMine: isMine,
                        searchQuery: chatViewModel.searchQuery,
                      );
                    }

                    return VisibilityDetector(
                      key: Key(doc.id),
                      onVisibilityChanged: (info) {
                        if (!isMine && info.visibleFraction > 0.5) {
                          chatViewModel.markAsRead(doc.id, data);
                        }
                      },
                      child: content,
                    );
                  },
                );
              },
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: chatViewModel.conversationStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData ||
                  snapshot.data == null ||
                  !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final typingMap = data['typing'] as Map<String, dynamic>? ?? {};

              bool isPartnerTyping = false;
              for (var entry in typingMap.entries) {
                final value = entry.value;
                final typedAt = value is Timestamp ? value.toDate() : null;
                final isRecent =
                    typedAt != null &&
                    DateTime.now().difference(typedAt).inSeconds < 6;
                if (entry.key != uid && isRecent) {
                  isPartnerTyping = true;
                  break;
                }
              }

              if (!isPartnerTyping) {
                return const SizedBox.shrink();
              }

              return const Align(
                alignment: Alignment.centerLeft,
                child: TypingIndicator(),
              );
            },
          ),
          // Input bar / recorder swap
          _showRecorder
              ? AudioRecorderBar(
                  onRecordingComplete: (path, seconds) {
                    setState(() => _showRecorder = false);
                    chatViewModel.sendAudioMessage(path, seconds);
                  },
                  onCancel: () => setState(() => _showRecorder = false),
                )
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textDark.withValues(
                            alpha: 0.05 * 255,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chatViewModel.editingMessageId != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.lightPeach,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: AppTheme.primaryOrange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Editing message',
                                        style: TextStyle(
                                          color: AppTheme.primaryOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        chatViewModel.editingMessageText ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    chatViewModel.cancelEditing();
                                    _textController.clear();
                                  },
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            // Attachment button
                            IconButton(
                              icon: const Icon(
                                Icons.attach_file_rounded,
                                color: AppTheme.primaryOrange,
                              ),
                              onPressed: () async {
                                final result = await showMediaPickerSheet(
                                  context,
                                );
                                if (result != null) {
                                  chatViewModel.sendMediaMessage(
                                    result.file,
                                    result.type,
                                  );
                                }
                              },
                            ),
                            // Mic button
                            IconButton(
                              icon: const Icon(
                                Icons.mic,
                                color: AppTheme.primaryOrange,
                              ),
                              onPressed: () =>
                                  setState(() => _showRecorder = true),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: chatViewModel.onTextChanged,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  if (_textController.text.trim().isNotEmpty) {
                                    chatViewModel.sendTextMessage(
                                      _textController.text,
                                    );
                                    _textController.clear();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
