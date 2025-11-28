import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/email_otp_service.dart';

enum EmailOTPStatus {
  initial,
  sendingOTP,
  otpSent,
  verifyingOTP,
  verified,
  error,
}

class EmailOTPProvider with ChangeNotifier {
  final EmailOTPService _emailOTPService = EmailOTPService();
  
  EmailOTPStatus _status = EmailOTPStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  String? _userId;
  String? _email;

  EmailOTPStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  String? get email => _email;
  bool get isLoading => _status == EmailOTPStatus.sendingOTP || 
                        _status == EmailOTPStatus.verifyingOTP;

  // Send OTP to email
  Future<bool> sendEmailOTP(String email) async {
    try {
      _status = EmailOTPStatus.sendingOTP;
      _errorMessage = null;
      _email = email;
      notifyListeners();

      _userId = await _emailOTPService.sendEmailOTP(email: email);

      _status = EmailOTPStatus.otpSent;
      notifyListeners();
      return true;
    } catch (e) {
      _status = EmailOTPStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Verify Email OTP
  Future<bool> verifyEmailOTP(String otp) async {
    if (_userId == null) {
      _errorMessage = 'Please send OTP first';
      _status = EmailOTPStatus.error;
      notifyListeners();
      return false;
    }

    try {
      _status = EmailOTPStatus.verifyingOTP;
      _errorMessage = null;
      notifyListeners();

      _user = await _emailOTPService.verifyEmailOTP(
        userId: _userId!,
        secret: otp,
      );

      _status = EmailOTPStatus.verified;
      notifyListeners();
      return true;
    } catch (e) {
      _status = EmailOTPStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Resend OTP
  Future<bool> resendOTP() async {
    if (_email == null) {
      _errorMessage = 'Email not found';
      _status = EmailOTPStatus.error;
      notifyListeners();
      return false;
    }

    return await sendEmailOTP(_email!);
  }

  // Logout
  Future<void> logout() async {
    try {
      await _emailOTPService.logout();
      _user = null;
      _userId = null;
      _email = null;
      _status = EmailOTPStatus.initial;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
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
    _status = EmailOTPStatus.initial;
    _userId = null;
    _email = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Check auth status
  Future<bool> checkAuthStatus() async {
    try {
      final isLoggedIn = await _emailOTPService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _emailOTPService.getCurrentUser();
        _status = EmailOTPStatus.verified;
        notifyListeners();
      }
      return isLoggedIn;
    } catch (e) {
      return false;
    }
  }
}