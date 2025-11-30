import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/main.dart' hide AppColors;
import 'package:truckmate/pages/login.dart';
// import 'package:truckmate/pages/login_screen.dart';
import '../../providers/email_otp_provider.dart';
// import '../../utils/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/snackbar_helper.dart';
import 'email_otp_verify_screen.dart';

class EmailOTPLoginScreen extends StatefulWidget {
  const EmailOTPLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmailOTPLoginScreen> createState() => _EmailOTPLoginScreenState();
}

class _EmailOTPLoginScreenState extends State<EmailOTPLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final emailOTPProvider = Provider.of<EmailOTPProvider>(
      context,
      listen: false,
    );
    
    final success = await emailOTPProvider.sendEmailOTP(
      _emailController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(
        context,
        'OTP sent to your email!',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailOTPVerifyScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else {
      SnackBarHelper.showError(
        context,
        emailOTPProvider.errorMessage ?? 'Failed to send OTP',
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
        message: 'Sending OTP...',
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    
                    IconButton(
                      onPressed: () =>Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChooseLoginScreen ()),
        ),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.dark,
                      iconSize: 28,
                    ),

                    SizedBox(height: size.height * 0.04),

                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              size: 40,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Email Verification',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your email address to receive\na verification code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: size.height * 0.06),

                    CustomTextField(
                      label: 'Email Address',
                      hint: 'Enter your email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.secondary,
                      ),
                    ),

                    const SizedBox(height: 40),

                    CustomButton(
                      text: 'Send Verification Code',
                      onPressed: _handleSendOTP,
                      isLoading: _isLoading,
                      icon: const Icon(
                        Icons.send,
                        color: AppColors.dark,
                        size: 20,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.dark,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Check Your Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'We will send you a verification code to your email address. Please check your inbox and spam folder.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textDark,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
}