import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'user_tables.dart';
import 'product_tables.dart';

// ========================================
// AR INVOICES (ใบแจ้งหนี้ลูกหนี้)
// ========================================
@DataClassName('ArInvoice')
class ArInvoices extends Table {
  TextColumn get invoiceId => text()();
  TextColumn get invoiceNo => text().withLength(max: 50)();
  DateTimeColumn get invoiceDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  // Customer
  TextColumn get customerId => text().references(Customers, #customerId)();
  TextColumn get customerName => text().withLength(max: 300)();

  // Amounts
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();

  // Reference (SalesOrder, etc.)
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
// AR INVOICE ITEMS (รายการสินค้าในใบแจ้งหนี้)
// ========================================
@DataClassName('ArInvoiceItem')
class ArInvoiceItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get invoiceId => text().references(ArInvoices, #invoiceId)();
  IntColumn get lineNo => integer()();

  // Product
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get productCode => text().withLength(max: 50)();
  TextColumn get productName => text().withLength(max: 300)();
  TextColumn get unit => text().withLength(max: 20)();

  // Quantity & Price
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get amount => real()();

  TextColumn get remark => text().nullable()();

  @override
  Set<Column> get primaryKey => {itemId};
}

// ========================================
// AR RECEIPTS (ใบเสร็จรับเงิน)
// ========================================
@DataClassName('ArReceipt')
class ArReceipts extends Table {
  TextColumn get receiptId => text()();
  TextColumn get receiptNo => text().withLength(max: 50)();
  DateTimeColumn get receiptDate => dateTime()();

  // Customer
  TextColumn get customerId => text().references(Customers, #customerId)();
  TextColumn get customerName => text().withLength(max: 300)();
  RealColumn get totalAmount => real()();

  // Payment Method: CASH, TRANSFER, CHEQUE, CREDIT_CARD
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('CASH'))();
  TextColumn get bankName => text().nullable().withLength(max: 100)();
  TextColumn get chequeNo => text().nullable().withLength(max: 50)();
  DateTimeColumn get chequeDate => dateTime().nullable()();
  TextColumn get transferRef => text().nullable().withLength(max: 100)();

  TextColumn get userId => text().references(Users, #userId)();
  TextColumn get remark => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {receiptId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {receiptNo},
      ];
}

// ========================================
// AR RECEIPT ALLOCATIONS (จัดสรรเงินรับ)
// ========================================
@DataClassName('ArReceiptAllocation')
class ArReceiptAllocations extends Table {
  TextColumn get allocationId => text()();
  TextColumn get receiptId =>
      text().references(ArReceipts, #receiptId)();
  TextColumn get invoiceId =>
      text().references(ArInvoices, #invoiceId)();
  RealColumn get allocatedAmount => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {allocationId};
}