import 'package:flutter/material.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/main.dart' hide AppColors;
import 'package:truckmate/pages/book_transport.dart';
import 'package:truckmate/pages/registeration.dart';
// import 'package:truckmate/constants/colors.dart' as AppColors;
// import 'package:truckmate/pages/book_transport.dart';
// import 'package:truckmate/pages/registeration.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width > 600 ? size.width * 0.25 : 40.0;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.1),
                  _buildBrandHeader(),
                  SizedBox(height: size.height * 0.08),
                  _buildLoginButton(
                    context,
                    'Login as\nCustomer',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BookTransportScreen()),
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildDivider(),
                  const SizedBox(height: 50),
                  _buildLoginButton(
                    context,
                    'Login as\nSeller',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RegistrationScreen()),
                    ),
                  ),
                  SizedBox(height: size.height * 0.1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
            children: [
              TextSpan(
                text: 'CARGO',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: ' BALANCER',
                style: TextStyle(color: AppColors.dark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Smart Logistics Solutions',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            color: AppColors.secondary.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            color: AppColors.secondary.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
      BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.4,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
