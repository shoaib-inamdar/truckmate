import 'dart:io';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/seller_model.dart';
import '../services/appwrite_service.dart';

class SellerService {
  final _appwriteService = AppwriteService();
  late final Databases _databases;
  late final Storage _storage;
  late final Account _account;
  SellerService() {
    _databases = _appwriteService.databases;
    _storage = Storage(_appwriteService.client);
    _account = _appwriteService.account;
  }
  Future<String?> _getCurrentUserId() async {
    try {
      final user = await _account.get();
      return user.$id;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadDocument(File file, String fileName) async {
    try {
      print('Uploading file: $fileName');
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw 'File size exceeds 5MB limit';
      }
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw 'User not authenticated';
      }
      print('Uploading file for user: $userId');
      final result = await _storage.createFile(
        bucketId: AppwriteConfig.sellerDocumentsBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      print('File uploaded successfully: ${result.$id}');
      return result.$id;
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in uploadDocument: Code ${e.code}, Message: ${e.message}, Response: ${e.response}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in uploadDocument: ${e.toString()}');
      throw 'Failed to upload document: ${e.toString()}';
    }
  }

  String getFileView(String fileId) {
    return '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.sellerDocumentsBucketId}/files/$fileId/view?project=${AppwriteConfig.projectId}';
  }

  Future<void> deleteDocument(String fileId) async {
    try {
      await _storage.deleteFile(
        bucketId: AppwriteConfig.sellerDocumentsBucketId,
        fileId: fileId,
      );
      print('File deleted successfully: $fileId');
    } on AppwriteException catch (e) {
      print('Error deleting file: ${e.message}');
    }
  }

  Future<String?> checkSellerStatus(String userId) async {
    try {
      print('Checking seller status for user: $userId');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) {
        return null;
      }
      final status = result.documents.first.data['status'] ?? 'pending';
      print('Seller status: $status');
      return status;
    } on AppwriteException catch (e) {
      print('Appwrite error checking seller status: ${e.message}');
      return null;
    } catch (e) {
      print('Error checking seller status: ${e.toString()}');
      return null;
    }
  }

  Future<SellerModel> createSellerRegistration({
    required String userId,
    required String name,
    required String address,
    required String contact,
    required String email,
    required String panCardNo,
    String? panDocumentId,
    required String drivingLicenseNo,
    String? licenseDocumentId,
    required String gstNo,
    String? gstDocumentId,
    required List<String> selectedVehicleTypes,
    required List<VehicleInfo> vehicles,
  }) async {
    try {
      print('Creating seller registration for user: $userId');
      final username = _generateUsername(name);
      final password = _generatePassword();
      print(
        'Generated credentials - username: $username, password: ${password.replaceAll(RegExp(r'.'), '*')}',
      );
      final vehiclesStrings = vehicles.map((v) {
        final parts = [
          v.vehicleNumber,
          v.vehicleType,
          v.type,
          v.rcBookNo,
          v.maxPassWeight,
          v.documentId ?? '',
          v.rcDocumentId ?? '',
          v.frontImageId ?? '',
          v.rearImageId ?? '',
          v.sideImageId ?? '',
        ];
        return parts.join('|');
      }).toList();

      final data = {
        'user_id': userId,
        'name': name,
        'address': address,
        'contact': contact,
        'email': email,
        'username': username,
        'password': password,
        'pan_card_no': panCardNo,
        'pan_document_id': panDocumentId ?? '',
        'driving_license_no': drivingLicenseNo,
        'license_document_id': licenseDocumentId ?? '',
        'gst_no': gstNo,
        'gst_document_id': gstDocumentId ?? '',
        'selected_vehicle_types': selectedVehicleTypes,
        'vehicles': vehiclesStrings,
        'status': 'pending',
      };

      // Populate individual vehicle columns for up to 2 vehicles
      if (vehicles.isNotEmpty) {
        data['type'] = vehicles[0].type;
        data['max_pass_weight'] = vehicles[0].maxPassWeight;
        data['rc_book_no_1'] = vehicles[0].rcBookNo;
        data['rc_document_id_1'] = vehicles[0].rcDocumentId ?? '';
      }
      if (vehicles.length > 1) {
        data['rc_book_no_2'] = vehicles[1].rcBookNo;
        data['rc_document_id_2'] = vehicles[1].rcDocumentId ?? '';
      }
      print('Seller data: $data');
      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: ID.unique(),
        data: data,
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      print('Seller registration created successfully: ${doc.$id}');
      return _documentToSellerModel(doc);
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in createSellerRegistration: Code ${e.code}, Message: ${e.message}, Response: ${e.response}',
      );
      if (panDocumentId != null && panDocumentId.isNotEmpty) {
        await deleteDocument(panDocumentId);
      }
      if (licenseDocumentId != null && licenseDocumentId.isNotEmpty) {
        await deleteDocument(licenseDocumentId);
      }
      if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
        await deleteDocument(gstDocumentId);
      }
      for (var vehicle in vehicles) {
        if (vehicle.documentId != null && vehicle.documentId!.isNotEmpty) {
          await deleteDocument(vehicle.documentId!);
        }
        if (vehicle.rcDocumentId != null && vehicle.rcDocumentId!.isNotEmpty) {
          await deleteDocument(vehicle.rcDocumentId!);
        }
      }
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createSellerRegistration: ${e.toString()}');
      throw 'Failed to create seller registration: ${e.toString()}';
    }
  }

  Future<SellerModel?> getSellerRegistration(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );
      if (result.documents.isEmpty) {
        return null;
      }
      return _documentToSellerModel(result.documents.first);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get seller registration: ${e.toString()}';
    }
  }

  Future<String?> getOriginalUserIdByEmail(String email) async {
    try {
      print('Getting original user_id for email: $email');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('email', email),
          Query.orderDesc(r'$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) {
        print('No seller found with email: $email');
        return null;
      }
      final userId = result.documents.first.data['user_id'] as String?;
      print('Found original user_id: $userId for email: $email');
      return userId;
    } on AppwriteException catch (e) {
      print('Appwrite error in getOriginalUserIdByEmail: ${e.message}');
      return null;
    } catch (e) {
      print('Error getting original user_id: ${e.toString()}');
      return null;
    }
  }

  Future<String?> getSellerNameByUserId(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc(r'$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) return null;
      final doc = result.documents.first;
      final name = doc.data['name'] as String?;
      return name;
    } on AppwriteException catch (e) {
      print('Appwrite error in getSellerNameByUserId: ${e.message}');
      return null;
    } catch (e) {
      print('General error in getSellerNameByUserId: ${e.toString()}');
      return null;
    }
  }

  Future<SellerModel> updateSellerStatus({
    required String sellerId,
    required String status,
  }) async {
    try {
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: sellerId,
        data: {'status': status},
      );
      return _documentToSellerModel(doc);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update seller status: ${e.toString()}';
    }
  }

  Future<bool> deleteSellerRequest(String sellerId) async {
    try {
      print('Deleting seller request: $sellerId');
      await _databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: sellerId,
      );
      print('✓ Seller request deleted successfully: $sellerId');
      return true;
    } on AppwriteException catch (e) {
      print('AppwriteException in deleteSellerRequest: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error deleting seller request: ${e.toString()}');
      throw 'Failed to delete seller request: ${e.toString()}';
    }
  }

  Future<bool> updateAvailabilityByUserId({
    required String userId,
    required String availability,
    String? returnLocation,
  }) async {
    try {
      print(
        '🟡 SellerService.updateAvailabilityByUserId: Called with userId=$userId, availability=$availability',
      );
      // Find latest seller_request document for this user
      print(
        '🟡 SellerService.updateAvailabilityByUserId: Querying seller_request collection...',
      );
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc(r'$createdAt'),
          Query.limit(1),
        ],
      );
      print(
        '🟡 SellerService.updateAvailabilityByUserId: Query result - found ${result.documents.length} documents',
      );
      if (result.documents.isEmpty) {
        print(
          '❌ SellerService.updateAvailabilityByUserId: No seller registration found for user $userId',
        );
        throw 'Seller registration not found for user';
      }
      final docId = result.documents.first.$id;
      print(
        '🟡 SellerService.updateAvailabilityByUserId: Found document $docId, preparing update...',
      );
      final data = {
        'availability': availability,
        'return_location': availability == 'return_available'
            ? (returnLocation ?? '')
            : '',
      };
      print(
        '🟡 SellerService.updateAvailabilityByUserId: Updating document with data: $data',
      );
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: data,
      );
      print(
        '✅ SellerService.updateAvailabilityByUserId: Document updated successfully',
      );
      return true;
    } on AppwriteException catch (e) {
      print(
        '❌ SellerService.updateAvailabilityByUserId: Appwrite error - Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print(
        '❌ SellerService.updateAvailabilityByUserId: Exception - ${e.toString()}',
      );
      throw 'Failed to update availability: ${e.toString()}';
    }
  }

  Future<Map<String, String>?> getSellerCredentials(String userId) async {
    try {
      print('Fetching seller credentials for user: $userId');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) {
        print('No seller documents found');
        return null;
      }
      final doc = result.documents.first;
      final username = doc.data['username'] as String?;
      final password = doc.data['password'] as String?;
      final email = doc.data['email'] as String?;
      print(
        'Fetched - username: $username, email: $email, password: ${password?.replaceAll(RegExp(r'.'), '*')}',
      );
      if (username != null && password != null && email != null) {
        print('Returning credentials - username: $username, email: $email');
        return {'username': username, 'password': password, 'email': email};
      }
      print(
        'Missing required credentials: username=$username, email=$email, password=$password',
      );
      return null;
    } on AppwriteException catch (e) {
      print('Appwrite error fetching seller credentials: ${e.message}');
      return null;
    } catch (e) {
      print('Error fetching seller credentials: ${e.toString()}');
      return null;
    }
  }

  Future<bool> isUserAuthenticated() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  SellerModel _documentToSellerModel(models.Document doc) {
    final vehiclesList =
        (doc.data['vehicles'] as List?)
            ?.map((v) {
              if (v is String) {
                try {
                  final jsonData = jsonDecode(v) as Map<String, dynamic>;
                  return VehicleInfo.fromJson(jsonData);
                } catch (e) {
                  final parts = v.split('|');
                  if (parts.isEmpty) return null;
                  return VehicleInfo(
                    vehicleNumber: parts[0],
                    vehicleType: parts.length > 1 && parts[1].isNotEmpty
                        ? parts[1]
                        : '',
                    type: parts.length > 2 && parts[2].isNotEmpty
                        ? parts[2]
                        : '',
                    rcBookNo: parts.length > 3 && parts[3].isNotEmpty
                        ? parts[3]
                        : '',
                    maxPassWeight: parts.length > 4 && parts[4].isNotEmpty
                        ? parts[4]
                        : '',
                    documentId: parts.length > 5 && parts[5].isNotEmpty
                        ? parts[5]
                        : null,
                    rcDocumentId: parts.length > 6 && parts[6].isNotEmpty
                        ? parts[6]
                        : null,
                    frontImageId: parts.length > 7 && parts[7].isNotEmpty
                        ? parts[7]
                        : null,
                    rearImageId: parts.length > 8 && parts[8].isNotEmpty
                        ? parts[8]
                        : null,
                    sideImageId: parts.length > 9 && parts[9].isNotEmpty
                        ? parts[9]
                        : null,
                  );
                }
              } else if (v is Map<String, dynamic>) {
                return VehicleInfo.fromJson(v);
              }
              return null;
            })
            .whereType<VehicleInfo>()
            .toList() ??
        [];
    return SellerModel(
      id: doc.$id,
      userId: doc.data['user_id'] ?? '',
      name: doc.data['name'] ?? '',
      address: doc.data['address'] ?? '',
      contact: doc.data['contact'] ?? '',
      email: doc.data['email'] ?? '',
      panCardNo: doc.data['pan_card_no'] ?? '',
      panDocumentId: doc.data['pan_document_id']?.isEmpty ?? true
          ? null
          : doc.data['pan_document_id'],
      drivingLicenseNo: doc.data['driving_license_no'] ?? '',
      licenseDocumentId: doc.data['license_document_id']?.isEmpty ?? true
          ? null
          : doc.data['license_document_id'],
      gstNo: doc.data['gst_no'] ?? '',
      gstDocumentId: doc.data['gst_document_id']?.isEmpty ?? true
          ? null
          : doc.data['gst_document_id'],
      selectedVehicleTypes: List<String>.from(
        doc.data['selected_vehicle_types'] ?? [],
      ),
      vehicles: vehiclesList,
      createdAt: DateTime.parse(doc.$createdAt),
      status: doc.data['status'] ?? 'pending',
      availability: doc.data['availability'] ?? 'free',
      returnLocation: (doc.data['return_location'] as String?) ?? '',
    );
  }

  Future<bool> createSellerAccount({
    required String email,
    required String password,
    required String sellerName,
  }) async {
    try {
      print('Creating Appwrite account for seller: $email');
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: sellerName,
      );
      print('✓ Appwrite account created successfully for: $email');
      return true;
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        // Account already exists. Verify whether provided password is valid.
        print(
          'Account already exists for $email. Verifying provided password...',
        );
        try {
          await _account.createEmailPasswordSession(
            email: email,
            password: password,
          );
          // Password matches existing account; clean up session to avoid side effects.
          await _account.deleteSession(sessionId: 'current');
          print('Existing account verified with provided password.');
          return true;
        } on AppwriteException catch (loginError) {
          print(
            'Password mismatch for existing account $email: ${loginError.message}',
          );
          // Signal mismatch to caller (they should prompt user to use existing password/reset).
          return false;
        }
      }
      print('Error creating Appwrite account: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Unexpected error creating seller account: ${e.toString()}');
      throw 'Failed to create seller account: ${e.toString()}';
    }
  }

  Future<bool> ensureSellerAccountExists({
    required String username,
    required String password,
    required String sellerName,
  }) async {
    try {
      print('Ensuring Appwrite account exists for: $username');
      await createSellerAccount(
        email: username,
        password: password,
        sellerName: sellerName,
      );
      return true;
    } catch (e) {
      print('Note: Could not ensure seller account exists: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateSellerUsername({
    required String userId,
    required String newUsername,
  }) async {
    try {
      print('Updating username for user: $userId to $newUsername');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) {
        throw 'Seller record not found';
      }
      final docId = result.documents.first.$id;
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: {'username': newUsername},
      );

      // Also update the Appwrite account name
      try {
        print('Updating Appwrite account name...');
        await _account.updateName(name: newUsername);
        print('✅ Appwrite account name updated successfully');
      } catch (e) {
        print('❌ Failed to update Appwrite account name: ${e.toString()}');
        // Continue anyway as database username is updated
      }

      print('Username updated successfully');
      return true;
    } on AppwriteException catch (e) {
      print('Appwrite error updating username: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error updating username: ${e.toString()}');
      throw 'Failed to update username: ${e.toString()}';
    }
  }

  Future<bool> updateSellerPassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      print('Updating password for user: $userId');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) {
        throw 'Seller record not found';
      }
      final docId = result.documents.first.$id;

      // Update the Appwrite account password first (requires old password)
      try {
        print('Updating Appwrite account password...');
        await _account.updatePassword(
          password: newPassword,
          oldPassword: oldPassword,
        );
        print('✅ Appwrite account password updated successfully');
      } catch (e) {
        print('❌ Failed to update Appwrite account password: ${e.toString()}');
        throw 'Failed to update password. Please check your current password.';
      }

      // If Appwrite update succeeded, update database
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: {'password': newPassword},
      );

      print('Password updated successfully in both Appwrite and database');
      return true;
    } on AppwriteException catch (e) {
      print('Appwrite error updating password: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error updating password: ${e.toString()}');
      throw 'Failed to update password: ${e.toString()}';
    }
  }

  Future<bool> deleteSellerAccount({required String userId}) async {
    try {
      print('Deleting seller account for user: $userId');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );
      if (result.documents.isEmpty) {
        throw 'Seller record not found';
      }
      for (var doc in result.documents) {
        await _databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.sellerRequestsCollectionId,
          documentId: doc.$id,
        );
        print('Deleted seller document: ${doc.$id}');
      }
      try {
        await _account.deleteSession(sessionId: 'current');
        print('Deleted current session');
      } catch (e) {
        print('Note: Could not delete session: ${e.toString()}');
      }
      print('Seller account deleted successfully');
      return true;
    } on AppwriteException catch (e) {
      print('Appwrite error deleting account: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error deleting account: ${e.toString()}');
      throw 'Failed to delete account: ${e.toString()}';
    }
  }

  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Unauthorized. Please check bucket and collection permissions in Appwrite Console.';
      case 404:
        return 'Seller registration not found.';
      case 409:
        return 'Seller registration already exists.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  String _generateUsername(String name) {
    final nameParts = name.toLowerCase().split(' ');
    final baseUsername = nameParts[0];
    final randomSuffix = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);
    return '$baseUsername$randomSuffix';
  }

  String _generatePassword() {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 12; i++) {
      buffer.write(characters[(random + i) % characters.length]);
    }
    return buffer.toString();
  }
}
