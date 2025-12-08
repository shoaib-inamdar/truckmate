import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/models/booking_model.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerBookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const CustomerBookingDetailScreen({Key? key, required this.booking})
    : super(key: key);

  @override
  State<CustomerBookingDetailScreen> createState() =>
      _CustomerBookingDetailScreenState();
}

class _CustomerBookingDetailScreenState
    extends State<CustomerBookingDetailScreen> {
  File? _paymentScreenshot;
  bool _isLoading = false;
  bool _showPaymentSection = false;
  String? _assignedSellerName;
  final _sellerService = SellerService();

  @override
  void initState() {
    super.initState();
    // Show payment section if booking is accepted and payment not yet submitted
    final status = widget.booking.status.toLowerCase();
    final paymentStatus = widget.booking.paymentStatus?.toLowerCase() ?? '';
    _showPaymentSection = status == 'accepted' && paymentStatus != 'submitted';

    // Load assigned seller name if available
    if (widget.booking.assignedTo != null &&
        widget.booking.assignedTo!.isNotEmpty) {
      _loadAssignedSellerName(widget.booking.assignedTo!);
    }
  }

  Future<void> _loadAssignedSellerName(String sellerId) async {
    try {
      final name = await _sellerService.getSellerNameByUserId(sellerId);
      if (!mounted) return;
      setState(() {
        _assignedSellerName = name ?? sellerId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assignedSellerName = sellerId;
      });
    }
  }

  Future<void> _pickPaymentScreenshot() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
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
          _paymentScreenshot = file;
        });

        SnackBarHelper.showSuccess(context, 'Payment screenshot selected');
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Failed to pick file: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      SnackBarHelper.showError(context, 'Could not make call');
    }
  }

  Future<void> _handleConfirmJourney() async {
    if (_paymentScreenshot == null) {
      SnackBarHelper.showError(context, 'Please upload payment screenshot');
      return;
    }

    setState(() => _isLoading = true);

    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );

    final success = await bookingProvider.confirmPayment(
      bookingId: widget.booking.bookingId,
      paymentScreenshot: _paymentScreenshot!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(context, 'Payment submitted successfully!');
      Navigator.pop(context);
    } else {
      SnackBarHelper.showError(
        context,
        bookingProvider.errorMessage ?? 'Failed to submit payment',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Processing...',
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                'Register ID',
                                widget.booking.bookingId,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Vehicle',
                                widget.booking.vehicleType,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('Date', widget.booking.date),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Start Location',
                                widget.booking.startLocation,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Destination',
                                widget.booking.destination,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Bid amount',
                                widget.booking.bidAmount,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Assigned Seller',
                                _assignedSellerName ??
                                    (widget.booking.assignedTo?.isNotEmpty ==
                                            true
                                        ? widget.booking.assignedTo!
                                        : 'Not assigned'),
                              ),
                              const SizedBox(height: 16),
                              _buildContactRow(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAssignedSellerCard(),
                        const SizedBox(height: 16),
                        if (_showPaymentSection) ...[
                          _buildPaymentSection(),
                          const SizedBox(height: 16),
                          _buildConfirmButton(),
                        ],
                      ],
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
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.dark),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Booking Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15),
              children: [
                TextSpan(
                  text: '$label : ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Contact : ${widget.booking.phoneNumber}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ),
        InkWell(
          onTap: () => _makePhoneCall(widget.booking.phoneNumber),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone, color: AppColors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedSellerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned Seller',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _assignedSellerName ??
                    (widget.booking.assignedTo?.isNotEmpty == true
                        ? widget.booking.assignedTo!
                        : 'Not assigned'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Payment Section',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          // QR Code placeholder
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 150,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan QR Code to Pay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          InkWell(
            onTap: _pickPaymentScreenshot,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              decoration: BoxDecoration(
                color: _paymentScreenshot != null
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.light,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _paymentScreenshot != null
                      ? AppColors.success
                      : AppColors.secondary.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _paymentScreenshot != null
                        ? Icons.check_circle
                        : Icons.cloud_upload_outlined,
                    size: 50,
                    color: _paymentScreenshot != null
                        ? AppColors.success
                        : AppColors.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _paymentScreenshot != null
                        ? 'Screenshot uploaded successfully'
                        : 'Upload payment screenshot',
                    style: TextStyle(
                      fontSize: 16,
                      color: _paymentScreenshot != null
                          ? AppColors.success
                          : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleConfirmJourney,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.success.withOpacity(0.4),
        ),
        child: const Text(
          'Confirm Journey',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
