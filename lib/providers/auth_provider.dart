import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider() {
    _checkAuthStatus();
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        _user = await _userService.getCurrentUserWithProfile();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _user = await _authService.register(
        email: email,
        password: password,
        name: name,
      );

      // Create user profile in database
      if (_user != null) {
        await _userService.createOrUpdateUserProfile(
          userId: _user!.id,
          email: _user!.email,
          name: name,
        );
        
        // Refresh user data to get profile info
        _user = await _userService.getCurrentUserWithProfile();
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Login user
  Future<bool> login({required String email, required String password}) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _user = await _authService.login(email: email, password: password);

      // Get user profile from database
      if (_user != null) {
        _user = await _userService.getCurrentUserWithProfile();
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Set user after email OTP verification
  Future<void> setUserAfterOTP(UserModel user) async {
    try {
      _user = user;
      
      // Try to get profile from database
      final profile = await _userService.getUserProfile(user.id);
      
      if (profile != null) {
        _user = profile;
      } else {
        // Create basic profile
        await _userService.createOrUpdateUserProfile(
          userId: user.id,
          email: user.email,
          name: user.name,
        );
        _user = await _userService.getCurrentUserWithProfile();
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    if (_user == null) {
      _errorMessage = 'No user logged in';
      return false;
    }

    try {
      _status = AuthStatus.loading;
      notifyListeners();

      _user = await _userService.createOrUpdateUserProfile(
        userId: _user!.id,
        email: _user!.email,
        name: name,
        phone: phone,
        address: address,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      print('AuthProvider: Starting logout...');
      _status = AuthStatus.loading;
      notifyListeners();

      print('AuthProvider: Calling auth service logout...');
      await _authService.logout();

      print('AuthProvider: Logout successful, clearing state...');
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      print('AuthProvider: State cleared, status is now: $_status');
    } catch (e) {
      print('Logout error: $e');
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      print('AuthProvider: Error handled, state cleared anyway');
    }
  }

  // Update user name
  Future<bool> updateName(String name) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      _user = await _authService.updateName(name);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      _user = await _userService.getCurrentUserWithProfile();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}