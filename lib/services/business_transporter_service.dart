import 'package:appwrite/appwrite.dart';
import 'package:truckmate/config/appwrite_config.dart';
import 'package:truckmate/models/business_transporter_model.dart';
import 'package:truckmate/services/appwrite_service.dart';

class BusinessTransporterService {
  final _appwriteService = AppwriteService();
  late final Databases _databases;

  BusinessTransporterService() {
    _databases = _appwriteService.databases;
  }

  Future<BusinessTransporterModel> assignDriver({
    required String driverName,
    required String vehicleNumber,
    required String contact,
    required String userId,
    required String bookingId,
  }) async {
    try {
      print('Assigning driver for booking: $bookingId');

      final data = {
        'driver_name': driverName,
        'vehicle_number': vehicleNumber,
        'contact': contact,
        'user_id': userId,
        'booking_id': bookingId,
      };

      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.businessTransporterCollectionId,
        documentId: ID.unique(),
        data: data,
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      print('Driver assigned successfully: ${doc.$id}');
      return BusinessTransporterModel.fromJson(doc.data);
    } catch (e) {
      print('Error assigning driver: $e');
      throw 'Failed to assign driver: ${e.toString()}';
    }
  }

  Future<BusinessTransporterModel?> getDriverByBookingId(
    String bookingId,
  ) async {
    try {
      print('Fetching driver for booking: $bookingId');

      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.businessTransporterCollectionId,
        queries: [Query.equal('booking_id', bookingId), Query.limit(1)],
      );

      if (result.documents.isEmpty) {
        print('No driver found for booking: $bookingId');
        return null;
      }

      return BusinessTransporterModel.fromJson(result.documents.first.data);
    } catch (e) {
      print('Error fetching driver: $e');
      return null;
    }
  }
}
