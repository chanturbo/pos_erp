class StockBalanceModel {
  final String productId;
  final String productCode;
  final String productName;
  final String baseUnit;
  final String warehouseId;
  final String warehouseName;
  final double balance;
  
  StockBalanceModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.baseUnit,
    required this.warehouseId,
    required this.warehouseName,
    required this.balance,
  });
  
  factory StockBalanceModel.fromJson(Map<String, dynamic> json) {
    return StockBalanceModel(
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      baseUnit: json['base_unit'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      balance: (json['balance'] as num).toDouble(),
    );
  }
}