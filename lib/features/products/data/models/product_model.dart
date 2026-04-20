/// หน่วยนับสำหรับสินค้า เช่น ลัง ขวด ชิ้น
/// [factor] = จำนวน base unit ต่อ 1 หน่วยนี้
/// ตัวอย่าง: ลัง (factor=24) → 1 ลัง = 24 ชิ้น
class ProductUnitOption {
  final String unit;
  final double factor;
  final String? barcode;

  const ProductUnitOption({
    required this.unit,
    required this.factor,
    this.barcode,
  });

  factory ProductUnitOption.fromJson(Map<String, dynamic> json) =>
      ProductUnitOption(
        unit: json['unit'] as String,
        factor: (json['factor'] as num).toDouble(),
        barcode: json['barcode'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'factor': factor,
    'barcode': barcode,
  };

  @override
  String toString() => unit;
}

class ProductModel {
  final String productId;
  final String productCode;
  final String productName;
  final String? barcode;
  final String? groupId;
  final String baseUnit;

  /// หน่วยแปลง เช่น [{"unit":"ลัง","factor":24},{"unit":"แพ็ค","factor":6}]
  final List<ProductUnitOption> unitConversions;
  final double priceLevel1;
  final double priceLevel2;
  final double priceLevel3;
  final double priceLevel4;
  final double priceLevel5;
  final double standardCost;
  final bool isStockControl;
  final bool allowNegativeStock;
  final bool isActive;
  final String? imagePath;

  // Restaurant context
  // RETAIL | RESTAURANT | BOTH
  final String serviceMode;
  // kitchen | bar | dessert | cashier (nullable)
  final String? prepStation;
  final bool requiresPreparation;
  final bool dineInAvailable;
  final bool takeawayAvailable;

  ProductModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.barcode,
    this.groupId,
    required this.baseUnit,
    this.unitConversions = const [],
    required this.priceLevel1,
    this.priceLevel2 = 0,
    this.priceLevel3 = 0,
    this.priceLevel4 = 0,
    this.priceLevel5 = 0,
    this.standardCost = 0,
    this.isStockControl = true,
    this.allowNegativeStock = false,
    this.isActive = true,
    this.imagePath,
    this.serviceMode = 'RETAIL',
    this.prepStation,
    this.requiresPreparation = false,
    this.dineInAvailable = false,
    this.takeawayAvailable = false,
  });

  /// ตัวเลือกหน่วยทั้งหมด: base unit (factor=1) + หน่วยแปลง
  List<ProductUnitOption> get allUnits => [
    ProductUnitOption(unit: baseUnit, factor: 1),
    ...unitConversions,
  ];

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // parse unitConversion JSON array
    List<ProductUnitOption> conversions = [];
    final raw = json['unit_conversion'];
    if (raw is List) {
      conversions = raw
          .whereType<Map<String, dynamic>>()
          .map(ProductUnitOption.fromJson)
          .toList();
    }

    return ProductModel(
      productId: json['product_id'] as String,
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      barcode: json['barcode'] as String?,
      groupId: json['group_id'] as String?,
      baseUnit: json['base_unit'] as String,
      unitConversions: conversions,
      priceLevel1: (json['price_level1'] as num).toDouble(),
      priceLevel2: (json['price_level2'] as num?)?.toDouble() ?? 0,
      priceLevel3: (json['price_level3'] as num?)?.toDouble() ?? 0,
      priceLevel4: (json['price_level4'] as num?)?.toDouble() ?? 0,
      priceLevel5: (json['price_level5'] as num?)?.toDouble() ?? 0,
      standardCost: (json['standard_cost'] as num?)?.toDouble() ?? 0,
      isStockControl: json['is_stock_control'] as bool? ?? true,
      allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      imagePath: json['image_path'] as String?,
      serviceMode: json['service_mode'] as String? ?? 'RETAIL',
      prepStation: json['prep_station'] as String?,
      requiresPreparation: json['requires_preparation'] as bool? ?? false,
      dineInAvailable: json['dine_in_available'] as bool? ?? false,
      takeawayAvailable: json['takeaway_available'] as bool? ?? false,
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
      'unit_conversion': unitConversions.map((u) => u.toJson()).toList(),
      'price_level1': priceLevel1,
      'price_level2': priceLevel2,
      'price_level3': priceLevel3,
      'price_level4': priceLevel4,
      'price_level5': priceLevel5,
      'standard_cost': standardCost,
      'is_stock_control': isStockControl,
      'allow_negative_stock': allowNegativeStock,
      'is_active': isActive,
      'image_path': imagePath,
      'service_mode': serviceMode,
      'prep_station': prepStation,
      'requires_preparation': requiresPreparation,
      'dine_in_available': dineInAvailable,
      'takeaway_available': takeawayAvailable,
    };
  }
}
