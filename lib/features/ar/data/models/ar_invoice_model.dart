// ar_invoice_model.dart
// Day 36: AR Invoice Model — ใบแจ้งหนี้ลูกหนี้

class ArInvoiceModel {
  final String invoiceId;
  final String invoiceNo;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String customerId;
  final String customerName;
  final double totalAmount;
  final double paidAmount;
  final String? referenceType;
  final String? referenceId;
  final String status;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ArInvoiceItemModel>? items;

  ArInvoiceModel({
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceDate,
    this.dueDate,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.paidAmount = 0,
    this.referenceType,
    this.referenceId,
    this.status = 'UNPAID',
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => remainingAmount <= 0.01;
  bool get isPartiallyPaid => paidAmount > 0.01 && paidAmount < totalAmount;
  bool get isOverdue =>
      dueDate != null && DateTime.now().isAfter(dueDate!) && !isFullyPaid;

  factory ArInvoiceModel.fromJson(Map<String, dynamic> json) {
    return ArInvoiceModel(
      invoiceId: json['invoice_id'] as String,
      invoiceNo: json['invoice_no'] as String,
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      status: json['status'] as String? ?? 'UNPAID',
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) =>
                  ArInvoiceItemModel.fromJson(i as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'invoice_no': invoiceNo,
      'invoice_date': invoiceDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'status': status,
      'remark': remark,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
    };
  }

  ArInvoiceModel copyWith({
    String? invoiceId,
    String? invoiceNo,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? customerId,
    String? customerName,
    double? totalAmount,
    double? paidAmount,
    String? referenceType,
    String? referenceId,
    String? status,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ArInvoiceItemModel>? items,
  }) {
    return ArInvoiceModel(
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ArInvoiceItemModel — รายการสินค้าในใบแจ้งหนี้
// ─────────────────────────────────────────────────────────────────
class ArInvoiceItemModel {
  final String itemId;
  final String invoiceId;
  final int lineNo;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double amount;
  final String? remark;

  ArInvoiceItemModel({
    required this.itemId,
    required this.invoiceId,
    required this.lineNo,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    required this.amount,
    this.remark,
  });

  factory ArInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return ArInvoiceItemModel(
      itemId: json['item_id'] as String,
      invoiceId: json['invoice_id'] as String,
      lineNo: json['line_no'] as int,
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num).toDouble(),
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'invoice_id': invoiceId,
      'line_no': lineNo,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'amount': amount,
      'remark': remark,
    };
  }

  ArInvoiceItemModel copyWith({
    String? itemId,
    String? invoiceId,
    int? lineNo,
    String? productId,
    String? productCode,
    String? productName,
    String? unit,
    double? quantity,
    double? unitPrice,
    double? discountAmount,
    double? amount,
    String? remark,
  }) {
    return ArInvoiceItemModel(
      itemId: itemId ?? this.itemId,
      invoiceId: invoiceId ?? this.invoiceId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
    );
  }
}