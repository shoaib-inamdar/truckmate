import 'package:flutter/material.dart';
import 'package:truckmate/constants/colors.dart';
import 'package:truckmate/pages/seller_registration_screen.dart';
import 'package:truckmate/pages/business_registration_screen.dart';

class TransporterRegistrationTabs extends StatefulWidget {
  const TransporterRegistrationTabs({Key? key}) : super(key: key);

  @override
  State<TransporterRegistrationTabs> createState() =>
      _TransporterRegistrationTabsState();
}

class _TransporterRegistrationTabsState
    extends State<TransporterRegistrationTabs> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(
          backgroundColor: AppColors.dark,
          foregroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.primary),
          title: const Text(
            'Transporter Registration',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondary,
            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'Individual'),
              Tab(text: 'Business'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [SellerRegistrationScreen(), BusinessRegistrationScreen()],
        ),
      ),
    );
  }
}
