import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';
import 'package:truckmate/pages/seller_waiting_confirmation.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _companyNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _transportLicenseController = TextEditingController();

  // Files
  File? _gstFile;
  File? _panFile;
  File? _transportLicenseFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _emailController.text =
          authProvider.user!.email != 'anonymous@seller.local'
          ? authProvider.user!.email
          : '';
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _transportLicenseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String documentType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > 1 * 1024 * 1024) {
          if (!mounted) return;
          SnackBarHelper.showError(context, 'File size must be less than 1MB');
          return;
        }

        setState(() {
          switch (documentType) {
            case 'gst':
              _gstFile = file;
              break;
            case 'pan':
              _panFile = file;
              break;
            case 'transport_license':
              _transportLicenseFile = file;
              break;
          }
        });

        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'File selected successfully');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error picking file: $e');
    }
  }

  Future<void> _viewFile(File? file, String fileName) async {
    if (file == null) return;

    // For now, just show a message that file is selected
    // You can implement a PDF viewer later if needed
    SnackBarHelper.showSuccess(context, 'File $fileName selected');
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showError(context, 'Please fill all required fields');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter email address');
      return;
    }

    if (_gstFile == null || _panFile == null || _transportLicenseFile == null) {
      SnackBarHelper.showError(context, 'Please upload all required documents');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sellerProvider = Provider.of<SellerProvider>(
        context,
        listen: false,
      );

      if (authProvider.user == null) {
        throw 'User not authenticated';
      }

      // Upload documents
      String? gstDocId;
      String? panDocId;
      String? transportLicenseDocId;

      try {
        gstDocId = await sellerProvider.uploadDocument(
          _gstFile!,
          authProvider.user!.id,
        );
        panDocId = await sellerProvider.uploadDocument(
          _panFile!,
          authProvider.user!.id,
        );
        transportLicenseDocId = await sellerProvider.uploadDocument(
          _transportLicenseFile!,
          authProvider.user!.id,
        );
      } catch (e) {
        throw 'Error uploading documents: $e';
      }

      // Submit business registration
      final success = await sellerProvider.createBusinessRegistration(
        userId: authProvider.user!.id,
        companyName: _companyNameController.text.trim(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        gstNo: _gstController.text.trim(),
        gstDocumentId: gstDocId,
        panCardNo: _panController.text.trim(),
        panDocumentId: panDocId,
        transportLicenseNo: _transportLicenseController.text.trim(),
        transportLicenseDocumentId: transportLicenseDocId,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (success) {
        SnackBarHelper.showSuccess(
          context,
          'Business registration submitted successfully!',
        );
        _showSuccessDialog();
      } else {
        SnackBarHelper.showError(
          context,
          sellerProvider.errorMessage ?? 'Failed to submit registration',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Registration Submitted!')),
          ],
        ),
        content: const Text(
          'Your Business Transporter registration has been submitted successfully. We will review your application and get back to you soon.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await prefs.setString('seller_status', 'pending');
              await prefs.setString('seller_user_id', authProvider.user!.id);
              await authProvider.deleteCurrentAnonymousSession();
              Navigator.pop(context); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const SellerWaitingConfirmationScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Submitting registration...',
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildSectionTitle('Business Information'),
                const SizedBox(height: 16),
                _buildTextField(
                  'Company Name',
                  'Enter company name',
                  _companyNameController,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Contact Number',
                  'Enter contact number',
                  _contactController,
                  maxLength: 10,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Company Address',
                  'Enter company address',
                  _addressController,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Email',
                  'Enter email address',
                  _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    final trimmed = value.trim();
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Documents'),
                const SizedBox(height: 16),
                _buildDocumentField(
                  'GST Number',
                  'Enter GST number',
                  _gstController,
                  'gst',
                  _gstFile != null,
                ),
                const SizedBox(height: 16),
                _buildDocumentField(
                  'PAN Card Number',
                  'Enter PAN number',
                  _panController,
                  'pan',
                  _panFile != null,
                ),
                const SizedBox(height: 16),
                _buildDocumentField(
                  'Transport Licence Number',
                  'Enter transport licence number',
                  _transportLicenseController,
                  'transport_license',
                  _transportLicenseFile != null,
                ),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator:
                validator ??
                (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              border: InputBorder.none,
              counterText: maxLength != null ? '' : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentField(
    String label,
    String hint,
    TextEditingController controller,
    String documentType,
    bool hasFile,
  ) {
    int? maxLength;
    List<TextInputFormatter> inputFormatters = [];

    switch (documentType) {
      case 'pan':
        maxLength = 10;
        inputFormatters = [
          // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            return TextEditingValue(
              text: newValue.text.toUpperCase(),
              selection: newValue.selection,
            );
          }),
        ];
        break;
      case 'gst':
        maxLength = 15;
        inputFormatters = [
          // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            return TextEditingValue(
              text: newValue.text.toUpperCase(),
              selection: newValue.selection,
            );
          }),
        ];
        break;
      case 'transport_license':
        maxLength = 20;
        inputFormatters = [
          // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            return TextEditingValue(
              text: newValue.text.toUpperCase(),
              selection: newValue.selection,
            );
          }),
        ];
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  maxLength: maxLength,
                  inputFormatters: inputFormatters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (documentType == 'pan' && value.length != 10) {
                      return 'PAN must be 10 characters';
                    }
                    if (documentType == 'gst' && value.length != 15) {
                      return 'GST must be 15 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppColors.textLight.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.upload_file,
              () => _pickFile(documentType),
              hasFile ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.visibility_outlined,
              hasFile
                  ? () {
                      File? fileToView;
                      String fileName = '';
                      switch (documentType) {
                        case 'pan':
                          fileToView = _panFile;
                          fileName = 'PAN Card';
                          break;
                        case 'gst':
                          fileToView = _gstFile;
                          fileName = 'GST Certificate';
                          break;
                        case 'transport_license':
                          fileToView = _transportLicenseFile;
                          fileName = 'Transport Licence';
                          break;
                      }
                      _viewFile(fileToView, fileName);
                    }
                  : null,
              hasFile
                  ? AppColors.primary
                  : AppColors.secondary.withOpacity(0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: AppColors.dark),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: const Text(
          'Submit Registration',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
