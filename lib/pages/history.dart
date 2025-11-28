import 'package:flutter/material.dart';
import '../constants/colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShipmentListScreen();
  }
}

class ShipmentListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> shipments = [
    {'from': 'Solapur', 'to': 'Pune', 'weight': '10 tons', 'status': 'Delivered'},
    {'from': 'Solapur', 'to': 'Pune', 'weight': '10 tons', 'status': 'Delivered'},
    {'from': 'Solapur', 'to': 'Pune', 'weight': '10 tons', 'status': 'In Progress'},
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isDesktop
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: shipments.length,
              itemBuilder: (context, index) => _buildShipmentCard(context, shipments[index]),
            )
          : Column(
              children: shipments.map((shipment) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildShipmentCard(context, shipment),
              )).toList(),
            ),
    );
  }

  Widget _buildShipmentCard(BuildContext context, Map<String, dynamic> shipment) {
    Color statusColor = shipment['status'] == 'Delivered' ? Colors.green : Colors.orange;
    return Card(
      elevation: 2,
      color: AppColors.secondary,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${shipment['from']} → ${shipment['to']}', style: Theme.of(context).textTheme.titleMedium),
                Icon(Icons.local_shipping, color: AppColors.primary),
              ],
            ),
            Text('Weight: ${shipment['weight']}', style: Theme.of(context).textTheme.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(shipment['status'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}