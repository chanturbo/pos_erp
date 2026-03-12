// ar_receipt_allocation_model.dart
// Day 39: AR Receipt Allocation Model — จัดสรรเงินรับกับใบแจ้งหนี้

class ArReceiptAllocationModel {
  final String allocationId;
  final String receiptId;
  final String invoiceId;
  final String? invoiceNo;       // เพิ่มเพื่อแสดงผล UI
  final String? customerName;    // เพิ่มเพื่อแสดงผล UI
  final double allocatedAmount;
  final DateTime createdAt;

  ArReceiptAllocationModel({
    required this.allocationId,
    required this.receiptId,
    required this.invoiceId,
    this.invoiceNo,
    this.customerName,
    required this.allocatedAmount,
    required this.createdAt,
  });

  factory ArReceiptAllocationModel.fromJson(Map<String, dynamic> json) {
    return ArReceiptAllocationModel(
      allocationId: json['allocation_id'] as String,
      receiptId: json['receipt_id'] as String,
      invoiceId: json['invoice_id'] as String,
      invoiceNo: json['invoice_no'] as String?,
      customerName: json['customer_name'] as String?,
      allocatedAmount: (json['allocated_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allocation_id': allocationId,
      'receipt_id': receiptId,
      'invoice_id': invoiceId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'allocated_amount': allocatedAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ArReceiptAllocationModel copyWith({
    String? allocationId,
    String? receiptId,
    String? invoiceId,
    String? invoiceNo,
    String? customerName,
    double? allocatedAmount,
    DateTime? createdAt,
  }) {
    return ArReceiptAllocationModel(
      allocationId: allocationId ?? this.allocationId,
      receiptId: receiptId ?? this.receiptId,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerName: customerName ?? this.customerName,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}