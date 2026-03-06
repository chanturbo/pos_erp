import 'purchase_order_item_model.dart';

class PurchaseOrderModel {
  final String poId;
  final String poNo;
  final DateTime poDate;
  final String supplierId;
  final String warehouseId;
  final String userId;
  final double subtotal;
  final double discountAmount;
  final double vatAmount;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime? deliveryDate;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related data
  final String? supplierName;
  final String? warehouseName;
  final List<PurchaseOrderItemModel>? items;

  PurchaseOrderModel({
    required this.poId,
    required this.poNo,
    required this.poDate,
    required this.supplierId,
    required this.warehouseId,
    required this.userId,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.vatAmount = 0,
    this.totalAmount = 0,
    this.status = 'DRAFT',
    this.paymentStatus = 'UNPAID',
    this.deliveryDate,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.warehouseName,
    this.items,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      poId: json['po_id'] as String,
      poNo: json['po_no'] as String,
      poDate: DateTime.parse(json['po_date'] as String),
      supplierId: json['supplier_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      userId: json['user_id'] as String,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'DRAFT',
      paymentStatus: json['payment_status'] as String? ?? 'UNPAID',
      deliveryDate: json['delivery_date'] != null 
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      supplierName: json['supplier_name'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => PurchaseOrderItemModel.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'po_id': poId,
      'po_no': poNo,
      'po_date': poDate.toIso8601String(),
      'supplier_id': supplierId,
      'warehouse_id': warehouseId,
      'user_id': userId,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'vat_amount': vatAmount,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'delivery_date': deliveryDate?.toIso8601String(),
      'remark': remark,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'supplier_name': supplierName, // ✅ เพิ่ม
      'warehouse_name': warehouseName, // ✅ เพิ่ม
      if (items != null) 'items': items!.map((e) => e.toJson()).toList(),
    };
  }

  PurchaseOrderModel copyWith({
    String? poId,
    String? poNo,
    DateTime? poDate,
    String? supplierId,
    String? warehouseId,
    String? userId,
    double? subtotal,
    double? discountAmount,
    double? vatAmount,
    double? totalAmount,
    String? status,
    String? paymentStatus,
    DateTime? deliveryDate,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? warehouseName,
    List<PurchaseOrderItemModel>? items,
  }) {
    return PurchaseOrderModel(
      poId: poId ?? this.poId,
      poNo: poNo ?? this.poNo,
      poDate: poDate ?? this.poDate,
      supplierId: supplierId ?? this.supplierId,
      warehouseId: warehouseId ?? this.warehouseId,
      userId: userId ?? this.userId,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      vatAmount: vatAmount ?? this.vatAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      warehouseName: warehouseName ?? this.warehouseName,
      items: items ?? this.items,
    );
  }
}