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
  final List<String>? couponCodes;           // รหัสคูปองที่ใช้
  final Map<String, String>? couponPromotionNames; // code → promotionName
  final double couponDiscount;               // ส่วนลดรวมจากคูปอง
  final int pointsUsed;                      // แต้มที่แลกในใบขายนี้
  final DateTime? dueDate;                   // วันครบกำหนดชำระ (สำหรับการขายเครดิต)
  final String? tableId;
  final String? sessionId;
  final String? serviceType;
  final int? partySize;

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
    this.couponCodes,
    this.couponPromotionNames,
    this.couponDiscount = 0.0,
    this.pointsUsed = 0,
    this.dueDate,
    this.tableId,
    this.sessionId,
    this.serviceType,
    this.partySize,
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
      couponCodes: (json['coupon_codes'] as List?)?.map((e) => e.toString()).toList(),
      couponPromotionNames: (json['coupon_promotion_names'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      couponDiscount: (json['coupon_discount'] as num?)?.toDouble() ?? 0.0,
      pointsUsed: (json['points_used'] as int?) ?? 0,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      tableId: json['table_id'] as String?,
      sessionId: json['session_id'] as String?,
      serviceType: json['service_type'] as String?,
      partySize: (json['party_size'] as num?)?.toInt(),
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
      'coupon_codes': couponCodes,
      'coupon_discount': couponDiscount,
      'points_used': pointsUsed,
      'due_date': dueDate?.toIso8601String(),
      'table_id': tableId,
      'session_id': sessionId,
      'service_type': serviceType,
      'party_size': partySize,
    };
  }
}

class SalesOrderItemModel {
  final String itemId;
  final String orderId;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? specialInstructions;
  final List<SalesOrderItemModifierModel> modifiers;
  final bool isFreeItem;
  final String? promotionName;
  final double unitCost;    // ต้นทุนเฉลี่ย (WAC) ณ เวลาขาย
  final double cogsAmount;  // ต้นทุนสินค้าที่ขาย = unitCost × quantity

  /// กำไรขั้นต้น = รายได้ - ต้นทุน
  double get grossProfit => amount - cogsAmount;

  SalesOrderItemModel({
    required this.itemId,
    required this.orderId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.specialInstructions,
    this.modifiers = const [],
    this.isFreeItem = false,
    this.promotionName,
    this.unitCost = 0,
    this.cogsAmount = 0,
  });

  factory SalesOrderItemModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModel(
      itemId: json['item_id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String? ?? '',
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      specialInstructions: json['special_instructions'] as String?,
      modifiers: (json['modifiers'] as List?)
              ?.map((item) => SalesOrderItemModifierModel.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          const [],
      isFreeItem: (json['is_free_item'] as bool?) ?? false,
      promotionName: json['promotion_name'] as String?,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      cogsAmount: (json['cogs_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'order_id': orderId,
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'special_instructions': specialInstructions,
      'modifiers': modifiers.map((item) => item.toJson()).toList(),
      'is_free_item': isFreeItem,
      'promotion_name': promotionName,
      'unit_cost': unitCost,
      'cogs_amount': cogsAmount,
    };
  }
}

class SalesOrderItemModifierModel {
  final String modifierId;
  final String modifierName;
  final double priceAdjustment;

  SalesOrderItemModifierModel({
    required this.modifierId,
    required this.modifierName,
    this.priceAdjustment = 0,
  });

  factory SalesOrderItemModifierModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModifierModel(
      modifierId: json['modifier_id'] as String? ?? '',
      modifierName: json['modifier_name'] as String? ?? '',
      priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modifier_id': modifierId,
      'modifier_name': modifierName,
      'price_adjustment': priceAdjustment,
    };
  }
}
