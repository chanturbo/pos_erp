import 'package:drift/drift.dart';
import 'company_tables.dart';
import 'converters.dart'; 

// ========================================
// ROLES
// ========================================
@DataClassName('Role')
class Roles extends Table {
  TextColumn get roleId => text()();
  TextColumn get roleName => text().withLength(max: 100)();
  TextColumn get permissions => text().map(const JsonConverter())();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {roleId};
}

// ========================================
// USERS
// ========================================
@DataClassName('User')
class Users extends Table {
  TextColumn get userId => text()();
  TextColumn get username => text().withLength(max: 100)();
  TextColumn get passwordHash => text().withLength(max: 255)();
  TextColumn get fullName => text().withLength(max: 200)();
  TextColumn get email => text().nullable().withLength(max: 100)();
  TextColumn get phone => text().nullable().withLength(max: 50)();
  TextColumn get roleId => text().nullable().references(Roles, #roleId)();
  TextColumn get branchId => text().nullable().references(Branches, #branchId)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {userId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {username},
  ];
}