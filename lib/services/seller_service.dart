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
      if (fileSize > 1 * 1024 * 1024) {
        throw 'File size exceeds 1MB limit';
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
    required int vehicleCount,
  }) async {
    try {
      print('Creating seller registration for user: $userId');

      // First, check if there's already a pending or approved registration for this user
      final existingDocs = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );

      if (existingDocs.documents.isNotEmpty) {
        print(
          'Found ${existingDocs.documents.length} existing registration(s) for user',
        );

        List<String> rejectedDocIds = [];
        List<String> pendingDocIds = [];
        bool hasApproved = false;

        // Check status of all existing registrations
        for (var doc in existingDocs.documents) {
          final status = doc.data['status'] ?? '';
          if (status == 'approved') {
            hasApproved = true;
            print(
              'User already has an approved registration with ID: ${doc.$id}',
            );
          } else if (status == 'pending') {
            pendingDocIds.add(doc.$id);
            print(
              'User has a pending registration with ID: ${doc.$id} - will be replaced',
            );
          } else if (status == 'rejected') {
            rejectedDocIds.add(doc.$id);
          }
        }

        // Block if user has an approved registration
        if (hasApproved) {
          // Clean up the newly uploaded documents since we won't use them
          if (panDocumentId != null && panDocumentId.isNotEmpty) {
            try {
              await deleteDocument(panDocumentId);
            } catch (e) {
              print('Could not clean up PAN document: $e');
            }
          }
          if (licenseDocumentId != null && licenseDocumentId.isNotEmpty) {
            try {
              await deleteDocument(licenseDocumentId);
            } catch (e) {
              print('Could not clean up license document: $e');
            }
          }
          if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
            try {
              await deleteDocument(gstDocumentId);
            } catch (e) {
              print('Could not clean up GST document: $e');
            }
          }
            for (var vehicle in vehicles) {
              if (vehicle.documentId != null &&
                  vehicle.documentId!.isNotEmpty) {
                try {
                  await deleteDocument(vehicle.documentId!);
                } catch (e) {
                  print('Could not clean up vehicle document: $e');
                }
              }
              if (vehicle.rcDocumentId != null &&
                  vehicle.rcDocumentId!.isNotEmpty) {
                try {
                  await deleteDocument(vehicle.rcDocumentId!);
                } catch (e) {
                  print('Could not clean up RC document: $e');
                }
              }
              if (vehicle.frontImageId != null &&
                  vehicle.frontImageId!.isNotEmpty) {
                try {
                  await deleteDocument(vehicle.frontImageId!);
                } catch (e) {
                  print('Could not clean up front image: $e');
                }
              }
              if (vehicle.rearImageId != null &&
                  vehicle.rearImageId!.isNotEmpty) {
                try {
                  await deleteDocument(vehicle.rearImageId!);
                } catch (e) {
                  print('Could not clean up rear image: $e');
                }
              }
              if (vehicle.sideImageId != null &&
                  vehicle.sideImageId!.isNotEmpty) {
                try {
                  await deleteDocument(vehicle.sideImageId!);
                } catch (e) {
                  print('Could not clean up side image: $e');
                }
              }
            }
          throw 'You already have an approved registration. Cannot create a new one.';
        }

        // Delete old pending registrations to allow new submission
        if (pendingDocIds.isNotEmpty) {
          print(
            'Deleting ${pendingDocIds.length} pending registration(s) to allow new submission',
          );
          for (var docId in pendingDocIds) {
            try {
              // Clean up old documents from the pending registration
              final oldDoc = await _databases.getDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              
              // Delete old documents
              final oldPanDocId = oldDoc.data['pan_document_id'] as String?;
              final oldLicenseDocId = oldDoc.data['license_document_id'] as String?;
              final oldGstDocId = oldDoc.data['gst_document_id'] as String?;
              final oldVehicles = oldDoc.data['vehicles'] as List?;
              
              if (oldPanDocId != null && oldPanDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldPanDocId);
                } catch (e) {
                  print('Could not delete old PAN document: $e');
                }
              }
              if (oldLicenseDocId != null && oldLicenseDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldLicenseDocId);
                } catch (e) {
                  print('Could not delete old license document: $e');
                }
              }
              if (oldGstDocId != null && oldGstDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldGstDocId);
                } catch (e) {
                  print('Could not delete old GST document: $e');
                }
              }
              
              // Delete old vehicle documents
              if (oldVehicles != null) {
                for (var vehicleStr in oldVehicles) {
                  if (vehicleStr is String) {
                    final parts = vehicleStr.split('|');
                    // parts[5] = documentId (old combined image, may be empty)
                    // parts[6] = rcDocumentId
                    // parts[7] = frontImageId
                    // parts[8] = rearImageId
                    // parts[9] = sideImageId
                    if (parts.length > 5 && parts[5].isNotEmpty) {
                      try {
                        await deleteDocument(parts[5]); // Old combined image
                      } catch (e) {
                        print('Could not delete old vehicle document: $e');
                      }
                    }
                    if (parts.length > 6 && parts[6].isNotEmpty) {
                      try {
                        await deleteDocument(parts[6]); // RC document
                      } catch (e) {
                        print('Could not delete old RC document: $e');
                      }
                    }
                    if (parts.length > 7 && parts[7].isNotEmpty) {
                      try {
                        await deleteDocument(parts[7]); // Front image
                      } catch (e) {
                        print('Could not delete old front image: $e');
                      }
                    }
                    if (parts.length > 8 && parts[8].isNotEmpty) {
                      try {
                        await deleteDocument(parts[8]); // Rear image
                      } catch (e) {
                        print('Could not delete old rear image: $e');
                      }
                    }
                    if (parts.length > 9 && parts[9].isNotEmpty) {
                      try {
                        await deleteDocument(parts[9]); // Side image
                      } catch (e) {
                        print('Could not delete old side image: $e');
                      }
                    }
                  }
                }
              }
              
              // Delete the old registration document
              await _databases.deleteDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              print('Deleted pending registration: $docId');
            } catch (deleteError) {
              print(
                'Could not delete pending registration $docId: $deleteError',
              );
            }
          }
        }

        // Try to delete old rejected registrations to free up space
        if (rejectedDocIds.isNotEmpty) {
          print(
            'Attempting to clean up ${rejectedDocIds.length} rejected registration(s)',
          );
          for (var docId in rejectedDocIds) {
            try {
              await _databases.deleteDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              print('Deleted rejected registration: $docId');
            } catch (deleteError) {
              print(
                'Could not delete rejected registration $docId: $deleteError',
              );
            }
          }
        }
      }

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
          v.maxPassWeight, // Now stores only the number without unit
          '', // documentId (empty, no longer using combined image)
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
        'vehicle_count': vehicleCount.toString(),
        'transporter_type': 'individual',
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

      // Retry logic for document creation in case of ID conflicts
      int maxRetries = 5;
      models.Document? doc;
      String? lastAttemptedId;

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          // Add a small random delay before each attempt to avoid ID collisions
          if (attempt > 0) {
            final randomDelay = 100 + (attempt * 200);
            await Future.delayed(Duration(milliseconds: randomDelay));
          }

          // On the last attempt, try using a custom ID based on userId + timestamp
          String documentId;
          if (attempt == maxRetries - 1) {
            documentId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
            print('Using custom document ID for final attempt: $documentId');
          } else {
            documentId = ID.unique();
          }
          lastAttemptedId = documentId;

          doc = await _databases.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.sellerRequestsCollectionId,
            documentId: documentId,
            data: data,
            permissions: [
              Permission.read(Role.user(userId)),
              Permission.update(Role.user(userId)),
              Permission.delete(Role.user(userId)),
            ],
          );
          print('Seller registration created successfully: ${doc.$id}');
          break; // Success, exit retry loop
        } on AppwriteException catch (retryError) {
          if (retryError.code == 409) {
            if (attempt < maxRetries - 1) {
              print(
                'Document ID conflict on attempt ${attempt + 1}, retrying... (${maxRetries - attempt - 1} attempts remaining)',
              );

              // Try to delete the conflicting document if it exists
              if (lastAttemptedId != null) {
                try {
                  await _databases.deleteDocument(
                    databaseId: AppwriteConfig.databaseId,
                    collectionId: AppwriteConfig.sellerRequestsCollectionId,
                    documentId: lastAttemptedId,
                  );
                  print('Deleted orphaned document: $lastAttemptedId');
                } catch (deleteError) {
                  print('Could not delete conflicting document: $deleteError');
                }
              }

              // Exponential backoff: 300ms, 600ms, 1200ms, 2400ms
              await Future.delayed(
                Duration(milliseconds: 300 * (1 << attempt)),
              );
              continue; // Retry with new ID
            } else {
              // Last attempt failed - provide detailed error
              print(
                'Failed to create document after $maxRetries attempts due to persistent ID conflicts',
              );
              print(
                'This may indicate orphaned documents in the database. Please contact support.',
              );
            }
          }
          rethrow; // If it's not a conflict or last attempt, throw
        }
      }

      if (doc == null) {
        throw 'Failed to create seller registration after $maxRetries attempts';
      }

      // Document created successfully, now convert to model
      // If this fails, don't delete documents since they're already linked to the document
      try {
        return _documentToSellerModel(doc);
      } catch (modelError) {
        print('Error converting document to model: $modelError');
        // Document exists in database, so don't delete uploaded documents
        // Just rethrow the error
        rethrow;
      }
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in createSellerRegistration: Code ${e.code}, Message: ${e.message}, Response: ${e.response}',
      );

      // Clean up uploaded documents on failure
      if (panDocumentId != null && panDocumentId.isNotEmpty) {
        try {
          await deleteDocument(panDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up PAN document: $cleanupError');
        }
      }
      if (licenseDocumentId != null && licenseDocumentId.isNotEmpty) {
        try {
          await deleteDocument(licenseDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up license document: $cleanupError');
        }
      }
      if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
        try {
          await deleteDocument(gstDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up GST document: $cleanupError');
        }
      }
          for (var vehicle in vehicles) {
            if (vehicle.documentId != null && vehicle.documentId!.isNotEmpty) {
              try {
                await deleteDocument(vehicle.documentId!);
              } catch (cleanupError) {
                print('Error cleaning up vehicle document: $cleanupError');
              }
            }
            if (vehicle.rcDocumentId != null && vehicle.rcDocumentId!.isNotEmpty) {
              try {
                await deleteDocument(vehicle.rcDocumentId!);
              } catch (cleanupError) {
                print('Error cleaning up RC document: $cleanupError');
              }
            }
            if (vehicle.frontImageId != null && vehicle.frontImageId!.isNotEmpty) {
              try {
                await deleteDocument(vehicle.frontImageId!);
              } catch (cleanupError) {
                print('Error cleaning up front image: $cleanupError');
              }
            }
            if (vehicle.rearImageId != null && vehicle.rearImageId!.isNotEmpty) {
              try {
                await deleteDocument(vehicle.rearImageId!);
              } catch (cleanupError) {
                print('Error cleaning up rear image: $cleanupError');
              }
            }
            if (vehicle.sideImageId != null && vehicle.sideImageId!.isNotEmpty) {
              try {
                await deleteDocument(vehicle.sideImageId!);
              } catch (cleanupError) {
                print('Error cleaning up side image: $cleanupError');
              }
            }
          }
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createSellerRegistration: ${e.toString()}');

      // Don't clean up documents if user already has a registration
      // (they may need these documents for their existing registration)
      final errorMessage = e.toString();
      final isExistingRegistrationError = errorMessage.contains('already have');

      if (!isExistingRegistrationError) {
        // Only clean up uploaded documents if it's not an "already registered" error
        if (panDocumentId != null && panDocumentId.isNotEmpty) {
          try {
            await deleteDocument(panDocumentId);
          } catch (cleanupError) {
            print('Error cleaning up PAN document: $cleanupError');
          }
        }
        if (licenseDocumentId != null && licenseDocumentId.isNotEmpty) {
          try {
            await deleteDocument(licenseDocumentId);
          } catch (cleanupError) {
            print('Error cleaning up license document: $cleanupError');
          }
        }
        if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
          try {
            await deleteDocument(gstDocumentId);
          } catch (cleanupError) {
            print('Error cleaning up GST document: $cleanupError');
          }
        }
        for (var vehicle in vehicles) {
          if (vehicle.documentId != null && vehicle.documentId!.isNotEmpty) {
            try {
              await deleteDocument(vehicle.documentId!);
            } catch (cleanupError) {
              print('Error cleaning up vehicle document: $cleanupError');
            }
          }
          if (vehicle.rcDocumentId != null &&
              vehicle.rcDocumentId!.isNotEmpty) {
            try {
              await deleteDocument(vehicle.rcDocumentId!);
            } catch (cleanupError) {
              print('Error cleaning up RC document: $cleanupError');
            }
          }
        }
      }

      throw e is String
          ? e
          : 'Failed to create seller registration: ${e.toString()}';
    }
  }

  Future<SellerModel> createBusinessRegistration({
    required String userId,
    required String companyName,
    required String contact,
    required String address,
    required String email,
    required String gstNo,
    String? gstDocumentId,
    required String panCardNo,
    String? panDocumentId,
    required String transportLicenseNo,
    String? transportLicenseDocumentId,
    String? shopPhotoId,
  }) async {
    try {
      print('Creating business registration for user: $userId');

      // First, check if there's already a pending or approved registration for this user
      final existingDocs = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );

      if (existingDocs.documents.isNotEmpty) {
        print(
          'Found ${existingDocs.documents.length} existing registration(s) for user',
        );

        List<String> rejectedDocIds = [];
        List<String> pendingDocIds = [];
        bool hasApproved = false;

        // Check status of all existing registrations
        for (var doc in existingDocs.documents) {
          final status = doc.data['status'] ?? '';
          if (status == 'approved') {
            hasApproved = true;
            print(
              'User already has an approved business registration with ID: ${doc.$id}',
            );
          } else if (status == 'pending') {
            pendingDocIds.add(doc.$id);
            print(
              'User has a pending business registration with ID: ${doc.$id} - will be replaced',
            );
          } else if (status == 'rejected') {
            rejectedDocIds.add(doc.$id);
          }
        }

        // Block if user has an approved registration
        if (hasApproved) {
          // Clean up the newly uploaded documents since we won't use them
          if (panDocumentId != null && panDocumentId.isNotEmpty) {
            try {
              await deleteDocument(panDocumentId);
            } catch (e) {
              print('Could not clean up PAN document: $e');
            }
          }
          if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
            try {
              await deleteDocument(gstDocumentId);
            } catch (e) {
              print('Could not clean up GST document: $e');
            }
          }
          if (transportLicenseDocumentId != null &&
              transportLicenseDocumentId.isNotEmpty) {
            try {
              await deleteDocument(transportLicenseDocumentId);
            } catch (e) {
              print('Could not clean up transport license document: $e');
            }
          }
          if (shopPhotoId != null && shopPhotoId.isNotEmpty) {
            try {
              await deleteDocument(shopPhotoId);
            } catch (e) {
              print('Could not clean up shop photo: $e');
            }
          }
          throw 'You already have an approved business registration. Cannot create a new one.';
        }

        // Delete old pending registrations to allow new submission
        if (pendingDocIds.isNotEmpty) {
          print(
            'Deleting ${pendingDocIds.length} pending business registration(s) to allow new submission',
          );
          for (var docId in pendingDocIds) {
            try {
              // Clean up old documents from the pending registration
              final oldDoc = await _databases.getDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              
              // Delete old documents
              final oldPanDocId = oldDoc.data['pan_document_id'] as String?;
              final oldLicenseDocId = oldDoc.data['license_document_id'] as String?;
              final oldGstDocId = oldDoc.data['gst_document_id'] as String?;
              final oldShopPhotoId = oldDoc.data['shop_photo_id'] as String?;
              
              if (oldPanDocId != null && oldPanDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldPanDocId);
                } catch (e) {
                  print('Could not delete old PAN document: $e');
                }
              }
              if (oldLicenseDocId != null && oldLicenseDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldLicenseDocId);
                } catch (e) {
                  print('Could not delete old license document: $e');
                }
              }
              if (oldGstDocId != null && oldGstDocId.isNotEmpty) {
                try {
                  await deleteDocument(oldGstDocId);
                } catch (e) {
                  print('Could not delete old GST document: $e');
                }
              }
              if (oldShopPhotoId != null && oldShopPhotoId.isNotEmpty) {
                try {
                  await deleteDocument(oldShopPhotoId);
                } catch (e) {
                  print('Could not delete old shop photo: $e');
                }
              }
              
              // Delete the old registration document
              await _databases.deleteDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              print('Deleted pending business registration: $docId');
            } catch (deleteError) {
              print(
                'Could not delete pending business registration $docId: $deleteError',
              );
            }
          }
        }

        // Try to delete old rejected registrations to free up space
        if (rejectedDocIds.isNotEmpty) {
          print(
            'Attempting to clean up ${rejectedDocIds.length} rejected registration(s)',
          );
          for (var docId in rejectedDocIds) {
            try {
              await _databases.deleteDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.sellerRequestsCollectionId,
                documentId: docId,
              );
              print('Deleted rejected registration: $docId');
            } catch (deleteError) {
              print(
                'Could not delete rejected registration $docId: $deleteError',
              );
            }
          }
        }
      }

      final username = _generateUsername(companyName);
      final password = _generatePassword();
      print(
        'Generated credentials - username: $username, password: ${password.replaceAll(RegExp(r'.'), '*')}',
      );

      final data = {
        'user_id': userId,
        'name': companyName,
        'address': address,
        'contact': contact,
        'email': email,
        'username': username,
        'password': password,
        'pan_card_no': panCardNo,
        'pan_document_id': panDocumentId ?? '',
        'driving_license_no': transportLicenseNo,
        'license_document_id': transportLicenseDocumentId ?? '',
        'gst_no': gstNo,
        'gst_document_id': gstDocumentId ?? '',
        'shop_photo_id': shopPhotoId ?? '',
        'selected_vehicle_types': [],
        'vehicles': [],
        'vehicle_count': '0',
        'transporter_type': 'business_company',
        'status': 'pending',
      };

      print('Business data: $data');

      // Retry logic for document creation in case of ID conflicts
      int maxRetries = 5;
      models.Document? doc;
      String? lastAttemptedId;

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          // Add a small random delay before each attempt to avoid ID collisions
          if (attempt > 0) {
            final randomDelay = 100 + (attempt * 200);
            await Future.delayed(Duration(milliseconds: randomDelay));
          }

          // On the last attempt, try using a custom ID based on userId + timestamp
          String documentId;
          if (attempt == maxRetries - 1) {
            documentId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
            print('Using custom document ID for final attempt: $documentId');
          } else {
            documentId = ID.unique();
          }
          lastAttemptedId = documentId;

          doc = await _databases.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.sellerRequestsCollectionId,
            documentId: documentId,
            data: data,
            permissions: [
              Permission.read(Role.user(userId)),
              Permission.update(Role.user(userId)),
              Permission.delete(Role.user(userId)),
            ],
          );
          print('Business registration created successfully: ${doc.$id}');
          break; // Success, exit retry loop
        } on AppwriteException catch (retryError) {
          if (retryError.code == 409) {
            if (attempt < maxRetries - 1) {
              print(
                'Document ID conflict on attempt ${attempt + 1}, retrying... (${maxRetries - attempt - 1} attempts remaining)',
              );

              // Try to delete the conflicting document if it exists
              if (lastAttemptedId != null) {
                try {
                  await _databases.deleteDocument(
                    databaseId: AppwriteConfig.databaseId,
                    collectionId: AppwriteConfig.sellerRequestsCollectionId,
                    documentId: lastAttemptedId,
                  );
                  print('Deleted orphaned document: $lastAttemptedId');
                } catch (deleteError) {
                  print('Could not delete conflicting document: $deleteError');
                }
              }

              // Exponential backoff: 300ms, 600ms, 1200ms, 2400ms
              await Future.delayed(
                Duration(milliseconds: 300 * (1 << attempt)),
              );
              continue; // Retry with new ID
            } else {
              // Last attempt failed - provide detailed error
              print(
                'Failed to create document after $maxRetries attempts due to persistent ID conflicts',
              );
              print(
                'This may indicate orphaned documents in the database. Please contact support.',
              );
            }
          }
          rethrow; // If it's not a conflict or last attempt, throw
        }
      }

      if (doc == null) {
        throw 'Failed to create business registration after $maxRetries attempts';
      }

      // Document created successfully, now convert to model
      // If this fails, don't delete documents since they're already linked to the document
      try {
        return _documentToSellerModel(doc);
      } catch (modelError) {
        print('Error converting document to model: $modelError');
        // Document exists in database, so don't delete uploaded documents
        // Just rethrow the error
        rethrow;
      }
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in createBusinessRegistration: Code ${e.code}, Message: ${e.message}, Response: ${e.response}',
      );

      // Clean up uploaded documents on failure
      if (panDocumentId != null && panDocumentId.isNotEmpty) {
        try {
          await deleteDocument(panDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up PAN document: $cleanupError');
        }
      }
      if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
        try {
          await deleteDocument(gstDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up GST document: $cleanupError');
        }
      }
      if (transportLicenseDocumentId != null &&
          transportLicenseDocumentId.isNotEmpty) {
        try {
          await deleteDocument(transportLicenseDocumentId);
        } catch (cleanupError) {
          print('Error cleaning up transport license document: $cleanupError');
        }
      }
      if (shopPhotoId != null && shopPhotoId.isNotEmpty) {
        try {
          await deleteDocument(shopPhotoId);
        } catch (cleanupError) {
          print('Error cleaning up shop photo: $cleanupError');
        }
      }
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createBusinessRegistration: ${e.toString()}');

      // Don't clean up documents if user already has a registration
      // (they may need these documents for their existing registration)
      final errorMessage = e.toString();
      final isExistingRegistrationError = errorMessage.contains('already have');

      if (!isExistingRegistrationError) {
        // Only clean up uploaded documents if it's not an "already registered" error
        if (panDocumentId != null && panDocumentId.isNotEmpty) {
          try {
            await deleteDocument(panDocumentId);
          } catch (cleanupError) {
            print('Error cleaning up PAN document: $cleanupError');
          }
        }
        if (gstDocumentId != null && gstDocumentId.isNotEmpty) {
          try {
            await deleteDocument(gstDocumentId);
          } catch (cleanupError) {
            print('Error cleaning up GST document: $cleanupError');
          }
        }
        if (transportLicenseDocumentId != null &&
            transportLicenseDocumentId.isNotEmpty) {
          try {
            await deleteDocument(transportLicenseDocumentId);
          } catch (cleanupError) {
            print(
              'Error cleaning up transport license document: $cleanupError',
            );
          }
        }
        if (shopPhotoId != null && shopPhotoId.isNotEmpty) {
          try {
            await deleteDocument(shopPhotoId);
          } catch (cleanupError) {
            print('Error cleaning up shop photo: $cleanupError');
          }
        }
      }

      throw e is String
          ? e
          : 'Failed to create business registration: ${e.toString()}';
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

  Future<Map<String, dynamic>?> getSellerByUserId(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );
      if (result.documents.isEmpty) {
        return null;
      }
      return result.documents.first.data;
    } catch (e) {
      print('Error getting seller by userId: $e');
      return null;
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

  Future<Map<String, dynamic>?> getSellerCredentials(String userId) async {
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
      final transporterType = doc.data['transporter_type'] as String?;
      final vehicles = doc.data['vehicles'];
      final vehicleCount = _parseVehicleCount(doc.data['vehicle_count']);
      print(
        'Fetched - username: $username, email: $email, transporter_type: $transporterType, password: ${password?.replaceAll(RegExp(r'.'), '*')}',
      );
      if (username != null && password != null && email != null) {
        print(
          'Returning credentials - username: $username, email: $email, transporter_type: $transporterType, vehicles: $vehicles',
        );
        return {
          'username': username,
          'password': password,
          'email': email,
          'transporter_type': transporterType ?? 'individual',
          'vehicles': vehicles ?? [],
          'vehicle_count': vehicleCount.toString(),
        };
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
      vehicleCount: _parseVehicleCount(doc.data['vehicle_count']),
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

  /// Updates the seller password in the seller_request table by user_id
  /// This should be called AFTER the Appwrite account password has been updated via recovery
  Future<bool> updateSellerPasswordByUserId({
    required String userId,
    required String newPassword,
  }) async {
    try {
      print('Updating seller password for user_id: $userId');

      // Find seller document by user_id
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('user_id', userId)],
      );

      if (result.documents.isEmpty) {
        throw 'Seller record not found for user_id: $userId';
      }

      final docId = result.documents.first.$id;

      // Update the password in seller_request table
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        documentId: docId,
        data: {'password': newPassword},
      );

      print('✅ Seller password updated successfully in database');
      return true;
    } on AppwriteException catch (e) {
      print('❌ Appwrite error updating seller password: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('❌ Error updating seller password: ${e.toString()}');
      throw 'Failed to update seller password: ${e.toString()}';
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

  /// Search for seller email by phone number in seller_request table
  Future<String?> getEmailByPhoneNumber(String phoneNumber) async {
    try {
      print('🔍 Searching for email by phone: $phoneNumber');
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.sellerRequestsCollectionId,
        queries: [Query.equal('contact', phoneNumber), Query.limit(1)],
      );
      if (result.documents.isEmpty) {
        print('❌ No seller found with phone: $phoneNumber');
        return null;
      }
      final email = result.documents.first.data['email'] as String?;
      print('✅ Found email: $email');
      return email;
    } on AppwriteException catch (e) {
      print('Appwrite error searching by phone: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error searching by phone: ${e.toString()}');
      throw 'Failed to search seller: ${e.toString()}';
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

  int _parseVehicleCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
