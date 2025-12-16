import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/user_model.dart';
class PhoneAuthService {
  late final Client _client;
  late final Account _account;
  PhoneAuthService() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true); // Only for development
    _account = Account(_client);
  }
  Future<String> sendOTP({required String phoneNumber}) async {
    try {
      final token = await _account.createPhoneToken(
        userId: ID.unique(),
        phone: phoneNumber,
      );
      return token.userId;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to send OTP: ${e.toString()}';
    }
  }
  Future<UserModel> verifyOTP({
    required String userId,
    required String otp,
  }) async {
    try {
      await _account.createSession(
        userId: userId,
        secret: otp,
      );
      final user = await getCurrentUser();
      return user;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to verify OTP: ${e.toString()}';
    }
  }
  Future<UserModel> updatePhone(String phone) async {
    try {
      final user = await _account.updatePhone(
        phone: phone,
        password: '', // Password required for phone update
      );
      return UserModel(
        id: user.$id,
        email: user.email,
        name: user.name,
        createdAt: DateTime.parse(user.$createdAt),
        phone: user.phone,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update phone: ${e.toString()}';
    }
  }
  Future<models.Token> updatePhoneVerification() async {
    try {
      return await _account.createPhoneVerification();
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to create phone verification: ${e.toString()}';
    }
  }
  Future<models.Token> confirmPhoneVerification({
    required String userId,
    required String secret,
  }) async {
    try {
      return await _account.updatePhoneVerification(
        userId: userId,
        secret: secret,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to confirm verification: ${e.toString()}';
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
        return 'Invalid OTP. Please check and try again.';
      case 404:
        return 'User not found or session expired.';
      case 409:
        return 'A user with this phone number already exists.';
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
