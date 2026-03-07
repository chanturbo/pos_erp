class GoodsReceiptItemModel {
  final String itemId;
  final String grId;
  final int lineNo;
  final String? poItemId;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double orderedQuantity;
  final double receivedQuantity;
  final double unitPrice;
  final double amount;
  final String? lotNumber;
  final DateTime? expiryDate;
  final String? remark;

  GoodsReceiptItemModel({
    required this.itemId,
    required this.grId,
    required this.lineNo,
    this.poItemId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    this.orderedQuantity = 0,
    this.receivedQuantity = 0,
    this.unitPrice = 0,
    this.amount = 0,
    this.lotNumber,
    this.expiryDate,
    this.remark,
  });

  factory GoodsReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptItemModel(
      itemId: json['item_id'] as String,
      grId: json['gr_id'] as String,
      lineNo: json['line_no'] as int,
      poItemId: json['po_item_id'] as String?,
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String,
      orderedQuantity: (json['ordered_quantity'] as num?)?.toDouble() ?? 0,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      lotNumber: json['lot_number'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'gr_id': grId,
      'line_no': lineNo,
      'po_item_id': poItemId,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'ordered_quantity': orderedQuantity,
      'received_quantity': receivedQuantity,
      'unit_price': unitPrice,
      'amount': amount,
      'lot_number': lotNumber,
      'expiry_date': expiryDate?.toIso8601String(),
      'remark': remark,
    };
  }

  GoodsReceiptItemModel copyWith({
    String? itemId,
    String? grId,
    int? lineNo,
    String? poItemId,
    String? productId,
    String? productCode,
    String? productName,
    String? unit,
    double? orderedQuantity,
    double? receivedQuantity,
    double? unitPrice,
    double? amount,
    String? lotNumber,
    DateTime? expiryDate,
    String? remark,
  }) {
    return GoodsReceiptItemModel(
      itemId: itemId ?? this.itemId,
      grId: grId ?? this.grId,
      lineNo: lineNo ?? this.lineNo,
      poItemId: poItemId ?? this.poItemId,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      lotNumber: lotNumber ?? this.lotNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      remark: remark ?? this.remark,
    );
  }
}