import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/add_vehicle_request_screen.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({Key? key}) : super(key: key);
  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _sellerService = SellerService();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEditingUsername = false;
  bool _isEditingPassword = false;
  String? _currentUsername;
  String? _userId;
  String? _transporterType;
  List<Map<String, dynamic>>? _vehicles;
  int _vehicleCount = 0;
  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUsername() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sellerEmail = authProvider.user?.email;

    if (sellerEmail == null) {
      print('❌ SellerProfile: No email found');
      return;
    }

    print('🔵 SellerProfile: Fetching credentials for email: $sellerEmail');

    try {
      // Get the original user_id using email
      final originalUserId = await _sellerService.getOriginalUserIdByEmail(
        sellerEmail,
      );

      if (originalUserId == null) {
        print('❌ SellerProfile: Could not find original user_id');
        return;
      }

      print('🔵 SellerProfile: Found original user_id: $originalUserId');
      _userId = originalUserId;

      // Now fetch credentials using the original user_id
      final credentials = await _sellerService.getSellerCredentials(
        originalUserId,
      );

      if (credentials != null && mounted) {
        print(
          '✅ SellerProfile: Credentials loaded - username: ${credentials['username']}',
        );
        setState(() {
          _currentUsername = credentials['username'];
          _usernameController.text = _currentUsername ?? '';
          // Auto-fill current password from seller_request table
          _currentPasswordController.text = credentials['password'] ?? '';
          _transporterType = credentials['transporter_type'];
          print('🔵 SellerProfile: Set transporter_type to: $_transporterType');
          // Parse vehicles from pipe-separated strings
          _vehicles = _parseVehicles(credentials['vehicles'] ?? []);
          print('🔵 SellerProfile: After parsing, _vehicles.length = ${_vehicles?.length ?? 0}');
          _vehicleCount =
              int.tryParse(credentials['vehicle_count']?.toString() ?? '0') ??
              0;
        });
      } else {
        print('❌ SellerProfile: No credentials found');
      }
    } catch (e) {
      print('❌ SellerProfile: Error loading credentials: $e');
    }
  }

  List<Map<String, dynamic>> _parseVehicles(dynamic vehiclesData) {
    List<Map<String, dynamic>> parsedVehicles = [];

    if (vehiclesData == null) {
      print('🔵 SellerProfile: vehiclesData is null');
      return parsedVehicles;
    }

    print('🔵 SellerProfile: vehiclesData type: ${vehiclesData.runtimeType}, value: $vehiclesData');

    // vehiclesData can be a List of strings (pipe-separated format)
    if (vehiclesData is List) {
      print('🔵 SellerProfile: vehiclesData is a List with ${vehiclesData.length} items');
      for (var vehicle in vehiclesData) {
        if (vehicle is String && vehicle.isNotEmpty) {
          print('🔵 SellerProfile: Parsing vehicle string: $vehicle');
          final parts = vehicle.split('|');
          if (parts.isNotEmpty) {
            parsedVehicles.add({
              'vehicle_number': parts.length > 0 ? parts[0] : '',
              'type_name': parts.length > 1 ? parts[1] : '',
              'vehicle_type': parts.length > 2 ? parts[2] : 'closed',
              'rc_book_no': parts.length > 3 ? parts[3] : '',
              'max_weight': parts.length > 4 ? parts[4] : '',
              'rc_book_id': parts.length > 5 ? parts[5] : '',
              'front_image_id': parts.length > 6 ? parts[6] : '',
              'rear_image_id': parts.length > 7 ? parts[7] : '',
            });
          }
        }
      }
      print('🟢 SellerProfile: Parsed ${parsedVehicles.length} vehicles');
    } else {
      print('❌ SellerProfile: vehiclesData is not a List, it is ${vehiclesData.runtimeType}');
    }

    return parsedVehicles;
  }

  Future<void> _handleUpdateUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final newUsername = _usernameController.text.trim();
    if (newUsername == _currentUsername) {
      SnackBarHelper.showError(context, 'Username is the same as current');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await _sellerService.updateSellerUsername(
        userId: _userId!,
        newUsername: newUsername,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (success) {
        SnackBarHelper.showSuccess(context, 'Username updated successfully');
        setState(() {
          _currentUsername = newUsername;
          _isEditingUsername = false;
        });
      } else {
        SnackBarHelper.showError(context, 'Failed to update username');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      SnackBarHelper.showError(context, 'Current password is required');
      return;
    }

    if (newPassword != confirmPassword) {
      SnackBarHelper.showError(context, 'Passwords do not match');
      return;
    }
    if (newPassword.length < 8) {
      SnackBarHelper.showError(
        context,
        'Password must be at least 8 characters',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await _sellerService.updateSellerPassword(
        userId: _userId!,
        oldPassword: currentPassword,
        newPassword: newPassword,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (success) {
        SnackBarHelper.showSuccess(context, 'Password updated successfully');
        setState(() {
          _isEditingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        SnackBarHelper.showError(context, 'Failed to update password');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Delete Account?')),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your seller account? This action cannot be undone and all your data will be permanently deleted.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textDark),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await _sellerService.deleteSellerAccount(
        userId: _userId!,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('seller_logged_in');
        await prefs.remove('startup_choice');
        await prefs.remove('seller_status');
        await prefs.remove('seller_user_id');
        await authProvider.logout();
        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'Account deleted successfully');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ChooseLoginScreen()),
          (route) => false,
        );
      } else {
        SnackBarHelper.showError(context, 'Failed to delete account');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('startup_choice');
    await prefs.remove('seller_logged_in');
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ChooseLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final pageTitle = _transporterType == 'business_company'
        ? 'Business Profile'
        : 'Transporter Profile';
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Processing...',
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(authProvider),
                  const SizedBox(height: 24),
                  _buildUsernameSection(),
                  const SizedBox(height: 24),
                  _buildPasswordSection(),
                  const SizedBox(height: 24),
                  if (_transporterType != 'business_company') ...[
                    _buildAddVehicleButton(),
                    const SizedBox(height: 24),
                  ],
                  if (_transporterType != 'business_company' &&
                      _vehicles != null &&
                      _vehicles!.isNotEmpty)
                    _buildVehiclesSection(),
                  if (_transporterType != 'business_company' &&
                      _vehicles != null &&
                      _vehicles!.isNotEmpty)
                    const SizedBox(height: 24),
                  _buildDangerZone(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withOpacity(0.2),
              border: Border.all(color: AppColors.success, width: 3),
            ),
            child: const Icon(Icons.person, size: 40, color: AppColors.dark),
          ),
          const SizedBox(height: 16),
          Text(
            authProvider.user?.name ?? 'Seller',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            authProvider.user?.email ?? '',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Transporter Account',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.success),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Username',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (!_isEditingUsername)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isEditingUsername = true);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isEditingUsername)
            Text(
              _currentUsername ?? 'Not loaded',
              style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            )
          else
            Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter new username',
                    filled: true,
                    fillColor: AppColors.light,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditingUsername = false;
                            _usernameController.text = _currentUsername ?? '';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: AppColors.secondary.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleUpdateUsername,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.dark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.success),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (!_isEditingPassword)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isEditingPassword = true);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isEditingPassword)
            const Text(
              '••••••••',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textDark,
                letterSpacing: 4,
              ),
            )
          else
            Column(
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter current password',
                    filled: true,
                    fillColor: AppColors.light,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textLight,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureCurrentPassword =
                              !_obscureCurrentPassword,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'New password is required';
                    }
                    if (value.trim().length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    filled: true,
                    fillColor: AppColors.light,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textLight,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Confirm new password',
                    filled: true,
                    fillColor: AppColors.light,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textLight,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditingPassword = false;
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: AppColors.secondary.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleUpdatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.dark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Add More Vehicles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You can add up to 10 vehicles. Currently you have $_vehicleCount vehicle(s).',
            style: const TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVehicleRequestScreen(
                      currentVehicleCount: _vehicleCount,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  // Reload profile data after successful submission
                  await _loadCurrentUsername();
                  if (!mounted) return;
                  SnackBarHelper.showSuccess(
                    context,
                    'Vehicle request submitted successfully',
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.success),
            SizedBox(width: 12),
            Text(
              'My Vehicles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...(_vehicles ?? []).asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> vehicle = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.dark.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle type and number
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkLight.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle['type_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vehicle #${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (vehicle['vehicle_type'] == 'open'
                                      ? AppColors.darkLight
                                      : AppColors.success)
                                  .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vehicle['vehicle_type']?.toString().toUpperCase() ??
                              'CLOSED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: vehicle['vehicle_type'] == 'open'
                                ? AppColors.light
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Vehicle Number',
                        vehicle['vehicle_number'] ?? '-',
                        Icons.directions_car,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'RC Book Number',
                        vehicle['rc_book_no'] ?? '-',
                        Icons.description,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Max Weight',
                        vehicle['max_weight'] ?? '-',
                        Icons.speed,
                      ),
                      if (vehicle['rc_book_id']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        _buildDocumentButton(
                          'RC Book Document',
                          vehicle['rc_book_id'],
                        ),
                      ],
                      if ((vehicle['front_image_id']?.isNotEmpty ?? false) ||
                          (vehicle['rear_image_id']?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (vehicle['front_image_id']?.isNotEmpty ?? false)
                              Expanded(
                                child: _buildDocumentButton(
                                  'Front Image',
                                  vehicle['front_image_id'],
                                ),
                              ),
                            if ((vehicle['front_image_id']?.isNotEmpty ??
                                    false) &&
                                (vehicle['rear_image_id']?.isNotEmpty ?? false))
                              const SizedBox(width: 8),
                            if (vehicle['rear_image_id']?.isNotEmpty ?? false)
                              Expanded(
                                child: _buildDocumentButton(
                                  'Rear Image',
                                  vehicle['rear_image_id'],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentButton(String label, String documentId) {
    return InkWell(
      onTap: () {
        SnackBarHelper.showInfo(context, 'Document viewing coming soon');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, color: AppColors.success, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 12),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Once you delete your account, there is no going back. Please be certain.',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleDeleteAccount,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
