class VehicleInfo {
  final String vehicleNumber;
  final String vehicleType;
  final String type; // open or closed
  final String rcBookNo;
  final String maxPassWeight; // concatenated weight + unit
  final String? documentId; // File ID from Appwrite Storage
  final String? rcDocumentId; // RC book document ID for this vehicle
  final String? frontImageId; // Front view image ID
  final String? rearImageId; // Rear view image ID
  final String? sideImageId; // Side view image ID
  VehicleInfo({
    required this.vehicleNumber,
    required this.vehicleType,
    required this.type,
    required this.rcBookNo,
    required this.maxPassWeight,
    this.documentId,
    this.rcDocumentId,
    this.frontImageId,
    this.rearImageId,
    this.sideImageId,
  });
  Map<String, dynamic> toJson() {
    return {
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'type': type,
      'rc_book_no': rcBookNo,
      'max_pass_weight': maxPassWeight,
      'document_id': documentId,
      'rc_document_id': rcDocumentId,
      'front_image_id': frontImageId,
      'rear_image_id': rearImageId,
      'side_image_id': sideImageId,
    };
  }

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      vehicleNumber: json['vehicle_number'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      type: json['type'] ?? '',
      rcBookNo: json['rc_book_no'] ?? '',
      maxPassWeight: json['max_pass_weight'] ?? '',
      documentId: json['document_id'],
      rcDocumentId: json['rc_document_id'],
      frontImageId: json['front_image_id'],
      rearImageId: json['rear_image_id'],
      sideImageId: json['side_image_id'],
    );
  }
}

class SellerModel {
  final String id;
  final String userId;
  final String name;
  final String address;
  final String contact;
  final String email;
  final String panCardNo;
  final String? panDocumentId;
  final String drivingLicenseNo;
  final String? licenseDocumentId;
  final String gstNo;
  final String? gstDocumentId;
  final List<String> selectedVehicleTypes;
  final List<VehicleInfo> vehicles;
  final DateTime createdAt;
  final String status; // pending, approved, rejected
  final String availability; // free, engage, return_available
  final String returnLocation; // only if availability is return_available
  SellerModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.panCardNo,
    this.panDocumentId,
    required this.drivingLicenseNo,
    this.licenseDocumentId,
    required this.gstNo,
    this.gstDocumentId,
    required this.selectedVehicleTypes,
    required this.vehicles,
    required this.createdAt,
    this.status = 'pending',
    this.availability = 'free',
    this.returnLocation = '',
  });
  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['\$id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      contact: json['contact'] ?? '',
      email: json['email'] ?? '',
      panCardNo: json['pan_card_no'] ?? '',
      panDocumentId: json['pan_document_id'],
      drivingLicenseNo: json['driving_license_no'] ?? '',
      licenseDocumentId: json['license_document_id'],
      gstNo: json['gst_no'] ?? '',
      gstDocumentId: json['gst_document_id'],
      selectedVehicleTypes: List<String>.from(
        json['selected_vehicle_types'] ?? [],
      ),
      vehicles:
          (json['vehicles'] as List?)
              ?.map((v) => VehicleInfo.fromJson(v))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['\$createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'pending',
      availability: json['availability'] ?? 'free',
      returnLocation: json['return_location'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'address': address,
      'contact': contact,
      'email': email,
      'pan_card_no': panCardNo,
      'pan_document_id': panDocumentId,
      'driving_license_no': drivingLicenseNo,
      'license_document_id': licenseDocumentId,
      'gst_no': gstNo,
      'gst_document_id': gstDocumentId,
      'selected_vehicle_types': selectedVehicleTypes,
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
      'status': status,
      'availability': availability,
      'return_location': returnLocation,
    };
  }
}
