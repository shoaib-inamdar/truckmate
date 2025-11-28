class UserModel {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? phone;
  final bool emailVerification;
  final bool phoneVerification;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.phone,
    this.emailVerification = false,
    this.phoneVerification = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['\$id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      createdAt: DateTime.parse(json['\$createdAt'] ?? DateTime.now().toIso8601String()),
      phone: json['phone'],
      emailVerification: json['emailVerification'] ?? false,
      phoneVerification: json['phoneVerification'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '\$id': id,
      'email': email,
      'name': name,
      '\$createdAt': createdAt.toIso8601String(),
      'phone': phone,
      'emailVerification': emailVerification,
      'phoneVerification': phoneVerification,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    String? phone,
    bool? emailVerification,
    bool? phoneVerification,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      phone: phone ?? this.phone,
      emailVerification: emailVerification ?? this.emailVerification,
      phoneVerification: phoneVerification ?? this.phoneVerification,
    );
  }
}