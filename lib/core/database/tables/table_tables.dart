import 'package:drift/drift.dart';
import 'company_tables.dart';

// ========================================
// ZONES
// ========================================
@DataClassName('Zone')
class Zones extends Table {
  TextColumn get zoneId => text()();
  TextColumn get zoneName => text().withLength(max: 200)();
  TextColumn get branchId => text().references(Branches, #branchId)();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {zoneId};
}

// ========================================
// TABLES (โต๊ะ)
// ========================================
@DataClassName('DiningTable')
class DiningTables extends Table {
  TextColumn get tableId => text()();
  TextColumn get tableNo => text().withLength(max: 20)();
  TextColumn get tableDisplayName => text().nullable().withLength(max: 200)();  // ✅ เปลี่ยนจาก tableName
  TextColumn get zoneId => text().references(Zones, #zoneId)();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(const Constant('AVAILABLE'))();
  TextColumn get currentOrderId => text().nullable()();
  DateTimeColumn get lastOccupiedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {tableId};
  
  // ✅ เพิ่มบรรทัดนี้เพื่อระบุชื่อตารางในฐานข้อมูล
  @override
  String get tableName => 'dining_tables';
}