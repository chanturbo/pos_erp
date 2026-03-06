class PurchaseOrderItemModel {
  final String itemId;
  final String poId;
  final int lineNo;
  final String productId;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double amount;
  final double receivedQuantity;
  final double remainingQuantity;
  
  // Related data
  final String? productCode;
  final String? productName;
  final String? unit; // ✅ เพิ่ม

  PurchaseOrderItemModel({
    required this.itemId,
    required this.poId,
    required this.lineNo,
    required this.productId,
    this.quantity = 0,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.amount = 0,
    this.receivedQuantity = 0,
    this.remainingQuantity = 0,
    this.productCode,
    this.productName,
    this.unit, // ✅ เพิ่ม
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      itemId: json['item_id'] as String,
      poId: json['po_id'] as String,
      lineNo: json['line_no'] as int,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toDouble() ?? 0,
      productCode: json['product_code'] as String?,
      productName: json['product_name'] as String?,
      unit: json['unit'] as String?, // ✅ เพิ่ม
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'po_id': poId,
      'line_no': lineNo,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'amount': amount,
      'received_quantity': receivedQuantity,
      'remaining_quantity': remainingQuantity,
      'product_code': productCode, // ✅ เพิ่ม
      'product_name': productName, // ✅ เพิ่ม
      'unit': unit, // ✅ เพิ่ม
    };
  }

  PurchaseOrderItemModel copyWith({
    String? itemId,
    String? poId,
    int? lineNo,
    String? productId,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? discountAmount,
    double? amount,
    double? receivedQuantity,
    double? remainingQuantity,
    String? productCode,
    String? productName,
    String? unit, // ✅ เพิ่ม
  }) {
    return PurchaseOrderItemModel(
      itemId: itemId ?? this.itemId,
      poId: poId ?? this.poId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      amount: amount ?? this.amount,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit, // ✅ เพิ่ม
    );
  }
}