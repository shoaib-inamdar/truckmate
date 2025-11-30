class VehicleInfo {
  final String vehicleNumber;
  final String? documentId; // File ID from Appwrite Storage

  VehicleInfo({
    required this.vehicleNumber,
    this.documentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehicle_number': vehicleNumber,
      'document_id': documentId,
    };
  }

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      vehicleNumber: json['vehicle_number'] ?? '',
      documentId: json['document_id'],
    );
  }
}

class SellerModel {
  final String id;
  final String userId;
  final String name;
  final String address;
  final String contact;
  final String aadharCardNo;
  final String? aadharDocumentId;
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
    required this.aadharCardNo,
    this.aadharDocumentId,
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
      aadharCardNo: json['aadhar_card_no'] ?? '',
      aadharDocumentId: json['aadhar_document_id'],
      panCardNo: json['pan_card_no'] ?? '',
      panDocumentId: json['pan_document_id'],
      drivingLicenseNo: json['driving_license_no'] ?? '',
      licenseDocumentId: json['license_document_id'],
      gstNo: json['gst_no'] ?? '',
      gstDocumentId: json['gst_document_id'],
      selectedVehicleTypes: List<String>.from(json['selected_vehicle_types'] ?? []),
      vehicles: (json['vehicles'] as List?)
              ?.map((v) => VehicleInfo.fromJson(v))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['\$createdAt'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'address': address,
      'contact': contact,
      'aadhar_card_no': aadharCardNo,
      'aadhar_document_id': aadharDocumentId,
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