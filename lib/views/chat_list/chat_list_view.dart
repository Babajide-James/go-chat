import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authViewModel.signOut();
            },
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
              icon: Icons.chat_bubble_outline,
              title: 'No chats yet',
              message: 'Start a new conversation!',
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // We'll just show the raw participants for now as requested by the starter structure,
              // but you can replace this with a displayName lookup.
              final participants = (data['participants'] as List)
                  .where((id) => id != authViewModel.currentUser?.uid)
                  .toList();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.2),
                  child: const Icon(Icons.person),
                ),
                title: Text(data['lastMessage'] ?? 'New Chat'),
                subtitle: Text(
                  'Partner UID: ${participants.isNotEmpty ? participants.first : 'Unknown'}',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatView(conversationId: doc.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatSearchView()),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
