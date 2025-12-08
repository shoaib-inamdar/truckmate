class VehicleInfo {
  final String vehicleNumber;
  final String? documentId; // File ID from Appwrite Storage
  final String? frontImageId; // Front view image ID
  final String? rearImageId; // Rear view image ID
  final String? sideImageId; // Side view image ID

  VehicleInfo({
    required this.vehicleNumber,
    this.documentId,
    this.frontImageId,
    this.rearImageId,
    this.sideImageId,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehicle_number': vehicleNumber,
      'document_id': documentId,
      'front_image_id': frontImageId,
      'rear_image_id': rearImageId,
      'side_image_id': sideImageId,
    };
  }

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      vehicleNumber: json['vehicle_number'] ?? '',
      documentId: json['document_id'],
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
  final String rcBookNo;
  final String? rcDocumentId;
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

  SellerModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.rcBookNo,
    this.rcDocumentId,
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
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['\$id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      contact: json['contact'] ?? '',
      email: json['email'] ?? '',
      rcBookNo: json['rc_book_no'] ?? '',
      rcDocumentId: json['rc_document_id'],
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'address': address,
      'contact': contact,
      'email': email,
      'rc_book_no': rcBookNo,
      'rc_document_id': rcDocumentId,
      'pan_card_no': panCardNo,
      'pan_document_id': panDocumentId,
      'driving_license_no': drivingLicenseNo,
      'license_document_id': licenseDocumentId,
      'gst_no': gstNo,
      'gst_document_id': gstDocumentId,
      'selected_vehicle_types': selectedVehicleTypes,
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
      'status': status,
    };
  }
}
