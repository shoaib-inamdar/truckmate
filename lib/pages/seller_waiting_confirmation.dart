import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/pages/seller_login_screen.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/providers/auth_provider.dart';

class SellerWaitingConfirmationScreen extends StatefulWidget {
  const SellerWaitingConfirmationScreen({Key? key}) : super(key: key);
  @override
  State<SellerWaitingConfirmationScreen> createState() =>
      _SellerWaitingConfirmationScreenState();
}

class _SellerWaitingConfirmationScreenState
    extends State<SellerWaitingConfirmationScreen> {
  final SellerService _sellerService = SellerService();
  Timer? _statusCheckTimer;
  bool _isCheckingStatus = false;
  bool _hasNavigated = false;
  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    if (_isCheckingStatus || _hasNavigated) return;
    setState(() => _isCheckingStatus = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('seller_user_id');
      if (userId == null) return;
      final status = await _sellerService.checkSellerStatus(userId);
      print('🔍 Status check returned: $status');
      if (!mounted) return;
      if (status == 'approved') {
        print('✓ Seller status is APPROVED');
        final credentials = await _sellerService.getSellerCredentials(userId);
        print('Credentials fetched: $credentials');
        if (credentials != null) {
          final username = credentials['username'];
          final password = credentials['password'];
          final email = credentials['email'];
          print(
            'Extracted - username: $username, email: $email, password: ${password?.replaceAll(RegExp(r'.'), '*')}',
          );
          if (username == null || password == null || email == null) {
            print('❌ Missing credentials, retrying...');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Approval confirmed! Your credentials are being prepared. Please wait...',
                ),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() => _isCheckingStatus = false);
            return;
          }
          print(
            '✓ All required credentials available, creating Appwrite account...',
          );
          try {
            final accountCreated = await _sellerService.createSellerAccount(
              email: email,
              password: password,
              sellerName: username,
            );
            if (!accountCreated) {
              print(
                '⚠️ Warning: Could not create Appwrite account, but proceeding...',
              );
            } else {
              print('✓ Appwrite account created successfully');
            }
          } catch (e) {
            print('⚠️ Error creating account: $e, but proceeding...');
          }
          print('✓ Preparing navigation...');
          await prefs.remove('seller_status');
          await prefs.remove('seller_user_id');
          print('✓ SharedPreferences cleared');
          _hasNavigated = true;
          _statusCheckTimer?.cancel();
          print('✓ Timer cancelled');
          if (!mounted) {
            print('❌ Widget not mounted, cannot navigate');
            return;
          }
          print('🔄 Navigating to SellerLoginScreen with username: $username');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SellerLoginScreen(
                approvedUsername: username,
                approvedPassword: password,
                approvedEmail: email,
              ),
            ),
            (route) => false,
          );
          print('✓ Navigation initiated');
        } else {
          print(
            '❌ Credentials are null, status is approved but credentials not found',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Approval confirmed! Your credentials are being prepared. Please wait...',
              ),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 3),
            ),
          );
          setState(() => _isCheckingStatus = false);
          return;
        }
      } else if (status == 'rejected') {
        print('❌ Seller status is REJECTED');
        _hasNavigated = true;
        _statusCheckTimer?.cancel();
        if (!mounted) return;
        await _handleRejection(userId!);
      }
    } catch (e) {
      print('❌ Error checking approval status: $e');
    } finally {
      if (mounted && !_hasNavigated) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Application Under Review',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Thank you for submitting your Transporter registration!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.light,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.verified_user,
                        'Our admin team is reviewing your documents',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.notifications_active,
                        'You will be notified once approved',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.access_time,
                        'Review process typically takes 24-48 hours',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please wait for admin confirmation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: _isCheckingStatus
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.warning,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: AppColors.warning,
                              ),
                        onPressed: _isCheckingStatus
                            ? null
                            : _checkApprovalStatus,
                        tooltip: 'Check status',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelSessionDialog(),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Session'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelSessionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Cancel Session?')),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this session? Your registration will remain pending, but you will be logged out.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, Keep Waiting',
              style: TextStyle(color: AppColors.textDark),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Yes, Cancel Session'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _cancelSession();
    }
  }

  Future<void> _handleRejection(String userId) async {
    // Show rejection popup dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: AppColors.danger, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Registration Rejected')),
          ],
        ),
        content: const Text(
          'Your Transporter registration has been rejected due to some reasons. Please contact support for more details or try registering again with correct information.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    try {
      // First, delete all uploaded files from storage bucket
      print('🗑️ Starting deletion of uploaded files from bucket...');
      final sellerRegistration = await _sellerService.getSellerRegistration(
        userId,
      );

      if (sellerRegistration != null) {
        // Delete personal documents
        final List<String> fileIdsToDelete = [];

        if (sellerRegistration.panDocumentId != null) {
          fileIdsToDelete.add(sellerRegistration.panDocumentId!);
        }
        if (sellerRegistration.licenseDocumentId != null) {
          fileIdsToDelete.add(sellerRegistration.licenseDocumentId!);
        }
        if (sellerRegistration.gstDocumentId != null) {
          fileIdsToDelete.add(sellerRegistration.gstDocumentId!);
        }

        // Delete vehicle documents
        for (var vehicle in sellerRegistration.vehicles) {
          if (vehicle.documentId != null) {
            fileIdsToDelete.add(vehicle.documentId!);
          }
          if (vehicle.rcDocumentId != null) {
            fileIdsToDelete.add(vehicle.rcDocumentId!);
          }
          if (vehicle.frontImageId != null) {
            fileIdsToDelete.add(vehicle.frontImageId!);
          }
          if (vehicle.rearImageId != null) {
            fileIdsToDelete.add(vehicle.rearImageId!);
          }
          if (vehicle.sideImageId != null) {
            fileIdsToDelete.add(vehicle.sideImageId!);
          }
        }

        // Delete all files from bucket
        print('🗑️ Deleting ${fileIdsToDelete.length} files from storage...');
        for (var fileId in fileIdsToDelete) {
          try {
            await _sellerService.deleteDocument(fileId);
            print('✓ Deleted file: $fileId');
          } catch (e) {
            print('⚠️ Error deleting file $fileId: $e');
            // Continue deleting other files even if one fails
          }
        }
        print('✓ Finished deleting files from storage');

        // Now delete the seller request from database
        print('🗑️ Deleting seller request from database...');
        await _sellerService.deleteSellerRequest(sellerRegistration.id);
        print('✓ Seller request deleted from database');
      }

      // Clear preferences and logout
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seller_status');
      await prefs.remove('seller_user_id');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.deleteCurrentAnonymousSession();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChooseLoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Error during rejection cleanup: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during cleanup: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      // Still navigate away even if cleanup fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seller_status');
      await prefs.remove('seller_user_id');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChooseLoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _cancelSession() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('seller_user_id');

      // Delete seller request from database
      if (userId != null) {
        try {
          final sellerRegistration = await _sellerService.getSellerRegistration(
            userId,
          );
          if (sellerRegistration != null) {
            await _sellerService.deleteSellerRequest(sellerRegistration.id);
            print('✓ Seller request deleted successfully');
          }
        } catch (e) {
          print('⚠️ Error deleting seller request: $e');
          // Continue with logout even if delete fails
        }
      }

      await prefs.remove('seller_status');
      await prefs.remove('seller_user_id');
      await authProvider.deleteCurrentAnonymousSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChooseLoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session cancelled and registration removed.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling session: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.dark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
