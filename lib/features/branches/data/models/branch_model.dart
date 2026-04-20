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
  // RETAIL | RESTAURANT | HYBRID
  final String businessMode;
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
    this.businessMode = 'RETAIL',
    required this.createdAt,
    required this.updatedAt,
    this.warehouseCount,
    this.userCount,
  });

  bool get isRestaurantMode =>
      businessMode == 'RESTAURANT' || businessMode == 'HYBRID';
  bool get isRetailMode =>
      businessMode == 'RETAIL' || businessMode == 'HYBRID';

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      branchId: json['branch_id'] as String,
      companyId: json['company_id'] as String,
      branchCode: json['branch_code'] as String,
      branchName: json['branch_name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      businessMode: json['business_mode'] as String? ?? 'RETAIL',
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
        'business_mode': businessMode,
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
    String? businessMode,
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
      businessMode: businessMode ?? this.businessMode,
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
  final int lastBatchTotalItems;
  final int lastBatchAppliedItems;
  final int lastBatchReplayedItems;
  final int lastBatchPassesUsed;
  final int lastBatchPendingItems;

  SyncStatusModel({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncAt,
    this.isOnline = true,
    this.appMode = 'master',
    this.serverBaseUrl,
    this.masterName,
    this.deviceName,
    this.lastBatchTotalItems = 0,
    this.lastBatchAppliedItems = 0,
    this.lastBatchReplayedItems = 0,
    this.lastBatchPassesUsed = 0,
    this.lastBatchPendingItems = 0,
  });

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;
  bool get hasBatchMetrics => lastBatchTotalItems > 0 || lastBatchPassesUsed > 0;
}

class SyncBatchHistoryModel {
  final String batchId;
  final DateTime createdAt;
  final int totalItems;
  final int appliedItems;
  final int replayedItems;
  final int passesUsed;
  final int pendingItems;
  final String? appMode;
  final String? deviceName;
  final Map<String, dynamic> payload;

  const SyncBatchHistoryModel({
    required this.batchId,
    required this.createdAt,
    required this.totalItems,
    required this.appliedItems,
    required this.replayedItems,
    required this.passesUsed,
    required this.pendingItems,
    this.appMode,
    this.deviceName,
    this.payload = const {},
  });

  factory SyncBatchHistoryModel.fromMap(Map<String, dynamic> map) {
    return SyncBatchHistoryModel(
      batchId: map['batch_id'] as String? ?? '-',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      totalItems: map['total_items'] as int? ?? 0,
      appliedItems: map['applied_items'] as int? ?? 0,
      replayedItems: map['replayed_items'] as int? ?? 0,
      passesUsed: map['passes_used'] as int? ?? 0,
      pendingItems: map['pending_items'] as int? ?? 0,
      appMode: map['app_mode'] as String?,
      deviceName: map['device_name'] as String?,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
    );
  }

  bool get hasReplay => replayedItems > 0;
  bool get hasPending => pendingItems > 0;
}

enum SyncBatchTimeRange {
  lastHour,
  last24Hours,
  last7Days,
  all,
}
