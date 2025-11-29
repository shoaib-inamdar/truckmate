import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

enum BookingStatus { initial, loading, success, error }

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();

  BookingStatus _status = BookingStatus.initial;
  List<BookingModel> _bookings = [];
  BookingModel? _currentBooking;
  String? _errorMessage;

  BookingStatus get status => _status;
  List<BookingModel> get bookings => _bookings;
  BookingModel? get currentBooking => _currentBooking;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == BookingStatus.loading;

  // Create a new booking
  Future<bool> createBooking({
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
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Check if user is authenticated
      final isAuthenticated = await _bookingService.isUserAuthenticated();
      if (!isAuthenticated) {
        throw 'User not authenticated. Please login again.';
      }

      _currentBooking = await _bookingService.createBooking(
        userId: userId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        address: address,
        date: date,
        loadDescription: loadDescription,
        startLocation: startLocation,
        destination: destination,
        bidAmount: bidAmount,
        vehicleType: vehicleType,
      );

      _status = BookingStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get user bookings
  Future<void> loadUserBookings(String userId) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _bookings = await _bookingService.getUserBookings(userId);

      _status = BookingStatus.success;
      notifyListeners();
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Get booking by ID
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      _status = BookingStatus.loading;
      notifyListeners();

      final booking = await _bookingService.getBooking(bookingId);
      _currentBooking = booking;

      _status = BookingStatus.success;
      notifyListeners();
      return booking;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      _status = BookingStatus.loading;
      notifyListeners();

      _currentBooking = await _bookingService.updateBookingStatus(
        bookingId: bookingId,
        status: status,
      );

      // Update in the list if exists
      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _currentBooking!;
      }

      _status = BookingStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete booking
  Future<bool> deleteBooking(String bookingId) async {
    try {
      _status = BookingStatus.loading;
      notifyListeners();

      await _bookingService.deleteBooking(bookingId);

      // Remove from list
      _bookings.removeWhere((b) => b.bookingId == bookingId);

      _status = BookingStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset
  void reset() {
    _status = BookingStatus.initial;
    _bookings = [];
    _currentBooking = null;
    _errorMessage = null;
    notifyListeners();
  }
}
