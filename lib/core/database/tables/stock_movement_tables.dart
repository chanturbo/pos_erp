import 'package:drift/drift.dart';
import 'product_tables.dart';
import 'stock_tables.dart';
import 'user_tables.dart';

// ========================================
// STOCK MOVEMENTS
// ========================================
@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get movementId => text()();
  TextColumn get movementNo => text().withLength(max: 50)();
  DateTimeColumn get movementDate => dateTime()();
  TextColumn get movementType => text()();
  
  // Product & Warehouse
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  
  // Quantity
  RealColumn get quantity => real()();
  RealColumn get unitCost => real().withDefault(const Constant(0))();
  
  // Reference
  TextColumn get referenceType => text().nullable().withLength(max: 20)();
  TextColumn get referenceId => text().nullable().withLength(max: 20)();
  
  TextColumn get userId => text().references(Users, #userId)();
  TextColumn get remark => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {movementId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {movementNo},
  ];
}