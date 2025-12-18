class BusinessTransporterModel {
  final String id;
  final String driverName;
  final String vehicleNumber;
  final String contact;
  final String userId;
  final String bookingId;

  BusinessTransporterModel({
    required this.id,
    required this.driverName,
    required this.vehicleNumber,
    required this.contact,
    required this.userId,
    required this.bookingId,
  });

  factory BusinessTransporterModel.fromJson(Map<String, dynamic> json) {
    return BusinessTransporterModel(
      id: json['\$id'] ?? '',
      driverName: json['driver_name'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? '',
      contact: json['contact'] ?? '',
      userId: json['user_id'] ?? '',
      bookingId: json['booking_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_name': driverName,
      'vehicle_number': vehicleNumber,
      'contact': contact,
      'user_id': userId,
      'booking_id': bookingId,
    };
  }
}
