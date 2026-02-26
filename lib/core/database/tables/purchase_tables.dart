import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'company_tables.dart';
import 'stock_tables.dart';
import 'user_tables.dart';
import 'product_tables.dart';

// ========================================
// PURCHASE ORDERS
// ========================================
@DataClassName('PurchaseOrder')
class PurchaseOrders extends Table {
  TextColumn get poId => text()();
  TextColumn get poNo => text().withLength(max: 50)();
  DateTimeColumn get poDate => dateTime()();
  TextColumn get poType => text().withDefault(const Constant('PO'))();
  
  // Supplier
  TextColumn get supplierId => text().references(Suppliers, #supplierId)();
  TextColumn get supplierName => text().withLength(max: 300)();
  
  // Branch & Warehouse
  TextColumn get branchId => text().references(Branches, #branchId)();
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  TextColumn get userId => text().references(Users, #userId)();
  
  // Amounts
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get amountBeforeVat => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  
  // Status
  TextColumn get status => text().withDefault(const Constant('OPEN'))();
  TextColumn get remark => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {poId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {poNo},
  ];
}

// ========================================
// PURCHASE ORDER ITEMS
// ========================================
@DataClassName('PurchaseOrderItem')
class PurchaseOrderItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get poId => text().references(PurchaseOrders, #poId, onDelete: KeyAction.cascade)();
  IntColumn get lineNo => integer()();
  
  // Product
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get productCode => text().withLength(max: 50)();
  TextColumn get productName => text().withLength(max: 500)();
  
  // Quantity & Price
  TextColumn get unit => text().withLength(max: 20)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  
  RealColumn get amount => real()();
  RealColumn get receivedQty => real().withDefault(const Constant(0))();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {itemId};
}