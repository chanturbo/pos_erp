class BillItemModel {
  final String itemId;
  final String orderId;
  final int lineNo;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountAmount;
  final double amount;
  final String kitchenStatus;
  final int courseNo;
  final String? specialInstructions;
  final List<Map<String, dynamic>> modifiers;

  const BillItemModel({
    required this.itemId,
    required this.orderId,
    required this.lineNo,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.discountAmount,
    required this.amount,
    required this.kitchenStatus,
    this.courseNo = 1,
    this.specialInstructions,
    this.modifiers = const [],
  });

  bool get isHeld => kitchenStatus == 'HELD';
  bool get isPreparing => kitchenStatus.toUpperCase() == 'PREPARING';

  factory BillItemModel.fromJson(Map<String, dynamic> json) => BillItemModel(
    itemId: json['item_id'] as String,
    orderId: json['order_id'] as String,
    lineNo: json['line_no'] as int? ?? 0,
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String? ?? '',
    unitPrice: (json['unit_price'] as num).toDouble(),
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    amount: (json['amount'] as num).toDouble(),
    kitchenStatus: json['kitchen_status'] as String? ?? 'PENDING',
    courseNo: json['course_no'] as int? ?? 1,
    specialInstructions: json['special_instructions'] as String?,
    modifiers:
        (json['modifiers'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [],
  );
}

class BillModel {
  final String? orderNo;
  final String sessionId;
  final String tableId;
  final int guestCount;
  final DateTime? openedAt;
  final String? customerId;
  final String? customerName;
  final List<String> orderIds;
  final List<BillItemModel> items;
  final double subtotal;
  final double discountAmount;
  final double serviceChargeRate;
  final double serviceChargeAmount;
  final double grandTotal;
  final String? previewToken;
  final String status;

  const BillModel({
    this.orderNo,
    required this.sessionId,
    required this.tableId,
    required this.guestCount,
    this.openedAt,
    this.customerId,
    this.customerName,
    required this.orderIds,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.serviceChargeRate,
    required this.serviceChargeAmount,
    required this.grandTotal,
    this.previewToken,
    this.status = 'OPEN',
  });

  factory BillModel.fromJson(Map<String, dynamic> json) => BillModel(
    orderNo: json['order_no'] as String?,
    sessionId: json['session_id'] as String? ?? '',
    tableId: json['table_id'] as String? ?? '',
    guestCount: json['guest_count'] as int? ?? 0,
    openedAt: json['opened_at'] != null
        ? DateTime.tryParse(json['opened_at'] as String)
        : null,
    customerId: json['customer_id'] as String?,
    customerName: json['customer_name'] as String?,
    orderIds: (json['order_ids'] as List).map((e) => e as String).toList(),
    items: (json['items'] as List)
        .map((j) => BillItemModel.fromJson(j as Map<String, dynamic>))
        .toList(),
    subtotal: (json['subtotal'] as num).toDouble(),
    discountAmount: (json['discount_amount'] as num).toDouble(),
    serviceChargeRate: (json['service_charge_rate'] as num).toDouble(),
    serviceChargeAmount: (json['service_charge_amount'] as num).toDouble(),
    grandTotal: (json['grand_total'] as num).toDouble(),
    previewToken: json['preview_token'] as String?,
    status: json['status'] as String? ?? 'OPEN',
  );

  factory BillModel.fromSalesOrderJson(Map<String, dynamic> json) => BillModel(
    orderNo: json['order_no'] as String?,
    sessionId: json['session_id'] as String? ?? '',
    tableId: json['table_id'] as String? ?? '',
    guestCount: (json['party_size'] as num?)?.toInt() ?? 1,
    customerId: json['customer_id'] as String?,
    customerName: json['customer_name'] as String?,
    orderIds: [
      if ((json['order_id'] as String?)?.isNotEmpty ?? false)
        json['order_id'] as String,
    ],
    items: ((json['items'] as List?) ?? const [])
        .map((j) => BillItemModel.fromJson(j as Map<String, dynamic>))
        .toList(),
    subtotal:
        (json['subtotal'] as num?)?.toDouble() ??
        (json['total_amount'] as num?)?.toDouble() ??
        0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    serviceChargeRate: (json['service_charge_rate'] as num?)?.toDouble() ?? 0,
    serviceChargeAmount:
        (json['service_charge_amount'] as num?)?.toDouble() ?? 0,
    grandTotal: (json['total_amount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'OPEN',
  );

  bool get isEmpty => items.isEmpty;
  bool get hasServiceCharge => serviceChargeRate > 0;
  bool get hasTable => tableId.trim().isNotEmpty;
  bool get isOpen => status.toUpperCase() == 'OPEN';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get hasPreparingItems => items.any((i) => i.isPreparing);
}

/// ผลลัพธ์จากการ split bill
class SplitResult {
  final String mode; // 'equal' | 'by_item'
  final int count;
  final double grandTotal;
  final double perPerson; // มีเฉพาะ mode = equal
  final List<SplitPortion> splits;
  final String? previewToken;

  const SplitResult({
    required this.mode,
    required this.count,
    required this.grandTotal,
    required this.perPerson,
    required this.splits,
    this.previewToken,
  });

  factory SplitResult.fromJson(Map<String, dynamic> json) => SplitResult(
    mode: json['mode'] as String,
    count:
        (json['count'] as int?) ??
        (json['splits'] != null ? (json['splits'] as List).length : 0),
    grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
    perPerson: (json['per_person'] as num?)?.toDouble() ?? 0,
    splits: (json['splits'] as List)
        .map((j) => SplitPortion.fromJson(j as Map<String, dynamic>))
        .toList(),
    previewToken: json['preview_token'] as String?,
  );
}

class SplitPortion {
  final String label;
  final double subtotal;
  final double discountAmount;
  final double serviceCharge;
  final double total;
  final List<String> orderIds;
  final List<Map<String, dynamic>> items;

  const SplitPortion({
    required this.label,
    required this.subtotal,
    this.discountAmount = 0,
    required this.serviceCharge,
    required this.total,
    this.orderIds = const [],
    required this.items,
  });

  factory SplitPortion.fromJson(Map<String, dynamic> json) => SplitPortion(
    label: json['label'] as String? ?? '',
    subtotal:
        (json['subtotal'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0,
    total:
        (json['total'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        0,
    orderIds:
        (json['order_ids'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    items:
        (json['items'] as List?)
            ?.map((j) => j as Map<String, dynamic>)
            .toList() ??
        [],
  );
}
