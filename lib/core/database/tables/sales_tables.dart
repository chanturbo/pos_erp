import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'company_tables.dart';
import 'stock_tables.dart';
import 'user_tables.dart';
import 'product_tables.dart';
import 'modifier_tables.dart';

// ========================================
// SALES ORDERS
// ========================================
@DataClassName('SalesOrder')
class SalesOrders extends Table {
  TextColumn get orderId => text()();
  TextColumn get orderNo => text().withLength(max: 50)();
  DateTimeColumn get orderDate => dateTime()();
  TextColumn get orderType => text().withDefault(const Constant('SALE'))();
  
  // Customer
  TextColumn get customerId => text().nullable().references(Customers, #customerId)();
  TextColumn get customerName => text().nullable().withLength(max: 300)();
  TextColumn get customerAddress => text().nullable()();
  TextColumn get customerTaxId => text().nullable().withLength(max: 20)();
  
  // Branch & Warehouse
  TextColumn get branchId => text().references(Branches, #branchId)();
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  TextColumn get userId => text().references(Users, #userId)();
  
  // Table (สำหรับร้านอาหาร)
  TextColumn get tableId => text().nullable()();
  IntColumn get partySize => integer().nullable()();
  
  // Amounts
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get amountBeforeVat => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  
  // Payment
  TextColumn get paymentType => text().withDefault(const Constant('CASH'))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0))();
  
  // Status
  TextColumn get status => text().withDefault(const Constant('OPEN'))();
  BoolColumn get isVatInclude => boolean().withDefault(const Constant(true))();
  
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {orderId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {orderNo},
  ];
}

// ========================================
// SALES ORDER ITEMS
// ========================================
@DataClassName('SalesOrderItem')
class SalesOrderItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get orderId => text().references(SalesOrders, #orderId, onDelete: KeyAction.cascade)();
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
  RealColumn get cost => real().withDefault(const Constant(0))();
  
  // Stock
  TextColumn get warehouseId => text().references(Warehouses, #warehouseId)();
  TextColumn get serialNo => text().nullable().withLength(max: 100)();
  
  // Kitchen Status (สำหรับร้านอาหาร)
  TextColumn get kitchenStatus => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get preparedAt => dateTime().nullable()();
  
  // Special Instructions
  TextColumn get specialInstructions => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {itemId};
}

// ========================================
// ORDER ITEM MODIFIERS (ตัวเลือกที่เลือก)
// ========================================
@DataClassName('OrderItemModifier')
class OrderItemModifiers extends Table {
  TextColumn get itemModifierId => text()();
  TextColumn get orderItemId => text().references(SalesOrderItems, #itemId, onDelete: KeyAction.cascade)();
  TextColumn get modifierId => text().references(Modifiers, #modifierId)();
  TextColumn get modifierName => text().withLength(max: 200)();
  RealColumn get priceAdjustment => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {itemModifierId};
}