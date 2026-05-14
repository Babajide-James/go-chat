import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/firestore_service.dart';

class ChatListViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot>? get conversationsStream {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestoreService.getConversations(uid);
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
}
