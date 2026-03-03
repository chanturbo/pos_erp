class SalesSummaryModel {
  final int totalOrders;
  final double totalSales;
  final double avgOrderValue;
  final double totalDiscount;
  
  SalesSummaryModel({
    required this.totalOrders,
    required this.totalSales,
    required this.avgOrderValue,
    required this.totalDiscount,
  });
  
  factory SalesSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesSummaryModel(
      totalOrders: json['total_orders'] as int,
      totalSales: (json['total_sales'] as num).toDouble(),
      avgOrderValue: (json['avg_order_value'] as num).toDouble(),
      totalDiscount: (json['total_discount'] as num).toDouble(),
    );
  }
}

class DailySalesModel {
  final String date;
  final int orders;
  final double sales;
  
  DailySalesModel({
    required this.date,
    required this.orders,
    required this.sales,
  });
  
  factory DailySalesModel.fromJson(Map<String, dynamic> json) {
    return DailySalesModel(
      date: json['date'] as String,
      orders: json['orders'] as int,
      sales: (json['sales'] as num).toDouble(),
    );
  }
}

class TopProductModel {
  final String productId;
  final String productCode;
  final String productName;
  final double totalQuantity;
  final double totalSales;
  final int orderCount;
  
  TopProductModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.totalQuantity,
    required this.totalSales,
    required this.orderCount,
  });
  
  factory TopProductModel.fromJson(Map<String, dynamic> json) {
    return TopProductModel(
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      totalQuantity: (json['total_quantity'] as num).toDouble(),
      totalSales: (json['total_sales'] as num).toDouble(),
      orderCount: json['order_count'] as int,
    );
  }
}

class TopCustomerModel {
  final String customerId;
  final String customerName;
  final int orderCount;
  final double totalSales;
  
  TopCustomerModel({
    required this.customerId,
    required this.customerName,
    required this.orderCount,
    required this.totalSales,
  });
  
  factory TopCustomerModel.fromJson(Map<String, dynamic> json) {
    return TopCustomerModel(
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      orderCount: json['order_count'] as int,
      totalSales: (json['total_sales'] as num).toDouble(),
    );
  }
}