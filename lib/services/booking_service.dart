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

  Future<String> _generateUniqueBookingId() async {
    String bookingId;
    bool exists;
    do {
      bookingId = _generateBookingId();
      exists = await _bookingIdExists(bookingId);
    } while (exists);
    return bookingId;
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final user = await _account.get();
      return user.$id;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadPaymentScreenshot(File file, String bookingId) async {
    try {
      print('Uploading payment screenshot for booking: $bookingId');
      final fileSize = await file.length();
      if (fileSize > 1 * 1024 * 1024) {
        throw 'File size exceeds 1MB limit';
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

  Future<void> confirmPayment({
    required String bookingId,
    required File paymentScreenshot,
    required String transactionId,
  }) async {
    try {
      print('Confirming payment for booking: $bookingId');
      final paymentFileId = await uploadPaymentScreenshot(
        paymentScreenshot,
        bookingId,
      );
      if (paymentFileId == null) {
        throw 'Failed to upload payment screenshot';
      }
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {
          'payment_screenshot_id': paymentFileId,
          'payment_status': 'submitted',
          'payment_date': DateTime.now().toIso8601String(),
          'payment_transaction_id': transactionId,
        },
      );
      print('Payment confirmed successfully');
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to confirm payment: ${e.toString()}';
    }
  }

  Future<BookingModel> createBooking({
    required String userId,
    required String fullName,
    required String phoneNumber,
    required String address,
    required String date,
    required String load,
    required String loadDescription,
    required String startLocation,
    required String destination,
    String? fixedLocation,
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
        'load': load,
        'load_description': loadDescription,
        'start_location': startLocation,
        'destination': destination,
        'fixed_location': fixedLocation,
        'bid_amount': bidAmount,
        'vehicle_type': vehicleType,
        'status': 'pending',
        'payment_status': 'pending',
        'booking_status': 'pending',
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

  Future<List<BookingModel>> getSellerAssignedBookings(String sellerId) async {
    try {
      print('Getting bookings assigned to seller: $sellerId');
      final assignedResult = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        queries: [
          Query.equal('assigned_to', sellerId),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      print('Found ${assignedResult.documents.length} assigned bookings');
      return assignedResult.documents
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

  /// Assign a booking to a seller
  /// This updates the assigned_to field to the seller's user ID
  Future<BookingModel> assignBookingToSeller({
    required String bookingId,
    required String sellerId,
  }) async {
    try {
      print('Assigning booking $bookingId to seller: $sellerId');
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {'assigned_to': sellerId, 'booking_status': 'accepted'},
      );
      print('Booking assigned to seller successfully');
      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      print('Appwrite error assigning booking: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error assigning booking: ${e.toString()}');
      throw 'Failed to assign booking: ${e.toString()}';
    }
  }

  /// Start shipping - updates booking status to in_transit
  /// This should be called when transporter clicks "Start Shipping" button
  Future<BookingModel> startShipping({required String bookingId}) async {
    try {
      print('Starting shipping for booking: $bookingId');
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {
          'booking_status': 'in_transit',
          'journey_state': 'shipping_done',
        },
      );
      print('Shipping started successfully');
      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      print('Appwrite error starting shipping: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error starting shipping: ${e.toString()}');
      throw 'Failed to start shipping: ${e.toString()}';
    }
  }

  /// Complete journey - verifies completion OTP and updates journey_state
  /// This should be called when transporter enters the completion OTP
  Future<BookingModel> completeJourney({
    required String bookingId,
    required String completionOtp,
  }) async {
    try {
      print('Completing journey for booking: $bookingId');

      // Get the booking to find the customer's user_id
      final booking = await getBooking(bookingId);
      final userId = booking.userId;

      print('Fetching completion OTP for user: $userId');

      // Get the user's completion_otp from user_data_collection
      String? storedOtp;
      try {
        final userResult = await _databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.userDataCollectionId,
          queries: [Query.equal('user_id', userId), Query.limit(1)],
        );

        if (userResult.documents.isNotEmpty) {
          storedOtp = userResult.documents.first.data['completion_otp'];
          print('Stored OTP from user_data_collection: $storedOtp');
        }
      } catch (e) {
        print(
          'Warning: failed to read completion_otp from user_data_collection: $e',
        );
      }

      // Fallback: check booking document itself
      if (storedOtp == null) {
        try {
          final bookingDoc = await _databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.bookingsCollectionId,
            documentId: bookingId,
          );
          storedOtp = bookingDoc.data['completion_otp'];
          print('Stored OTP from booking document: $storedOtp');
        } catch (e) {
          print(
            'Warning: failed to read completion_otp from booking document: $e',
          );
        }
      }

      print('Entered OTP: $completionOtp');

      // Verify OTP
      if (storedOtp == null || storedOtp.toString() != completionOtp.trim()) {
        throw 'Invalid completion OTP. Please check and try again.';
      }

      // Update journey_state to journey_completed
      final doc = await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId,
        data: {
          'journey_state': 'journey_completed',
          'booking_status': 'delivered',
        },
      );

      print('Journey completed successfully');
      return _documentToBookingModel(doc);
    } on AppwriteException catch (e) {
      print('Appwrite error completing journey: ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('Error completing journey: ${e.toString()}');
      rethrow;
    }
  }

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

  Future<bool> isUserAuthenticated() async {
    try {
      await _account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  BookingModel _documentToBookingModel(models.Document doc) {
    return BookingModel(
      id: doc.$id,
      bookingId: doc.data['booking_id'] ?? '',
      userId: doc.data['user_id'] ?? '',
      fullName: doc.data['full_name'] ?? '',
      phoneNumber: doc.data['phone_number'] ?? '',
      address: doc.data['address'] ?? '',
      date: doc.data['date'] ?? '',
      load: doc.data['load'] ?? '',
      loadDescription: doc.data['load_description'] ?? '',
      startLocation: doc.data['start_location'] ?? '',
      destination: doc.data['destination'] ?? '',
      fixedLocation: doc.data['fixed_location'] ?? '',
      bidAmount: doc.data['bid_amount'] ?? '',
      vehicleType: doc.data['vehicle_type'] ?? '',
      createdAt: DateTime.parse(doc.$createdAt),
      status: doc.data['status'] ?? 'pending',
      assignedTo: doc.data['assigned_to'],
      paymentStatus: doc.data['payment_status'],
      bookingStatus: doc.data['booking_status'],
      paymentTransactionId: doc.data['payment_transaction_id'],
      journeyState: doc.data['journey_state'],
      completionOtp: doc.data['completion_otp'],
    );
  }

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
