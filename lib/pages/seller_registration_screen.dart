import 'dart:io';
import 'package:flutter/material.dart';
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
  final Set<int> _selectedVehicles = {};
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _rcBookController = TextEditingController();
  final _panController = TextEditingController();
  final _licenseController = TextEditingController();
  final _gstController = TextEditingController();

  // Document files
  File? _rcBookFile;
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

  bool _isFormComplete() {
    // Check all text fields are filled
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _contactController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _rcBookController.text.trim().isEmpty ||
        _panController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty ||
        _gstController.text.trim().isEmpty) {
      return false;
    }

    // Check all documents are uploaded
    if (_rcBookFile == null ||
        _panFile == null ||
        _licenseFile == null ||
        _gstFile == null) {
      return false;
    }

    // Check at least one vehicle type is selected
    if (_selectedVehicles.isEmpty) {
      return false;
    }

    // Check at least one vehicle is added
    if (_vehicles.isEmpty) {
      return false;
    }

    // Check all vehicles have numbers
    for (var vehicle in _vehicles) {
      if (vehicle.controller.text.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _nameController.text = authProvider.user!.name;
      _addressController.text = authProvider.user!.address ?? '';
      _contactController.text = authProvider.user!.phone ?? '';
      _emailController.text = authProvider.user!.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _rcBookController.dispose();
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

    if (isPdf) {
      // Navigate to PDF viewer page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(file: file, fileName: fileName),
        ),
      );
    } else {
      // Show image in dialog
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
                // Image Content
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

        // Check file size (5MB max)
        if (fileSize > 5 * 1024 * 1024) {
          SnackBarHelper.showError(context, 'File size must be less than 5MB');
          return;
        }

        setState(() {
          switch (documentType) {
            case 'rcBook':
              _rcBookFile = file;
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
    if (_vehicles.length >= 2) {
      SnackBarHelper.showError(context, 'Maximum 2 vehicles allowed');
      return;
    }
    setState(() {
      _vehicles.add(VehicleEntry(controller: TextEditingController()));
    });
  }

  void _removeVehicle(int index) {
    setState(() {
      _vehicles[index].controller.dispose();
      _vehicles.removeAt(index);
    });
  }

  Future<File?> _combineVehicleImages(
    File? frontImage,
    File? rearImage,
    File? sideImage,
    int vehicleIndex,
    String userId,
  ) async {
    try {
      // Check if all three images are provided
      if (frontImage == null || rearImage == null || sideImage == null) {
        print('Skipping image combining: Not all images selected');
        print('Front: $frontImage, Rear: $rearImage, Side: $sideImage');
        return null;
      }

      print('Starting image combining for vehicle $vehicleIndex');

      // Decode images
      final frontBytes = await frontImage.readAsBytes();
      final rearBytes = await rearImage.readAsBytes();
      final sideBytes = await sideImage.readAsBytes();

      print(
        'Read image bytes - Front: ${frontBytes.length}, Rear: ${rearBytes.length}, Side: ${sideBytes.length}',
      );

      final front = img.decodeImage(frontBytes);
      final rear = img.decodeImage(rearBytes);
      final side = img.decodeImage(sideBytes);

      print(
        'Decoded images - Front: ${front != null}, Rear: ${rear != null}, Side: ${side != null}',
      );

      if (front == null || rear == null || side == null) {
        throw 'Failed to decode images. Front: ${front == null}, Rear: ${rear == null}, Side: ${side == null}';
      }

      // Resize images to same height (300px) while maintaining aspect ratio
      final targetHeight = 300;
      final resizedFront = img.copyResize(front, height: targetHeight);
      final resizedRear = img.copyResize(rear, height: targetHeight);
      final resizedSide = img.copyResize(side, height: targetHeight);

      print('Resized images successfully');

      // Calculate total width
      final totalWidth =
          resizedFront.width + resizedRear.width + resizedSide.width;

      // Create combined image (horizontal layout)
      final combined = img.Image(width: totalWidth, height: targetHeight);

      // Copy images side by side
      img.compositeImage(combined, resizedFront, dstX: 0, dstY: 0);
      img.compositeImage(
        combined,
        resizedRear,
        dstX: resizedFront.width,
        dstY: 0,
      );
      img.compositeImage(
        combined,
        resizedSide,
        dstX: resizedFront.width + resizedRear.width,
        dstY: 0,
      );

      // Encode to JPEG
      final combinedBytes = img.encodeJpg(combined, quality: 85);

      print(
        'Combined image created successfully, size: ${combinedBytes.length} bytes',
      );

      // Save to temporary file
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

  /// Validates if a file is a valid image that can be decoded
  Future<bool> _isValidImageFile(File? file) async {
    if (file == null) return false;

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        print('Invalid image: File is empty');
        return false;
      }

      // Try to decode the image
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

  /// Validates all three images for a vehicle before combining
  Future<bool> _validateVehicleImages(
    File? frontImage,
    File? rearImage,
    File? sideImage,
    int vehicleIndex,
  ) async {
    print('Validating images for vehicle $vehicleIndex...');

    final isFrontValid = await _isValidImageFile(frontImage);
    final isRearValid = await _isValidImageFile(rearImage);
    final isSideValid = await _isValidImageFile(sideImage);

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

    if (!isSideValid) {
      SnackBarHelper.showError(
        context,
        'Vehicle ${vehicleIndex + 1}: Side image is invalid or corrupted',
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

      if (_rcBookFile != null) {
        aadharDocId = await sellerProvider.uploadDocument(
          _rcBookFile!,
          'rcbook_${authProvider.user!.id}.${_rcBookFile!.path.split('.').last}',
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

      // Upload vehicle documents and images
      List<VehicleInfo> vehicleInfoList = [];
      for (int i = 0; i < _vehicles.length; i++) {
        String? combinedImageId;

        try {
          print(
            'Processing vehicle $i with number: ${_vehicles[i].controller.text.trim()}',
          );

          // Validate images before combining
          final imagesValid = await _validateVehicleImages(
            _vehicles[i].frontImage,
            _vehicles[i].rearImage,
            _vehicles[i].sideImage,
            i,
          );

          if (!imagesValid) {
            SnackBarHelper.showError(
              context,
              'Vehicle ${i + 1} has one or more invalid images. Please reselect.',
            );
            return;
          }

          // Combine the three images into one
          final combinedImage = await _combineVehicleImages(
            _vehicles[i].frontImage,
            _vehicles[i].rearImage,
            _vehicles[i].sideImage,
            i,
            authProvider.user!.id,
          );

          // Upload the combined image
          if (combinedImage != null) {
            print('Uploading combined image for vehicle $i...');
            combinedImageId = await sellerProvider.uploadDocument(
              combinedImage,
              'vehicle_${i}_combined_${authProvider.user!.id}.jpg',
            );
            print(
              'Successfully uploaded combined image for vehicle $i. ID: $combinedImageId',
            );

            // Delete temporary combined file
            await combinedImage.delete();
          } else {
            print(
              'Warning: Combined image is null for vehicle $i. This may indicate missing or invalid images.',
            );
            SnackBarHelper.showError(
              context,
              'Failed to combine images for vehicle ${i + 1}. Please check image formats.',
            );
            return;
          }
        } catch (e) {
          print('Error processing vehicle $i images: $e');
          SnackBarHelper.showError(
            context,
            'Error processing vehicle ${i + 1} images: $e',
          );
          rethrow;
        }

        vehicleInfoList.add(
          VehicleInfo(
            vehicleNumber: _vehicles[i].controller.text.trim(),
            documentId: combinedImageId,
            frontImageId: null,
            rearImageId: null,
            sideImageId: null,
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
        email: _emailController.text.trim(),
        rcBookNo: _rcBookController.text.trim(),
        rcDocumentId: aadharDocId,
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
            onPressed: () async {
              // Save seller pending status
              final prefs = await SharedPreferences.getInstance();
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await prefs.setString('seller_status', 'pending');
              await prefs.setString('seller_user_id', authProvider.user!.id);

              // Delete the current anonymous session
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
                              'RC Book No.',
                              'Enter RC book number',
                              _rcBookController,
                              'rcBook',
                              _rcBookFile != null,
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
    FormFieldValidator<String>? validator,
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
                        case 'rcBook':
                          fileToView = _rcBookFile;
                          fileName = 'RC Book';
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
                    if (_selectedVehicles.length >= 2) {
                      SnackBarHelper.showError(
                        context,
                        'Maximum 2 vehicle types allowed',
                      );
                      return;
                    }
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
    final hasVehicleNumber = _vehicles[index].controller.text.trim().isNotEmpty;

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
        // Vehicle number field - Full width
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: _vehicles[index].controller,
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
            ),
          ),
        ),
        // Vehicle Images Section - Show only when vehicle number is entered
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
              // Front Image - Full width button
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

                    if (fileSize > 5 * 1024 * 1024) {
                      SnackBarHelper.showError(
                        context,
                        'Image size must be less than 5MB',
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
              // Rear Image - Full width button
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

                    if (fileSize > 5 * 1024 * 1024) {
                      SnackBarHelper.showError(
                        context,
                        'Image size must be less than 5MB',
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
              const SizedBox(height: 12),
              // Side Image - Full width button
              _buildFullWidthImageButton(
                'Side Image',
                _vehicles[index].sideImage,
                () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png'],
                      );

                  if (result != null) {
                    final file = File(result.files.single.path!);
                    final fileSize = await file.length();

                    if (fileSize > 5 * 1024 * 1024) {
                      SnackBarHelper.showError(
                        context,
                        'Image size must be less than 5MB',
                      );
                      return;
                    }

                    setState(() {
                      _vehicles[index].sideImage = file;
                    });
                    SnackBarHelper.showSuccess(context, 'Side image selected');
                  }
                },
                _vehicles[index].sideImage != null
                    ? () {
                        _viewFile(
                          _vehicles[index].sideImage,
                          'Vehicle ${index + 1} Side',
                        );
                      }
                    : null,
              ),
            ],
          ),
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
  File? file;
  File? frontImage;
  File? rearImage;
  File? sideImage;

  VehicleEntry({
    required this.controller,
    this.file,
    this.frontImage,
    this.rearImage,
    this.sideImage,
  });
}
