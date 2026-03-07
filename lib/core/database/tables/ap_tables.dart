import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'user_tables.dart';
import 'product_tables.dart';

// ========================================
// AP INVOICES (ใบแจ้งหนี้เจ้าหนี้)
// ========================================
@DataClassName('ApInvoice')
class ApInvoices extends Table {
  TextColumn get invoiceId => text()();
  TextColumn get invoiceNo => text().withLength(max: 50)();
  DateTimeColumn get invoiceDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  
  // Supplier
  TextColumn get supplierId => text().references(Suppliers, #supplierId)();
  TextColumn get supplierName => text().withLength(max: 300)();
  
  // Amounts
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  
  // Reference (GR, PO, etc.)
  TextColumn get referenceType => text().nullable().withLength(max: 20)();
  TextColumn get referenceId => text().nullable()();
  
  // Status: UNPAID, PARTIAL, PAID, CANCELLED
  TextColumn get status => text().withDefault(const Constant('UNPAID'))();
  
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {invoiceId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {invoiceNo},
  ];
}

// ========================================
// AP INVOICE ITEMS (รายการสินค้าในใบแจ้งหนี้)
// ========================================
@DataClassName('ApInvoiceItem')
class ApInvoiceItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get invoiceId => text().references(ApInvoices, #invoiceId)();
  IntColumn get lineNo => integer()();
  
  // Product
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get productCode => text().withLength(max: 50)();
  TextColumn get productName => text().withLength(max: 300)();
  TextColumn get unit => text().withLength(max: 20)();
  
  // Quantity & Price
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get amount => real()();
  
  TextColumn get remark => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {itemId};
}

// ========================================
// AP PAYMENTS (ใบจ่ายเงิน)
// ========================================
@DataClassName('ApPayment')
class ApPayments extends Table {
  TextColumn get paymentId => text()();
  TextColumn get paymentNo => text().withLength(max: 50)();
  DateTimeColumn get paymentDate => dateTime()();
  
  // Supplier
  TextColumn get supplierId => text().references(Suppliers, #supplierId)();
  TextColumn get supplierName => text().withLength(max: 300)();
  RealColumn get totalAmount => real()();
  
  // Payment Method: CASH, TRANSFER, CHEQUE
  TextColumn get paymentMethod => text().withDefault(const Constant('CASH'))();
  TextColumn get bankName => text().nullable().withLength(max: 100)();
  TextColumn get chequeNo => text().nullable().withLength(max: 50)();
  DateTimeColumn get chequeDate => dateTime().nullable()();
  TextColumn get transferRef => text().nullable().withLength(max: 100)();
  
  TextColumn get userId => text().references(Users, #userId)();
  TextColumn get remark => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {paymentId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {paymentNo},
  ];
}

// ========================================
// AP PAYMENT ALLOCATIONS (จัดสรรเงินจ่าย)
// ========================================
@DataClassName('ApPaymentAllocation')
class ApPaymentAllocations extends Table {
  TextColumn get allocationId => text()();
  TextColumn get paymentId => text().references(ApPayments, #paymentId)();
  TextColumn get invoiceId => text().references(ApInvoices, #invoiceId)();
  RealColumn get allocatedAmount => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {allocationId};
}