import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/models/booking_model.dart';
import 'package:truckmate/pages/customer_booking_detail_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/widgets/loading_overlay.dart';

class CustomerBookingsListScreen extends StatefulWidget {
  const CustomerBookingsListScreen({Key? key}) : super(key: key);
  @override
  State<CustomerBookingsListScreen> createState() =>
      _CustomerBookingsListScreenState();
}

class _CustomerBookingsListScreenState
    extends State<CustomerBookingsListScreen> {
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    if (authProvider.user != null) {
      setState(() => _isLoading = true);
      await bookingProvider.loadUserBookings(authProvider.user!.id);
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'in progress':
      case 'accepted':
        return AppColors.warning;
      case 'pending':
        return AppColors.secondary;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.secondary;
    }
  }

  Color _getJourneyStateColor(String? journeyState) {
    switch (journeyState) {
      case 'pending':
        return AppColors.warning;
      case 'payment_done':
        return Colors.blue;
      case 'shipping_done':
        return Colors.orange;
      case 'journey_completed':
        return AppColors.success;
      default:
        return AppColors.secondary;
    }
  }

  String _getJourneyStateLabel(String? journeyState) {
    switch (journeyState) {
      case 'pending':
        return 'Pending Payment';
      case 'payment_done':
        return 'Payment Done';
      case 'shipping_done':
        return 'In Transit';
      case 'journey_completed':
        return 'Journey Completed';
      default:
        return 'Not Started';
    }
  }

  String _formatDateOnly(String date) {
    try {
      // Remove time portion if present
      if (date.contains('T')) {
        return date.split('T')[0];
      }
      // Remove time if format is "YYYY-MM-DD HH:MM:SS"
      if (date.contains(' ')) {
        return date.split(' ')[0];
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  Color _getPaymentStatusColor(String? paymentStatus) {
    switch (paymentStatus?.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusLabel(String? paymentStatus) {
    switch (paymentStatus?.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Loading your bookings...',
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Consumer<BookingProvider>(
                  builder: (context, bookingProvider, child) {
                    if (bookingProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      );
                    }
                    if (bookingProvider.bookings.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: AppColors.secondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your booking requests will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: bookingProvider.bookings.length,
                        itemBuilder: (context, index) {
                          final booking = bookingProvider.bookings[index];
                          return _buildBookingCard(booking);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.dark),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.person, size: 80, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'My Account',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: AppColors.primary),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: const Text('My Bookings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Logout'),
              onTap: () async {
                await authProvider.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerBookingDetailScreen(booking: booking),
          ),
        ).then((_) => _loadBookings());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking ID: ${booking.bookingId}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.startLocation,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.destination,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${_formatDateOnly(booking.date)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(booking.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Show payment status badge
                  if (booking.paymentStatus != null &&
                      booking.paymentStatus!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(
                          booking.paymentStatus,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getPaymentStatusColor(booking.paymentStatus),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getPaymentStatusLabel(booking.paymentStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getPaymentStatusColor(booking.paymentStatus),
                        ),
                      ),
                    ),
                  ],
                  // Show journey state badge when journey is completed or in progress
                  if (booking.journeyState != null &&
                      booking.journeyState!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getJourneyStateColor(
                          booking.journeyState,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getJourneyStateColor(booking.journeyState),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getJourneyStateLabel(booking.journeyState),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getJourneyStateColor(booking.journeyState),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 36,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
