class SalesOrderModel {
  final String orderId;
  final String orderNo;
  final DateTime orderDate;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String paymentType;
  final double paidAmount;
  final double changeAmount;
  final String status;
  final List<SalesOrderItemModel>? items;
  
  SalesOrderModel({
    required this.orderId,
    required this.orderNo,
    required this.orderDate,
    this.customerId,
    this.customerName,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentType,
    required this.paidAmount,
    required this.changeAmount,
    required this.status,
    this.items,
  });
  
  factory SalesOrderModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderModel(
      orderId: json['order_id'] as String,
      orderNo: json['order_no'] as String,
      orderDate: DateTime.parse(json['order_date'] as String),
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentType: json['payment_type'] as String,
      paidAmount: (json['paid_amount'] as num).toDouble(),
      changeAmount: (json['change_amount'] as num).toDouble(),
      status: json['status'] as String,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => SalesOrderItemModel.fromJson(item))
              .toList()
          : null,
    );
  }
}

class SalesOrderItemModel {
  final String productId;
  final String productCode;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double amount;
  
  SalesOrderItemModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });
  
  factory SalesOrderItemModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModel(
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}