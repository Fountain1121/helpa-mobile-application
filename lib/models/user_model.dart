import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Helpa user.
/// All three roles (customer, tasker, admin) share this base model.
/// Taskers also have a separate [TaskerModel] document with extended data.
class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;

  /// One of: "customer" | "tasker" | "admin"
  final String role;

  final String? profilePhoto;
  final String? location;
  final DateTime createdAt;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhoto,
    this.location,
    required this.createdAt,
    required this.isActive,
  });

  // ---------------------------------------------------------------------------
  // Factory: build from a Firestore DocumentSnapshot
  // ---------------------------------------------------------------------------
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] as String? ?? 'customer',
      profilePhoto: data['profilePhoto'] as String?,
      location: data['location'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: build from a plain Map (e.g. after a Firestore query)
  // ---------------------------------------------------------------------------
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] as String? ?? 'customer',
      profilePhoto: data['profilePhoto'] as String?,
      location: data['location'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialize to Map for writing to Firestore
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'profilePhoto': profilePhoto,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  // ---------------------------------------------------------------------------
  // CopyWith — useful for updating a single field without rebuilding the object
  // ---------------------------------------------------------------------------
  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? profilePhoto,
    String? location,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      location: location ?? this.location,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  bool get isCustomer => role == 'customer';
  bool get isTasker => role == 'tasker';
  bool get isAdmin => role == 'admin';

  @override
  String toString() => 'UserModel(uid: $uid, fullName: $fullName, role: $role)';
}
