import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final Timestamp createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt,
    };
  }
}
