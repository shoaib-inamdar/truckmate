import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/user_model.dart';

class GoogleAuthService {
  late final Client _client;
  late final Account _account;

  GoogleAuthService() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true);
    
    _account = Account(_client);
  }

  // Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    try {
      // Create OAuth2 session with Google
      await _account.createOAuth2Session(
        provider:'',
        success: '${AppwriteConfig.appUrl}/auth/oauth/success', // Success redirect
        failure: '${AppwriteConfig.appUrl}/auth/oauth/failure', // Failure redirect
      );

      // Wait for redirect and session creation
      await Future.delayed(const Duration(seconds: 2));

      // Get user details
      final user = await getCurrentUser();
      return user;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Google sign-in failed: ${e.toString()}';
    }
  }

  // Get current user
  Future<UserModel> getCurrentUser() async {
    try {
      final user = await _account.get();
      return UserModel(
        id: user.$id,
        email: user.email,
        name: user.name,
        createdAt: DateTime.parse(user.$createdAt),
        phone: user.phone,
        emailVerification: user.emailVerification,
        phoneVerification: user.phoneVerification,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get user: ${e.toString()}';
    }
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Logout failed: ${e.toString()}';
    }
  }

  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Authentication failed. Please try again.';
      case 409:
        return 'Account already exists. Please login instead.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}