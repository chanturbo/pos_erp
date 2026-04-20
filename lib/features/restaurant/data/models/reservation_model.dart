class ReservationModel {
  final String reservationId;
  final String? tableId;
  final String? tableName;
  final String branchId;
  final String customerName;
  final String? customerPhone;
  final DateTime reservationTime;
  final int partySize;
  final String? notes;
  final String status;
  final String? sessionId;
  final DateTime createdAt;

  const ReservationModel({
    required this.reservationId,
    this.tableId,
    this.tableName,
    required this.branchId,
    required this.customerName,
    this.customerPhone,
    required this.reservationTime,
    required this.partySize,
    this.notes,
    required this.status,
    this.sessionId,
    required this.createdAt,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      ReservationModel(
        reservationId: json['reservation_id'] as String,
        tableId: json['table_id'] as String?,
        tableName: json['table_name'] as String?,
        branchId: json['branch_id'] as String,
        customerName: json['customer_name'] as String,
        customerPhone: json['customer_phone'] as String?,
        reservationTime:
            DateTime.parse(json['reservation_time'] as String),
        partySize: json['party_size'] as int? ?? 2,
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        sessionId: json['session_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isSeated => status == 'SEATED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isNoShow => status == 'NO_SHOW';
  bool get isActive => isPending || isConfirmed;
}
