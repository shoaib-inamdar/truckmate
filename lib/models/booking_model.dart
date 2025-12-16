class BookingModel {
  final String id; // Document ID (same as booking_id)
  final String bookingId; // Auto-generated 6-character alphanumeric
  final String userId; // Reference to the user who made the booking
  final String fullName;
  final String phoneNumber;
  final String address;
  final String date;
  final String load;
  final String loadDescription;
  final String startLocation;
  final String destination;
  final String? fixedLocation;
  final String bidAmount;
  final String vehicleType; // Single selected vehicle type
  final DateTime createdAt;
  final String status; // e.g., 'pending', 'accepted', 'rejected', 'completed'
  final String? assignedTo;
  final String? paymentStatus;
  final String? bookingStatus; // new column: booking_status
  final String? paymentTransactionId;
  final String? journeyState; // Tracks delivery progress
  final String? completionOtp; // OTP to confirm delivery completion
  BookingModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.address,
    required this.date,
    required this.load,
    required this.loadDescription,
    required this.startLocation,
    required this.destination,
    this.fixedLocation,
    required this.bidAmount,
    required this.vehicleType,
    required this.createdAt,
    this.status = 'pending',
    this.assignedTo,
    this.paymentStatus,
    this.bookingStatus,
    this.paymentTransactionId,
    this.journeyState,
    this.completionOtp,
  });
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['\$id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      date: json['date'] ?? '',
      load: json['load'] ?? '',
      loadDescription: json['load_description'] ?? '',
      startLocation: json['start_location'] ?? '',
      destination: json['destination'] ?? '',
      fixedLocation: json['fixed_location'] ?? '',
      bidAmount: json['bid_amount'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      createdAt: DateTime.parse(
        json['\$createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'pending',
      assignedTo: json['assigned_to'],
      paymentStatus: json['payment_status'],
      bookingStatus: json['booking_status'],
      paymentTransactionId: json['payment_transaction_id'],
      journeyState: json['journey_state'],
      completionOtp: json['completion_otp'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'user_id': userId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'address': address,
      'date': date,
      'load': load,
      'load_description': loadDescription,
      'start_location': startLocation,
      'destination': destination,
      'fixed_location': fixedLocation,
      'bid_amount': bidAmount,
      'vehicle_type': vehicleType,
      'status': status,
      'assigned_to': assignedTo,
      'payment_status': paymentStatus,
      'booking_status': bookingStatus,
      'payment_transaction_id': paymentTransactionId,
      'journey_state': journeyState,
      'completion_otp': completionOtp,
    };
  }

  BookingModel copyWith({
    String? id,
    String? bookingId,
    String? userId,
    String? fullName,
    String? phoneNumber,
    String? address,
    String? date,
    String? load,
    String? loadDescription,
    String? startLocation,
    String? destination,
    String? fixedLocation,
    String? bidAmount,
    String? vehicleType,
    DateTime? createdAt,
    String? status,
    String? assignedTo,
    String? paymentStatus,
    String? bookingStatus,
    String? paymentTransactionId,
    String? journeyState,
    String? completionOtp,
  }) {
    return BookingModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      date: date ?? this.date,
      load: load ?? this.load,
      loadDescription: loadDescription ?? this.loadDescription,
      startLocation: startLocation ?? this.startLocation,
      destination: destination ?? this.destination,
      fixedLocation: fixedLocation ?? this.fixedLocation,
      bidAmount: bidAmount ?? this.bidAmount,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      journeyState: journeyState ?? this.journeyState,
      completionOtp: completionOtp ?? this.completionOtp,
    );
  }
}
