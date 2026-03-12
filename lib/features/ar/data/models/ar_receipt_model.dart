// ar_receipt_model.dart
// Day 39: AR Receipt Model — ใบเสร็จรับเงินลูกหนี้

import 'ar_receipt_allocation_model.dart';

class ArReceiptModel {
  final String receiptId;
  final String receiptNo;
  final DateTime receiptDate;
  final String customerId;
  final String customerName;
  final double totalAmount;
  final String paymentMethod; // CASH, TRANSFER, CHEQUE, CREDIT_CARD
  final String? bankName;
  final String? chequeNo;
  final DateTime? chequeDate;
  final String? transferRef;
  final String userId;
  final String? remark;
  final DateTime createdAt;
  final List<ArReceiptAllocationModel>? allocations;

  ArReceiptModel({
    required this.receiptId,
    required this.receiptNo,
    required this.receiptDate,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.paymentMethod = 'CASH',
    this.bankName,
    this.chequeNo,
    this.chequeDate,
    this.transferRef,
    required this.userId,
    this.remark,
    required this.createdAt,
    this.allocations,
  });

  double get allocatedAmount =>
      allocations?.fold(0.0, (sum, a) => sum! + a.allocatedAmount) ?? 0;

  factory ArReceiptModel.fromJson(Map<String, dynamic> json) {
    return ArReceiptModel(
      receiptId: json['receipt_id'] as String,
      receiptNo: json['receipt_no'] as String,
      receiptDate: DateTime.parse(json['receipt_date'] as String),
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'CASH',
      bankName: json['bank_name'] as String?,
      chequeNo: json['cheque_no'] as String?,
      chequeDate: json['cheque_date'] != null
          ? DateTime.parse(json['cheque_date'] as String)
          : null,
      transferRef: json['transfer_ref'] as String?,
      userId: json['user_id'] as String,
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      allocations: json['allocations'] != null
          ? (json['allocations'] as List)
              .map((a) => ArReceiptAllocationModel.fromJson(
                  a as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receipt_id': receiptId,
      'receipt_no': receiptNo,
      'receipt_date': receiptDate.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'cheque_no': chequeNo,
      'cheque_date': chequeDate?.toIso8601String(),
      'transfer_ref': transferRef,
      'user_id': userId,
      'remark': remark,
      'created_at': createdAt.toIso8601String(),
      if (allocations != null)
        'allocations': allocations!.map((a) => a.toJson()).toList(),
    };
  }

  ArReceiptModel copyWith({
    String? receiptId,
    String? receiptNo,
    DateTime? receiptDate,
    String? customerId,
    String? customerName,
    double? totalAmount,
    String? paymentMethod,
    String? bankName,
    String? chequeNo,
    DateTime? chequeDate,
    String? transferRef,
    String? userId,
    String? remark,
    DateTime? createdAt,
    List<ArReceiptAllocationModel>? allocations,
  }) {
    return ArReceiptModel(
      receiptId: receiptId ?? this.receiptId,
      receiptNo: receiptNo ?? this.receiptNo,
      receiptDate: receiptDate ?? this.receiptDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankName: bankName ?? this.bankName,
      chequeNo: chequeNo ?? this.chequeNo,
      chequeDate: chequeDate ?? this.chequeDate,
      transferRef: transferRef ?? this.transferRef,
      userId: userId ?? this.userId,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      allocations: allocations ?? this.allocations,
    );
  }
}