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
      // ✅ ใช้ default value ถ้าไม่มี
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? (json['total_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentType: json['payment_type'] as String? ?? 'CASH',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? (json['total_amount'] as num).toDouble(),
      changeAmount: (json['change_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'COMPLETED',
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => SalesOrderItemModel.fromJson(item))
              .toList()
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'order_no': orderNo,
      'order_date': orderDate.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'status': status,
      'items': items?.map((item) => item.toJson()).toList(),
    };
  }
}

class SalesOrderItemModel {
  final String itemId;
  final String orderId;
  final String productId;
  final String productCode;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double amount;
  
  SalesOrderItemModel({
    required this.itemId,
    required this.orderId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });
  
  factory SalesOrderItemModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModel(
      itemId: json['item_id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'order_id': orderId,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
    };
  }
}