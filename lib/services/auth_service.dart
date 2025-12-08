import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/user_model.dart';
import '../services/appwrite_service.dart';

class AuthService {
  final _appwriteService = AppwriteService();
  late final Account _account;

  AuthService() {
    _account = _appwriteService.account;
  }

  // Register new user
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create the user account
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // Create a session (login) for the newly created user
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      // Get the current user data
      final user = await _account.get();
      return UserModel(
        id: user.$id,
        email: user.email,
        name: user.name,
        createdAt: DateTime.parse(user.$createdAt),
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Registration failed: ${e.toString()}';
    }
  }

  // Login user
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // Appwrite SDK: create an email/password session
      // This will automatically replace any existing anonymous session
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await getCurrentUser();
      return user;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Login failed: ${e.toString()}';
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
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get user: ${e.toString()}';
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Create anonymous session
  Future<UserModel> createAnonymousSession() async {
    try {
      // Create anonymous session
      await _account.createAnonymousSession();

      // Get the anonymous user data
      final user = await _account.get();
      return UserModel(
        id: user.$id,
        email: 'anonymous@seller.local',
        name: 'Anonymous Seller',
        createdAt: DateTime.parse(user.$createdAt),
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to create anonymous session: ${e.toString()}';
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      // First check if user is logged in
      final isLoggedIn = await this.isLoggedIn();

      if (isLoggedIn) {
        // Only try to delete session if user is actually logged in
        await _account.deleteSession(sessionId: 'current');
      }
      // If not logged in, just return without doing anything
    } on AppwriteException catch (e) {
      // If it's a 401 error (not authorized), ignore it for logout
      if (e.code != 401) {
        throw _handleAppwriteException(e);
      }
      // For 401 errors during logout, just ignore them
    } catch (e) {
      // For logout, we don't want to throw errors if already logged out
      print('Logout info: ${e.toString()}');
    }
  }

  // Delete current anonymous session
  Future<void> deleteCurrentAnonymousSession() async {
    try {
      final isLoggedIn = await this.isLoggedIn();

      if (isLoggedIn) {
        // Delete the current session
        await _account.deleteSession(sessionId: 'current');
      }
    } on AppwriteException catch (e) {
      // Ignore 401 errors (not authorized)
      if (e.code != 401) {
        throw _handleAppwriteException(e);
      }
    } catch (e) {
      print('Delete session info: ${e.toString()}');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      // Delete all sessions first
      await _account.deleteSessions();
      // Note: Appwrite doesn't have a direct delete user method from client
      // This needs to be handled from server side or Admin API
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Account deletion failed: ${e.toString()}';
    }
  }

  // Get all sessions
  Future<models.SessionList> getSessions() async {
    try {
      return await _account.listSessions();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get sessions: ${e.toString()}';
    }
  }

  // Update name
  Future<UserModel> updateName(String name) async {
    try {
      final user = await _account.updateName(name: name);
      return UserModel(
        id: user.$id,
        email: user.email,
        name: user.name,
        createdAt: DateTime.parse(user.$createdAt),
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update name: ${e.toString()}';
    }
  }

  // Update password
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _account.updatePassword(
        password: newPassword,
        oldPassword: oldPassword,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update password: ${e.toString()}';
    }
  }

  // Create password recovery
  Future<void> createPasswordRecovery(String email) async {
    try {
      await _account.createRecovery(
        email: email,
        url: 'https://your-app-url.com/reset-password', // Replace with your URL
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to create recovery: ${e.toString()}';
    }
  }

  // Complete password recovery
  Future<void> completePasswordRecovery({
    required String userId,
    required String secret,
    required String password,
  }) async {
    try {
      await _account.updateRecovery(
        userId: userId,
        secret: secret,
        password: password,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to complete recovery: ${e.toString()}';
    }
  }

  // Delete all sessions safely (used for logout or cleanup)
  // Note: This may fail if user is in guest/anonymous session without account scope
  Future<void> deleteAllSessionsSafely() async {
    try {
      print('Attempting to delete all sessions...');
      // Try to delete current session first
      try {
        await _account.deleteSession(sessionId: 'current');
        print('Deleted current session');
      } catch (e) {
        print('Could not delete current session: ${e.toString()}');
      }

      // Try to delete all sessions
      try {
        await _account.deleteSessions();
        print('Deleted all sessions');
      } catch (e) {
        print('Could not delete all sessions: ${e.toString()}');
      }
    } catch (e) {
      print('Error in deleteAllSessionsSafely: ${e.toString()}');
    }
  }

  // Handle Appwrite exceptions
  String _handleAppwriteException(AppwriteException e) {
    print(
      'Appwrite Error - Code: ${e.code}, Message: ${e.message}, Type: ${e.type}',
    );

    switch (e.code) {
      case 401:
        return 'Invalid credentials. Please check your email and password.';
      case 409:
        return 'An account with this email already exists.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
