import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/user_model.dart';
import '../services/appwrite_service.dart';

class UserService {
  final _appwriteService = AppwriteService();
  late final Databases _databases;
  late final Account _account;
  UserService() {
    _databases = _appwriteService.databases;
    _account = _appwriteService.account;
  }
  Future<UserModel> createOrUpdateUserProfile({
    required String userId,
    required String email,
    required String name,
    String role = 'user',
    String? phone,
    String? address,
  }) async {
    try {
      print('Creating/Updating profile for user: $userId');
      print('Email received: $email');
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        print('Invalid email format detected: $email');
        throw 'Invalid email format. Please provide a valid email address.';
      }
      final data = {
        'email': email,
        'name': name,
        'role': role,
        'phone': phone ?? '',
        'address': address ?? '',
      };
      print('Profile data: $data');
      try {
        await _databases.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.usersCollectionId,
          documentId: userId,
        );
        print('Document exists, updating...');
        final doc = await _databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.usersCollectionId,
          documentId: userId,
          data: data,
        );
        print('Document updated successfully');
        return _documentToUserModel(doc);
      } catch (e) {
        print('Document does not exist, creating new one...');
        print('Creating document with permissions for user: $userId');
        final doc = await _databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.usersCollectionId,
          documentId: userId,
          data: data,
          permissions: [
            Permission.read(Role.user(userId)),
            Permission.update(Role.user(userId)),
            Permission.delete(Role.user(userId)),
          ],
        );
        print('Document created successfully');
        return _documentToUserModel(doc);
      }
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in createOrUpdateUserProfile: Code ${e.code}, Message: ${e.message}, Response: ${e.response}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createOrUpdateUserProfile: ${e.toString()}');
      throw 'Failed to save profile: ${e.toString()}';
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      print('Getting profile for user: $userId');
      final doc = await _databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        documentId: userId,
      );
      print('Profile retrieved successfully');
      return _documentToUserModel(doc);
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        print('Profile not found for user: $userId');
        return null; // User profile doesn't exist yet
      }
      print(
        'Appwrite error in getUserProfile: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in getUserProfile: ${e.toString()}');
      throw 'Failed to get profile: ${e.toString()}';
    }
  }

  Future<UserModel> getCurrentUserWithProfile() async {
    try {
      print('Getting current user with profile...');
      final user = await _account.get();
      print('Got user from account: ${user.$id}');
      final profile = await getUserProfile(user.$id);
      if (profile != null) {
        print('Profile found in database');
        return profile;
      }
      print('No profile in database, returning basic user data');
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
      print(
        'Appwrite error in getCurrentUserWithProfile: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in getCurrentUserWithProfile: ${e.toString()}');
      throw 'Failed to get user: ${e.toString()}';
    }
  }

  Future<UserModel> updateUserFields({
    required String userId,
    String? name,
    String? role,
    String? phone,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (role != null) data['role'] = role;
      if (phone != null) data['phone'] = phone;
      if (address != null) data['address'] = address;
      data['updatedAt'] = DateTime.now().toIso8601String();
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        documentId: userId,
        data: data,
      );
      return _documentToUserModel(doc);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update profile: ${e.toString()}';
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    try {
      await _databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        documentId: userId,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to delete profile: ${e.toString()}';
    }
  }

  UserModel _documentToUserModel(models.Document doc) {
    final name = doc.data['name'] ?? '';
    final phone = doc.data['phone'];
    final address = doc.data['address'];
    final computedComplete =
        name.isNotEmpty &&
        phone != null &&
        phone.isNotEmpty &&
        address != null &&
        address.isNotEmpty;
    return UserModel(
      id: doc.$id,
      email: doc.data['email'] ?? '',
      name: name,
      createdAt: DateTime.parse(doc.$createdAt),
      role: doc.data['role'] ?? 'user',
      phone: phone,
      address: address,
      emailVerification: doc.data['emailVerification'] ?? false,
      phoneVerification: doc.data['phoneVerification'] ?? false,
      isProfileComplete: computedComplete,
    );
  }

  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Unauthorized. Please check collection permissions in Appwrite Console.';
      case 404:
        return 'Profile not found.';
      case 409:
        return 'Profile already exists.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
