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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // เพิ่ม migration logic ในอนาคต
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
