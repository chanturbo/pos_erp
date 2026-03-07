class ApInvoiceItemModel {
  final String itemId;
  final String invoiceId;
  final int lineNo;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? remark;

  ApInvoiceItemModel({
    required this.itemId,
    required this.invoiceId,
    required this.lineNo,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.remark,
  });

  factory ApInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return ApInvoiceItemModel(
      itemId: json['item_id'] as String,
      invoiceId: json['invoice_id'] as String,
      lineNo: json['line_no'] as int,
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'invoice_id': invoiceId,
      'line_no': lineNo,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'remark': remark,
    };
  }

  ApInvoiceItemModel copyWith({
    String? itemId,
    String? invoiceId,
    int? lineNo,
    String? productId,
    String? productCode,
    String? productName,
    String? unit,
    double? quantity,
    double? unitPrice,
    double? amount,
    String? remark,
  }) {
    return ApInvoiceItemModel(
      itemId: itemId ?? this.itemId,
      invoiceId: invoiceId ?? this.invoiceId,
      lineNo: lineNo ?? this.lineNo,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
    );
  }
}