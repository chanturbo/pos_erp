// ignore_for_file: avoid_print

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
    ArInvoiceItems,    // ✅ เพิ่มใหม่
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

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
      },
    );
  }
}

// เปิดการเชื่อมต่อ Database
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pos_erp.db'));
    // ✅ เพิ่มบรรทัดนี้
    //print('📁 Database path: ${file.path}');

    return NativeDatabase.createInBackground(file);
  });
}
