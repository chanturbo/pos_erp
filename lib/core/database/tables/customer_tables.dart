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
  TextColumn get supplierId => text()();
  TextColumn get supplierCode => text().withLength(max: 50)();
  TextColumn get supplierName => text().withLength(max: 300)();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable().withLength(max: 50)();
  TextColumn get email => text().nullable().withLength(max: 100)();
  TextColumn get taxId => text().nullable().withLength(max: 20)();
  IntColumn get creditDays => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {supplierId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {supplierCode},
  ];
}