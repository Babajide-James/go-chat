import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Future<DocumentSnapshot> getUser(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).get();
  }

  Future<QuerySnapshot> searchUsersByDisplayName(String query) {
    return _firestore
        .collection(FirestorePaths.users)
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
  }

  Future<QuerySnapshot> searchUsersByEmail(String query) {
    return _firestore
        .collection(FirestorePaths.users)
        .where('email', isEqualTo: query.toLowerCase().trim())
        .limit(20)
        .get();
  }

  Future<QuerySnapshot> getUsersForSearch({int limit = 100}) {
    return _firestore
        .collection(FirestorePaths.users)
        .orderBy('displayName')
        .limit(limit)
        .get();
  }

  // Conversations
  Stream<QuerySnapshot> getConversations(String uid) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<DocumentReference> createConversation(List<String> participants) {
    return _firestore.collection(FirestorePaths.conversations).add({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessage': 'New Chat',
      'typing': {},
    });
  }

  Future<QuerySnapshot> findExistingConversation(List<String> participants) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .where('participants', arrayContainsAny: participants)
        .get();
  }

  // Messages
  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentReference> sendMessage(
    String conversationId,
    Map<String, dynamic> messageData,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .add(messageData);
  }

  Future<void> updateConversationLastMessage(
    String conversationId,
    String text,
    Timestamp time,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .update({'lastMessage': text, 'lastMessageAt': time});
  }

  Future<void> updateTypingStatus(
    String conversationId,
    String uid,
    bool isTyping,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .update({
          'typing.$uid': isTyping
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
        });
  }

  Future<void> updateMessageReaction(
    String conversationId,
    String messageId,
    String uid,
    String? emoji,
  ) {
    final ref = _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .doc(messageId);

    if (emoji == null) {
      return ref.update({'reactions.$uid': FieldValue.delete()});
    } else {
      return ref.update({'reactions.$uid': emoji});
    }
  }

  Future<void> markMessageAsRead(
    String conversationId,
    String messageId,
    String uid,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .update({
          'readBy.$uid': FieldValue.serverTimestamp(),
          'status':
              'seen', // Simplifying status logic; effectively 'seen' when any recipient reads it
        });
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .update({'text': newText, 'editedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMessageForMe(
    String conversationId,
    String messageId,
    String uid,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .update({
          'deletedFor': FieldValue.arrayUnion([uid]),
        });
  }

  Future<void> deleteMessageForEveryone(
    String conversationId,
    String messageId,
  ) {
    return _firestore
        .collection(FirestorePaths.conversations)
        .doc(conversationId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .update({
          'deletedForEveryone': true,
          'text': null,
          'mediaUrl': null, // optional: you could clean up storage too
        });
  }
}
