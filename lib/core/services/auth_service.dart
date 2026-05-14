import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/firestore_paths.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signUp(
      String email, String password, String displayName) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      await user.updateDisplayName(displayName);

      // Create user profile in Firestore
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
