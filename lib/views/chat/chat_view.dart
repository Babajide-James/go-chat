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
  String? _lastEditingMessageId;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
    } else if (status == 'sending') {
      iconData = Icons.access_time_rounded;
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
                    final status = data['status'] as String? ?? 'sent';
                    final localFilePath = data['localFilePath'] as String?;
                    final mediaUrl = data['mediaUrl'] as String? ?? '';

                    // Get upload progress for this message from the queue
                    final uploadProgress = chatViewModel.getUploadProgress(doc.id);
                    final isFailed = chatViewModel.isUploadFailed(doc.id);

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
                                audioUrl: mediaUrl,
                                localFilePath: localFilePath,
                                durationSeconds: data['duration'] as int? ?? 0,
                                isMine: isMine,
                                status: status,
                              ),
                              if (isMine) ...[
                                const SizedBox(height: 2),
                                if (isFailed)
                                  GestureDetector(
                                    onTap: () => chatViewModel.retryUpload(doc.id),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline,
                                            size: 14, color: Colors.red.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Failed · Tap to retry',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  _buildReadReceipt(
                                    status,
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
                                mediaUrl: mediaUrl,
                                localFilePath: localFilePath,
                                type: type,
                                isMine: isMine,
                                uploadProgress: uploadProgress,
                                status: status,
                              ),
                              if (isMine) ...[
                                const SizedBox(height: 4),
                                if (isFailed)
                                  GestureDetector(
                                    onTap: () => chatViewModel.retryUpload(doc.id),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline,
                                            size: 14, color: Colors.red.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Failed · Tap to retry',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  _buildReadReceipt(
                                    status,
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
                            alpha: 0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit message banner
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
                        // Pending media attachment strip — does NOT cover send button
                        if (chatViewModel.pendingMediaFile != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.lightPeach,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail preview
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: chatViewModel.pendingMediaType == 'image'
                                      ? Image.file(
                                          chatViewModel.pendingMediaFile!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.videocam,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                // File info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chatViewModel.pendingMediaType == 'image'
                                            ? 'Image Attached'
                                            : 'Video Attached',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (chatViewModel.isCompressing)
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(
                                                  AppTheme.primaryOrange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Compressing...',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (chatViewModel.lastCompression != null)
                                        Text(
                                          chatViewModel.lastCompression!.summary,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                // Remove attachment button
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: chatViewModel.clearPendingMedia,
                                ),
                              ],
                            ),
                          ),
                        // Input row
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
                                  chatViewModel.setPendingMedia(
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
                            // Send button — always visible, handles both text and media
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
                                onPressed: chatViewModel.isCompressing
                                    ? null // Disable while compressing
                                    : () {
                                        // Send pending media if attached
                                        if (chatViewModel.pendingMediaFile != null) {
                                          chatViewModel.sendMediaMessage(
                                            chatViewModel.pendingMediaFile!,
                                            chatViewModel.pendingMediaType!,
                                          );
                                          chatViewModel.clearPendingMedia();
                                        }
                                        // Send text if typed
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
