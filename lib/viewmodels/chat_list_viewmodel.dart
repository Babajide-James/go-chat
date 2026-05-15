import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/firestore_service.dart';
import '../core/services/local_database_service.dart';

class ChatListViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> get conversations => _conversations;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription? _sub;

  ChatListViewModel() {
    _init();
  }

  void _init() async {
    if (_currentUserId == null) return;
    
    // 1. Load from local DB immediately
    _conversations = await _localDb.getCachedConversations();
    _isLoading = _conversations.isEmpty;
    notifyListeners();

    // 2. Listen to remote changes
    _sub = _firestoreService.getConversations(_currentUserId).listen((snapshot) {
      final docs = snapshot.docs.map((d) {
        var data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        // Convert Timestamp to iso8601 string for sqflite compatibility
        if (data['lastMessageAt'] is Timestamp) {
          data['lastMessageAt'] = (data['lastMessageAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        // Also convert 'typing' timestamps
        if (data['typing'] != null && data['typing'] is Map) {
          final typingMap = data['typing'] as Map;
          final newTypingMap = <String, dynamic>{};
          typingMap.forEach((key, value) {
            if (value is Timestamp) {
              newTypingMap[key] = value.toDate().toIso8601String();
            } else {
              newTypingMap[key] = value;
            }
          });
          data['typing'] = newTypingMap;
        }
        return data;
      }).toList();

      _conversations = docs;
      _isLoading = false;
      notifyListeners();

      // Cache the latest conversations locally
      _localDb.cacheConversations(docs);
    });
  }

  Future<String?> createConversation(String otherUserId) async {
    final uid = _currentUserId;
    if (uid == null) return null;
    
    try {
      // Check if conversation already exists (simplified check)
      final conversations = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .get();

      for (var doc in conversations.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return doc.id; // Return existing conversation ID
        }
      }

      // Create new conversation
      final docRef = await _firestoreService.createConversation([
        uid,
        otherUserId
      ]);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
