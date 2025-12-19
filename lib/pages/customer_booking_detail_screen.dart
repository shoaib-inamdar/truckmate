import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:truckmate/models/booking_model.dart';
import 'package:truckmate/models/business_transporter_model.dart';
import 'package:truckmate/pages/customer_chat_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/services/business_transporter_service.dart';
import 'package:truckmate/widgets/loading_overlay.dart';
import 'package:truckmate/widgets/snackbar_helper.dart';
import 'package:truckmate/widgets/delivery_timeline.dart';
// import 'package:url_launcher/url_launcher.dart';

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
  String? _transporterType;
  BusinessTransporterModel? _driverInfo;
  final _sellerService = SellerService();
  final _businessTransporterService = BusinessTransporterService();
  final TextEditingController _transactionIdController =
      TextEditingController();
  Timer? _refreshTimer;
  BookingModel? _currentBooking;
  BookingProvider? _bookingProvider;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    // Store the provider reference
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    // Get and store the user ID
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userId = authProvider.user?.id;

    final status = widget.booking.status.toLowerCase();
    final paymentStatus = widget.booking.paymentStatus?.toLowerCase() ?? '';
    final bookingStatus = widget.booking.bookingStatus?.toLowerCase() ?? '';
    _showPaymentSection =
        status == 'accepted' &&
        (paymentStatus != 'submitted' ||
            paymentStatus == 'rejected' ||
            bookingStatus == 'rejected');
    if (widget.booking.assignedTo != null &&
        widget.booking.assignedTo!.isNotEmpty) {
      _loadAssignedSellerName(widget.booking.assignedTo!);
      _loadTransporterInfo(widget.booking.assignedTo!);
    }
    // Start auto-refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshBookingData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _refreshBookingData() async {
    if (!mounted || _bookingProvider == null || _userId == null) return;
    try {
      await _bookingProvider!.loadUserBookings(_userId!);
      if (!mounted) return;
      final updatedBooking = _bookingProvider!.bookings.firstWhere(
        (b) => b.bookingId == widget.booking.bookingId,
        orElse: () => widget.booking,
      );
      if (mounted) {
        setState(() {
          _currentBooking = updatedBooking;
        });

        // Reload transporter info if booking has an assigned seller
        if (_currentBooking?.assignedTo != null &&
            _currentBooking!.assignedTo!.isNotEmpty) {
          _loadTransporterInfo(_currentBooking!.assignedTo!);
        }
      }
    } catch (e) {
      // Silently fail refresh
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

  Future<void> _loadTransporterInfo(String sellerId) async {
    try {
      final seller = await _sellerService.getSellerByUserId(sellerId);
      if (seller != null && mounted) {
        setState(() {
          _transporterType = seller['transporter_type'] as String?;
        });

        if (_transporterType == 'business_company' && _currentBooking != null) {
          final driver = await _businessTransporterService.getDriverByBookingId(
            _currentBooking!.id,
          );
          if (mounted) {
            setState(() {
              _driverInfo = driver;
            });
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      setState(() => _isLoading = true);

      // Get the Downloads directory
      late Directory downloadsDirectory;

      if (Platform.isAndroid) {
        // For Android, use external storage downloads
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to Downloads folder
          downloadsDirectory = Directory(
            '${externalDir.path.split('/Android')[0]}/Download',
          );
        } else {
          throw 'Could not access external storage';
        }
      } else if (Platform.isIOS) {
        // For iOS, use application documents directory
        downloadsDirectory = await getApplicationDocumentsDirectory();
      } else {
        throw 'Unsupported platform';
      }

      // Create directory if it doesn't exist
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      // Load the asset image
      final ByteData data = await rootBundle.load('assets/images/payment.png');
      final List<int> bytes = data.buffer.asUint8List();

      // Save the file
      final fileName = 'PaymentQR_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${downloadsDirectory.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() => _isLoading = false);
      if (!mounted) return;

      // Show download notification
      SnackBarHelper.showSuccess(context, '✓ Downloaded: $fileName');

      // For Android, show a more detailed notification
      if (Platform.isAndroid) {
        SnackBarHelper.showInfo(context, 'Check your Downloads folder');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Failed to download QR Code: $e');
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
        if (fileSize > 1 * 1024 * 1024) {
          SnackBarHelper.showError(context, 'File size must be less than 1MB');
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

  Future<void> _handleConfirmJourney() async {
    // Require transaction ID before upload if visible
    if (_showPaymentSection && _transactionIdController.text.trim().isEmpty) {
      SnackBarHelper.showError(context, 'Please enter payment transaction ID');
      return;
    }
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
      bookingId: _currentBooking!.bookingId,
      paymentScreenshot: _paymentScreenshot!,
      transactionId: _transactionIdController.text.trim(),
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
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        title: Row(
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
                  color: AppColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Processing...',
        child: SafeArea(
          child: Column(
            children: [
              // _buildTopBar(),
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
                                _currentBooking!.bookingId,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Vehicle',
                                _currentBooking!.vehicleType,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Date',
                                _formatDate(_currentBooking!.date),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Start Location',
                                _currentBooking!.startLocation,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Destination',
                                _currentBooking!.destination,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Bid amount',
                                _currentBooking!.bidAmount,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Assigned Transporter',
                                _assignedSellerName ??
                                    (_currentBooking!.assignedTo?.isNotEmpty ==
                                            true
                                        ? _currentBooking!.assignedTo!
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
                        // Show driver info for business transporters
                        if (_transporterType == 'business_company' &&
                            _driverInfo != null) ...[
                          _buildDriverInfoCard(),
                          const SizedBox(height: 16),
                        ],
                        // Show delivery timeline when booking is accepted or has journey state
                        if (_currentBooking!.bookingStatus?.toLowerCase() ==
                                'accepted' ||
                            (_currentBooking!.journeyState != null &&
                                _currentBooking!.journeyState!.isNotEmpty)) ...[
                          DeliveryTimeline(
                            journeyState: _currentBooking!.journeyState,
                          ),
                          const SizedBox(height: 16),
                          // Show completion OTP when payment is done, transporter assigned, or shipping started
                          if (_currentBooking!.completionOtp != null &&
                              (_currentBooking!.journeyState?.toLowerCase() ==
                                      'payment_done' ||
                                  _currentBooking!.journeyState
                                          ?.toLowerCase() ==
                                      'transporter_assigned' ||
                                  _currentBooking!.journeyState
                                          ?.toLowerCase() ==
                                      'shipping_done')) ...[
                            _buildCompletionOtpCard(),
                            const SizedBox(height: 16),
                          ],
                        ],
                        if (_showPaymentSection) ...[
                          _buildPaymentSection(),
                          const SizedBox(height: 16),
                          _buildConfirmButton(),
                        ] else if (_currentBooking!.paymentStatus
                                ?.toLowerCase() ==
                            'submitted') ...[
                          _buildChatButton(),
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

  String _formatDate(String value) {
    try {
      // Handle values like '2025-12-18T05:30:00.000' or with timezone suffix
      final trimmed = value.trim();
      // If there is a 'T', prefer splitting and taking only the date
      if (trimmed.contains('T')) {
        return trimmed.split('T').first;
      }
      // Fallback: try parsing as DateTime and return just the date portion
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) {
        return '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
      }
      // If parsing fails, return original string
      return value;
    } catch (_) {
      return value;
    }
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return SingleChildScrollView(
      child: Row(
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
      ),
    );
  }

  Widget _buildContactRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Contact Admin :+91 8265049054 ',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ),
        InkWell(
          onTap: () => FlutterPhoneDirectCaller.callNumber('+918265049054'),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/call.png"),
                fit: BoxFit.cover,
              ),
            ),
            padding: const EdgeInsets.all(18),
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
            child: const Icon(Icons.person, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned Transporter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _assignedSellerName ??
                      (_currentBooking!.assignedTo?.isNotEmpty == true
                          ? _currentBooking!.assignedTo!
                          : 'Not assigned'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    if (_driverInfo == null) return const SizedBox.shrink();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Driver Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Driver Name', _driverInfo!.driverName),
          const SizedBox(height: 12),
          _buildInfoRow('Vehicle Number', _driverInfo!.vehicleNumber),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone, size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _driverInfo!.contact,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  try {
                    await FlutterPhoneDirectCaller.callNumber(
                      _driverInfo!.contact,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    SnackBarHelper.showError(context, 'Could not place call');
                  }
                },
                child: Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/call.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
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
          if ((_currentBooking!.paymentStatus?.toLowerCase() == 'rejected') ||
              (_currentBooking!.bookingStatus?.toLowerCase() ==
                  'rejected')) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Rejected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Payment rejected. Please provide the correct payment transaction ID and upload the correct screenshot.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Transaction ID input field
          TextField(
            controller: _transactionIdController,
            decoration: const InputDecoration(
              labelText: 'Payment Transaction ID',
              hintText: 'Enter your transaction/reference ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Container(
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
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/payment.png'),
                      fit: BoxFit.contain,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadQRCode,
              icon: const Icon(Icons.download),
              label: const Text('Download QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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

  Widget _buildChatButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerChatScreen(booking: _currentBooking!),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 20),
            SizedBox(width: 8),
            Text(
              'Chat with Admin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionOtpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.primary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user, color: AppColors.success, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Journey Completion OTP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: AppColors.success, size: 24),
                const SizedBox(width: 12),
                Text(
                  _currentBooking!.completionOtp ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Share this OTP with the transporter to complete the delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
