import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final Timestamp? lastMessageAt;
  final Map<String, Timestamp> typing;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    required this.typing,
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] as Timestamp?,
      typing: Map<String, Timestamp>.from(data['typing'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt,
      'typing': typing,
    };
  }
}
