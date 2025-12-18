import 'package:appwrite/appwrite.dart';
import 'package:truckmate/config/appwrite_config.dart';
import 'package:truckmate/services/appwrite_service.dart';

class VehicleRequestService {
  final _appwriteService = AppwriteService();
  late final Databases _databases;

  VehicleRequestService() {
    _databases = _appwriteService.databases;
  }

  Future<Map<String, dynamic>> createVehicleRequest({
    required String userId,
    required String appwriteUserId,
    required List<String> vehicles, // Changed from List<Map<String, dynamic>>
  }) async {
    try {
      print('Creating vehicle request for user: $userId');
      print('Vehicle count: ${vehicles.length}');

      final data = {
        'user_id': userId,
        'vehicles': vehicles,
        'status': 'pending',
        'request_type': 'add_vehicle',
      };

      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'vehicle_request',
        documentId: ID.unique(),
        data: data,
        permissions: [
          Permission.read(Role.user(appwriteUserId)),
          Permission.update(Role.user(appwriteUserId)),
          Permission.delete(Role.user(appwriteUserId)),
        ],
      );

      print('Vehicle request created successfully: ${doc.$id}');
      return doc.data;
    } catch (e) {
      print('Error creating vehicle request: $e');
      throw 'Failed to create vehicle request: ${e.toString()}';
    }
  }

  Future<Map<String, dynamic>?> getPendingVehicleRequest(String userId) async {
    try {
      final docs = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'vehicle_request',
        queries: [
          Query.equal('user_id', userId),
          Query.equal('request_type', 'add_vehicle'),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );

      if (docs.documents.isNotEmpty) {
        return docs.documents.first.data;
      }
      return null;
    } catch (e) {
      print('Error fetching vehicle request: $e');
      return null;
    }
  }

  Future<void> deleteVehicleRequest(String documentId, String userId) async {
    try {
      await _databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'vehicle_request',
        documentId: documentId,
      );
      print('Vehicle request deleted: $documentId');
    } catch (e) {
      print('Error deleting vehicle request: $e');
      throw 'Failed to delete request: ${e.toString()}';
    }
  }
}
