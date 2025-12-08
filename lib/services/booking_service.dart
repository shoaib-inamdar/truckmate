import 'dart:io';
import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/booking_model.dart';
import '../services/appwrite_service.dart';

class BookingService {
  final _appwriteService = AppwriteService();

  late final Databases _databases;
  late final Storage _storage;
  late final Account _account;

  BookingService() {
    _databases = _appwriteService.databases;
    _storage = Storage(_appwriteService.client);
    _account = _appwriteService.account;
  }

  // Generate unique 6-character alphanumeric booking ID
  String _generateBookingId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  // Check if booking ID already exists
  Future<bool> _bookingIdExists(String bookingId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        queries: [Query.equal('booking_id', bookingId)],
      );
      return result.documents.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Generate unique booking ID
  Future<String> _generateUniqueBookingId() async {
    String bookingId;
    bool exists;

    do {
      bookingId = _generateBookingId();
      exists = await _bookingIdExists(bookingId);
    } while (exists);

    return bookingId;
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

  // Upload payment screenshot
  Future<String?> uploadPaymentScreenshot(File file, String bookingId) async {
    try {
      print('Uploading payment screenshot for booking: $bookingId');

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw 'File size exceeds 5MB limit';
      }

      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw 'User not authenticated';
      }

      final fileName =
          'payment_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await _storage.createFile(
        bucketId: AppwriteConfig.paymentScreenshotsBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      print('Payment screenshot uploaded: ${result.$id}');
      return result.$id;
    } on AppwriteException catch (e) {
      print('Appwrite error uploading payment: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error uploading payment: ${e.toString()}');
      throw 'Failed to upload payment screenshot: ${e.toString()}';
    }
  }

  // Confirm payment
  Future<void> confirmPayment({
    required String bookingId,
    required File paymentScreenshot,
  }) async {
    try {
      print('Confirming payment for booking: $bookingId');

      // Upload payment screenshot
      final paymentFileId = await uploadPaymentScreenshot(
        paymentScreenshot,
        bookingId,
      );

      if (paymentFileId == null) {
        throw 'Failed to upload payment screenshot';
      }

      // Update booking with payment info
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {
          'payment_screenshot_id': paymentFileId,
          'payment_status': 'submitted',
          'payment_date': DateTime.now().toIso8601String(),
        },
      );

      print('Payment confirmed successfully');
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to confirm payment: ${e.toString()}';
    }
  }

  // Create a new booking
  Future<BookingModel> createBooking({
    required String userId,
    required String fullName,
    required String phoneNumber,
    required String address,
    required String date,
    required String loadDescription,
    required String startLocation,
    required String destination,
    required String bidAmount,
    required String vehicleType,
  }) async {
    try {
      print('Creating booking for user: $userId');

      final bookingId = await _generateUniqueBookingId();
      print('Generated booking ID: $bookingId');

      final data = {
        'booking_id': bookingId,
        'user_id': userId,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'address': address,
        'date': date,
        'load_description': loadDescription,
        'start_location': startLocation,
        'destination': destination,
        'bid_amount': bidAmount,
        // Store single required vehicle type (Appwrite schema is `vehicle_type`)
        'vehicle_type': vehicleType,
        'status': 'pending',
        'payment_status': 'pending',
      };

      print('Booking data: $data');

      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: data,
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      print('Booking created successfully: ${doc.$id}');
      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in createBooking: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in createBooking: ${e.toString()}');
      throw 'Failed to create booking: ${e.toString()}';
    }
  }

  // Get booking by ID
  Future<BookingModel> getBooking(String bookingId) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
      );

      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to get booking: ${e.toString()}';
    }
  }

  // Get all bookings for a user
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      print('Getting bookings for user: $userId');

      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc(r'$createdAt'),
        ],
      );

      print('Found ${result.documents.length} bookings');

      return result.documents
          .map((doc) => _documentToBookingModel(doc))
          .toList();
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in getUserBookings: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in getUserBookings: ${e.toString()}');
      throw 'Failed to get bookings: ${e.toString()}';
    }
  }

  // Get bookings assigned to a seller
  Future<List<BookingModel>> getSellerAssignedBookings(String sellerId) async {
    try {
      print('Getting bookings assigned to seller: $sellerId');

      // First try to fetch bookings explicitly assigned to this seller
      final assignedResult = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        queries: [
          Query.equal('assigned_to', sellerId),
          Query.orderDesc(r'$createdAt'),
        ],
      );

      if (assignedResult.documents.isNotEmpty) {
        print('Found ${assignedResult.documents.length} assigned bookings');
        return assignedResult.documents
            .map((doc) => _documentToBookingModel(doc))
            .toList();
      }

      // If none are assigned yet, fall back to pending bookings so seller sees open jobs
      print(
        'No assigned bookings found. Loading pending bookings as fallback.',
      );

      final pendingResult = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        queries: [
          Query.equal('status', 'pending'),
          Query.orderDesc(r'$createdAt'),
        ],
      );

      print('Found ${pendingResult.documents.length} pending bookings');

      return pendingResult.documents
          .map((doc) => _documentToBookingModel(doc))
          .toList();
    } on AppwriteException catch (e) {
      print(
        'Appwrite error in getSellerAssignedBookings: Code ${e.code}, Message: ${e.message}',
      );
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error in getSellerAssignedBookings: ${e.toString()}');
      throw 'Failed to get assigned bookings: ${e.toString()}';
    }
  }

  // Update booking status
  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {'status': status},
      );

      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to update booking: ${e.toString()}';
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to delete booking: ${e.toString()}';
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

  // Convert Appwrite document to BookingModel
  BookingModel _documentToBookingModel(models.Document doc) {
    return BookingModel(
      id: doc.$id,
      bookingId: doc.data['booking_id'] ?? '',
      userId: doc.data['user_id'] ?? '',
      fullName: doc.data['full_name'] ?? '',
      phoneNumber: doc.data['phone_number'] ?? '',
      address: doc.data['address'] ?? '',
      date: doc.data['date'] ?? '',
      loadDescription: doc.data['load_description'] ?? '',
      startLocation: doc.data['start_location'] ?? '',
      destination: doc.data['destination'] ?? '',
      bidAmount: doc.data['bid_amount'] ?? '',
      vehicleType: doc.data['vehicle_type'] ?? '',
      createdAt: DateTime.parse(doc.$createdAt),
      status: doc.data['status'] ?? 'pending',
      assignedTo: doc.data['assigned_to'],
      paymentStatus: doc.data['payment_status'],
    );
  }

  // Handle Appwrite exceptions
  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Unauthorized. Please login again.';
      case 404:
        return 'Booking not found.';
      case 409:
        return 'Booking already exists.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
