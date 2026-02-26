import 'package:drift/drift.dart';
import 'company_tables.dart';
import 'product_tables.dart';

// ========================================
// WAREHOUSES
// ========================================
@DataClassName('Warehouse')
class Warehouses extends Table {
  TextColumn get warehouseId => text()();
  TextColumn get warehouseCode => text().withLength(max: 20)();
  TextColumn get warehouseName => text().withLength(max: 200)();
  TextColumn get branchId => text().references(Branches, #branchId)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {warehouseId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {warehouseCode},
  ];
}

// ========================================
// STOCK BALANCE
// ========================================
@DataClassName('StockBalance')
class StockBalances extends Table {
  TextColumn get stockId => text()();
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get reservedQty => real().withDefault(const Constant(0))();
  RealColumn get avgCost => real().withDefault(const Constant(0))();
  RealColumn get lastCost => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {stockId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, warehouseId},
  ];
}

// ========================================
// SERIAL NUMBERS
// ========================================
@DataClassName('SerialNumber')
class SerialNumbers extends Table {
  TextColumn get serialId => text()();
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get serialNo => text().withLength(max: 100)();
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  TextColumn get status => text().withDefault(const Constant('AVAILABLE'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {serialId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {serialNo},
  ];
}