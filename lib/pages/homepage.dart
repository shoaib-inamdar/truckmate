import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/pages/customer_dashboard.dart';
import 'package:truckmate/pages/customer_bookings_list_screen.dart';
import 'package:truckmate/pages/book_transport.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import 'customer_profile_page.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _changeTab(int index) {
    setState(() => _selectedIndex = index);
  }

  List<Widget> get _screens => [
    CustomerDashboard(onTabChange: _changeTab),
    BookTransportScreen(),
    CustomerBookingsListScreen(),
    const CustomerProfilePage(),
  ];
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 40, width: 40),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Cargo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' Balancer',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        actions: const [],
      ),
      backgroundColor: AppColors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.white,
        backgroundColor: AppColors.dark,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
