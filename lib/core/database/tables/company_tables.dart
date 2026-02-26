import 'package:drift/drift.dart';

// ========================================
// COMPANIES
// ========================================
@DataClassName('Company')
class Companies extends Table {
  TextColumn get companyId => text()();
  TextColumn get companyName => text().withLength(max: 200)();
  TextColumn get taxId => text().nullable().withLength(max: 20)();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable().withLength(max: 50)();
  TextColumn get logoUrl => text().nullable().withLength(max: 500)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {companyId};
}

// ========================================
// BRANCHES
// ========================================
@DataClassName('Branch')
class Branches extends Table {
  TextColumn get branchId => text()();
  TextColumn get companyId => text().references(Companies, #companyId)();
  TextColumn get branchCode => text().withLength(max: 10)();
  TextColumn get branchName => text().withLength(max: 200)();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable().withLength(max: 50)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {branchId};
}