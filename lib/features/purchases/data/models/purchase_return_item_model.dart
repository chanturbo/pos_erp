class PurchaseReturnItemModel {
  final String itemId;
  final String returnId;
  final int lineNo;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? reason;
  final String? remark;

  PurchaseReturnItemModel({
    required this.itemId,
    required this.returnId,
    required this.lineNo,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.reason,
    this.remark,
  });

  factory PurchaseReturnItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnItemModel(
      itemId: json['item_id'] as String,
      returnId: json['return_id'] as String,
      lineNo: json['line_no'] as int,
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String?,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'return_id': returnId,
      'line_no': lineNo,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'reason': reason,
      'remark': remark,
    };
  }

  PurchaseReturnItemModel copyWith({
    String? itemId,
    String? returnId,
    int? lineNo,
    String? productId,
    String? productCode,
    String? productName,
    String? unit,
    String? warehouseId,
    String? warehouseName,
    double? quantity,
    double? unitPrice,
    double? amount,
    String? reason,
    String? remark,
  }) {
    return PurchaseReturnItemModel(
      itemId: itemId ?? this.itemId,
      returnId: returnId ?? this.returnId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      remark: remark ?? this.remark,
    );
  }
}