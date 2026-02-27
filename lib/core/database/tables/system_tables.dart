import 'package:drift/drift.dart';
import 'user_tables.dart';
import 'converters.dart';

// ========================================
// DEVICES
// ========================================
@DataClassName('Device')
class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text().withLength(max: 200)();
  TextColumn get deviceType => text()();
  TextColumn get ipAddress => text().nullable().withLength(max: 50)();
  TextColumn get macAddress => text().nullable().withLength(max: 50)();
  BoolColumn get isOnline => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {deviceId};
}

// ========================================
// ACTIVE SESSIONS
// ========================================
@DataClassName('ActiveSession')
class ActiveSessions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get deviceId => text().nullable().references(Devices, #deviceId)();
  TextColumn get userId => text().nullable().references(Users, #userId)();
  TextColumn get token => text()();
  TextColumn get ipAddress => text().nullable().withLength(max: 50)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastActivity => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {sessionId};
}

// ========================================
// SYNC QUEUE
// ========================================
@DataClassName('SyncQueue')
class SyncQueues extends Table {
  TextColumn get queueId => text()();
  TextColumn get deviceId => text().withLength(max: 50)();
  TextColumn get tableNameValue => text().withLength(max: 100)();
  TextColumn get recordId => text().withLength(max: 20)();
  TextColumn get operation => text().withLength(max: 10)();
  TextColumn get data => text().nullable().map(const JsonConverter())();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {queueId};
  
  @override
  String get tableName => 'sync_queues';
}

// ========================================
// AUDIT LOGS
// ========================================
@DataClassName('AuditLog')
class AuditLogs extends Table {
  TextColumn get logId => text()();
  TextColumn get tableNameValue => text().nullable().withLength(max: 100)();
  TextColumn get recordId => text().nullable().withLength(max: 20)();
  TextColumn get action => text().nullable().withLength(max: 20)();
  TextColumn get userId => text().nullable()();
  TextColumn get oldValue => text().nullable().map(const JsonConverter())();
  TextColumn get newValue => text().nullable().map(const JsonConverter())();
  TextColumn get ipAddress => text().nullable().withLength(max: 50)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {logId};
  
  @override
  String get tableName => 'audit_logs';
}