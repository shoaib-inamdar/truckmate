import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/pages/seller_profile_page.dart';
import 'package:truckmate/pages/seller_booking_detail_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:truckmate/services/seller_service.dart';
import 'package:truckmate/models/booking_model.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({Key? key}) : super(key: key);
  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _selectedIndex = 0;
  bool _hasLoadedSellerBookings = false;
  Timer? _refreshTimer;
  String? _originalUserId; // Store the original user_id from seller_request

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSellerBookings();
      _loadSellerData();
      _fetchOriginalUserId();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      // Refresh data for all tabs
      _loadSellerBookings();
      _loadSellerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 40, width: 40),
            const SizedBox(width: 10),
            const Text('Cargo Balancer'),
          ],
        ),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        actions: [],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOriginalUserId() async {
    print('🟡 Dashboard._fetchOriginalUserId: Starting...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sellerEmail = authProvider.user?.email;
    print('🟡 Dashboard._fetchOriginalUserId: sellerEmail=$sellerEmail');
    if (sellerEmail == null) {
      print('❌ Dashboard._fetchOriginalUserId: No email found, returning');
      return;
    }

    print('🔵 Dashboard: Fetching original user_id for email: $sellerEmail');
    try {
      final sellerService = SellerService();
      print(
        '🟡 Dashboard._fetchOriginalUserId: Calling getOriginalUserIdByEmail...',
      );
      final originalUserId = await sellerService.getOriginalUserIdByEmail(
        sellerEmail,
      );
      print('🟡 Dashboard._fetchOriginalUserId: Got result: $originalUserId');
      if (mounted) {
        setState(() {
          _originalUserId = originalUserId;
        });
        print('🔵 Dashboard: Original user_id stored: $_originalUserId');
      } else {
        print('❌ Dashboard._fetchOriginalUserId: Widget not mounted');
      }
    } catch (e) {
      print('❌ Dashboard._fetchOriginalUserId: Exception - $e');
      print('❌ Dashboard: Error fetching original user_id: $e');
    }
  }

  Future<void> _loadSellerData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sellerProvider = Provider.of<SellerProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId != null) {
      await sellerProvider.loadSellerRegistration(userId);
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildBookingsTab();
      case 2:
        return const SellerProfilePage();
      default:
        return _buildHomeTab();
    }
  }

  Future<void> _loadSellerBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    final sellerEmail = authProvider.user?.email;
    if (sellerEmail == null) return;

    print('DEBUG: Fetching original user_id for email: $sellerEmail');

    try {
      // Get the original user_id from seller_request table using email
      final sellerService = SellerService();
      final originalUserId = await sellerService.getOriginalUserIdByEmail(
        sellerEmail,
      );

      if (originalUserId == null) {
        print('DEBUG: Could not find original user_id for seller');
        return;
      }

      // Store the original user_id in state for availability section
      if (mounted && _originalUserId != originalUserId) {
        setState(() {
          _originalUserId = originalUserId;
        });
        print(
          '🟢 _loadSellerBookings: Stored original_user_id: $_originalUserId',
        );
      }

      print('DEBUG: Loading bookings for original user_id: $originalUserId');
      await bookingProvider.loadSellerAssignedBookings(originalUserId);
    } finally {
      if (mounted) {
        setState(() => _hasLoadedSellerBookings = true);
      }
    }
  }

  Widget _buildHomeTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final sellerProvider = Provider.of<SellerProvider>(context);
    final activeBookingsCount = bookingProvider.bookings.length;
    final vehicleCount =
        sellerProvider.sellerRegistration?.selectedVehicleTypes.length ?? 0;
    print('🟢 _buildHomeTab: _originalUserId = $_originalUserId');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.dark.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.user?.name ?? 'Seller',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Approved Transporter',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.dark.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                icon: Icons.assignment,
                title: 'Active Bookings',
                value: '$activeBookingsCount',
                color: AppColors.success,
              ),
              _buildStatCard(
                icon: Icons.local_shipping,
                title: 'My Vehicles',
                value: '$vehicleCount',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          _buildAvailabilitySection(
            sellerProvider: sellerProvider,
            userId: _originalUserId ?? authProvider.user?.id ?? '',
            originalUserId: _originalUserId,
          ),
          const SizedBox(height: 24),
          const Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          _buildCallAdminButton(),
          const SizedBox(height: 16),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCallAdminButton() {
    return InkWell(
      onTap: () async {
        try {
          await FlutterPhoneDirectCaller.callNumber('+919309049054');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error making call: $e'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
          ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Admin Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+91 93090 49054',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection({
    required SellerProvider sellerProvider,
    required String userId,
    String? originalUserId,
  }) {
    final currentAvailability =
        sellerProvider.sellerRegistration?.availability ?? 'free';
    String selected = currentAvailability;
    print(
      '🔵 AvailabilitySection: userId=$userId, originalUserId=$originalUserId',
    );
    final TextEditingController _returnLocationController =
        TextEditingController(
          text: sellerProvider.sellerRegistration?.returnLocation ?? '',
        );
    print(
      '🔵 AvailabilitySection: Initial state - selected: $currentAvailability',
    );
    return StatefulBuilder(
      builder: (context, setLocalState) {
        Future<void> _submitAvailability() async {
          print('🟠 AvailabilitySection: Submit button clicked');
          print(
            '📤 AvailabilitySection: Submitting - availability: $selected, location: ${selected == 'return_available' ? _returnLocationController.text.trim() : 'N/A'}',
          );

          // If originalUserId is still null, fetch it now before submitting
          String finalUserId = userId;
          if (_originalUserId == null) {
            print(
              '🟠 AvailabilitySection: Original user_id is null, fetching now...',
            );
            try {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final sellerEmail = authProvider.user?.email;
              if (sellerEmail != null) {
                final sellerService = SellerService();
                final fetchedUserId = await sellerService
                    .getOriginalUserIdByEmail(sellerEmail);
                if (fetchedUserId != null) {
                  finalUserId = fetchedUserId;
                  print(
                    '🟢 AvailabilitySection: Fetched original user_id: $finalUserId',
                  );
                }
              }
            } catch (e) {
              print('❌ AvailabilitySection: Error fetching user_id: $e');
            }
          }

          final ok = await sellerProvider.setAvailability(
            userId: finalUserId,
            availability: selected,
            returnLocation: selected == 'return_available'
                ? _returnLocationController.text.trim()
                : null,
          );
          print(
            '✅ AvailabilitySection: Response - ok: $ok, error: ${sellerProvider.errorMessage}',
          );
          if (ok && mounted) {
            print('✅ AvailabilitySection: Success - showing snackbar');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Availability updated')),
            );
          } else if (!ok && mounted) {
            print(
              '❌ AvailabilitySection: Failed - error: ${sellerProvider.errorMessage}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(sellerProvider.errorMessage ?? 'Failed')),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _availabilityRadio(
                  label: 'Free',
                  value: 'free',
                  groupValue: selected,
                  onChanged: (v) {
                    print('🔵 AvailabilityRadio: Free selected');
                    setLocalState(() {
                      selected = v!;
                      _returnLocationController.clear();
                    });
                  },
                ),
                _availabilityRadio(
                  label: 'Engage',
                  value: 'engage',
                  groupValue: selected,
                  onChanged: (v) {
                    print('🔵 AvailabilityRadio: Engage selected');
                    setLocalState(() {
                      selected = v!;
                      _returnLocationController.clear();
                    });
                  },
                ),
                _availabilityRadio(
                  label: 'Return Load',
                  value: 'return_available',
                  groupValue: selected,
                  onChanged: (v) {
                    print('🔵 AvailabilityRadio: Return available selected');
                    setLocalState(() => selected = v!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selected == 'return_available')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _returnLocationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter current location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: sellerProvider.isLoading
                          ? null
                          : _submitAvailability,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.dark,
                      ),
                      child: sellerProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            if (selected != 'return_available')
              ElevatedButton(
                onPressed: sellerProvider.isLoading
                    ? null
                    : _submitAvailability,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.dark,
                ),
                child: sellerProvider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm'),
              ),
          ],
        );
      },
    );
  }

  Widget _availabilityRadio({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: groupValue == value
              ? AppColors.primary
              : AppColors.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    if (bookingProvider.isLoading && !_hasLoadedSellerBookings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bookingProvider.bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSellerBookings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: AppColors.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'No Bookings Assigned',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Pull to refresh',
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSellerBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookingProvider.bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = bookingProvider.bookings[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: const Icon(Icons.assignment, color: AppColors.primary),
              ),
              title: Text(
                booking.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${booking.startLocation} → ${booking.destination}',
                    style: TextStyle(fontSize: 13, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateOnly(booking.date),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
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
              ),
              onTap: () => _showBookingDetails(booking),
            ),
          );
        },
      ),
    );
  }

  void _showBookingDetails(BookingModel booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerBookingDetailScreen(booking: booking),
      ),
    ).then((result) {
      // Refresh bookings if changes were made
      if (result == true) {
        _loadSellerBookings();
      }
    });
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

  String _getJourneyStateLabel(String? journeyState) {
    switch (journeyState) {
      case 'pending':
        return 'Pending Payment';
      case 'payment_done':
        return 'Ready to Ship';
      case 'shipping_done':
        return 'In Transit';
      case 'journey_completed':
        return 'Completed';
      default:
        return 'Not Started';
    }
  }

  Widget _buildVehiclesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Vehicles Added',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your vehicles to start accepting bookings',
            style: TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_money,
            size: 80,
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Earnings Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete bookings to start earning',
            style: TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
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
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.white,
        backgroundColor: AppColors.dark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Refresh data based on selected tab
          if (index == 0) {
            // Home tab - refresh seller data and bookings
            _loadSellerData();
            _loadSellerBookings();
          } else if (index == 1) {
            // Bookings tab - refresh bookings
            _loadSellerBookings();
          } else if (index == 2) {
            // Profile tab - refresh seller data
            _loadSellerData();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
