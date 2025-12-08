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

  // Upload document
  Future<String?> uploadDocument(File file, String fileName) async {
    try {
      return await _sellerService.uploadDocument(file, fileName);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Create seller registration
  Future<bool> createSellerRegistration({
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
      _status = SellerStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Check if user is authenticated
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
        rcBookNo: rcBookNo,
        rcDocumentId: rcDocumentId,
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

  // Get seller registration
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

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset
  void reset() {
    _status = SellerStatus.initial;
    _sellerRegistration = null;
    _errorMessage = null;
    notifyListeners();
  }
}
