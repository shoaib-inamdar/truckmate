import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:truckmate/services/appwrite_service.dart';
import '../config/appwrite_config.dart';
import '../models/user_model.dart';
// import '../services/appwrite_service.dart';

class EmailOTPService {
  final _appwriteService = AppwriteService();
  late final Account _account;

  EmailOTPService() {
    _account = _appwriteService.account;
  }

  // Send OTP to email
  Future<String> sendEmailOTP({required String email}) async {
    try {
      print('Sending OTP to email: $email');

      final token = await _account.createEmailToken(
        userId: ID.unique(),
        email: email,
      );

      print('Email token created - UserId: ${token.userId}');
      return token.userId;
    } on AppwriteException catch (e) {
      print('Send OTP Appwrite error - Code: ${e.code}, Message: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Send OTP general error: ${e.toString()}');
      throw 'Failed to send OTP: ${e.toString()}';
    }
  }

  // Verify Email OTP
  Future<UserModel> verifyEmailOTP({
    required String userId,
    required String secret,
  }) async {
    try {
      print('=== VERIFY EMAIL OTP ===');
      print('UserId: $userId');
      print('Secret (OTP): $secret');
      print('Secret length: ${secret.length}');

      // Delete existing session if any
      print('Checking for existing sessions...');
      try {
        await _account.deleteSession(sessionId: 'current');
        print('Existing session deleted');
      } catch (e) {
        print('No existing session to delete or error: $e');
      }

      print('Calling _account.createSession...');

      // Create session using the OTP (secret)
      final session = await _account.createSession(
        userId: userId,
        secret: secret,
      );

      print('Session created successfully!');
      print('Session userId: ${session.userId}');
      print('Session id: ${session.$id}');
      print('Getting current user...');

      // Get user details
      final user = await getCurrentUser();
      print('User retrieved: ${user.email}');
      print('=== END VERIFY EMAIL OTP ===');
      return user;
    } on AppwriteException catch (e) {
      print('=== APPWRITE ERROR ===');
      print('Error Code: ${e.code}');
      print('Error Message: ${e.message}');
      print('Error Type: ${e.type}');
      print('Error Response: ${e.response}');
      print('=== END ERROR ===');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('=== GENERAL ERROR ===');
      print('Error: ${e.toString()}');
      print('Error type: ${e.runtimeType}');
      print('=== END ERROR ===');
      throw 'Failed to verify OTP: ${e.toString()}';
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
        return 'Invalid OTP. Please check and try again.';
      case 404:
        return 'User not found or session expired.';
      case 409:
        return 'A user with this email already exists.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
