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

// ========================================
// TABLE SESSIONS (รอบการใช้งานโต๊ะ)
// ========================================
@DataClassName('TableSession')
class TableSessions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get tableId => text().references(DiningTables, #tableId)();
  TextColumn get branchId => text().references(Branches, #branchId)();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get guestCount => integer().withDefault(const Constant(1))();
  // open | billed | closed | cancelled
  TextColumn get status => text().withDefault(const Constant('OPEN'))();
  TextColumn get openedBy => text().nullable()();
  TextColumn get note => text().nullable()();
  // Waiter assignment (R4)
  TextColumn get waiterId => text().nullable()();
  TextColumn get waiterName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  String get tableName => 'table_sessions';
}

// ========================================
// TABLE RESERVATIONS (การจองโต๊ะ) — R4
// ========================================
@DataClassName('TableReservation')
class TableReservations extends Table {
  TextColumn get reservationId => text()();
  TextColumn get tableId => text().nullable().references(DiningTables, #tableId)();
  TextColumn get branchId => text().references(Branches, #branchId)();
  TextColumn get customerName => text().withLength(max: 300)();
  TextColumn get customerPhone => text().nullable().withLength(max: 50)();
  DateTimeColumn get reservationTime => dateTime()();
  IntColumn get partySize => integer().withDefault(const Constant(2))();
  TextColumn get notes => text().nullable()();
  // PENDING | CONFIRMED | SEATED | CANCELLED | NO_SHOW
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get sessionId => text().nullable()(); // linked when seated
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {reservationId};

  @override
  String get tableName => 'table_reservations';
}