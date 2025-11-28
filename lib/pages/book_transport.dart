// import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/main.dart' hide AppColors;
import 'package:truckmate/providers/auth_provider.dart';
// import 'package:truckmate/constants/colors.dart' as AppColors;

class BookTransportScreen extends StatefulWidget {
  const BookTransportScreen({super.key});

  @override
  State<BookTransportScreen> createState() => _BookTransportScreenState();
}

class _BookTransportScreenState extends State<BookTransportScreen> {
  final Set<int> _selectedVehicles = {};
  int activeIndex = 0;
  final widgets = [
    Container(
      decoration: BoxDecoration(
        image: new DecorationImage(
          image: AssetImage("assets/images/Cargo1.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: new DecorationImage(
          image: AssetImage("assets/images/Cargo2.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: new DecorationImage(
          image: AssetImage("assets/images/Cargo3.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    Container(
      decoration: BoxDecoration(
        image: new DecorationImage(
          image: AssetImage("assets/images/Cargo4.png"),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargo Balancer'),
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                height: 200,
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
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Contact Number',
                          'Enter your Contact number',
                          Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Address',
                          'Enter your Address',
                          Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Date',
                          'Enter Date',
                          Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Load Description',
                          'Enter Description',
                          Icons.description_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Start Location',
                          'Enter your Location',
                          Icons.my_location_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Destination',
                          'Enter Destination',
                          Icons.location_city_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Your Bid Amount',
                          'Enter Bid Value',
                          Icons.attach_money_outlined,
                        ),
                        const SizedBox(height: 24),
                        _buildVehicleSelector(),
                        const SizedBox(height: 28),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomNav(0),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: Icon(Icons.person, size: 120)),
            ListTile(
              leading: Icon(Icons.feed_outlined),
              title: Text("Feedback"),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              onTap: () async {
                await authProvider.logout();
              },
              title: Text("Logout"),
            ),
          ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: _buildTopIcon(Icons.person_outline),
          ),
          _buildTopIcon(Icons.notifications_outlined),
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

  Widget _buildTextField(String label, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SizedBox(width: 24),
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
          // margin: EdgeInsets.symmetric(horizontal: 13.0),
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
          child: TextField(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
              prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              // contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  buildIndicator() => AnimatedSmoothIndicator(
    activeIndex: activeIndex,
    count: widgets.length,
    effect: JumpingDotEffect(
      // paintStyle: PaintingStyle.fill,
      // strokeWidth: 1,
      spacing: 20,
      // offset: 22,r
      verticalOffset: 14.0,
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
            final isSelected = _selectedVehicles.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedVehicles.remove(index);
                  } else {
                    _selectedVehicles.add(index);
                  }
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
                      'Truck',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.dark : AppColors.textDark,
                      ),
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
        onPressed: () {},
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

  Widget _buildBottomNav(int currentIndex) {
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
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.secondary,
        backgroundColor: AppColors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            label: 'Favourites',
          ),
        ],
      ),
    );
  }
}

Widget buildImage(assetImage, int index) => Container(
  // margin: EdgeInsets.symmetric(horizontal: 12),
  // width: 300,
  // color: Colors.grey,
  child: InkWell(
    onTap: () {},
    child: Container(
      child: assetImage,
      decoration: BoxDecoration(),

      // width: 500,

      // child: Image.asset(
      //   assetImage,
      //   fit: BoxFit.cover,
      // ),
    ),
  ),
);
