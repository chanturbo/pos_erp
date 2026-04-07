// branch_model.dart
// Week 7: Branch & Warehouse Models

class BranchModel {
  final String branchId;
  final String companyId;
  final String branchCode;
  final String branchName;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // UI helpers
  final int? warehouseCount;
  final int? userCount;

  BranchModel({
    required this.branchId,
    required this.companyId,
    required this.branchCode,
    required this.branchName,
    this.address,
    this.phone,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.warehouseCount,
    this.userCount,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      branchId: json['branch_id'] as String,
      companyId: json['company_id'] as String,
      branchCode: json['branch_code'] as String,
      branchName: json['branch_name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      warehouseCount: json['warehouse_count'] as int?,
      userCount: json['user_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'company_id': companyId,
        'branch_code': branchCode,
        'branch_name': branchName,
        'address': address,
        'phone': phone,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  BranchModel copyWith({
    String? branchId,
    String? companyId,
    String? branchCode,
    String? branchName,
    String? address,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchModel(
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      branchCode: branchCode ?? this.branchCode,
      branchName: branchName ?? this.branchName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WarehouseModel {
  final String warehouseId;
  final String warehouseCode;
  final String warehouseName;
  final String branchId;
  final String? branchName;
  final bool isActive;
  final DateTime createdAt;

  WarehouseModel({
    required this.warehouseId,
    required this.warehouseCode,
    required this.warehouseName,
    required this.branchId,
    this.branchName,
    this.isActive = true,
    required this.createdAt,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      warehouseId: json['warehouse_id'] as String,
      warehouseCode: json['warehouse_code'] as String,
      warehouseName: json['warehouse_name'] as String,
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'warehouse_id': warehouseId,
        'warehouse_code': warehouseCode,
        'warehouse_name': warehouseName,
        'branch_id': branchId,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

// Sync Status Model
class SyncStatusModel {
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncAt;
  final bool isOnline;
  final String appMode; // master | clientPOS | clientMobile
  final String? serverBaseUrl;
  final String? masterName;
  final String? deviceName;

  SyncStatusModel({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncAt,
    this.isOnline = true,
    this.appMode = 'master',
    this.serverBaseUrl,
    this.masterName,
    this.deviceName,
  });

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;
}
