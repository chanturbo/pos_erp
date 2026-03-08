import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'user_tables.dart';
import 'product_tables.dart';

// ========================================
// PURCHASE RETURNS (ใบคืนสินค้า)
// ========================================
@DataClassName('PurchaseReturn')
class PurchaseReturns extends Table {
  TextColumn get returnId => text()();
  TextColumn get returnNo => text().withLength(max: 50)();
  DateTimeColumn get returnDate => dateTime()();
  
  // Supplier
  TextColumn get supplierId => text().references(Suppliers, #supplierId)();
  TextColumn get supplierName => text().withLength(max: 300)();
  
  // Reference (GR, PO)
  TextColumn get referenceType => text().nullable().withLength(max: 20)();
  TextColumn get referenceId => text().nullable()();
  
  // Amounts
  RealColumn get totalAmount => real()();
  
  // Status: DRAFT, CONFIRMED
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  
  TextColumn get reason => text().nullable()();
  TextColumn get remark => text().nullable()();
  TextColumn get userId => text().references(Users, #userId)();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {returnId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {returnNo},
  ];
}

// ========================================
// PURCHASE RETURN ITEMS (รายการสินค้าที่คืน)
// ========================================
@DataClassName('PurchaseReturnItem')
class PurchaseReturnItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get returnId => text().references(PurchaseReturns, #returnId)();
  IntColumn get lineNo => integer()();
  
  // Product
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get productCode => text().withLength(max: 50)();
  TextColumn get productName => text().withLength(max: 300)();
  TextColumn get unit => text().withLength(max: 20)();
  
  // Warehouse (ไม่ใช้ Foreign Key เพื่อความยืดหยุ่น)
  TextColumn get warehouseId => text()();
  TextColumn get warehouseName => text().withLength(max: 200)();
  
  // Quantity & Price
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get amount => real()();
  
  TextColumn get reason => text().nullable()();
  TextColumn get remark => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {itemId};
}