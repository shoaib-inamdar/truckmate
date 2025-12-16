import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../models/user_model.dart';
import '../services/appwrite_service.dart';

class AuthService {
  final _appwriteService = AppwriteService();
  late final Account _account;
  AuthService() {
    _account = _appwriteService.account;
  }
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
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

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
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

  Future<bool> isLoggedIn() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<UserModel> createAnonymousSession() async {
    try {
      await _account.createAnonymousSession();
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

  Future<void> logout() async {
    try {
      final isLoggedIn = await this.isLoggedIn();
      if (isLoggedIn) {
        await _account.deleteSession(sessionId: 'current');
      }
    } on AppwriteException catch (e) {
      if (e.code != 401) {
        throw _handleAppwriteException(e);
      }
    } catch (e) {
      print('Logout info: ${e.toString()}');
    }
  }

  Future<void> deleteCurrentAnonymousSession() async {
    try {
      final isLoggedIn = await this.isLoggedIn();
      if (isLoggedIn) {
        await _account.deleteSession(sessionId: 'current');
      }
    } on AppwriteException catch (e) {
      if (e.code != 401) {
        throw _handleAppwriteException(e);
      }
    } catch (e) {
      print('Delete session info: ${e.toString()}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _account.deleteSessions();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Account deletion failed: ${e.toString()}';
    }
  }

  Future<models.SessionList> getSessions() async {
    try {
      return await _account.listSessions();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get sessions: ${e.toString()}';
    }
  }

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

  Future<void> deleteAllSessionsSafely() async {
    try {
      print('Attempting to delete all sessions...');
      try {
        await _account.deleteSession(sessionId: 'current');
        print('Deleted current session');
      } catch (e) {
        print('Could not delete current session: ${e.toString()}');
      }
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
