import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/audio_recorder_bar.dart';
import 'widgets/audio_bubble.dart';

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final chatViewModel = context.watch<ChatViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(chatViewModel.conversationId)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatViewModel.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }
                
                final docs = snapshot.data?.docs ?? [];
                
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

                    if (type == 'audio') {
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 16),
                          child: AudioBubble(
                            audioUrl: data['mediaUrl'] ?? '',
                            durationSeconds: data['duration'] as int? ?? 0,
                            isMine: isMine,
                          ),
                        ),
                      );
                    }

                    return MessageBubble(
                      messageId: doc.id,
                      data: data,
                      isMine: isMine,
                    );
                  },
                );
              },
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: chatViewModel.conversationStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final typingMap = data['typing'] as Map<String, dynamic>? ?? {};
              
              // Check if any participant other than the current user is typing
              bool isPartnerTyping = false;
              for (var entry in typingMap.entries) {
                if (entry.key != uid) {
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
                          color: AppTheme.textDark.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Mic button
                        IconButton(
                          icon: const Icon(Icons.mic,
                              color: AppTheme.primaryOrange),
                          onPressed: () =>
                              setState(() => _showRecorder = true),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            textCapitalization: TextCapitalization.sentences,
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
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () {
                              if (_textController.text.trim().isNotEmpty) {
                                chatViewModel
                                    .sendTextMessage(_textController.text);
                                _textController.clear();
                              }
                            },
                          ),
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
