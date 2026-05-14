import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Authentication failed';
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signUp(String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(email, password, displayName);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign up failed';
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
