import 'ap_invoice_item_model.dart';

class ApInvoiceModel {
  final String invoiceId;
  final String invoiceNo;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String supplierId;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final String? referenceType;
  final String? referenceId;
  final String status;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ApInvoiceItemModel>? items;

  ApInvoiceModel({
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceDate,
    this.dueDate,
    required this.supplierId,
    required this.supplierName,
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
  bool get isFullyPaid => remainingAmount <= 0;
  bool get isPartiallyPaid => paidAmount > 0 && paidAmount < totalAmount;
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!) && !isFullyPaid;

  factory ApInvoiceModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    final updatedAtRaw = json['updated_at'] as String?;

    return ApInvoiceModel(
      invoiceId: json['invoice_id'] as String? ?? '',
      invoiceNo: json['invoice_no'] as String? ?? '',
      invoiceDate: DateTime.parse(
        json['invoice_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      supplierId: json['supplier_id'] as String? ?? '',
      supplierName: json['supplier_name'] as String? ?? '',
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      status: json['status'] as String? ?? 'UNPAID',
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(
        createdAtRaw ?? updatedAtRaw ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        updatedAtRaw ?? createdAtRaw ?? DateTime.now().toIso8601String(),
      ),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) => ApInvoiceItemModel.fromJson(i as Map<String, dynamic>))
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
      'supplier_id': supplierId,
      'supplier_name': supplierName,
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

  ApInvoiceModel copyWith({
    String? invoiceId,
    String? invoiceNo,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? supplierId,
    String? supplierName,
    double? totalAmount,
    double? paidAmount,
    String? referenceType,
    String? referenceId,
    String? status,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ApInvoiceItemModel>? items,
  }) {
    return ApInvoiceModel(
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
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
