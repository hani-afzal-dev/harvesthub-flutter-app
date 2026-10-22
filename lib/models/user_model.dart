import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, farmer, admin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'farmer':
      return UserRole.farmer;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.customer;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.farmer:
      return 'farmer';
    case UserRole.admin:
      return 'admin';
    case UserRole.customer:
      return 'customer';
  }
}

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.farmer:
      return 'Farmer';
    case UserRole.admin:
      return 'Administrator';
    case UserRole.customer:
      return 'Customer';
  }
}

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final UserRole role;
  final bool isActive;
  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    this.isActive = true,
    this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      role: userRoleFromString(map['role'] ?? 'customer'),
      isActive: map['isActive'] ?? true,
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': userRoleToString(role),
      'isActive': isActive,
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? address,
  }) {
    return UserModel(
      userId: userId,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role,
      isActive: isActive,
      fcmToken: fcmToken,
      createdAt: createdAt,
    );
  }
}
