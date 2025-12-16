import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';

class BookTransportScreen extends StatefulWidget {
  const BookTransportScreen({super.key});
  @override
  State<BookTransportScreen> createState() => _BookTransportScreenState();
}

class _BookTransportScreenState extends State<BookTransportScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedVehicle;
  int activeIndex = 0;
  bool _isLoading = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateController = TextEditingController();
  final _loadNumberController = TextEditingController();
  String _loadUnit = 'kg';
  final _loadDescriptionController = TextEditingController();
  final _startLocationController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fixedLocationController = TextEditingController();
  final _bidAmountController = TextEditingController();
  final List<String> vehicleTypesList = [
    'Truck',
    'Tempo',
    'Mini Truck',
    'Container',
    'Trailer',
    'Mini Pickup',
  ];
  final widgets = [
    Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/Cargo1.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/Cargo2.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/Cargo3.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/Cargo4.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
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
      _phoneController.text = authProvider.user!.phone ?? '';
      _addressController.text = authProvider.user!.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dateController.dispose();
    _loadNumberController.dispose();
    _loadDescriptionController.dispose();
    _startLocationController.dispose();
    _destinationController.dispose();
    _fixedLocationController.dispose();
    _bidAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.dark,
              onSurface: AppColors.dark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      SnackBarHelper.showError(context, 'Please fill all required fields');
      return;
    }
    if (_selectedVehicle == null) {
      SnackBarHelper.showError(context, 'Please select a vehicle type');
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    if (authProvider.user == null) {
      SnackBarHelper.showError(context, 'Please login to continue');
      return;
    }
    setState(() => _isLoading = true);
    final selectedVehicleType = vehicleTypesList[_selectedVehicle!];

    final load = _loadNumberController.text.trim().isNotEmpty
        ? '${_loadNumberController.text.trim()} $_loadUnit'
        : '';

    final success = await bookingProvider.createBooking(
      userId: authProvider.user!.id,
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      date: _dateController.text.trim(),
      load: load,
      loadDescription: _loadDescriptionController.text.trim(),
      startLocation: _startLocationController.text.trim(),
      destination: _destinationController.text.trim(),
      fixedLocation: _fixedLocationController.text.trim().isNotEmpty
          ? _fixedLocationController.text.trim()
          : null,
      bidAmount: '₹${_bidAmountController.text.trim()}',
      vehicleType: selectedVehicleType,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (success) {
      SnackBarHelper.showSuccess(
        context,
        'Booking submitted successfully! Booking ID: ${bookingProvider.currentBooking?.bookingId}',
      );
      _showBookingConfirmationDialog(
        bookingProvider.currentBooking?.bookingId ?? '',
      );
      _clearForm();
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to submit booking',
      );
    }
  }

  void _showBookingConfirmationDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            SizedBox(width: 12),
            Text('Booking Confirmed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your transport booking has been submitted successfully.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Booking ID: ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    bookingId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please save this booking ID for future reference.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

  void _clearForm() {
    _dateController.clear();
    _loadNumberController.clear();
    setState(() => _loadUnit = 'kg');
    _loadDescriptionController.clear();
    _startLocationController.clear();
    _destinationController.clear();
    _fixedLocationController.clear();
    _bidAmountController.clear();
    setState(() {
      _selectedVehicle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Submitting booking...',
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15.0),
                          color: AppColors.light,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                CarouselSlider.builder(
                                  itemCount: widgets.length,
                                  itemBuilder: (context, index, realIndex) {
                                    var assetImage = widgets[index];
                                    return buildImage(assetImage, index);
                                  },
                                  options: CarouselOptions(
                                    onPageChanged: (index, reason) =>
                                        setState(() => activeIndex = index),
                                    enlargeStrategy:
                                        CenterPageEnlargeStrategy.scale,
                                    enlargeCenterPage: true,
                                    height: 180,
                                    autoPlay: true,
                                    autoPlayInterval: Duration(seconds: 2),
                                  ),
                                ),
                                buildIndicator(),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Text(
                                'Book Your Transport',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fill in the details to get started',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.dark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              'Full Name',
                              'Enter your name',
                              Icons.person_outline,
                              _nameController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Contact Number',
                              'Enter your contact number',
                              Icons.phone_outlined,
                              _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Address',
                              'Enter your address',
                              Icons.location_on_outlined,
                              _addressController,
                            ),
                            const SizedBox(height: 16),
                            _buildDateField(),
                            const SizedBox(height: 16),
                            _buildLoadField(),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Load Description',
                              'Enter description',
                              Icons.description_outlined,
                              _loadDescriptionController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Start Location',
                              'Enter your location',
                              Icons.my_location_outlined,
                              _startLocationController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Destination',
                              'Enter destination',
                              Icons.location_city_outlined,
                              _destinationController,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Preferred traveling route',
                              'Enter Preferred traveling route',
                              Icons.place_outlined,
                              _fixedLocationController,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Your Bid Amount',
                              'Enter bid value',
                              Icons.currency_rupee,
                              _bidAmountController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 24),
                            _buildVehicleSelector(),
                            const SizedBox(height: 28),
                            _buildSubmitButton(),
                            const SizedBox(height: 24),
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

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _dateController,
            readOnly: true,
            onTap: _selectDate,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a date';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Select date',
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.secondary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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

  Widget _buildLoadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Load',
          style: TextStyle(
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
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _loadNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter load',
                    hintStyle: TextStyle(
                      color: AppColors.textLight.withOpacity(0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.scale_outlined,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _loadUnit,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: ['kg', 'tons'].map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _loadUnit = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  buildIndicator() => AnimatedSmoothIndicator(
    activeIndex: activeIndex,
    count: widgets.length,
    effect: JumpingDotEffect(
      spacing: 12,
      verticalOffset: 10.0,
      dotHeight: 10,
      dotWidth: 10,
      activeDotColor: AppColors.primary,
      dotColor: Color(0xffdadada),
    ),
  );
  Widget _buildVehicleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Vehicle Type',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
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
            final isSelected = _selectedVehicle == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVehicle = index;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.secondary.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
        child: const Text(
          'Submit Request',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget buildImage(assetImage, int index) => Container(
    child: InkWell(
      onTap: () {},
      child: Container(child: assetImage, decoration: BoxDecoration()),
    ),
  );
}
