import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/models/seller_model.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';
import 'package:truckmate/pages/seller_waiting_confirmation.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedVehicles = {};
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _aadharController = TextEditingController();
  final _panController = TextEditingController();
  final _licenseController = TextEditingController();
  final _gstController = TextEditingController();

  // Document files
  File? _aadharFile;
  File? _panFile;
  File? _licenseFile;
  File? _gstFile;

  // Vehicle list
  final List<VehicleEntry> _vehicles = [];

  final List<String> vehicleTypesList = [
    'Truck',
    'Tempo',
    'Mini Truck',
    'Container',
    'Trailer',
    'Van',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _nameController.text = authProvider.user!.name;
      _addressController.text = authProvider.user!.address ?? '';
      _contactController.text = authProvider.user!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _licenseController.dispose();
    _gstController.dispose();
    for (var vehicle in _vehicles) {
      vehicle.controller.dispose();
    }
    super.dispose();
  }

  void _viewFile(File? file, String fileName) {
    if (file == null) {
      SnackBarHelper.showError(context, 'No file uploaded');
      return;
    }

    final isPdf = file.path.toLowerCase().endsWith('.pdf');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: isPdf
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 80,
                                color: AppColors.danger,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                file.path.split('/').last,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PDF Preview not available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile(String documentType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        // Check file size (5MB max)
        if (fileSize > 5 * 1024 * 1024) {
          SnackBarHelper.showError(context, 'File size must be less than 5MB');
          return;
        }

        setState(() {
          switch (documentType) {
            case 'aadhar':
              _aadharFile = file;
              break;
            case 'pan':
              _panFile = file;
              break;
            case 'license':
              _licenseFile = file;
              break;
            case 'gst':
              _gstFile = file;
              break;
          }
        });

        SnackBarHelper.showSuccess(context, 'File selected successfully');
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Failed to pick file: $e');
    }
  }

  void _addVehicle() {
    setState(() {
      _vehicles.add(
        VehicleEntry(controller: TextEditingController(), file: null),
      );
    });
  }

  void _removeVehicle(int index) {
    setState(() {
      _vehicles[index].controller.dispose();
      _vehicles.removeAt(index);
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showError(context, 'Please fill all required fields');
      return;
    }

    if (_selectedVehicles.isEmpty) {
      SnackBarHelper.showError(
        context,
        'Please select at least one vehicle type',
      );
      return;
    }

    if (_vehicles.isEmpty) {
      SnackBarHelper.showError(context, 'Please add at least one vehicle');
      return;
    }

    // Check if all vehicles have numbers
    for (int i = 0; i < _vehicles.length; i++) {
      if (_vehicles[i].controller.text.trim().isEmpty) {
        SnackBarHelper.showError(
          context,
          'Please enter vehicle number for vehicle ${i + 1}',
        );
        return;
      }
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sellerProvider = Provider.of<SellerProvider>(context, listen: false);

    if (authProvider.user == null) {
      SnackBarHelper.showError(context, 'Please login to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload documents
      String? aadharDocId;
      String? panDocId;
      String? licenseDocId;
      String? gstDocId;

      if (_aadharFile != null) {
        aadharDocId = await sellerProvider.uploadDocument(
          _aadharFile!,
          'aadhar_${authProvider.user!.id}.${_aadharFile!.path.split('.').last}',
        );
      }

      if (_panFile != null) {
        panDocId = await sellerProvider.uploadDocument(
          _panFile!,
          'pan_${authProvider.user!.id}.${_panFile!.path.split('.').last}',
        );
      }

      if (_licenseFile != null) {
        licenseDocId = await sellerProvider.uploadDocument(
          _licenseFile!,
          'license_${authProvider.user!.id}.${_licenseFile!.path.split('.').last}',
        );
      }

      if (_gstFile != null) {
        gstDocId = await sellerProvider.uploadDocument(
          _gstFile!,
          'gst_${authProvider.user!.id}.${_gstFile!.path.split('.').last}',
        );
      }

      // Upload vehicle documents
      List<VehicleInfo> vehicleInfoList = [];
      for (int i = 0; i < _vehicles.length; i++) {
        String? vehicleDocId;
        if (_vehicles[i].file != null) {
          vehicleDocId = await sellerProvider.uploadDocument(
            _vehicles[i].file!,
            'vehicle_${i}_${authProvider.user!.id}.${_vehicles[i].file!.path.split('.').last}',
          );
        }

        vehicleInfoList.add(
          VehicleInfo(
            vehicleNumber: _vehicles[i].controller.text.trim(),
            documentId: vehicleDocId,
          ),
        );
      }

      // Get selected vehicle types
      final selectedVehicleTypes = _selectedVehicles
          .map((index) => vehicleTypesList[index])
          .toList();

      // Create seller registration
      final success = await sellerProvider.createSellerRegistration(
        userId: authProvider.user!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        contact: _contactController.text.trim(),
        aadharCardNo: _aadharController.text.trim(),
        aadharDocumentId: aadharDocId,
        panCardNo: _panController.text.trim(),
        panDocumentId: panDocId,
        drivingLicenseNo: _licenseController.text.trim(),
        licenseDocumentId: licenseDocId,
        gstNo: _gstController.text.trim(),
        gstDocumentId: gstDocId,
        selectedVehicleTypes: selectedVehicleTypes,
        vehicles: vehicleInfoList,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (success) {
        SnackBarHelper.showSuccess(
          context,
          'Seller registration submitted successfully!',
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
          'Your seller registration has been submitted successfully. We will review your application and get back to you soon.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
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
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
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
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Submitting registration...',
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFAFBFB),
                              Color(0xFF7ECF9A).withOpacity(0.3),
                              Color(0xFFFAFBFB),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seller Registration',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildTextField(
                              'Name',
                              'Enter your full name',
                              _nameController,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              'Address',
                              'Enter your address',
                              _addressController,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              'Contact',
                              'Enter contact number',
                              _contactController,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),

                            _buildDocumentField(
                              'Aadhar Card No.',
                              'Enter Aadhar number',
                              _aadharController,
                              'aadhar',
                              _aadharFile != null,
                            ),
                            const SizedBox(height: 16),

                            _buildDocumentField(
                              'Pan Card No',
                              'Enter PAN number',
                              _panController,
                              'pan',
                              _panFile != null,
                            ),
                            const SizedBox(height: 16),

                            _buildDocumentField(
                              'Driving License No:',
                              'Enter license number',
                              _licenseController,
                              'license',
                              _licenseFile != null,
                            ),
                            const SizedBox(height: 16),

                            _buildDocumentField(
                              'GST No :',
                              'Enter GST number',
                              _gstController,
                              'gst',
                              _gstFile != null,
                            ),
                            const SizedBox(height: 24),

                            _buildVehicleSelector(),
                            const SizedBox(height: 16),

                            ..._buildVehicleList(),

                            const SizedBox(height: 16),
                            _buildAddVehicleButton(),
                            const SizedBox(height: 24),

                            _buildRegisterButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomNav(0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.darkLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopIcon(Icons.person_outline),
          Row(
            children: [
              _buildTopIcon(Icons.notifications_outlined),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await authProvider.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const ChooseLoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.dark, width: 2),
                    color: AppColors.white,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: AppColors.dark,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIcon(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.dark, width: 2),
        color: AppColors.white,
      ),
      child: Icon(icon, color: AppColors.dark, size: 24),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
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
            keyboardType: keyboardType,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              border: InputBorder.none,
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppColors.textLight.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
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
                        case 'aadhar':
                          fileToView = _aadharFile;
                          fileName = 'Aadhar Card';
                          break;
                        case 'pan':
                          fileToView = _panFile;
                          fileName = 'PAN Card';
                          break;
                        case 'license':
                          fileToView = _licenseFile;
                          fileName = 'Driving License';
                          break;
                        case 'gst':
                          fileToView = _gstFile;
                          fileName = 'GST Certificate';
                          break;
                      }
                      _viewFile(fileToView, fileName);
                    }
                  : null,
              hasFile
                  ? AppColors.primary
                  : AppColors.secondary.withOpacity(0.3),
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.close,
              hasFile
                  ? () {
                      setState(() {
                        switch (documentType) {
                          case 'aadhar':
                            _aadharFile = null;
                            break;
                          case 'pan':
                            _panFile = null;
                            break;
                          case 'license':
                            _licenseFile = null;
                            break;
                          case 'gst':
                            _gstFile = null;
                            break;
                        }
                      });
                      SnackBarHelper.showInfo(context, 'File removed');
                    }
                  : null,
              hasFile ? AppColors.danger : AppColors.secondary.withOpacity(0.3),
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

  Widget _buildVehicleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'Select Vehicle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final isSelected = _selectedVehicles.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedVehicles.remove(index);
                  } else {
                    _selectedVehicles.add(index);
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.light,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.secondary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 40,
                      color: isSelected ? AppColors.dark : AppColors.textDark,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleTypesList[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.dark : AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildVehicleList() {
    List<Widget> vehicleWidgets = [];
    for (int i = 0; i < _vehicles.length; i++) {
      vehicleWidgets.add(_buildVehicleEntry(i));
      vehicleWidgets.add(const SizedBox(height: 16));
    }
    return vehicleWidgets;
  }

  Widget _buildVehicleEntry(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Vehicle No. ${index + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            if (index > 0)
              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.danger),
                onPressed: () => _removeVehicle(index),
              ),
          ],
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
                  controller: _vehicles[index].controller,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter vehicle number',
                    hintStyle: TextStyle(
                      color: AppColors.textLight.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
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
              () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                );

                if (result != null) {
                  final file = File(result.files.single.path!);
                  final fileSize = await file.length();

                  if (fileSize > 5 * 1024 * 1024) {
                    SnackBarHelper.showError(
                      context,
                      'File size must be less than 5MB',
                    );
                    return;
                  }

                  setState(() {
                    _vehicles[index].file = file;
                  });

                  SnackBarHelper.showSuccess(context, 'Document selected');
                }
              },
              _vehicles[index].file != null
                  ? AppColors.success
                  : AppColors.primary,
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.visibility_outlined,
              _vehicles[index].file != null
                  ? () {
                      _viewFile(
                        _vehicles[index].file,
                        'Vehicle ${index + 1} Document',
                      );
                    }
                  : null,
              _vehicles[index].file != null
                  ? AppColors.primary
                  : AppColors.secondary.withOpacity(0.3),
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.close,
              _vehicles[index].file != null
                  ? () {
                      setState(() {
                        _vehicles[index].file = null;
                      });
                      SnackBarHelper.showInfo(context, 'File removed');
                    }
                  : null,
              _vehicles[index].file != null
                  ? AppColors.danger
                  : AppColors.secondary.withOpacity(0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddVehicleButton() {
    return InkWell(
      onTap: _addVehicle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, size: 22, color: AppColors.dark),
            SizedBox(width: 8),
            Text(
              'Add Vehicle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.dark.withOpacity(0.4),
        ),
        child: const Text(
          'Register',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.secondary,
        backgroundColor: AppColors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            label: 'Favourites',
          ),
        ],
      ),
    );
  }
}

class VehicleEntry {
  final TextEditingController controller;
  File? file;

  VehicleEntry({required this.controller, this.file});
}
