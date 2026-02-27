import 'package:drift/drift.dart';
import 'converters.dart';
// ========================================
// PRODUCT GROUPS
// ========================================
@DataClassName('ProductGroup')
class ProductGroups extends Table {
  TextColumn get groupId => text()();
  TextColumn get groupCode => text().withLength(max: 20)();
  TextColumn get groupName => text().withLength(max: 200)();
  TextColumn get parentGroupId => text().nullable()();
  TextColumn get groupType => text().withDefault(const Constant('GENERAL'))();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {groupId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {groupCode},
  ];
}

// ========================================
// PRODUCTS
// ========================================
@DataClassName('Product')
class Products extends Table {
  TextColumn get productId => text()();
  TextColumn get productCode => text().withLength(max: 50)();
  TextColumn get barcode => text().nullable().withLength(max: 50)();
  TextColumn get productName => text().withLength(max: 500)();
  TextColumn get productNameEn => text().nullable().withLength(max: 500)();
  TextColumn get groupId => text().nullable().references(ProductGroups, #groupId)();
  TextColumn get brand => text().nullable().withLength(max: 100)();
  TextColumn get model => text().nullable().withLength(max: 100)();
  TextColumn get color => text().nullable().withLength(max: 50)();
  
  // Units
  TextColumn get baseUnit => text().withLength(max: 20)();
  TextColumn get unitConversion => text().nullable().map(const JsonConverter())();
  
  // Pricing
  RealColumn get priceLevel1 => real().withDefault(const Constant(0))();
  RealColumn get priceLevel2 => real().withDefault(const Constant(0))();
  RealColumn get priceLevel3 => real().withDefault(const Constant(0))();
  RealColumn get priceLevel4 => real().withDefault(const Constant(0))();
  RealColumn get priceLevel5 => real().withDefault(const Constant(0))();
  
  // Cost
  TextColumn get costMethod => text().withDefault(const Constant('AVG'))();
  RealColumn get standardCost => real().withDefault(const Constant(0))();
  
  // Stock Control
  BoolColumn get isStockControl => boolean().withDefault(const Constant(true))();
  BoolColumn get isSerialControl => boolean().withDefault(const Constant(false))();
  BoolColumn get allowNegativeStock => boolean().withDefault(const Constant(false))();
  RealColumn get reorderPoint => real().withDefault(const Constant(0))();
  
  // Tax
  TextColumn get vatType => text().withDefault(const Constant('I'))();
  RealColumn get vatRate => real().withDefault(const Constant(7.00))();
  
  // Images
  TextColumn get imageUrls => text().nullable().map(const JsonConverter())();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {productId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {productCode},
  ];
}