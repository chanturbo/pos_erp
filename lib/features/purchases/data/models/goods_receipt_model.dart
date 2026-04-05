import 'goods_receipt_item_model.dart';

class GoodsReceiptModel {
  final String grId;
  final String grNo;
  final DateTime grDate;
  final String? poId;
  final String? poNo;
  final String supplierId;
  final String supplierName;
  final String warehouseId;
  final String warehouseName;
  final String userId;
  final String status;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related data
  final List<GoodsReceiptItemModel>? items;
  final int itemCount; // จำนวนรายการ (จาก COUNT query, ไม่ต้องโหลด items เต็ม)

  GoodsReceiptModel({
    required this.grId,
    required this.grNo,
    required this.grDate,
    this.poId,
    this.poNo,
    required this.supplierId,
    required this.supplierName,
    required this.warehouseId,
    required this.warehouseName,
    required this.userId,
    this.status = 'DRAFT',
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.itemCount = 0,
  });

  factory GoodsReceiptModel.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptModel(
      grId: json['gr_id'] as String,
      grNo: json['gr_no'] as String,
      grDate: DateTime.parse(json['gr_date'] as String),
      poId: json['po_id'] as String?,
      poNo: json['po_no'] as String?,
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'DRAFT',
      remark: json['remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => GoodsReceiptItemModel.fromJson(item))
              .toList()
          : null,
      itemCount: (json['item_count'] as num?)?.toInt() ??
          (json['items'] as List?)?.length ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gr_id': grId,
      'gr_no': grNo,
      'gr_date': grDate.toIso8601String(),
      'po_id': poId,
      'po_no': poNo,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'user_id': userId,
      'status': status,
      'remark': remark,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (items != null) 'items': items!.map((e) => e.toJson()).toList(),
    };
  }

  GoodsReceiptModel copyWith({
    String? grId,
    String? grNo,
    DateTime? grDate,
    String? poId,
    String? poNo,
    String? supplierId,
    String? supplierName,
    String? warehouseId,
    String? warehouseName,
    String? userId,
    String? status,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GoodsReceiptItemModel>? items,
  }) {
    return GoodsReceiptModel(
      grId: grId ?? this.grId,
      grNo: grNo ?? this.grNo,
      grDate: grDate ?? this.grDate,
      poId: poId ?? this.poId,
      poNo: poNo ?? this.poNo,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}