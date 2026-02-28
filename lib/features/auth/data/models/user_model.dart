class UserModel {
  final String userId;
  final String username;
  final String fullName;
  final String? email;
  final String? roleId;
  final String? branchId;
  
  UserModel({
    required this.userId,
    required this.username,
    required this.fullName,
    this.email,
    this.roleId,
    this.branchId,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      roleId: json['role_id'] as String?,
      branchId: json['branch_id'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role_id': roleId,
      'branch_id': branchId,
    };
  }
}