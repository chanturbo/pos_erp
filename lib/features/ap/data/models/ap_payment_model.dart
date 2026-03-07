import 'ap_payment_allocation_model.dart';

class ApPaymentModel {
  final String paymentId;
  final String paymentNo;
  final DateTime paymentDate;
  final String supplierId;
  final String supplierName;
  final double totalAmount;
  final String paymentMethod;
  final String? bankName;
  final String? chequeNo;
  final DateTime? chequeDate;
  final String? transferRef;
  final String userId;
  final String? remark;
  final DateTime createdAt;
  final List<ApPaymentAllocationModel>? allocations;

  ApPaymentModel({
    required this.paymentId,
    required this.paymentNo,
    required this.paymentDate,
    required this.supplierId,
    required this.supplierName,
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

  factory ApPaymentModel.fromJson(Map<String, dynamic> json) {
    return ApPaymentModel(
      paymentId: json['payment_id'] as String,
      paymentNo: json['payment_no'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'CASH',
      bankName: json['bank_name'] as String?,
      chequeNo: json['cheque_no'] as String?,
      chequeDate: json['cheque_date'] != null ? DateTime.parse(json['cheque_date'] as String) : null,
      transferRef: json['transfer_ref'] as String?,
      userId: json['user_id'] as String,
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      allocations: json['allocations'] != null
          ? (json['allocations'] as List).map((a) => ApPaymentAllocationModel.fromJson(a as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'payment_no': paymentNo,
      'payment_date': paymentDate.toIso8601String(),
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'cheque_no': chequeNo,
      'cheque_date': chequeDate?.toIso8601String(),
      'transfer_ref': transferRef,
      'user_id': userId,
      'remark': remark,
      'created_at': createdAt.toIso8601String(),
      if (allocations != null) 'allocations': allocations!.map((a) => a.toJson()).toList(),
    };
  }

  ApPaymentModel copyWith({
    String? paymentId,
    String? paymentNo,
    DateTime? paymentDate,
    String? supplierId,
    String? supplierName,
    double? totalAmount,
    String? paymentMethod,
    String? bankName,
    String? chequeNo,
    DateTime? chequeDate,
    String? transferRef,
    String? userId,
    String? remark,
    DateTime? createdAt,
    List<ApPaymentAllocationModel>? allocations,
  }) {
    return ApPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      paymentNo: paymentNo ?? this.paymentNo,
      paymentDate: paymentDate ?? this.paymentDate,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
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