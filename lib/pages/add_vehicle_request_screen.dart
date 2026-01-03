import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/services/vehicle_request_service.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';

class AddVehicleRequestScreen extends StatefulWidget {
  final int currentVehicleCount;

  const AddVehicleRequestScreen({Key? key, required this.currentVehicleCount})
    : super(key: key);

  @override
  State<AddVehicleRequestScreen> createState() =>
      _AddVehicleRequestScreenState();
}

class _AddVehicleRequestScreenState extends State<AddVehicleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _sellerService = SellerService();
  final _vehicleRequestService = VehicleRequestService();

  final List<VehicleEntry> _vehicles = [];
  final List<String> vehicleTypesList = [
    'Truck',
    'Tempo',
    'Mini Truck',
    'Container',
    'Trailer',
    'Mini Pickup',
  ];

  final Map<String, int> _vehicleQuantities = {
    'Truck': 0,
    'Tempo': 0,
    'Mini Truck': 0,
    'Container': 0,
    'Trailer': 0,
    'Mini Pickup': 0,
  };

  static const int _maxTotalVehicles = 10;

  int _currentVehicleCount = 0; // Will be loaded from database
  List<Map<String, dynamic>> _existingVehicles =
      []; // Will be loaded from database

  @override
  void initState() {
    super.initState();
    _loadExistingVehicles();
  }

  Future<void> _loadExistingVehicles() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;

      if (userId == null) return;

      // Fetch seller credentials to get current vehicle count and list
      final sellerService = SellerService();
      final originalUserId = await sellerService.getOriginalUserIdByEmail(
        authProvider.user?.email ?? '',
      );

      if (originalUserId == null) return;

      final credentials = await sellerService.getSellerCredentials(
        originalUserId,
      );

      if (credentials != null && mounted) {
        setState(() {
          // Parse vehicle count
          _currentVehicleCount =
              int.tryParse(credentials['vehicle_count']?.toString() ?? '0') ??
              0;

          // Parse existing vehicles if available
          final vehiclesStr = credentials['vehicles'];
          if (vehiclesStr != null && vehiclesStr.isNotEmpty) {
            // Try to parse as JSON string
            try {
              _existingVehicles = List<Map<String, dynamic>>.from([]);
            } catch (e) {
              print('Error parsing vehicles: $e');
            }
          }
        });
      }
    } catch (e) {
      print('Error loading existing vehicles: $e');
    }
  }

  int get _totalVehicles {
    return _vehicleQuantities.values.fold(0, (sum, count) => sum + count);
  }

  int get _remainingSlots {
    return _maxTotalVehicles - _currentVehicleCount - _totalVehicles;
  }

  void _updateVehicleQuantity(String type, int newCount) {
    final currentTotal = _currentVehicleCount + _totalVehicles;
    final currentCount = _vehicleQuantities[type] ?? 0;
    final difference = newCount - currentCount;

    if (currentTotal + difference > _maxTotalVehicles) {
      SnackBarHelper.showError(
        context,
        'Maximum $_maxTotalVehicles vehicles allowed total',
      );
      return;
    }

    setState(() {
      _vehicleQuantities[type] = newCount;
      _syncVehicleEntries();
    });
  }

  void _syncVehicleEntries() {
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

      for (int i = count; i < existing.length; i++) {
        existing[i].controller.dispose();
        existing[i].rcBookController.dispose();
        existing[i].maxWeightController.dispose();
      }
    }

    _vehicles.clear();
    _vehicles.addAll(newVehicles);
  }

  @override
  void dispose() {
    for (var vehicle in _vehicles) {
      vehicle.controller.dispose();
      vehicle.rcBookController.dispose();
      vehicle.maxWeightController.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showError(context, 'Please fill all required fields');
      return;
    }

    if (_totalVehicles == 0) {
      SnackBarHelper.showError(context, 'Please add at least one vehicle');
      return;
    }

    for (var vehicle in _vehicles) {
      if (vehicle.controller.text.trim().isEmpty ||
          vehicle.rcBookController.text.trim().isEmpty ||
          vehicle.maxWeightController.text.trim().isEmpty ||
          vehicle.rcBookFile == null ||
          vehicle.frontImage == null ||
          vehicle.rearImage == null) {
        SnackBarHelper.showError(
          context,
          'Please complete all vehicle details and upload images',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final appwriteUserId = authProvider.user?.id;
      final email = authProvider.user?.email;

      if (appwriteUserId == null || email == null) {
        throw 'User not authenticated';
      }

      // Get the original user_id from seller_request table
      final originalUserId = await _sellerService.getOriginalUserIdByEmail(
        email,
      );

      if (originalUserId == null) {
        throw 'Could not find seller record';
      }

      // Upload documents and prepare vehicle data
      List<Map<String, dynamic>> vehiclesData = [];

      for (var vehicle in _vehicles) {
        final rcBookId = await _sellerService.uploadDocument(
          vehicle.rcBookFile!,
          appwriteUserId,
        );
        final frontImageId = await _sellerService.uploadDocument(
          vehicle.frontImage!,
          appwriteUserId,
        );
        final rearImageId = await _sellerService.uploadDocument(
          vehicle.rearImage!,
          appwriteUserId,
        );

        vehiclesData.add({
          'type_name': vehicle.typeName,
          'vehicle_number': vehicle.controller.text.trim(),
          'vehicle_type': vehicle.vehicleType,
          'rc_book_no': vehicle.rcBookController.text.trim(),
          'max_weight': vehicle.maxWeightController.text.trim(),
          'rc_book_id': rcBookId,
          'front_image_id': frontImageId,
          'rear_image_id': rearImageId,
        });
      }

      // Convert vehicles to JSON strings for Appwrite storage (max 350 chars per string)
      final serializedVehicles = vehiclesData.map((v) {
        // Format: vehicle_number|type_name|type|rc_book_no|max_weight|rc_book_id|front_image_id|rear_image_id|||
        final jsonStr =
            '${v['vehicle_number']}|'
            '${v['type_name']}|'
            '${v['vehicle_type']}|'
            '${v['rc_book_no']}||'
            '${v['max_weight']}|'
            '${v['rc_book_id']}|'
            '${v['front_image_id']}|'
            '${v['rear_image_id']}|'
            '|'
            '|';
        return jsonStr;
      }).toList();

      // Verify appwrite user ID is still valid

      await _vehicleRequestService.createVehicleRequest(
        userId: originalUserId,
        appwriteUserId: appwriteUserId,
        vehicles: serializedVehicles,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        'Vehicle request submitted successfully!',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Add Vehicle Request'),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Submitting request...',
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current Vehicles: ${widget.currentVehicleCount}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available Slots: $_remainingSlots',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _remainingSlots > 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildVehicleSelector(),
                const SizedBox(height: 16),
                ..._buildVehicleList(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _totalVehicles > 0 ? _submitRequest : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark,
                      disabledBackgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                'Select Vehicle Types',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...vehicleTypesList.map((type) => _buildVehicleTypeSpinner(type)),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeSpinner(String type) {
    final count = _vehicleQuantities[type] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping,
                color: AppColors.secondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                type,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: count > 0
                    ? () => _updateVehicleQuantity(type, count - 1)
                    : null,
                icon: const Icon(Icons.remove_circle),
                color: AppColors.danger,
                iconSize: 28,
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              IconButton(
                onPressed: _remainingSlots > 0
                    ? () => _updateVehicleQuantity(type, count + 1)
                    : null,
                icon: const Icon(Icons.add_circle),
                color: AppColors.success,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVehicleList() {
    return _vehicles.asMap().entries.map((entry) {
      final index = entry.key;
      final vehicle = entry.value;
      return _buildVehicleEntry(vehicle, index);
    }).toList();
  }

  Widget _buildVehicleEntry(VehicleEntry vehicle, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${vehicle.typeName} #${index + 1}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vehicle.typeName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVehicleTextField(
            'Vehicle Number',
            'Enter vehicle number',
            vehicle.controller,
            maxLength: 15,
            inputFormatters: [
              // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
          ),
          const SizedBox(height: 12),
          _buildVehicleTextField(
            'RC Book Number',
            'Enter RC book number',
            vehicle.rcBookController,
            maxLength: 20,
            inputFormatters: [
              // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
          ),
          const SizedBox(height: 12),
          _buildVehicleTextField(
            'Max Weight (in tons)',
            'Enter maximum weight capacity',
            vehicle.maxWeightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          _buildVehicleTypeSelector(vehicle),
          const SizedBox(height: 16),
          _buildDocumentUpload(
            'RC Book',
            vehicle.rcBookFile,
            () => _pickDocument(vehicle, 'rc_book'),
          ),
          const SizedBox(height: 12),
          _buildImageUpload(
            'Front Image',
            vehicle.frontImage,
            () => _pickImage(vehicle, 'front'),
          ),
          const SizedBox(height: 12),
          _buildImageUpload(
            'Rear Image',
            vehicle.rearImage,
            () => _pickImage(vehicle, 'rear'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeSelector(VehicleEntry vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Open'),
                value: 'open',
                groupValue: vehicle.vehicleType,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      vehicle.vehicleType = value;
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Closed'),
                value: 'closed',
                groupValue: vehicle.vehicleType,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      vehicle.vehicleType = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleTextField(
    String label,
    String hint,
    TextEditingController controller, {
    int? maxLength,
    TextInputType? keyboardType,
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
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
            filled: true,
            fillColor: AppColors.light,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDocumentUpload(String label, File? file, VoidCallback onTap) {
    return Column(
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
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: file != null
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.light,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: file != null
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.secondary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Icons.check_circle : Icons.upload_file,
                  color: file != null ? AppColors.success : AppColors.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file != null ? 'Document uploaded' : 'Upload document',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: file != null ? AppColors.success : AppColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUpload(String label, File? file, VoidCallback onTap) {
    return Column(
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
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: file != null
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.light,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: file != null
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.secondary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Icons.check_circle : Icons.add_photo_alternate,
                  color: file != null ? AppColors.success : AppColors.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file != null ? 'Image uploaded' : 'Upload image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: file != null ? AppColors.success : AppColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDocument(VehicleEntry vehicle, String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          SnackBarHelper.showError(context, 'File size must be less than 5MB');
          return;
        }

        setState(() {
          vehicle.rcBookFile = file;
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error picking file: $e');
    }
  }

  Future<void> _pickImage(VehicleEntry vehicle, String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          SnackBarHelper.showError(context, 'Image size must be less than 5MB');
          return;
        }

        setState(() {
          if (type == 'front') {
            vehicle.frontImage = file;
          } else {
            vehicle.rearImage = file;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error picking image: $e');
    }
  }
}

class VehicleEntry {
  final TextEditingController controller;
  final String typeName;
  final TextEditingController rcBookController;
  final TextEditingController maxWeightController;
  String vehicleType = 'closed'; // open or closed
  File? rcBookFile;
  File? frontImage;
  File? rearImage;

  VehicleEntry({
    required this.controller,
    required this.typeName,
    required this.rcBookController,
    required this.maxWeightController,
    this.rcBookFile,
    this.frontImage,
    this.rearImage,
    this.vehicleType = 'closed',
  });
}
