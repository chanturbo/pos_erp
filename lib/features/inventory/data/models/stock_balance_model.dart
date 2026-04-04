class StockBalanceModel {
  final String productId;
  final String productCode;
  final String productName;
  final String? barcode;
  final String baseUnit;
  final String warehouseId;
  final String warehouseName;
  final double balance;

  StockBalanceModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.barcode,
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
      barcode: json['barcode'] as String?,
      baseUnit: json['base_unit'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      balance: (json['balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'barcode': barcode,
      'base_unit': baseUnit,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'balance': balance,
    };
  }

  StockBalanceModel copyWith({
    String? productId,
    String? productCode,
    String? productName,
    Object? barcode = _sentinel,
    String? baseUnit,
    String? warehouseId,
    String? warehouseName,
    double? balance,
  }) {
    return StockBalanceModel(
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      barcode: barcode == _sentinel ? this.barcode : barcode as String?,
      baseUnit: baseUnit ?? this.baseUnit,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      balance: balance ?? this.balance,
    );
  }
}

const _sentinel = Object();