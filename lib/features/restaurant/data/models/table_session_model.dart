class TableSessionModel {
  final String sessionId;
  final String tableId;
  final String branchId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int guestCount;
  final String status; // OPEN | BILLED | CLOSED | CANCELLED
  final String? openedBy;
  final String? note;
  final String? waiterId;
  final String? waiterName;

  const TableSessionModel({
    required this.sessionId,
    required this.tableId,
    required this.branchId,
    required this.openedAt,
    this.closedAt,
    this.guestCount = 1,
    this.status = 'OPEN',
    this.openedBy,
    this.note,
    this.waiterId,
    this.waiterName,
  });

  bool get isOpen => status == 'OPEN';
  bool get isBilled => status == 'BILLED';
  bool get isClosed => status == 'CLOSED' || status == 'CANCELLED';

  Duration get duration => DateTime.now().difference(openedAt);

  factory TableSessionModel.fromJson(Map<String, dynamic> json) =>
      TableSessionModel(
        sessionId: json['session_id'] as String,
        tableId: json['table_id'] as String,
        branchId: json['branch_id'] as String,
        openedAt: DateTime.parse(json['opened_at'] as String),
        closedAt: json['closed_at'] != null
            ? DateTime.tryParse(json['closed_at'] as String)
            : null,
        guestCount: json['guest_count'] as int? ?? 1,
        status: json['status'] as String? ?? 'OPEN',
        openedBy: json['opened_by'] as String?,
        note: json['note'] as String?,
        waiterId: json['waiter_id'] as String?,
        waiterName: json['waiter_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'table_id': tableId,
        'branch_id': branchId,
        'opened_at': openedAt.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'guest_count': guestCount,
        'status': status,
        'opened_by': openedBy,
        'note': note,
        'waiter_id': waiterId,
        'waiter_name': waiterName,
      };

  TableSessionModel copyWith({
    String? sessionId,
    String? tableId,
    String? branchId,
    DateTime? openedAt,
    DateTime? closedAt,
    int? guestCount,
    String? status,
    String? openedBy,
    String? note,
    String? waiterId,
    String? waiterName,
  }) =>
      TableSessionModel(
        sessionId: sessionId ?? this.sessionId,
        tableId: tableId ?? this.tableId,
        branchId: branchId ?? this.branchId,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt ?? this.closedAt,
        guestCount: guestCount ?? this.guestCount,
        status: status ?? this.status,
        openedBy: openedBy ?? this.openedBy,
        note: note ?? this.note,
        waiterId: waiterId ?? this.waiterId,
        waiterName: waiterName ?? this.waiterName,
      );
}
