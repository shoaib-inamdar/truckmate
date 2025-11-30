import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/book_transport.dart';
import 'package:truckmate/pages/profile_screen.dart';
// import 'package:truckmate/pages/profile_completion_screen.dart';
import '../../providers/email_otp_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/pages/seller_registration_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/snackbar_helper.dart';

class EmailOTPVerifyScreen extends StatefulWidget {
  final String email;

  const EmailOTPVerifyScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<EmailOTPVerifyScreen> createState() => _EmailOTPVerifyScreenState();
}

class _EmailOTPVerifyScreenState extends State<EmailOTPVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String _getOTP() {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _getOTP();

    if (otp.length != 6) {
      SnackBarHelper.showError(context, 'Please enter complete code');
      return;
    }

    setState(() => _isLoading = true);

    final emailOTPProvider = Provider.of<EmailOTPProvider>(
      context,
      listen: false,
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await emailOTPProvider.verifyEmailOTP(otp);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(context, 'Email verified successfully!');

      // Set user in auth provider
      if (emailOTPProvider.user != null) {
        // Check startup choice (customer/seller) to set role and route accordingly
        final prefs = await SharedPreferences.getInstance();
        final startupChoice = prefs.getString('startup_choice');

        if (startupChoice == 'seller') {
          // Create user profile with role 'seller'
          await authProvider.setUserAfterOTP(
            emailOTPProvider.user!,
            role: 'seller',
          );
          // Navigate to seller registration
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()),
            (route) => false,
          );
        } else {
          // Default customer flow
          await authProvider.setUserAfterOTP(emailOTPProvider.user!);
          // Check if profile is complete
          if (authProvider.user?.needsProfileCompletion() ?? true) {
            // Navigate to profile completion
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ProfileCompletionScreen(),
              ),
              (route) => false,
            );
          } else {
            // Navigate directly to booking page
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const BookTransportScreen()),
              (route) => false,
            );
          }
        }
      }
    } else {
      SnackBarHelper.showError(
        context,
        emailOTPProvider.errorMessage ?? 'Invalid verification code',
      );
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _handleResendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    final emailOTPProvider = Provider.of<EmailOTPProvider>(
      context,
      listen: false,
    );

    final success = await emailOTPProvider.resendOTP();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(context, 'Code resent to your email!');
      _startResendTimer();
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      SnackBarHelper.showError(
        context,
        emailOTPProvider.errorMessage ?? 'Failed to resend code',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Verifying code...',
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.dark,
                        iconSize: 28,
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),

                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 50,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Verify Your Email',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Enter the 6-digit code sent to',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),

                    SizedBox(height: size.height * 0.06),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return _buildOTPField(index);
                      }),
                    ),

                    const SizedBox(height: 40),

                    CustomButton(
                      text: 'Verify & Continue',
                      onPressed: _handleVerifyOTP,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive code? ",
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: _canResend ? _handleResendOTP : null,
                          child: Text(
                            _canResend
                                ? 'Resend Code'
                                : 'Resend in ${_resendTimer}s',
                            style: TextStyle(
                              color: _canResend
                                  ? AppColors.primary
                                  : AppColors.textLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.light,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tips',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTip('Code is valid for 15 minutes'),
                          _buildTip('Check your spam/junk folder'),
                          _buildTip('Code contains numbers and letters'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _otpControllers[index].text.isNotEmpty
              ? AppColors.primary
              : AppColors.secondary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.length == 1) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
            }
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
