import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:truckmate/constants/colors.dart';

class DeliveryTimeline extends StatelessWidget {
  final String?
  journeyState; // e.g., 'payment_done', 'transporter_assigned', 'shipping_done', 'journey_completed'

  const DeliveryTimeline({Key? key, this.journeyState}) : super(key: key);

  // Journey states in order
  static const List<String> journeyStates = [
    'payment_done',
    'transporter_assigned',
    'shipping_done',
    'journey_completed',
  ];

  static const Map<String, String> stateLabels = {
    'payment_done': 'Payment Done',
    'transporter_assigned': 'Transporter Assigned',
    'shipping_done': 'Shipping Started',
    'journey_completed': 'Journey Completed',
  };

  static const Map<String, IconData> stateIcons = {
    'payment_done': Icons.check_circle,
    'transporter_assigned': Icons.person,
    'shipping_done': Icons.local_shipping,
    'journey_completed': Icons.flag,
  };

  /// Determines if a state is completed based on the current journeyState
  bool _isCompleted(String state) {
    if (journeyState == null) return false;
    final currentIndex = journeyStates.indexOf(journeyState!);
    final stateIndex = journeyStates.indexOf(state);
    return stateIndex <= currentIndex;
  }

  /// Determines if a state is current
  bool _isCurrent(String state) {
    return journeyState == state;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: journeyStates.length,
            itemBuilder: (context, index) {
              final state = journeyStates[index];
              final isLast = index == journeyStates.length - 1;
              final isCompleted = _isCompleted(state);
              final isCurrent = _isCurrent(state);

              return TimelineTile(
                alignment: TimelineAlign.start,
                isFirst: index == 0,
                isLast: isLast,
                beforeLineStyle: LineStyle(
                  color: isCompleted
                      ? AppColors.success
                      : AppColors.secondary.withOpacity(0.2),
                  thickness: 3,
                ),
                indicatorStyle: IndicatorStyle(
                  width: 50,
                  color: isCurrent
                      ? AppColors.success
                      : isCompleted
                      ? AppColors.success
                      : AppColors.secondary.withOpacity(0.3),
                  iconStyle: IconStyle(
                    iconData: stateIcons[state] ?? Icons.check_circle,
                    color: isCurrent || isCompleted
                        ? AppColors.white
                        : AppColors.textLight,
                    fontSize: 24,
                  ),
                ),
                endChild: Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.success.withOpacity(0.1)
                        : isCompleted
                        ? AppColors.success.withOpacity(0.08)
                        : AppColors.light,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.success
                          : isCompleted
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.secondary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stateLabels[state] ?? state,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? AppColors.success
                              : isCompleted
                              ? AppColors.success
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isCurrent
                            ? (state == 'journey_completed'
                                  ? 'Completed'
                                  : 'In Progress')
                            : isCompleted
                            ? 'Completed'
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
