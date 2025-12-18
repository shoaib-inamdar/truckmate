import 'package:flutter/material.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/seller_choice_screen.dart';
import 'package:truckmate/main.dart' hide AppColors;
import 'package:shared_preferences/shared_preferences.dart';


class ChooseLoginScreen extends StatelessWidget {
  const ChooseLoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      // appBar: AppBar(backgroundColor: AppColors.dark,),
      backgroundColor: AppColors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SizedBox(height: size.height * 0.05),
              _buildBrandHeader(),
              SizedBox(height: size.height * 0.08),
              _buildCustomerButton(context),
              const SizedBox(height: 40),
              _buildDivider(),
              const SizedBox(height: 40),
              _buildSellerButton(context),
              SizedBox(height: size.height * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20, top: 30),
      decoration: BoxDecoration(color: AppColors.dark),
      child: Column(
        children: [
          Container(
            width: 200,
            height: 100,
            decoration: BoxDecoration(
              image: new DecorationImage(
                image: AssetImage("assets/images/logo.png"),
                fit: BoxFit.contain,
              ),
            ),
          ),
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
                  style: TextStyle(color: AppColors.light),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Smart Logistics Solutions',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.light,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
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
              fontSize: 14,
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

  Widget _buildCustomerButton(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width > 600 ? size.width * 0.25 : 40.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: InkWell(
        onTap: () async {
          print('=== LOGIN AS CUSTOMER CLICKED ===');
          print('Timestamp: ${DateTime.now()}');
          print('Getting SharedPreferences instance...');
          final prefs = await SharedPreferences.getInstance();
          print('Setting startup_choice to "customer"...');
          await prefs.setString('startup_choice', 'customer');
          print('startup_choice saved: ${prefs.getString('startup_choice')}');
          if (!context.mounted) {
            print('ERROR: Context not mounted, aborting navigation');
            return;
          }
          print('Context is mounted, navigating to AuthWrapper...');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
          );
          print('Navigation completed to AuthWrapper');
          print('=== END LOGIN AS CUSTOMER ===');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 32, color: AppColors.dark),
              ),
              const SizedBox(height: 12),
              const Text(
                'Login as\nCustomer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Book transport services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dark.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerButton(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width > 600 ? size.width * 0.25 : 40.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: InkWell(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('startup_choice', 'seller');
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellerChoiceScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
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
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Register as\nTransporter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Provide transport services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
