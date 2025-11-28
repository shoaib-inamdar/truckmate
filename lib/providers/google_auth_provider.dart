import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/google_auth_service.dart';

enum GoogleAuthStatus {
  initial,
  loading,
  authenticated,
  error,
}

class GoogleAuthProvider with ChangeNotifier {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  
  GoogleAuthStatus _status = GoogleAuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  GoogleAuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == GoogleAuthStatus.loading;
  bool get isAuthenticated => _status == GoogleAuthStatus.authenticated;

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _status = GoogleAuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _user = await _googleAuthService.signInWithGoogle();

      _status = GoogleAuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = GoogleAuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleAuthService.logout();
      _user = null;
      _status = GoogleAuthStatus.initial;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Check auth status
  Future<bool> checkAuthStatus() async {
    try {
      final isLoggedIn = await _googleAuthService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _googleAuthService.getCurrentUser();
        _status = GoogleAuthStatus.authenticated;
        notifyListeners();
      }
      return isLoggedIn;
    } catch (e) {
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      _user = await _googleAuthService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}