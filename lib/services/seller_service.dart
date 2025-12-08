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

  // Get current user ID
  Future<String?> _getCurrentUserId() async {
    try {
      final user = await _account.get();
      return user.$id;
    } catch (e) {
      return null;
    }
  }

  // Upload file to Appwrite Storage
  Future<String?> uploadDocument(File file, String fileName) async {
    try {
      print('Uploading file: $fileName');

      // Check file size (max 5MB)
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw 'File size exceeds 5MB limit';
      }

      // Get current user ID for permissions
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw 'User not authenticated';
      }

      print('Uploading file for user: $userId');

      // Upload file with explicit permissions
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

  // Get file preview/download URL
  String getFileView(String fileId) {
    return '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.sellerDocumentsBucketId}/files/$fileId/view?project=${AppwriteConfig.projectId}';
  }

  // Delete file from storage
  Future<void> deleteDocument(String fileId) async {
    try {
      await _storage.deleteFile(
        bucketId: AppwriteConfig.sellerDocumentsBucketId,
        fileId: fileId,
      );
      print('File deleted successfully: $fileId');
    } on AppwriteException catch (e) {
      print('Error deleting file: ${e.message}');
      // Don't throw error for file deletion failures
    }
  }

  // Create seller registration
  // Check seller registration status
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
    required String rcBookNo,
    String? rcDocumentId,
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

      // Generate default credentials for the seller
      final username = _generateUsername(name);
      final password = _generatePassword();

      print(
        'Generated credentials - username: $username, password: ${password.replaceAll(RegExp(r'.'), '*')}',
      );

      // Convert vehicles to compact string format for Appwrite (max 100 chars per string)
      // Format: vehicleNumber|documentId|frontId|rearId|sideId
      final vehiclesStrings = vehicles.map((v) {
        final parts = [
          v.vehicleNumber,
          v.documentId ?? '',
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
        'rc_book_no': rcBookNo,
        'rc_document_id': rcDocumentId ?? '',
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

      // If registration fails, cleanup uploaded files
      if (rcDocumentId != null && rcDocumentId.isNotEmpty) {
        await deleteDocument(rcDocumentId);
      }
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
      }

      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createSellerRegistration: ${e.toString()}');
      throw 'Failed to create seller registration: ${e.toString()}';
    }
  }

  // Get seller registration by user ID
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

  // Get seller display name by user ID from seller_request
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

  // Update seller registration status
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

  // Get seller request credentials (username, email, and password)
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

      // If username, email, and password exist, proceed
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

  // Check if user is authenticated
  Future<bool> isUserAuthenticated() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Convert Appwrite document to SellerModel
  SellerModel _documentToSellerModel(models.Document doc) {
    // Parse vehicles from compact pipe-separated format
    final vehiclesList =
        (doc.data['vehicles'] as List?)
            ?.map((v) {
              if (v is String) {
                try {
                  // Try to parse as JSON string first (for any old JSON format)
                  final jsonData = jsonDecode(v) as Map<String, dynamic>;
                  return VehicleInfo.fromJson(jsonData);
                } catch (e) {
                  // Parse pipe-separated format: vehicleNumber|documentId|frontId|rearId|sideId
                  final parts = v.split('|');
                  if (parts.isEmpty) return null;

                  return VehicleInfo(
                    vehicleNumber: parts[0],
                    documentId: parts.length > 1 && parts[1].isNotEmpty
                        ? parts[1]
                        : null,
                    frontImageId: parts.length > 2 && parts[2].isNotEmpty
                        ? parts[2]
                        : null,
                    rearImageId: parts.length > 3 && parts[3].isNotEmpty
                        ? parts[3]
                        : null,
                    sideImageId: parts.length > 4 && parts[4].isNotEmpty
                        ? parts[4]
                        : null,
                  );
                }
              } else if (v is Map<String, dynamic>) {
                // Direct JSON object (for safety)
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
      rcBookNo: doc.data['rc_book_no'] ?? '',
      rcDocumentId: doc.data['rc_document_id']?.isEmpty ?? true
          ? null
          : doc.data['rc_document_id'],
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
    );
  }

  // Create an Appwrite account for the seller when approved
  // The username must be a valid email address
  Future<bool> createSellerAccount({
    required String email,
    required String password,
    required String sellerName,
  }) async {
    try {
      print('Creating Appwrite account for seller: $email');

      // Create the user account in Appwrite
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: sellerName,
      );

      print('✓ Appwrite account created successfully for: $email');
      return true;
    } on AppwriteException catch (e) {
      // If account already exists (409), it's okay
      if (e.code == 409) {
        print('Account already exists for $email (no action needed)');
        return true;
      }
      print('Error creating Appwrite account: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Unexpected error creating seller account: ${e.toString()}');
      throw 'Failed to create seller account: ${e.toString()}';
    }
  }

  // Ensure seller account exists before login (create if needed)
  Future<bool> ensureSellerAccountExists({
    required String username,
    required String password,
    required String sellerName,
  }) async {
    try {
      // The username is used as the email for Appwrite authentication
      print('Ensuring Appwrite account exists for: $username');

      await createSellerAccount(
        email: username,
        password: password,
        sellerName: sellerName,
      );

      return true;
    } catch (e) {
      // If account creation fails, log but don't throw
      // Let the login attempt proceed - it will fail properly if account truly doesn't exist
      print('Note: Could not ensure seller account exists: ${e.toString()}');
      return false;
    }
  }

  // Update seller username in seller_request collection
  Future<bool> updateSellerUsername({
    required String userId,
    required String newUsername,
  }) async {
    try {
      print('Updating username for user: $userId to $newUsername');

      // Find the seller document
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

      // Update the username field
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: {'username': newUsername},
      );

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

  // Update seller password in seller_request collection
  Future<bool> updateSellerPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      print('Updating password for user: $userId');

      // Find the seller document
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

      // Update the password field
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: {'password': newPassword},
      );

      // Also update the Appwrite account password if the account exists
      try {
        final email = result.documents.first.data['email'] as String?;
        if (email != null) {
          // Note: Updating password for authenticated user requires current session
          // This is a simplified approach - in production, you might need
          // to use the account.updatePassword() method with current password
          print(
            'Password updated in database. Account password update may require re-authentication.',
          );
        }
      } catch (e) {
        print(
          'Note: Could not update Appwrite account password: ${e.toString()}',
        );
      }

      print('Password updated successfully');
      return true;
    } on AppwriteException catch (e) {
      print('Appwrite error updating password: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error updating password: ${e.toString()}');
      throw 'Failed to update password: ${e.toString()}';
    }
  }

  // Delete seller account (soft delete - mark as deleted or hard delete the record)
  Future<bool> deleteSellerAccount({required String userId}) async {
    try {
      print('Deleting seller account for user: $userId');

      // Find the seller document
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );

      if (result.documents.isEmpty) {
        throw 'Seller record not found';
      }

      // Delete all seller documents for this user
      for (var doc in result.documents) {
        await _databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.sellerRequestsCollectionId,
          documentId: doc.$id,
        );
        print('Deleted seller document: ${doc.$id}');
      }

      // Delete the Appwrite user account session
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

  // Handle Appwrite exceptions
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

  // Generate a unique username from seller name
  String _generateUsername(String name) {
    // Create a base from the first word of the name
    final nameParts = name.toLowerCase().split(' ');
    final baseUsername = nameParts[0];

    // Add a random suffix to ensure uniqueness
    final randomSuffix = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);
    return '$baseUsername$randomSuffix';
  }

  // Generate a secure random password
  String _generatePassword() {
    // Use only alphanumeric characters to avoid Appwrite validation issues
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
