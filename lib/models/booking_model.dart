class BookingModel {
  final String id; // Document ID (same as booking_id)
  final String bookingId; // Auto-generated 6-character alphanumeric
  final String userId; // Reference to the user who made the booking
  final String fullName;
  final String phoneNumber;
  final String address;
  final String date;
  final String loadDescription;
  final String startLocation;
  final String destination;
  final String bidAmount;
  final String vehicleType; // Single selected vehicle type
  final DateTime createdAt;
  final String status; // e.g., 'pending', 'accepted', 'rejected', 'completed'

  BookingModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.address,
    required this.date,
    required this.loadDescription,
    required this.startLocation,
    required this.destination,
    required this.bidAmount,
    required this.vehicleType,
    required this.createdAt,
    this.status = 'pending',
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
      loadDescription: json['load_description'] ?? '',
      startLocation: json['start_location'] ?? '',
      destination: json['destination'] ?? '',
      bidAmount: json['bid_amount'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      createdAt: DateTime.parse(
        json['\$createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'pending',
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
      'load_description': loadDescription,
      'start_location': startLocation,
      'destination': destination,
      'bid_amount': bidAmount,
      'vehicle_type': vehicleType,
      'status': status,
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
    String? loadDescription,
    String? startLocation,
    String? destination,
    String? bidAmount,
    String? vehicleType,
    DateTime? createdAt,
    String? status,
  }) {
    return BookingModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      date: date ?? this.date,
      loadDescription: loadDescription ?? this.loadDescription,
      startLocation: startLocation ?? this.startLocation,
      destination: destination ?? this.destination,
      bidAmount: bidAmount ?? this.bidAmount,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
