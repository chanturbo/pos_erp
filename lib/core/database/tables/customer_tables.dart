import 'package:drift/drift.dart';

// ========================================
// CUSTOMER GROUPS
// ========================================
@DataClassName('CustomerGroup')
class CustomerGroups extends Table {
  TextColumn get customerGroupId => text()();
  TextColumn get groupName => text().withLength(max: 200)();
  RealColumn get discountRate => real().withDefault(const Constant(0))();
  IntColumn get priceLevel => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {customerGroupId};
}

// ========================================
// CUSTOMERS
// ========================================
@DataClassName('Customer')
class Customers extends Table {
  TextColumn get customerId => text()();
  TextColumn get customerCode => text().withLength(max: 50)();
  TextColumn get customerName => text().withLength(max: 300)();
  TextColumn get customerGroupId => text().nullable().references(CustomerGroups, #customerGroupId)();
  
  // Contact
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable().withLength(max: 50)();
  TextColumn get email => text().nullable().withLength(max: 100)();
  TextColumn get taxId => text().nullable().withLength(max: 20)();
  
  // Credit
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  IntColumn get creditDays => integer().withDefault(const Constant(0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0))();
  
  // Member
  TextColumn get memberNo => text().nullable().withLength(max: 50)();
  IntColumn get points => integer().withDefault(const Constant(0))();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {customerId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {customerCode},
  ];
}

// ========================================
// SUPPLIERS
// ========================================
@DataClassName('Supplier')
class Suppliers extends Table {
  TextColumn get supplierId => text().named('supplier_id')();
  TextColumn get supplierCode => text().named('supplier_code')(); // ✅ ลบ .unique() ออก
  TextColumn get supplierName => text().named('supplier_name')();
  TextColumn get contactPerson => text().named('contact_person').nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxId => text().named('tax_id').nullable()();
  IntColumn get creditTerm => integer().named('credit_term').withDefault(const Constant(30))();
  RealColumn get creditLimit => real().named('credit_limit').withDefault(const Constant(0))();
  RealColumn get currentBalance => real().named('current_balance').withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {supplierId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {supplierCode},
  ];
}