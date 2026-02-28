class ProductModel {
  final String productId;
  final String productCode;
  final String productName;
  final String? barcode;
  final String? groupId;
  final String baseUnit;
  final double priceLevel1;
  final double priceLevel2;
  final double priceLevel3;
  final double priceLevel4;
  final double priceLevel5;
  final double standardCost;
  final bool isStockControl;
  final bool allowNegativeStock;
  final bool isActive;
  
  ProductModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.barcode,
    this.groupId,
    required this.baseUnit,
    required this.priceLevel1,
    this.priceLevel2 = 0,
    this.priceLevel3 = 0,
    this.priceLevel4 = 0,
    this.priceLevel5 = 0,
    this.standardCost = 0,
    this.isStockControl = true,
    this.allowNegativeStock = false,
    this.isActive = true,
  });
  
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      barcode: json['barcode'] as String?,
      groupId: json['group_id'] as String?,
      baseUnit: json['base_unit'] as String,
      priceLevel1: (json['price_level1'] as num).toDouble(),
      priceLevel2: (json['price_level2'] as num?)?.toDouble() ?? 0,
      priceLevel3: (json['price_level3'] as num?)?.toDouble() ?? 0,
      priceLevel4: (json['price_level4'] as num?)?.toDouble() ?? 0,
      priceLevel5: (json['price_level5'] as num?)?.toDouble() ?? 0,
      standardCost: (json['standard_cost'] as num?)?.toDouble() ?? 0,
      isStockControl: json['is_stock_control'] as bool? ?? true,
      allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'barcode': barcode,
      'group_id': groupId,
      'base_unit': baseUnit,
      'price_level1': priceLevel1,
      'price_level2': priceLevel2,
      'price_level3': priceLevel3,
      'price_level4': priceLevel4,
      'price_level5': priceLevel5,
      'standard_cost': standardCost,
      'is_stock_control': isStockControl,
      'allow_negative_stock': allowNegativeStock,
      'is_active': isActive,
    };
  }
}