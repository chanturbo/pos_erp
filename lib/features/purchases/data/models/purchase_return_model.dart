import 'purchase_return_item_model.dart';

class PurchaseReturnModel {
  final String returnId;
  final String returnNo;
  final DateTime returnDate;
  final String supplierId;
  final String supplierName;
  final String? referenceType;
  final String? referenceId;
  final double totalAmount;
  final String status;
  final String? reason;
  final String? remark;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseReturnItemModel>? items;

  PurchaseReturnModel({
    required this.returnId,
    required this.returnNo,
    required this.returnDate,
    required this.supplierId,
    required this.supplierName,
    this.referenceType,
    this.referenceId,
    required this.totalAmount,
    this.status = 'DRAFT',
    this.reason,
    this.remark,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  bool get isDraft => status == 'DRAFT';
  bool get isConfirmed => status == 'CONFIRMED';

  factory PurchaseReturnModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnModel(
      returnId: json['return_id'] as String,
      returnNo: json['return_no'] as String,
      returnDate: DateTime.parse(json['return_date'] as String),
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'DRAFT',
      reason: json['reason'] as String?,
      remark: json['remark'] as String?,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['items'] != null
          ? (json['items'] as List).map((i) => PurchaseReturnItemModel.fromJson(i as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'return_id': returnId,
      'return_no': returnNo,
      'return_date': returnDate.toIso8601String(),
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'total_amount': totalAmount,
      'status': status,
      'reason': reason,
      'remark': remark,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
    };
  }

  PurchaseReturnModel copyWith({
    String? returnId,
    String? returnNo,
    DateTime? returnDate,
    String? supplierId,
    String? supplierName,
    String? referenceType,
    String? referenceId,
    double? totalAmount,
    String? status,
    String? reason,
    String? remark,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchaseReturnItemModel>? items,
  }) {
    return PurchaseReturnModel(
      returnId: returnId ?? this.returnId,
      returnNo: returnNo ?? this.returnNo,
      returnDate: returnDate ?? this.returnDate,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      remark: remark ?? this.remark,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}