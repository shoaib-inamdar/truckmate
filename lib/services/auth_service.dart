import 'dart:ffi';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/user_model.dart';

class AuthService {
  late final Client _client;
  late final Account _account;

  AuthService() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true); // Only for development

    _account = Account(_client);
  }

  // Register new user
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    // required String phone,
  }) async {
    try {
      // Create the user account
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // final token=await _account.createPhoneToken(userId: ID.unique(), phone: phone);
      // // print("token:",token);
      // final userId = token.userId;
      // await _account.createSession(userId: userId,secret:'' );

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
