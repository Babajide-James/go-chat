import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../core/services/firestore_service.dart';
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/go_logo.png', height: 30),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: chatListViewModel.conversationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No chats yet',
              message: 'Tap the button below to start a new conversation!',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: AppTheme.lightPeach,
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final participants = List<String>.from(data['participants'] ?? [])
                  .where((id) => id != myUid)
                  .toList();

              final partnerId =
                  participants.isNotEmpty ? participants.first : null;
              final lastMessage = data['lastMessage'] as String? ?? 'New Chat';
              final lastMessageAt = data['lastMessageAt'] as Timestamp?;

              return _ConversationTile(
                conversationId: doc.id,
                partnerId: partnerId,
                lastMessage: lastMessage,
                lastMessageAt: lastMessageAt,
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
}

/// A stateful tile that fetches the partner's display name asynchronously.
class _ConversationTile extends StatefulWidget {
  final String conversationId;
  final String? partnerId;
  final String lastMessage;
  final Timestamp? lastMessageAt;

  const _ConversationTile({
    required this.conversationId,
    required this.partnerId,
    required this.lastMessage,
    this.lastMessageAt,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final FirestoreService _fs = FirestoreService();
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
    try {
      final doc = await _fs.getUser(widget.partnerId!);
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _partnerName = data?['displayName'] as String? ??
              data?['email'] as String? ??
              'Unknown';
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppTheme.darkOrange.withValues(alpha: 0.15 * 255),
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
      title: _loading
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.textDark,
              ),
            ),
      subtitle: Text(
        widget.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textLight,
        ),
      ),
      trailing: Text(
        _formatTime(widget.lastMessageAt),
        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatView(conversationId: widget.conversationId),
          ),
        );
      },
    );
  }
}
