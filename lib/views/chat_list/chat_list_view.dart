import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../chat/chat_view.dart';
import '../new_chat/new_chat_search_view.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final chatListViewModel = context.watch<ChatListViewModel>();
    final authViewModel = context.read<AuthViewModel>();
    final myUid = authViewModel.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.softWhite,
      appBar: AppBar(
        title: Row(
          // mainAxisSize: MainAxisSize.min,
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/images/go_logo.png', height: 30),
            Center(
              child: Text('Welcome to Go Chat', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async => await authViewModel.signOut(),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (chatListViewModel.isLoading) {
            return const LoadingIndicator();
          }
          final docs = chatListViewModel.conversations;

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No chats yet',
              message: 'Tap the button below to start a new conversation!',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final docId = data['id'] as String;

              final participants = List<String>.from(
                data['participants'] ?? [],
              ).where((id) => id != myUid).toList();

              final partnerId = participants.isNotEmpty
                  ? participants.first
                  : null;
              final lastMessage = data['lastMessage'] as String? ?? 'New Chat';

              Timestamp? lastMessageAt;
              if (data['lastMessageAt'] is String) {
                lastMessageAt = Timestamp.fromDate(
                  DateTime.parse(data['lastMessageAt']),
                );
              } else if (data['lastMessageAt'] is Timestamp) {
                lastMessageAt = data['lastMessageAt'];
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ConversationTile(
                  key: ValueKey(docId),
                  conversationId: docId,
                  partnerId: partnerId,
                  lastMessage: lastMessage,
                  lastMessageAt: lastMessageAt,
                  isTyping: _hasActivePartnerTyping(data, myUid),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatSearchView()),
          );
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New Chat'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
    );
  }

  bool _hasActivePartnerTyping(Map<String, dynamic> data, String? myUid) {
    final typing = data['typing'] as Map<String, dynamic>? ?? {};
    for (final entry in typing.entries) {
      DateTime? typedAt;
      if (entry.value is Timestamp) {
        typedAt = (entry.value as Timestamp).toDate();
      } else if (entry.value is String) {
        typedAt = DateTime.tryParse(entry.value);
      }
      final isRecent =
          typedAt != null && DateTime.now().difference(typedAt).inSeconds < 6;
      if (entry.key != myUid && isRecent) return true;
    }
    return false;
  }
}

/// A stateful tile that fetches the partner's display name asynchronously.
class _ConversationTile extends StatefulWidget {
  final String conversationId;
  final String? partnerId;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final bool isTyping;

  const _ConversationTile({
    super.key,
    required this.conversationId,
    required this.partnerId,
    required this.lastMessage,
    this.lastMessageAt,
    required this.isTyping,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final FirestoreService _fs = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  String? _partnerName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPartnerName();
  }

  Future<void> _fetchPartnerName() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }

    // Check local database first
    final cachedUser = await _localDb.getCachedUser(widget.partnerId!);
    if (cachedUser != null && mounted) {
      setState(() {
        _partnerName =
            cachedUser['displayName'] as String? ??
            cachedUser['email'] as String? ??
            'Unknown';
        _loading = false;
      });
    }

    try {
      final doc = await _fs.getUser(widget.partnerId!);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          // Cache for next time
          await _localDb.cacheUser(widget.partnerId!, data);
          if (mounted) {
            setState(() {
              _partnerName =
                  data['displayName'] as String? ??
                  data['email'] as String? ??
                  'Unknown';
              _loading = false;
            });
          }
        }
      } else if (mounted && cachedUser == null) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted && cachedUser == null) setState(() => _loading = false);
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_partnerName?.isNotEmpty == true)
        ? _partnerName![0].toUpperCase()
        : '?';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.lightPeach.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatView(conversationId: widget.conversationId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.darkOrange.withValues(alpha: 0.15),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryOrange,
                        ),
                      )
                    : Text(
                        initials,
                        style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _loading
                        ? Container(
                            height: 14,
                            width: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.lightPeach,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Text(
                            _partnerName ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textDark,
                            ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isTyping ? 'typing...' : widget.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isTyping
                            ? AppTheme.primaryOrange
                            : AppTheme.textLight,
                        fontWeight: widget.isTyping
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(widget.lastMessageAt),
                style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
