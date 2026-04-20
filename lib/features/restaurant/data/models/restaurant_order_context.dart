class RestaurantOrderContext {
  final String tableId;
  final String tableName;
  final String sessionId;
  final String branchId;
  final int guestCount;
  final String serviceType;
  final String? currentOrderId;
  final String? currentOrderNo;
  final List<String> currentOrderIds;
  final double? subtotalOverride;
  final double? discountOverride;
  final double? serviceChargeOverride;
  final double? totalOverride;
  final String? paymentTitle;
  final String? splitLabel;

  const RestaurantOrderContext({
    required this.tableId,
    required this.tableName,
    required this.sessionId,
    required this.branchId,
    required this.guestCount,
    this.serviceType = 'DINE_IN',
    this.currentOrderId,
    this.currentOrderNo,
    this.currentOrderIds = const [],
    this.subtotalOverride,
    this.discountOverride,
    this.serviceChargeOverride,
    this.totalOverride,
    this.paymentTitle,
    this.splitLabel,
  });

  Map<String, dynamic> toJson() => {
        'table_id': tableId,
        'table_name': tableName,
        'session_id': sessionId,
        'branch_id': branchId,
        'guest_count': guestCount,
        'service_type': serviceType,
        'current_order_id': currentOrderId,
        'current_order_no': currentOrderNo,
        'current_order_ids': currentOrderIds,
        'subtotal_override': subtotalOverride,
        'discount_override': discountOverride,
        'service_charge_override': serviceChargeOverride,
        'total_override': totalOverride,
        'payment_title': paymentTitle,
        'split_label': splitLabel,
      };

  factory RestaurantOrderContext.fromJson(Map<String, dynamic> json) =>
      RestaurantOrderContext(
        tableId: json['table_id'] as String? ?? '',
        tableName: json['table_name'] as String? ?? '',
        sessionId: json['session_id'] as String? ?? '',
        branchId: json['branch_id'] as String? ?? '',
        guestCount: json['guest_count'] as int? ?? 1,
        serviceType: json['service_type'] as String? ?? 'DINE_IN',
        currentOrderId: json['current_order_id'] as String?,
        currentOrderNo: json['current_order_no'] as String?,
        currentOrderIds: (json['current_order_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        subtotalOverride: (json['subtotal_override'] as num?)?.toDouble(),
        discountOverride: (json['discount_override'] as num?)?.toDouble(),
        serviceChargeOverride:
            (json['service_charge_override'] as num?)?.toDouble(),
        totalOverride: (json['total_override'] as num?)?.toDouble(),
        paymentTitle: json['payment_title'] as String?,
        splitLabel: json['split_label'] as String?,
      );

  RestaurantOrderContext copyWith({
    String? tableId,
    String? tableName,
    String? sessionId,
    String? branchId,
    int? guestCount,
    String? serviceType,
    String? currentOrderId,
    String? currentOrderNo,
    List<String>? currentOrderIds,
    double? subtotalOverride,
    double? discountOverride,
    double? serviceChargeOverride,
    double? totalOverride,
    String? paymentTitle,
    String? splitLabel,
  }) =>
      RestaurantOrderContext(
        tableId: tableId ?? this.tableId,
        tableName: tableName ?? this.tableName,
        sessionId: sessionId ?? this.sessionId,
        branchId: branchId ?? this.branchId,
        guestCount: guestCount ?? this.guestCount,
        serviceType: serviceType ?? this.serviceType,
        currentOrderId: currentOrderId ?? this.currentOrderId,
        currentOrderNo: currentOrderNo ?? this.currentOrderNo,
        currentOrderIds: currentOrderIds ?? this.currentOrderIds,
        subtotalOverride: subtotalOverride ?? this.subtotalOverride,
        discountOverride: discountOverride ?? this.discountOverride,
        serviceChargeOverride:
            serviceChargeOverride ?? this.serviceChargeOverride,
        totalOverride: totalOverride ?? this.totalOverride,
        paymentTitle: paymentTitle ?? this.paymentTitle,
        splitLabel: splitLabel ?? this.splitLabel,
      );
}
