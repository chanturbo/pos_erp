import 'package:drift/drift.dart';

// ========================================
// PURCHASE ORDERS (ใบสั่งซื้อ)
// ========================================
@DataClassName('PurchaseOrder')
class PurchaseOrders extends Table {
  TextColumn get poId => text().named('po_id')();
  TextColumn get poNo => text().named('po_no')();
  DateTimeColumn get poDate => dateTime().named('po_date')();
  
  // Supplier & Warehouse (with names for snapshot)
  TextColumn get supplierId => text().named('supplier_id')();
  TextColumn get supplierName => text().named('supplier_name')(); // ✅ เก็บชื่อด้วย
  TextColumn get warehouseId => text().named('warehouse_id')();
  TextColumn get warehouseName => text().named('warehouse_name')(); // ✅ เก็บชื่อด้วย
  TextColumn get userId => text().named('user_id')();
  
  // Amounts
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().named('discount_amount').withDefault(const Constant(0))();
  RealColumn get vatAmount => real().named('vat_amount').withDefault(const Constant(0))();
  RealColumn get totalAmount => real().named('total_amount').withDefault(const Constant(0))();
  
  // Status
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get paymentStatus => text().named('payment_status').withDefault(const Constant('UNPAID'))();
  DateTimeColumn get deliveryDate => dateTime().named('delivery_date').nullable()();
  TextColumn get remark => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {poId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {poNo},
  ];
}

// ========================================
// PURCHASE ORDER ITEMS (รายการสินค้าในใบสั่งซื้อ)
// ========================================
@DataClassName('PurchaseOrderItem')
class PurchaseOrderItems extends Table {
  TextColumn get itemId => text().named('item_id')();
  TextColumn get poId => text().named('po_id')();
  IntColumn get lineNo => integer().named('line_no')();
  
  // Product (with details for snapshot)
  TextColumn get productId => text().named('product_id')();
  TextColumn get productCode => text().named('product_code')(); // ✅ เก็บรหัสด้วย
  TextColumn get productName => text().named('product_name')(); // ✅ เก็บชื่อด้วย
  TextColumn get unit => text()(); // ✅ เก็บหน่วยด้วย
  
  // Quantity & Price
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real().named('unit_price').withDefault(const Constant(0))();
  RealColumn get discountPercent => real().named('discount_percent').withDefault(const Constant(0))();
  RealColumn get discountAmount => real().named('discount_amount').withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0))();
  
  // Received tracking
  RealColumn get receivedQuantity => real().named('received_quantity').withDefault(const Constant(0))();
  RealColumn get remainingQuantity => real().named('remaining_quantity').withDefault(const Constant(0))();
  
  @override
  Set<Column> get primaryKey => {itemId};
}

// ========================================
// GOODS RECEIPTS (ใบรับสินค้า)
// ========================================
@DataClassName('GoodsReceipt')
class GoodsReceipts extends Table {
  TextColumn get grId => text().named('gr_id')();
  TextColumn get grNo => text().named('gr_no')();
  DateTimeColumn get grDate => dateTime().named('gr_date')();
  
  // Reference to Purchase Order
  TextColumn get poId => text().named('po_id').nullable()();
  TextColumn get poNo => text().named('po_no').nullable()();
  
  // Supplier & Warehouse
  TextColumn get supplierId => text().named('supplier_id')();
  TextColumn get supplierName => text().named('supplier_name')();
  TextColumn get warehouseId => text().named('warehouse_id')();
  TextColumn get warehouseName => text().named('warehouse_name')();
  TextColumn get userId => text().named('user_id')();
  
  // Status
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get remark => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {grId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {grNo},
  ];
}

// ========================================
// GOODS RECEIPT ITEMS (รายการสินค้าในใบรับสินค้า)
// ========================================
@DataClassName('GoodsReceiptItem')
class GoodsReceiptItems extends Table {
  TextColumn get itemId => text().named('item_id')();
  TextColumn get grId => text().named('gr_id')();
  IntColumn get lineNo => integer().named('line_no')();
  
  // Reference to PO Item
  TextColumn get poItemId => text().named('po_item_id').nullable()();
  
  // Product
  TextColumn get productId => text().named('product_id')();
  TextColumn get productCode => text().named('product_code')();
  TextColumn get productName => text().named('product_name')();
  TextColumn get unit => text()();
  
  // Quantities
  RealColumn get orderedQuantity => real().named('ordered_quantity').withDefault(const Constant(0))();
  RealColumn get receivedQuantity => real().named('received_quantity')();
  RealColumn get unitPrice => real().named('unit_price').withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0))();
  
  // Quality Check
  TextColumn get lotNumber => text().named('lot_number').nullable()();
  DateTimeColumn get expiryDate => dateTime().named('expiry_date').nullable()();
  TextColumn get remark => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {itemId};
}