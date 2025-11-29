class UserModel {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? phone;
  final String? address;
  final String? role;
  final bool emailVerification;
  final bool phoneVerification;
  final bool isProfileComplete;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.phone,
    this.address,
    this.role,
    this.emailVerification = false,
    this.phoneVerification = false,
    this.isProfileComplete = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['\$id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      createdAt: DateTime.parse(
        json['\$createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      phone: json['phone'],
      address: json['address'],
      role: json['role'],
      emailVerification: json['emailVerification'] ?? false,
      phoneVerification: json['phoneVerification'] ?? false,
      isProfileComplete: json['isProfileComplete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '\$id': id,
      'email': email,
      'name': name,
      '\$createdAt': createdAt.toIso8601String(),
      'phone': phone,
      'address': address,
      'role': role,
      'emailVerification': emailVerification,
      'phoneVerification': phoneVerification,
      'isProfileComplete': isProfileComplete,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    String? phone,
    String? address,
    String? role,
    bool? emailVerification,
    bool? phoneVerification,
    bool? isProfileComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      emailVerification: emailVerification ?? this.emailVerification,
      phoneVerification: phoneVerification ?? this.phoneVerification,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }

  // Check if user needs to complete profile
  bool needsProfileCompletion() {
    return !isProfileComplete ||
        name.isEmpty ||
        phone == null ||
        phone!.isEmpty ||
        address == null ||
        address!.isEmpty;
  }
}
