import 'dart:io';
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
  Future<bool> createBooking({
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
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();
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
        load: load,
        loadDescription: loadDescription,
        startLocation: startLocation,
        destination: destination,
        fixedLocation: fixedLocation,
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

  Future<void> loadSellerAssignedBookings(String sellerId) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();
      _bookings = await _bookingService.getSellerAssignedBookings(sellerId);
      _status = BookingStatus.success;
      notifyListeners();
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

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

  Future<bool> confirmPayment({
    required String bookingId,
    required File paymentScreenshot,
    required String transactionId,
  }) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();
      await _bookingService.confirmPayment(
        bookingId: bookingId,
        paymentScreenshot: paymentScreenshot,
        transactionId: transactionId,
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

  /// Assign booking to seller
  /// This should be called when seller accepts a booking
  Future<BookingModel?> assignBookingToSeller({
    required String bookingId,
    required String sellerId,
  }) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _currentBooking = await _bookingService.assignBookingToSeller(
        bookingId: bookingId,
        sellerId: sellerId,
      );

      // Update in the bookings list if present
      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _currentBooking!;
      }

      _status = BookingStatus.success;
      notifyListeners();
      return _currentBooking;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Start shipping - updates booking to in_transit and returns updated booking
  /// This should be called when transporter clicks "Start Shipping" button
  Future<BookingModel?> startShipping({required String bookingId}) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _currentBooking = await _bookingService.startShipping(
        bookingId: bookingId,
      );

      // Update in the bookings list if present
      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _currentBooking!;
      }

      _status = BookingStatus.success;
      notifyListeners();
      return _currentBooking;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Complete journey - verifies completion OTP and updates journey_state
  /// This should be called when transporter enters the completion OTP
  Future<BookingModel?> completeJourney({
    required String bookingId,
    required String completionOtp,
  }) async {
    try {
      _status = BookingStatus.loading;
      _errorMessage = null;
      notifyListeners();

      _currentBooking = await _bookingService.completeJourney(
        bookingId: bookingId,
        completionOtp: completionOtp,
      );

      // Update in the bookings list if present
      final index = _bookings.indexWhere((b) => b.bookingId == bookingId);
      if (index != -1) {
        _bookings[index] = _currentBooking!;
      }

      _status = BookingStatus.success;
      notifyListeners();
      return _currentBooking;
    } catch (e) {
      _status = BookingStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteBooking(String bookingId) async {
    try {
      _status = BookingStatus.loading;
      notifyListeners();
      await _bookingService.deleteBooking(bookingId);
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _status = BookingStatus.initial;
    _bookings = [];
    _currentBooking = null;
    _errorMessage = null;
    notifyListeners();
  }
}
