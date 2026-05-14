import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../chat/chat_view.dart';
import '../../core/theme/app_theme.dart';

class NewChatSearchView extends StatefulWidget {
  const NewChatSearchView({super.key});

  @override
  State<NewChatSearchView> createState() => _NewChatSearchViewState();
}

class _NewChatSearchViewState extends State<NewChatSearchView> {
  final _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _firestoreService.searchUsers(query.trim());
      setState(() {
        _searchResults = results.docs;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatListViewModel = context.read<ChatListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by display name...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryOrange),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _searchResults.isEmpty
                    ? const EmptyState(
                        icon: Icons.search,
                        title: 'No users found',
                        message: 'Try a different search term.',
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final userDoc = _searchResults[index];
                          final userData = userDoc.data() as Map<String, dynamic>;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.lightPeach,
                              child: Text(
                                (userData['displayName'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(color: AppTheme.darkOrange),
                              ),
                            ),
                            title: Text(userData['displayName'] ?? 'Unknown User'),
                            subtitle: Text(userData['email'] ?? ''),
                            onTap: () async {
                              // Create or find conversation
                              final convId = await chatListViewModel.createConversation(userDoc.id);
                              if (convId != null && mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatView(conversationId: convId),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
