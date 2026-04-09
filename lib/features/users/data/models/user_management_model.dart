class UserManagementModel {
  final String userId;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? roleId;
  final String? roleName;
  final String? branchId;
  final String? branchName;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const UserManagementModel({
    required this.userId,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.roleId,
    this.roleName,
    this.branchId,
    this.branchName,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
  });

  factory UserManagementModel.fromJson(Map<String, dynamic> json) {
    return UserManagementModel(
      userId:     json['user_id']     as String,
      username:   json['username']    as String,
      fullName:   json['full_name']   as String,
      email:      json['email']       as String?,
      phone:      json['phone']       as String?,
      roleId:     json['role_id']     as String?,
      roleName:   json['role_name']   as String?,
      branchId:   json['branch_id']   as String?,
      branchName: json['branch_name'] as String?,
      isActive:   (json['is_active']  as bool?) ?? true,
      lastLogin:  json['last_login'] != null
          ? DateTime.tryParse(json['last_login'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  UserManagementModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? roleName,
    String? branchId,
    String? branchName,
    bool? isActive,
  }) {
    return UserManagementModel(
      userId:     userId,
      username:   username,
      fullName:   fullName   ?? this.fullName,
      email:      email      ?? this.email,
      phone:      phone      ?? this.phone,
      roleId:     roleId     ?? this.roleId,
      roleName:   roleName   ?? this.roleName,
      branchId:   branchId   ?? this.branchId,
      branchName: branchName ?? this.branchName,
      isActive:   isActive   ?? this.isActive,
      lastLogin:  lastLogin,
      createdAt:  createdAt,
    );
  }
}
