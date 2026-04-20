// ignore_for_file: avoid_print

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Import ทุก Table ที่สร้างไว้
import 'tables/converters.dart';
import 'tables/company_tables.dart';
import 'tables/purchase_return_tables.dart';
import 'tables/user_tables.dart';
import 'tables/product_tables.dart';
import 'tables/stock_tables.dart';
import 'tables/modifier_tables.dart';
import 'tables/table_tables.dart';
import 'tables/customer_tables.dart';
import 'tables/sales_tables.dart';
import 'tables/purchase_tables.dart';
import 'tables/stock_movement_tables.dart';
import 'tables/promotion_tables.dart';
import 'tables/ar_tables.dart';
import 'tables/ap_tables.dart';
import 'tables/system_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Company & Branch
    Companies,
    Branches,

    // Users & Roles
    Users,
    Roles,

    // Products
    ProductGroups,
    Products,

    // Stock
    Warehouses,
    StockBalances,
    SerialNumbers,

    // Modifiers (ร้านอาหาร)
    ModifierGroups,
    Modifiers,
    ProductModifiers,

    // Tables (ร้านอาหาร)
    Zones,
    DiningTables,
    TableSessions,
    TableReservations,

    // Customers & Suppliers
    CustomerGroups,
    Customers,
    PointsTransactions,
    Suppliers, // ✅ ตรวจสอบว่ามีบรรทัดนี้อยู่แล้ว
    // Sales
    SalesOrders,
    SalesOrderItems,
    OrderItemModifiers,

    //
    PurchaseOrders,
    PurchaseOrderItems,
    GoodsReceipts, // ✅ เพิ่ม
    GoodsReceiptItems, // ✅ เพิ่ม
    // Purchase Returns
    PurchaseReturns,
    PurchaseReturnItems,

    // Stock Movement
    StockMovements,

    // Promotions
    Promotions,
    PromotionUsages,
    Coupons,

    // AR
    ArInvoices,
    ArInvoiceItems, // ✅ เพิ่มใหม่
    ArReceipts,
    ArReceiptAllocations,

    // AP
    ApInvoices,
    ApInvoiceItems,
    ApPayments,
    ApPaymentAllocations,

    // System
    Devices,
    ActiveSessions,
    SyncQueues,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  static const databaseFileName = 'pos_erp.db';
  static const productImagesFolderName = 'product_images';
  static const backupsFolderName = 'backups';

  static const _createCustomerDividendRunsTable = '''
    CREATE TABLE IF NOT EXISTS customer_dividend_runs (
      run_id TEXT PRIMARY KEY NOT NULL,
      run_no TEXT NOT NULL UNIQUE,
      period_start TEXT,
      period_end TEXT,
      dividend_percent REAL NOT NULL DEFAULT 0,
      total_customers INTEGER NOT NULL DEFAULT 0,
      total_dividend_base REAL NOT NULL DEFAULT 0,
      total_dividend_amount REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'DRAFT',
      remark TEXT,
      created_by TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      paid_at TEXT
    )
  ''';

  static const _createCustomerDividendRunItemsTable = '''
    CREATE TABLE IF NOT EXISTS customer_dividend_run_items (
      item_id TEXT PRIMARY KEY NOT NULL,
      run_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      customer_name TEXT NOT NULL,
      order_count INTEGER NOT NULL DEFAULT 0,
      paid_amount REAL NOT NULL DEFAULT 0,
      credit_amount REAL NOT NULL DEFAULT 0,
      dividend_base REAL NOT NULL DEFAULT 0,
      dividend_percent REAL NOT NULL DEFAULT 0,
      dividend_amount REAL NOT NULL DEFAULT 0,
      payment_status TEXT NOT NULL DEFAULT 'PENDING',
      paid_amount_actual REAL NOT NULL DEFAULT 0,
      paid_at TEXT,
      note TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(run_id) REFERENCES customer_dividend_runs(run_id) ON DELETE CASCADE
    )
  ''';

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await customStatement(_createCustomerDividendRunsTable);
        await customStatement(_createCustomerDividendRunItemsTable);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(salesOrders, salesOrders.couponDiscount);
          await m.addColumn(salesOrders, salesOrders.couponCodes);
        }
        if (from < 3) {
          await m.addColumn(salesOrders, salesOrders.pointsUsed);
          await m.createTable(pointsTransactions);
        }
        if (from < 4) {
          await m.addColumn(salesOrders, salesOrders.promotionIds);
          await m.addColumn(salesOrderItems, salesOrderItems.isFreeItem);
          await m.addColumn(salesOrderItems, salesOrderItems.promotionId);
        }
        if (from < 5) {
          await m.addColumn(stockMovements, stockMovements.lotNumber);
          await m.addColumn(stockMovements, stockMovements.expiryDate);
        }
        if (from < 6) {
          // WAC: เพิ่ม avg_cost, last_cost ใน stock_balances (ถ้ายังไม่มี)
          // และ unit_cost ใน stock_movements (ถ้ายังไม่มี)
          // หมายเหตุ: ถ้า schema สร้างใหม่ตั้งแต่ต้น columns เหล่านี้มีอยู่แล้ว
          // migration นี้ใช้สำหรับ DB เก่าที่ upgrade ขึ้นมา
          await customStatement('''
            ALTER TABLE stock_balances ADD COLUMN avg_cost REAL NOT NULL DEFAULT 0
          ''').catchError((_) {}); // ignore ถ้ามีอยู่แล้ว
          await customStatement('''
            ALTER TABLE stock_balances ADD COLUMN last_cost REAL NOT NULL DEFAULT 0
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE stock_movements ADD COLUMN unit_cost REAL NOT NULL DEFAULT 0
          ''').catchError((_) {});
        }
        if (from < 7) {
          await customStatement(_createCustomerDividendRunsTable);
          await customStatement(_createCustomerDividendRunItemsTable);
        }
        if (from < 8) {
          // Phase R0: Restaurant Module preparation
          await customStatement('''
            ALTER TABLE branches ADD COLUMN business_mode TEXT NOT NULL DEFAULT 'RETAIL'
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE products ADD COLUMN service_mode TEXT NOT NULL DEFAULT 'RETAIL'
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE products ADD COLUMN prep_station TEXT
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE products ADD COLUMN requires_preparation INTEGER NOT NULL DEFAULT 0
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE products ADD COLUMN dine_in_available INTEGER NOT NULL DEFAULT 0
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE products ADD COLUMN takeaway_available INTEGER NOT NULL DEFAULT 0
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE sales_orders ADD COLUMN session_id TEXT
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE sales_orders ADD COLUMN service_type TEXT
          ''').catchError((_) {});
          await m.createTable(tableSessions);
        }
        if (from < 9) {
          // Phase R3: Billing Flow — service charge
          await customStatement('''
            ALTER TABLE sales_orders ADD COLUMN service_charge_rate REAL NOT NULL DEFAULT 0
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE sales_orders ADD COLUMN service_charge_amount REAL NOT NULL DEFAULT 0
          ''').catchError((_) {});
        }
        if (from < 10) {
          // Phase R4: Advanced Restaurant Operations
          await customStatement('''
            ALTER TABLE table_sessions ADD COLUMN waiter_id TEXT
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE table_sessions ADD COLUMN waiter_name TEXT
          ''').catchError((_) {});
          await customStatement('''
            ALTER TABLE sales_order_items ADD COLUMN course_no INTEGER NOT NULL DEFAULT 1
          ''').catchError((_) {});
          await m.createTable(tableReservations);
        }
      },
    );
  }

  static Future<Directory> resolveDocumentsDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<File> resolveDatabaseFile() async {
    final dbFolder = await resolveDocumentsDirectory();
    return File(p.join(dbFolder.path, databaseFileName));
  }

  static Future<Directory> resolveProductImagesDirectory() async {
    final dbFolder = await resolveDocumentsDirectory();
    return Directory(p.join(dbFolder.path, productImagesFolderName));
  }

  static Future<Directory> resolveBackupDirectory() async {
    final dbFolder = await resolveDocumentsDirectory();
    return Directory(p.join(dbFolder.path, backupsFolderName));
  }
}

// เปิดการเชื่อมต่อ Database
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await AppDatabase.resolveDatabaseFile();
    // ✅ เพิ่มบรรทัดนี้
    //print('📁 Database path: ${file.path}');

    return NativeDatabase.createInBackground(file);
  });
}

/// Provider สำหรับ AppDatabase (singleton) — override ด้วย instance จริงใน main.dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden with a real AppDatabase instance',
  );
});
