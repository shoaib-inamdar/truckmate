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
  bool get isLoading =>
      _status == EmailOTPStatus.sendingOTP ||
      _status == EmailOTPStatus.verifyingOTP;
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

  /// Set userId and email directly (used for forgot password flow)
  void setUserIdAndEmail(String userId, String email) {
    print('Setting userId: $userId, email: $email');
    _userId = userId;
    _email = email;
    _status = EmailOTPStatus.otpSent;
    notifyListeners();
  }

  Future<bool> verifyEmailOTP(String otp) async {
    print('=== PROVIDER: Verify Email OTP ===');
    print('OTP received: $otp');
    print('Stored userId: $_userId');
    print('Stored email: $_email');
    if (_userId == null) {
      print('ERROR: userId is null!');
      _errorMessage = 'Please send OTP first';
      _status = EmailOTPStatus.error;
      notifyListeners();
      return false;
    }
    try {
      print('Setting status to verifying...');
      _status = EmailOTPStatus.verifyingOTP;
      _errorMessage = null;
      notifyListeners();
      print('Calling email OTP service...');
      _user = await _emailOTPService.verifyEmailOTP(
        userId: _userId!,
        secret: otp,
      );
      print('Verification successful!');
      print('User: ${_user?.email}');
      _status = EmailOTPStatus.verified;
      notifyListeners();
      print('=== END PROVIDER ===');
      return true;
    } catch (e) {
      print('ERROR in provider: ${e.toString()}');
      _status = EmailOTPStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      print('=== END PROVIDER (ERROR) ===');
      return false;
    }
  }

  Future<bool> resendOTP() async {
    if (_email == null) {
      _errorMessage = 'Email not found';
      _status = EmailOTPStatus.error;
      notifyListeners();
      return false;
    }
    return await sendEmailOTP(_email!);
  }

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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _status = EmailOTPStatus.initial;
    _userId = null;
    _email = null;
    _errorMessage = null;
    notifyListeners();
  }

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
