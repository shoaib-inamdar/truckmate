import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/seller_model.dart';
import '../services/seller_service.dart';

enum SellerStatus { initial, loading, success, error }

class SellerProvider with ChangeNotifier {
  final SellerService _sellerService = SellerService();
  SellerStatus _status = SellerStatus.initial;
  SellerModel? _sellerRegistration;
  String? _errorMessage;
  SellerStatus get status => _status;
  SellerModel? get sellerRegistration => _sellerRegistration;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SellerStatus.loading;
  Future<String?> uploadDocument(File file, String fileName) async {
    try {
      return await _sellerService.uploadDocument(file, fileName);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createSellerRegistration({
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
      _status = SellerStatus.loading;
      _errorMessage = null;
      notifyListeners();
      final isAuthenticated = await _sellerService.isUserAuthenticated();
      if (!isAuthenticated) {
        throw 'User not authenticated. Please login again.';
      }
      _sellerRegistration = await _sellerService.createSellerRegistration(
        userId: userId,
        name: name,
        address: address,
        contact: contact,
        email: email,
        panCardNo: panCardNo,
        panDocumentId: panDocumentId,
        drivingLicenseNo: drivingLicenseNo,
        licenseDocumentId: licenseDocumentId,
        gstNo: gstNo,
        gstDocumentId: gstDocumentId,
        selectedVehicleTypes: selectedVehicleTypes,
        vehicles: vehicles,
      );
      _status = SellerStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SellerStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSellerRegistration(String userId) async {
    try {
      _status = SellerStatus.loading;
      _errorMessage = null;
      notifyListeners();
      _sellerRegistration = await _sellerService.getSellerRegistration(userId);
      _status = SellerStatus.success;
      notifyListeners();
    } catch (e) {
      _status = SellerStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _status = SellerStatus.initial;
    _sellerRegistration = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> setAvailability({
    required String userId,
    required String availability,
    String? returnLocation,
  }) async {
    try {
      print(
        '🟠 SellerProvider.setAvailability: Called with userId=$userId, availability=$availability, returnLocation=$returnLocation',
      );
      _status = SellerStatus.loading;
      notifyListeners();
      print(
        '🟠 SellerProvider.setAvailability: Status set to loading, calling service...',
      );
      final ok = await _sellerService.updateAvailabilityByUserId(
        userId: userId,
        availability: availability,
        returnLocation: returnLocation,
      );
      print('🟠 SellerProvider.setAvailability: Service returned ok=$ok');
      if (ok) {
        print(
          '🟠 SellerProvider.setAvailability: Update successful, refreshing seller registration...',
        );
        // Refresh local registration
        _sellerRegistration = await _sellerService.getSellerRegistration(
          userId,
        );
        print(
          '🟠 SellerProvider.setAvailability: Seller registration refreshed, new availability=${_sellerRegistration?.availability}',
        );
        _status = SellerStatus.success;
        notifyListeners();
        print('🟠 SellerProvider.setAvailability: Status set to success');
        return true;
      }
      _status = SellerStatus.error;
      _errorMessage = 'Failed to update availability';
      notifyListeners();
      print('❌ SellerProvider.setAvailability: Update failed');
      return false;
    } catch (e) {
      print('❌ SellerProvider.setAvailability: Exception caught: $e');
      _status = SellerStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
