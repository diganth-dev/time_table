import 'user_role.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? collegeId;
  final String? departmentId;
  final String? sectionId;
  final String? staffId;
  final DateTime createdAt;
  final bool active;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.collegeId,
    this.departmentId,
    this.sectionId,
    this.staffId,
    DateTime? createdAt,
    this.active = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? id}) {
    return UserProfile(
      id: id ?? json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      collegeId: json['collegeId'] as String?,
      departmentId: json['departmentId'] as String?,
      sectionId: json['sectionId'] as String?,
      staffId: json['staffId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toDbString(),
      'collegeId': collegeId,
      'departmentId': departmentId,
      'sectionId': sectionId,
      'staffId': staffId,
      'createdAt': createdAt.toIso8601String(),
      'active': active,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? collegeId,
    String? departmentId,
    String? sectionId,
    String? staffId,
    DateTime? createdAt,
    bool? active,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      sectionId: sectionId ?? this.sectionId,
      staffId: staffId ?? this.staffId,
      createdAt: createdAt ?? this.createdAt,
      active: active ?? this.active,
    );
  }
}
