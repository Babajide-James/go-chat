import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/enums/message_type.dart';
import '../core/enums/message_status.dart';

class Message {
  final String id;
  final String senderId;
  final String? text;
  final MessageType type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? duration;
  final Map<String, String> reactions;
  final MessageStatus status;
  final Map<String, Timestamp> readBy;
  final Timestamp? editedAt;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final Timestamp createdAt;

  Message({
    required this.id,
    required this.senderId,
    this.text,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    this.duration,
    required this.reactions,
    required this.status,
    required this.readBy,
    this.editedAt,
    required this.deletedFor,
    required this.deletedForEveryone,
    required this.createdAt,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String,
      text: data['text'] as String?,
      type: data['type'] != null 
          ? MessageType.fromString(data['type'] as String)
          : MessageType.text,
      mediaUrl: data['mediaUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      duration: data['duration'] as int?,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      status: data['status'] != null
          ? MessageStatus.fromString(data['status'] as String)
          : MessageStatus.sent,
      readBy: Map<String, Timestamp>.from(data['readBy'] ?? {}),
      editedAt: data['editedAt'] as Timestamp?,
      deletedFor: List<String>.from(data['deletedFor'] ?? []),
      deletedForEveryone: data['deletedForEveryone'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type.stringValue,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (duration != null) 'duration': duration,
      'reactions': reactions,
      'status': status.stringValue,
      'readBy': readBy,
      if (editedAt != null) 'editedAt': editedAt,
      'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      'createdAt': createdAt,
    };
  }
}
