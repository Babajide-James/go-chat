import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestoreService.getUsersForSearch();
      final query = trimmed.toLowerCase();
      final seen = <String, DocumentSnapshot>{};

      for (final doc in snapshot.docs) {
        if (doc.id == _currentUserId) continue;

        final data = doc.data() as Map<String, dynamic>;
        final name = (data['displayName'] as String? ?? '').toLowerCase();
        final email = (data['email'] as String? ?? '').toLowerCase();
        final nameParts = name.split(RegExp(r'\s+'));
        final matchesName =
            name.contains(query) ||
            nameParts.any((part) => part.startsWith(query));
        final matchesEmail = email.contains(query);

        if (matchesName || matchesEmail) {
          seen[doc.id] = doc;
        }
      }

      setState(() {
        _searchResults = seen.values.toList();
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _errorMessage = 'Search failed. Check your internet connection.';
      });
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
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.primaryOrange,
                ),
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
                : _errorMessage != null
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: 'Error',
                    message: _errorMessage!,
                  )
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                ? const EmptyState(
                    icon: Icons.person_search,
                    title: 'No users found',
                    message: 'Try a name, surname initial, or email.',
                  )
                : _searchResults.isEmpty
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Find someone',
                    message: 'Search by display name or email address.',
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final userDoc = _searchResults[index];
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final displayName =
                          userData['displayName'] as String? ?? 'Unknown User';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.lightPeach,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: AppTheme.darkOrange),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text(userData['email'] as String? ?? ''),
                        onTap: () async {
                          final convId = await chatListViewModel
                              .createConversation(userDoc.id);
                          if (convId != null && context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatView(conversationId: convId),
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
