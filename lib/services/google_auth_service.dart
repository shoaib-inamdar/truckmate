import 'package:appwrite/appwrite.dart';
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
  Future<UserModel> signInWithGoogle() async {
    try {
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success:
            '${AppwriteConfig.appUrl}/auth/oauth/success', // Success redirect
        failure:
            '${AppwriteConfig.appUrl}/auth/oauth/failure', // Failure redirect
      );
      await Future.delayed(const Duration(seconds: 2));
      final user = await getCurrentUser();
      return user;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Google sign-in failed: ${e.toString()}';
    }
  }

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

  Future<bool> isLoggedIn() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

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
