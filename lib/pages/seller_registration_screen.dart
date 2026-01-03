import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/models/seller_model.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';
import 'package:truckmate/pages/seller_waiting_confirmation.dart';
import 'package:truckmate/pages/pdf_viewer_page.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({Key? key}) : super(key: key);
  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _panController = TextEditingController();
  final _licenseController = TextEditingController();
  final _gstController = TextEditingController();
  File? _panFile;
  File? _licenseFile;
  File? _gstFile;
  final List<VehicleEntry> _vehicles = [];
  final List<String> vehicleTypesList = [
    'Truck',
    'Tempo',
    'Mini Truck',
    'Container',
    'Trailer',
    'Mini Pickup',
  ];
  // New vehicle selection system with spinners
  final Map<String, int> _vehicleQuantities = {
    'Truck': 0,
    'Tempo': 0,
    'Mini Truck': 0,
    'Container': 0,
    'Trailer': 0,
    'Mini Pickup': 0,
  };
  static const int _maxTotalVehicles = 10;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  int get _totalVehicles {
    return _vehicleQuantities.values.fold(0, (sum, count) => sum + count);
  }

  int get _remainingSlots {
    return _maxTotalVehicles - _totalVehicles;
  }

  void _updateVehicleQuantity(String type, int newCount) {
    final currentTotal = _totalVehicles;
    final currentCount = _vehicleQuantities[type] ?? 0;
    final difference = newCount - currentCount;

    if (currentTotal + difference > _maxTotalVehicles) {
      SnackBarHelper.showError(
        context,
        'Maximum $_maxTotalVehicles vehicles allowed',
      );
      return;
    }

    setState(() {
      _vehicleQuantities[type] = newCount;
      _syncVehicleEntries();
    });
  }

  void _syncVehicleEntries() {
    // Remove excess vehicles or add new ones based on quantities
    final List<VehicleEntry> newVehicles = [];

    for (var type in vehicleTypesList) {
      final count = _vehicleQuantities[type] ?? 0;
      final existing = _vehicles.where((v) => v.typeName == type).toList();

      for (int i = 0; i < count; i++) {
        if (i < existing.length) {
          newVehicles.add(existing[i]);
        } else {
          newVehicles.add(
            VehicleEntry(
              controller: TextEditingController(),
              typeName: type,
              rcBookController: TextEditingController(),
              maxWeightController: TextEditingController(),
            ),
          );
        }
      }

      // Dispose controllers for removed vehicles
      for (int i = count; i < existing.length; i++) {
        existing[i].controller.dispose();
        existing[i].rcBookController.dispose();
        existing[i].maxWeightController.dispose();
      }
    }

    _vehicles.clear();
    _vehicles.addAll(newVehicles);
  }

  bool _isFormComplete() {
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _contactController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _panController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty) {
      return false;
    }
    if (_panFile == null || _licenseFile == null) {
      return false;
    }
    if (_totalVehicles == 0 || _totalVehicles > _maxTotalVehicles) {
      return false;
    }
    if (_vehicles.isEmpty) {
      return false;
    }
    for (var vehicle in _vehicles) {
      if (vehicle.controller.text.trim().isEmpty ||
          vehicle.rcBookController.text.trim().isEmpty ||
          vehicle.maxWeightController.text.trim().isEmpty ||
          vehicle.rcBookFile == null ||
          vehicle.frontImage == null ||
          vehicle.rearImage == null) {
        return false;
      }
    }
    return true;
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _nameController.text = authProvider.user!.name != 'Anonymous Seller'
          ? authProvider.user!.name
          : '';
      _addressController.text = authProvider.user!.address ?? '';
      _contactController.text = authProvider.user!.phone ?? '';
      _emailController.text =
          authProvider.user!.email != 'anonymous@seller.local'
          ? authProvider.user!.email
          : '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _panController.dispose();
    _licenseController.dispose();
    _gstController.dispose();
    for (var vehicle in _vehicles) {
      vehicle.controller.dispose();
      vehicle.rcBookController.dispose();
      vehicle.maxWeightController.dispose();
    }
    super.dispose();
  }

  void _viewFile(File? file, String fileName) {
    if (file == null) {
      SnackBarHelper.showError(context, 'No file uploaded');
      return;
    }
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(file: file, fileName: fileName),
        ),
      );
    } else {
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
                        Icons.image,
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
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
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
        if (fileSize > 1 * 1024 * 1024) {
          SnackBarHelper.showError(context, 'File size must be less than 1MB');
          return;
        }
        setState(() {
          switch (documentType) {
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

  void _addVehicle({int? typeIndex}) {
    if (_vehicles.length >= _maxTotalVehicles) {
      SnackBarHelper.showError(
        context,
        'Maximum $_maxTotalVehicles vehicles allowed',
      );
      return;
    }
    final selectedTypeNames = _vehicleQuantities.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    if (selectedTypeNames.isEmpty) {
      SnackBarHelper.showError(context, 'Select a vehicle type first');
      return;
    }

    String? typeName;
    if (typeIndex != null) {
      typeName = vehicleTypesList[typeIndex];
    } else {
      final availableType = selectedTypeNames.firstWhere(
        (name) => !_vehicles.any((v) => v.typeName == name),
        orElse: () => '',
      );
      typeName = availableType.isEmpty ? null : availableType;
    }

    if (typeName == null ||
        _vehicles.any((vehicle) => vehicle.typeName == typeName)) {
      SnackBarHelper.showError(context, 'Selected vehicle type already added');
      return;
    }

    setState(() {
      _vehicles.add(
        VehicleEntry(
          controller: TextEditingController(),
          typeName: typeName!,
          rcBookController: TextEditingController(),
          maxWeightController: TextEditingController(),
          type: 'open',
          weightUnit: 'kg',
        ),
      );
    });
  }

  void _removeVehicle(int index) {
    setState(() {
      final vehicleType = _vehicles[index].typeName;
      _vehicles[index].controller.dispose();
      _vehicles[index].rcBookController.dispose();
      _vehicles[index].maxWeightController.dispose();
      _vehicles.removeAt(index);

      // Decrease the count in the spinner for this vehicle type
      if (_vehicleQuantities.containsKey(vehicleType) &&
          _vehicleQuantities[vehicleType]! > 0) {
        _vehicleQuantities[vehicleType] = _vehicleQuantities[vehicleType]! - 1;
      }
    });
  }

  void _removeVehicleByType(String typeName) {
    final removalIndex = _vehicles.indexWhere(
      (vehicle) => vehicle.typeName == typeName,
    );
    if (removalIndex != -1) {
      _vehicles[removalIndex].controller.dispose();
      _vehicles[removalIndex].rcBookController.dispose();
      _vehicles[removalIndex].maxWeightController.dispose();
      _vehicles.removeAt(removalIndex);
    }
  }

  Future<File?> _combineVehicleImages(
    File? frontImage,
    File? rearImage,
    int vehicleIndex,
    String userId,
  ) async {
    try {
      if (frontImage == null || rearImage == null) {
        print('Skipping image combining: Not all images selected');
        print('Front: $frontImage, Rear: $rearImage');
        return null;
      }
      print('Starting image combining for vehicle $vehicleIndex');
      final frontBytes = await frontImage.readAsBytes();
      final rearBytes = await rearImage.readAsBytes();
      print(
        'Read image bytes - Front: ${frontBytes.length}, Rear: ${rearBytes.length}',
      );
      final front = img.decodeImage(frontBytes);
      final rear = img.decodeImage(rearBytes);
      print('Decoded images - Front: ${front != null}, Rear: ${rear != null}');
      if (front == null || rear == null) {
        throw 'Failed to decode images. Front: ${front == null}, Rear: ${rear == null}';
      }
      final targetHeight = 300;
      final resizedFront = img.copyResize(front, height: targetHeight);
      final resizedRear = img.copyResize(rear, height: targetHeight);
      print('Resized images successfully');
      final totalWidth = resizedFront.width + resizedRear.width;
      final combined = img.Image(width: totalWidth, height: targetHeight);
      img.compositeImage(combined, resizedFront, dstX: 0, dstY: 0);
      img.compositeImage(
        combined,
        resizedRear,
        dstX: resizedFront.width,
        dstY: 0,
      );
      final combinedBytes = img.encodeJpg(combined, quality: 85);
      print(
        'Combined image created successfully, size: ${combinedBytes.length} bytes',
      );
      final tempDir = await getTemporaryDirectory();
      final combinedFile = File(
        '${tempDir.path}/vehicle_${vehicleIndex}_combined_$userId.jpg',
      );
      await combinedFile.writeAsBytes(combinedBytes);
      return combinedFile;
    } catch (e, stackTrace) {
      print('Error combining images: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> _isValidImageFile(File? file) async {
    if (file == null) return false;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        print('Invalid image: File is empty');
        return false;
      }
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        print('Invalid image: Could not decode image from ${file.path}');
        print('File size: ${bytes.length} bytes');
        return false;
      }
      print(
        'Valid image: ${file.path} (${decodedImage.width}x${decodedImage.height})',
      );
      return true;
    } catch (e) {
      print('Error validating image file: $e');
      return false;
    }
  }

  Future<bool> _validateVehicleImages(
    File? frontImage,
    File? rearImage,
    int vehicleIndex,
  ) async {
    print('Validating images for vehicle $vehicleIndex...');
    final isFrontValid = await _isValidImageFile(frontImage);
    final isRearValid = await _isValidImageFile(rearImage);
    if (!isFrontValid) {
      SnackBarHelper.showError(
        context,
        'Vehicle ${vehicleIndex + 1}: Front image is invalid or corrupted',
      );
      return false;
    }
    if (!isRearValid) {
      SnackBarHelper.showError(
        context,
        'Vehicle ${vehicleIndex + 1}: Rear image is invalid or corrupted',
      );
      return false;
    }
    print('All images valid for vehicle $vehicleIndex');
    return true;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showError(context, 'Please fill all required fields');
      return;
    }
    if (_totalVehicles == 0) {
      SnackBarHelper.showError(context, 'Please select at least one vehicle');
      return;
    }
    if (_totalVehicles > _maxTotalVehicles) {
      SnackBarHelper.showError(
        context,
        'Total vehicles cannot exceed $_maxTotalVehicles',
      );
      return;
    }
    if (_vehicles.isEmpty) {
      SnackBarHelper.showError(context, 'Please add at least one vehicle');
      return;
    }
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
      String? panDocId;
      String? licenseDocId;
      String? gstDocId;
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
      List<VehicleInfo> vehicleInfoList = [];
      for (int i = 0; i < _vehicles.length; i++) {
        String? frontImageId;
        String? rearImageId;
        try {
          print(
            'Processing vehicle $i with number: ${_vehicles[i].controller.text.trim()}',
          );
          final imagesValid = await _validateVehicleImages(
            _vehicles[i].frontImage,
            _vehicles[i].rearImage,
            i,
          );
          if (!imagesValid) {
            SnackBarHelper.showError(
              context,
              'Vehicle ${i + 1} has one or more invalid images. Please reselect.',
            );
            return;
          }

          // Upload front image separately
          if (_vehicles[i].frontImage != null) {
            try {
              print('Uploading front image for vehicle $i...');
              frontImageId = await sellerProvider.uploadDocument(
                _vehicles[i].frontImage!,
                'vehicle_${i}_front_${authProvider.user!.id}.${_vehicles[i].frontImage!.path.split('.').last}',
              );
              print(
                'Successfully uploaded front image for vehicle $i. ID: $frontImageId',
              );
            } catch (e) {
              print('Error uploading front image for vehicle $i: $e');
              SnackBarHelper.showError(
                context,
                'Error uploading front image for vehicle ${i + 1}: $e',
              );
              rethrow;
            }
          }

          // Upload rear image separately
          if (_vehicles[i].rearImage != null) {
            try {
              print('Uploading rear image for vehicle $i...');
              rearImageId = await sellerProvider.uploadDocument(
                _vehicles[i].rearImage!,
                'vehicle_${i}_rear_${authProvider.user!.id}.${_vehicles[i].rearImage!.path.split('.').last}',
              );
              print(
                'Successfully uploaded rear image for vehicle $i. ID: $rearImageId',
              );
            } catch (e) {
              print('Error uploading rear image for vehicle $i: $e');
              SnackBarHelper.showError(
                context,
                'Error uploading rear image for vehicle ${i + 1}: $e',
              );
              rethrow;
            }
          }
        } catch (e) {
          print('Error processing vehicle $i images: $e');
          SnackBarHelper.showError(
            context,
            'Error processing vehicle ${i + 1} images: $e',
          );
          rethrow;
        }

        // Upload RC book document for this vehicle
        String? rcDocId;
        if (_vehicles[i].rcBookFile != null) {
          try {
            rcDocId = await sellerProvider.uploadDocument(
              _vehicles[i].rcBookFile!,
              'rc_book_${i}_${authProvider.user!.id}.${_vehicles[i].rcBookFile!.path.split('.').last}',
            );
            print(
              'Successfully uploaded RC document for vehicle $i. ID: $rcDocId',
            );
          } catch (e) {
            print('Error uploading RC document for vehicle $i: $e');
            SnackBarHelper.showError(
              context,
              'Error uploading RC document for vehicle ${i + 1}: $e',
            );
            rethrow;
          }
        }

        // Extract weight number only (without unit)
        final weightText = _vehicles[i].maxWeightController.text.trim();
        final weightNumber = weightText.isEmpty ? '0' : weightText;

        vehicleInfoList.add(
          VehicleInfo(
            vehicleNumber: _vehicles[i].controller.text.trim(),
            vehicleType: _vehicles[i].typeName,
            type: _vehicles[i].type,
            rcBookNo: _vehicles[i].rcBookController.text.trim(),
            maxPassWeight: weightNumber,
            documentId: null, // No longer using combined image
            rcDocumentId: rcDocId,
            frontImageId: frontImageId,
            rearImageId: rearImageId,
            sideImageId: null,
          ),
        );
      }
      final selectedVehicleTypes = _vehicleQuantities.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList();
      final success = await sellerProvider.createSellerRegistration(
        userId: authProvider.user!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        contact: _contactController.text.trim(),
        email: _emailController.text.trim(),
        panCardNo: _panController.text.trim(),
        panDocumentId: panDocId,
        drivingLicenseNo: _licenseController.text.trim(),
        licenseDocumentId: licenseDocId,
        gstNo: _gstController.text.trim(),
        gstDocumentId: gstDocId,
        selectedVehicleTypes: selectedVehicleTypes,
        vehicles: vehicleInfoList,
        vehicleCount: _totalVehicles,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (success) {
        SnackBarHelper.showSuccess(
          context,
          'Transporter registration submitted successfully!',
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
          'Your Transporter registration has been submitted successfully. We will review your application and get back to you soon.',
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
              // _buildTopBar(),
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
                              'Transporter Registration',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              'Name / Company Name',
                              'Enter your full name or company name',
                              _nameController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Residential Address / Company Address',
                              'Enter your address',
                              _addressController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Contact Number',
                              'Enter contact number',
                              _contactController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                                if (!trimmed.contains('@') ||
                                    !trimmed.contains('.')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
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
                              'GST No (Optional):',
                              'Enter GST number (optional)',
                              _gstController,
                              'gst',
                              _gstFile != null,
                            ),
                            const SizedBox(height: 24),
                            _buildVehicleSelector(),
                            const SizedBox(height: 16),
                            ..._buildVehicleList(),
                            const SizedBox(height: 16),
                            if (_vehicles.length < 2) _buildAddVehicleButton(),
                            const SizedBox(height: 24),
                            _buildRegisterButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
    FormFieldValidator<String>? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
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
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            validator:
                validator ??
                (value) {
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
              counterText: '',
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
    // Define max length and input formatters based on document type
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
      case 'license':
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
                    // GST is optional, so skip validation if empty
                    if (documentType == 'gst') {
                      if (value == null || value.isEmpty) {
                        return null; // GST is optional
                      }
                      if (value.length != 15) {
                        return 'GST must be 15 characters';
                      }
                      return null;
                    }
                    
                    // For other documents (PAN, License), they are required
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (documentType == 'pan' && value.length != 10) {
                      return 'PAN must be 10 characters';
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
              'Select Vehicles (Max 10 Total)',
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
        // Vehicle type selector with spinners
        ...vehicleTypesList
            .map((type) => _buildVehicleTypeSpinner(type))
            .toList(),
        const SizedBox(height: 16),
        // Total vehicles counter
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _totalVehicles > _maxTotalVehicles
                ? AppColors.danger.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _totalVehicles > _maxTotalVehicles
                  ? AppColors.danger
                  : AppColors.primary,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Vehicles:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              Text(
                '$_totalVehicles / $_maxTotalVehicles',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _totalVehicles > _maxTotalVehicles
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeSpinner(String type) {
    final currentCount = _vehicleQuantities[type] ?? 0;
    final maxForThisType = currentCount + _remainingSlots;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentCount > 0
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.secondary.withOpacity(0.2),
          width: currentCount > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping,
            color: currentCount > 0 ? AppColors.primary : AppColors.textLight,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type,
              style: TextStyle(
                fontSize: 15,
                fontWeight: currentCount > 0
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: currentCount > 0 ? AppColors.dark : AppColors.textDark,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: AppColors.danger),
                  onPressed: currentCount > 0
                      ? () => _updateVehicleQuantity(type, currentCount - 1)
                      : null,
                ),
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text(
                      currentCount.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: currentCount < maxForThisType
                      ? () => _updateVehicleQuantity(type, currentCount + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
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
    final hasVehicleNumber = _vehicles[index].controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Vehicle: ${_vehicles[index].typeName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            if (index > 0)
              TextButton.icon(
                icon: const Icon(Icons.delete, color: AppColors.danger),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger),
                ),
                onPressed: () => _removeVehicle(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: _vehicles[index].controller,
            maxLength: 10,
            inputFormatters: [
              // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: newValue.text.toUpperCase(),
                  selection: newValue.selection,
                );
              }),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Enter vehicle number',
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Type',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Open'),
                value: 'open',
                groupValue: _vehicles[index].type,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _vehicles[index].type = value;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Closed'),
                value: 'closed',
                groupValue: _vehicles[index].type,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _vehicles[index].type = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Maximum Weight Passing',
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
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _vehicles[index].maxWeightController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter weight',
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
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vehicles[index].weightUnit,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'tons', child: Text('tons')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _vehicles[index].weightUnit = value;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'RC Book No.',
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
                  controller: _vehicles[index].rcBookController,
                  maxLength: 15,
                  inputFormatters: [
                    // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter RC book number',
                    hintStyle: TextStyle(
                      color: AppColors.textLight.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.upload_file,
              () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                );
                if (result != null) {
                  final file = File(result.files.single.path!);
                  final fileSize = await file.length();
                  if (fileSize > 1 * 1024 * 1024) {
                    SnackBarHelper.showError(
                      context,
                      'File size must be less than 1MB',
                    );
                    return;
                  }
                  setState(() {
                    _vehicles[index].rcBookFile = file;
                  });
                  SnackBarHelper.showSuccess(context, 'RC document selected');
                }
              },
              _vehicles[index].rcBookFile != null
                  ? AppColors.success
                  : AppColors.primary,
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.visibility_outlined,
              _vehicles[index].rcBookFile != null
                  ? () {
                      _viewFile(
                        _vehicles[index].rcBookFile,
                        '${_vehicles[index].typeName} - RC Book',
                      );
                    }
                  : null,
              _vehicles[index].rcBookFile != null
                  ? AppColors.primary
                  : AppColors.secondary.withOpacity(0.3),
            ),
          ],
        ),
        if (hasVehicleNumber)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Vehicle Images',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              _buildFullWidthImageButton(
                'Front Image',
                _vehicles[index].frontImage,
                () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png'],
                      );
                  if (result != null) {
                    final file = File(result.files.single.path!);
                    final fileSize = await file.length();
                    if (fileSize > 1 * 1024 * 1024) {
                      SnackBarHelper.showError(
                        context,
                        'Image size must be less than 1MB',
                      );
                      return;
                    }
                    setState(() {
                      _vehicles[index].frontImage = file;
                    });
                    SnackBarHelper.showSuccess(context, 'Front image selected');
                  }
                },
                _vehicles[index].frontImage != null
                    ? () {
                        _viewFile(
                          _vehicles[index].frontImage,
                          'Vehicle ${index + 1} Front',
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              _buildFullWidthImageButton(
                'Rear Image',
                _vehicles[index].rearImage,
                () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png'],
                      );
                  if (result != null) {
                    final file = File(result.files.single.path!);
                    final fileSize = await file.length();
                    if (fileSize > 1 * 1024 * 1024) {
                      SnackBarHelper.showError(
                        context,
                        'Image size must be less than 1MB',
                      );
                      return;
                    }
                    setState(() {
                      _vehicles[index].rearImage = file;
                    });
                    SnackBarHelper.showSuccess(context, 'Rear image selected');
                  }
                },
                _vehicles[index].rearImage != null
                    ? () {
                        _viewFile(
                          _vehicles[index].rearImage,
                          'Vehicle ${index + 1} Rear',
                        );
                      }
                    : null,
              ),
            ],
          ),
        SizedBox(height: 16),
        Divider(thickness: 3),
      ],
    );
  }

  Widget _buildFullWidthImageButton(
    String label,
    File? imageFile,
    VoidCallback onPick,
    VoidCallback? onView,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: imageFile != null
              ? AppColors.success.withOpacity(0.4)
              : AppColors.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (imageFile != null)
                  Text(
                    'Selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildIconButton(
            Icons.upload_file,
            onPick,
            imageFile != null ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            Icons.visibility_outlined,
            onView,
            imageFile != null
                ? AppColors.primary
                : AppColors.secondary.withOpacity(0.3),
          ),
        ],
      ),
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
    final isComplete = _isFormComplete();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isComplete ? _handleRegister : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isComplete ? AppColors.dark : Colors.grey,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: isComplete ? 4 : 0,
          shadowColor: AppColors.dark.withOpacity(0.4),
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
        ),
        child: Text(
          isComplete ? 'Register' : 'Complete All Fields to Register',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class VehicleEntry {
  final TextEditingController controller;
  final String typeName;
  final TextEditingController rcBookController;
  final TextEditingController maxWeightController;
  String type; // open or closed
  String weightUnit; // kg or tons
  File? file;
  File? rcBookFile;
  File? frontImage;
  File? rearImage;
  VehicleEntry({
    required this.controller,
    required this.typeName,
    required this.rcBookController,
    required this.maxWeightController,
    this.type = 'open',
    this.weightUnit = 'kg',
    this.file,
    this.rcBookFile,
    this.frontImage,
    this.rearImage,
  });
}
