import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/phone_auth_service.dart';
enum PhoneAuthStatus {
  initial,
  sendingOTP,
  otpSent,
  verifyingOTP,
  verified,
  error,
}
class PhoneAuthProvider with ChangeNotifier {
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  PhoneAuthStatus _status = PhoneAuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  String? _userId; // Store userId after sending OTP
  String? _phoneNumber; // Store phone number
  PhoneAuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  String? get phoneNumber => _phoneNumber;
  bool get isLoading => _status == PhoneAuthStatus.sendingOTP || 
                        _status == PhoneAuthStatus.verifyingOTP;
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _status = PhoneAuthStatus.sendingOTP;
      _errorMessage = null;
      _phoneNumber = phoneNumber;
      notifyListeners();
      _userId = await _phoneAuthService.sendOTP(phoneNumber: phoneNumber);
      _status = PhoneAuthStatus.otpSent;
      notifyListeners();
      return true;
    } catch (e) {
      _status = PhoneAuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> verifyOTP(String otp) async {
    if (_userId == null) {
      _errorMessage = 'Please send OTP first';
      _status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
    try {
      _status = PhoneAuthStatus.verifyingOTP;
      _errorMessage = null;
      notifyListeners();
      _user = await _phoneAuthService.verifyOTP(
        userId: _userId!,
        otp: otp,
      );
      _status = PhoneAuthStatus.verified;
      notifyListeners();
      return true;
    } catch (e) {
      _status = PhoneAuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
  Future<bool> resendOTP() async {
    if (_phoneNumber == null) {
      _errorMessage = 'Phone number not found';
      _status = PhoneAuthStatus.error;
      notifyListeners();
      return false;
    }
    return await sendOTP(_phoneNumber!);
  }
  Future<void> logout() async {
    try {
      await _phoneAuthService.logout();
      _user = null;
      _userId = null;
      _phoneNumber = null;
      _status = PhoneAuthStatus.initial;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  void reset() {
    _status = PhoneAuthStatus.initial;
    _userId = null;
    _phoneNumber = null;
    _errorMessage = null;
    notifyListeners();
  }
  Future<bool> checkAuthStatus() async {
    try {
      final isLoggedIn = await _phoneAuthService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _phoneAuthService.getCurrentUser();
        _status = PhoneAuthStatus.verified;
        notifyListeners();
      }
      return isLoggedIn;
    } catch (e) {
      return false;
    }
  }
}
