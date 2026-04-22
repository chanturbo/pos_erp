class ZoneModel {
  final String zoneId;
  final String zoneName;
  final String branchId;
  final int displayOrder;
  final bool isActive;

  const ZoneModel({
    required this.zoneId,
    required this.zoneName,
    required this.branchId,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) => ZoneModel(
        zoneId: json['zone_id'] as String,
        zoneName: json['zone_name'] as String,
        branchId: json['branch_id'] as String,
        displayOrder: json['display_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'zone_id': zoneId,
        'zone_name': zoneName,
        'branch_id': branchId,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  ZoneModel copyWith({
    String? zoneId,
    String? zoneName,
    String? branchId,
    int? displayOrder,
    bool? isActive,
  }) =>
      ZoneModel(
        zoneId: zoneId ?? this.zoneId,
        zoneName: zoneName ?? this.zoneName,
        branchId: branchId ?? this.branchId,
        displayOrder: displayOrder ?? this.displayOrder,
        isActive: isActive ?? this.isActive,
      );
}

class DiningTableModel {
  final String tableId;
  final String tableNo;
  final String? tableDisplayName;
  final String zoneId;
  final String? zoneName;
  final int capacity;
  final String status; // AVAILABLE | OCCUPIED | RESERVED | CLEANING | DISABLED
  final String? currentOrderId;
  final DateTime? lastOccupiedAt;

  // Active session ถ้ามี (โหลดมาพร้อมกัน)
  final String? activeSessionId;
  final int? activeGuestCount;
  final DateTime? sessionOpenedAt;
  final String? waiterName;

  const DiningTableModel({
    required this.tableId,
    required this.tableNo,
    this.tableDisplayName,
    required this.zoneId,
    this.zoneName,
    this.capacity = 4,
    this.status = 'AVAILABLE',
    this.currentOrderId,
    this.lastOccupiedAt,
    this.activeSessionId,
    this.activeGuestCount,
    this.sessionOpenedAt,
    this.waiterName,
  });

  String get displayName => tableDisplayName ?? tableNo;

  bool get isAvailable => status == 'AVAILABLE';
  bool get isOccupied => status == 'OCCUPIED';
  bool get isReserved => status == 'RESERVED';
  bool get isCleaning => status == 'CLEANING';
  bool get isDisabled => status == 'DISABLED';

  factory DiningTableModel.fromJson(Map<String, dynamic> json) =>
      DiningTableModel(
        tableId: json['table_id'] as String,
        tableNo: json['table_no'] as String,
        tableDisplayName: json['table_display_name'] as String?,
        zoneId: json['zone_id'] as String,
        zoneName: json['zone_name'] as String?,
        capacity: json['capacity'] as int? ?? 4,
        status: json['status'] as String? ?? 'AVAILABLE',
        currentOrderId: json['current_order_id'] as String?,
        lastOccupiedAt: json['last_occupied_at'] != null
            ? DateTime.tryParse(json['last_occupied_at'] as String)
            : null,
        activeSessionId: json['active_session_id'] as String?,
        activeGuestCount: json['active_guest_count'] as int?,
        sessionOpenedAt: json['session_opened_at'] != null
            ? DateTime.tryParse(json['session_opened_at'] as String)
            : null,
        waiterName: json['waiter_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'table_id': tableId,
        'table_no': tableNo,
        'table_display_name': tableDisplayName,
        'zone_id': zoneId,
        'zone_name': zoneName,
        'capacity': capacity,
        'status': status,
        'current_order_id': currentOrderId,
        'last_occupied_at': lastOccupiedAt?.toIso8601String(),
        'active_session_id': activeSessionId,
        'active_guest_count': activeGuestCount,
        'session_opened_at': sessionOpenedAt?.toIso8601String(),
        'waiter_name': waiterName,
      };

  DiningTableModel copyWith({
    String? tableId,
    String? tableNo,
    String? tableDisplayName,
    String? zoneId,
    String? zoneName,
    int? capacity,
    String? status,
    String? currentOrderId,
    DateTime? lastOccupiedAt,
    String? activeSessionId,
    int? activeGuestCount,
    DateTime? sessionOpenedAt,
    String? waiterName,
  }) =>
      DiningTableModel(
        tableId: tableId ?? this.tableId,
        tableNo: tableNo ?? this.tableNo,
        tableDisplayName: tableDisplayName ?? this.tableDisplayName,
        zoneId: zoneId ?? this.zoneId,
        zoneName: zoneName ?? this.zoneName,
        capacity: capacity ?? this.capacity,
        status: status ?? this.status,
        currentOrderId: currentOrderId ?? this.currentOrderId,
        lastOccupiedAt: lastOccupiedAt ?? this.lastOccupiedAt,
        activeSessionId: activeSessionId ?? this.activeSessionId,
        activeGuestCount: activeGuestCount ?? this.activeGuestCount,
        sessionOpenedAt: sessionOpenedAt ?? this.sessionOpenedAt,
        waiterName: waiterName ?? this.waiterName,
      );
}
