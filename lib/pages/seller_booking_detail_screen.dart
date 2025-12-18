import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/models/booking_model.dart';
import 'package:truckmate/pages/shipping_map_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/services/booking_service.dart';
import 'package:truckmate/services/business_transporter_service.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';

/// Seller Booking Detail Screen
///
/// Shows booking details for sellers/transporters with ability to:
/// - View booking information
/// - Accept/Reject bookings
/// - Start shipping (opens map screen and updates status to in_transit)
class SellerBookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const SellerBookingDetailScreen({Key? key, required this.booking})
    : super(key: key);

  @override
  State<SellerBookingDetailScreen> createState() =>
      _SellerBookingDetailScreenState();
}

class _SellerBookingDetailScreenState extends State<SellerBookingDetailScreen> {
  bool _isLoading = false;
  Timer? _refreshTimer;
  late BookingModel _currentBooking;
  final BookingService _bookingService = BookingService();
  final BusinessTransporterService _businessTransporterService =
      BusinessTransporterService();
  final SellerService _sellerService = SellerService();

  // Driver assignment form controllers
  final _driverNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _driverContactController = TextEditingController();
  String? _transporterType;
  bool _driverAssigned = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    _loadTransporterType();
    _checkDriverAssignment();
    // Start auto-refresh timer - refresh every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshBookingData();
    });
    print('🔄 Auto-refresh started for booking ${widget.booking.bookingId}');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driverNameController.dispose();
    _vehicleNumberController.dispose();
    _driverContactController.dispose();
    print('⏹️ Auto-refresh stopped for booking ${widget.booking.bookingId}');
    super.dispose();
  }

  Future<void> _loadTransporterType() async {
    try {
      final seller = await _sellerService.getSellerByUserId(
        _currentBooking.assignedTo ?? '',
      );
      if (seller != null && mounted) {
        setState(() {
          _transporterType = seller['transporter_type'] as String?;
        });
        print('Transporter type: $_transporterType');
      }
    } catch (e) {
      print('Error loading transporter type: $e');
    }
  }

  Future<void> _checkDriverAssignment() async {
    try {
      final driver = await _businessTransporterService.getDriverByBookingId(
        _currentBooking.id,
      );
      if (driver != null && mounted) {
        setState(() {
          _driverAssigned = true;
        });
      }
    } catch (e) {
      print('Error checking driver assignment: $e');
    }
  }

  Future<void> _refreshBookingData() async {
    try {
      final updatedBooking = await _bookingService.getBooking(
        widget.booking.id,
      );
      if (mounted) {
        setState(() {
          _currentBooking = updatedBooking;
        });
        print(
          '✅ Booking refreshed: ${_currentBooking.bookingId}, Journey State: ${_currentBooking.journeyState}',
        );
      }
    } catch (e) {
      print('❌ Error refreshing booking: $e');
      // Don't show error to user, just log it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('Booking ${_currentBooking.bookingId}'),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Processing...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBadge(),
              const SizedBox(height: 20),
              _buildBookingInfoCard(),
              const SizedBox(height: 16),
              _buildCustomerInfoCard(),
              const SizedBox(height: 16),
              _buildRouteInfoCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _currentBooking.bookingStatus ?? _currentBooking.status;
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            _getStatusText(status),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return AppColors.success;
      case 'in_transit':
        return AppColors.warning;
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.secondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'in_transit':
        return Icons.local_shipping;
      case 'delivered':
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'ACCEPTED';
      case 'in_transit':
        return 'IN TRANSIT';
      case 'delivered':
      case 'completed':
        return 'DELIVERED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'PENDING';
    }
  }

  Widget _buildBookingInfoCard() {
    return _buildCard(
      title: 'Booking Information',
      icon: Icons.assignment,
      children: [
        _buildInfoRow(
          'Booking ID',
          _currentBooking.bookingId,
          Icons.confirmation_number,
        ),
        const SizedBox(height: 12),

        _buildInfoRow('Date', _currentBooking.date, Icons.calendar_today),
        const SizedBox(height: 12),
        _buildInfoRow('Load', _currentBooking.load, Icons.scale),
        if (_currentBooking.loadDescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            'Description',
            _currentBooking.loadDescription,
            Icons.description,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCustomerInfoCard() {
    return _buildCard(
      title: 'Customer Information',
      icon: Icons.person,
      children: [
        _buildInfoRow('Name', _currentBooking.fullName, Icons.account_circle),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Phone',
                _currentBooking.phoneNumber,
                Icons.phone,
              ),
            ),
            GestureDetector(
              onTap: () async {
                try {
                  await FlutterPhoneDirectCaller.callNumber(
                    _currentBooking.phoneNumber,
                  );
                } catch (e) {
                  if (!mounted) return;
                  SnackBarHelper.showError(context, 'Could not place call');
                }
              },
              child: Container(
                height: 28,
                width: 28,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/call.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRouteInfoCard() {
    return _buildCard(
      title: 'Route Details',
      icon: Icons.route,
      children: [
        _buildRoutePoint(
          'Start Location',
          _currentBooking.startLocation,
          AppColors.success,
          Icons.my_location,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Icon(
            Icons.arrow_downward,
            color: AppColors.secondary,
            size: 24,
          ),
        ),
        const SizedBox(height: 16),
        _buildRoutePoint(
          'Destination',
          _currentBooking.destination,
          AppColors.danger,
          Icons.location_on,
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Icon(icon, color: AppColors.success, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.dark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutePoint(
    String label,
    String location,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.dark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bookingStatus =
        _currentBooking.bookingStatus ?? _currentBooking.status;
    final journeyState = _currentBooking.journeyState ?? '';
    final isPending = bookingStatus.toLowerCase() == 'pending';
    final isAccepted = bookingStatus.toLowerCase() == 'accepted';
    final isInTransit = bookingStatus.toLowerCase() == 'in_transit';
    final isShippingDone = journeyState.toLowerCase() == 'shipping_done';
    final isPaymentDone = journeyState.toLowerCase() == 'payment_done';

    // If business_company and payment_done, show driver assignment form
    if (_transporterType == 'business_company' &&
        isPaymentDone &&
        !_driverAssigned) {
      return _buildDriverAssignmentForm();
    }

    // If journey state is shipping_done, show Complete Journey button
    if (isShippingDone) {
      return Column(
        children: [
          _buildViewMapButton(),
          const SizedBox(height: 12),
          _buildCompleteJourneyButton(),
        ],
      );
    }

    if (isInTransit) {
      // If already in transit, show "View Map" and "Complete Journey" buttons
      return Column(
        children: [
          _buildViewMapButton(),
          const SizedBox(height: 12),
          _buildCompleteJourneyButton(),
        ],
      );
    }

    if (isAccepted) {
      // If accepted and payment confirmed, show "Start Shipping" button
      return _buildStartShippingButton();
    }

    // if (isPending) {
    //   // If pending, show Accept/Reject buttons
    //   return _buildAcceptRejectButtons();
    // }

    // For other statuses (rejected, completed, etc.)
    return const SizedBox.shrink();
  }

  Widget _buildStartShippingButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleStartShipping(),
        icon: const Icon(Icons.local_shipping, size: 24),
        label: const Text(
          'Start Shipping',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.success.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildViewMapButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openMapScreen(),
        icon: const Icon(Icons.map, size: 24),
        label: const Text(
          'View Map',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildCompleteJourneyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleCompleteJourney(),
        icon: const Icon(Icons.check_circle, size: 24),
        label: const Text(
          'Complete Journey',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.success.withOpacity(0.4),
        ),
      ),
    );
  }

  Future<void> _handleCompleteJourney() async {
    // Show OTP input dialog
    final otp = await _showOtpDialog();

    if (otp == null || otp.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );

    final updatedBooking = await bookingProvider.completeJourney(
      bookingId: _currentBooking.id,
      completionOtp: otp.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (updatedBooking != null) {
      SnackBarHelper.showSuccess(context, 'Journey completed successfully!');
      Navigator.pop(context, true);
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to complete journey',
      );
    }
  }

  Future<String?> _showOtpDialog() async {
    final TextEditingController otpController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Enter Completion OTP',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please enter the completion OTP provided by the customer to complete this journey.',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Completion OTP',
                hintText: 'Enter 6-digit OTP',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, otpController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    final confirmed = await _showConfirmationDialog(
      'Accept Booking',
      'Are you sure you want to accept this booking?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );

    final sellerId = authProvider.user?.id;
    if (sellerId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Seller ID not found. Please login again.',
        );
      }
      return;
    }

    // Assign the booking to this seller and update status
    final updatedBooking = await bookingProvider.assignBookingToSeller(
      bookingId: _currentBooking.id,
      sellerId: sellerId,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (updatedBooking != null) {
      SnackBarHelper.showSuccess(context, 'Booking accepted successfully!');
      Navigator.pop(context, true); // Return to previous screen with success
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to accept booking',
      );
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await _showConfirmationDialog(
      'Reject Booking',
      'Are you sure you want to reject this booking?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    final success = await bookingProvider.updateBookingStatus(
      bookingId: _currentBooking.id,
      status: 'rejected',
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(context, 'Booking rejected');
      Navigator.pop(context, true);
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to reject booking',
      );
    }
  }

  Future<void> _handleStartShipping() async {
    final confirmed = await _showConfirmationDialog(
      'Start Shipping',
      'This will mark the shipment as in transit and open the live map. Make sure location is enabled on your device.\n\nContinue?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    final updatedBooking = await bookingProvider.startShipping(
      bookingId: _currentBooking.id,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (updatedBooking != null) {
      SnackBarHelper.showSuccess(context, 'Shipping started!');

      // Open the map screen
      _openMapScreen(booking: updatedBooking);
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to start shipping',
      );
    }
  }

  void _openMapScreen({BookingModel? booking}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShippingMapScreen(booking: booking ?? _currentBooking),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAssignmentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Assign Driver',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDriverTextField(
            'Driver Name',
            'Enter driver name',
            _driverNameController,
          ),
          const SizedBox(height: 12),
          _buildDriverTextField(
            'Vehicle Number',
            'Enter vehicle number',
            _vehicleNumberController,
            maxLength: 15,
            inputFormatters: [
              // FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
          ),
          const SizedBox(height: 12),
          _buildDriverTextField(
            'Contact Number',
            'Enter contact number',
            _driverContactController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleDriverAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Confirm Assignment',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTextField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
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
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Future<void> _handleDriverAssignment() async {
    if (_driverNameController.text.trim().isEmpty ||
        _vehicleNumberController.text.trim().isEmpty ||
        _driverContactController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please fill all fields');
      return;
    }

    if (_driverContactController.text.trim().length != 10) {
      SnackBarHelper.showError(context, 'Contact must be 10 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the currently authenticated user's ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;

      if (currentUserId == null) {
        throw 'User not authenticated';
      }

      print('Assigning driver with user_id: $currentUserId');

      await _businessTransporterService.assignDriver(
        driverName: _driverNameController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        contact: _driverContactController.text.trim(),
        userId: currentUserId,
        bookingId: _currentBooking.id,
      );

      setState(() {
        _isLoading = false;
        _driverAssigned = true;
      });

      if (!mounted) return;
      SnackBarHelper.showSuccess(context, 'Driver assigned successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Error: $e');
    }
  }
}
