import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../config/appwrite_config.dart';
import '../models/booking_model.dart';
import '../services/appwrite_service.dart';

class BookingService {
  final _appwriteService = AppwriteService();

  late final Databases _databases;
  late final Account _account;

  BookingService() {
    _databases = _appwriteService.databases;
    _account = _appwriteService.account;
  }

  // Generate unique booking ID with format CBK-XXXXXXXXXX (10 random chars)
  String _generateBookingId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final randomString = String.fromCharCodes(
      Iterable.generate(
        10,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    return 'CBK-$randomString';
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

      // Generate unique booking ID
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
        'vehicle_type': vehicleType,
        'status': 'pending',
      };

      print('Booking data: $data');

      // Create document with booking ID as document ID
      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.bookingsCollectionId,
        documentId: bookingId, // Use booking ID as document ID
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
          Query.orderDesc('\$createdAt'),
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
