// ignore_for_file: avoid_print

import 'package:drift/drift.dart';
import 'app_database.dart';

class SeedData {
  /// Seed All Data
  static Future<void> seedAll(AppDatabase db) async {
    print('🌱 Starting seed data...');
    await seedBranches(db);
    await seedWarehouses(db);
    await seedRoles(db);   // ✅ ต้องอยู่ก่อน seedUsers (FK constraint)
    await seedUsers(db);
    await seedCustomerGroups(db); // ✅ ต้องอยู่ก่อน seedCustomers
    await seedCustomers(db);
    await seedSuppliers(db); // ✅ เพิ่ม
    await seedProductGroups(db);
    await seedProducts(db);

    print('✅ Seed data completed');
  }

  /// Seed Branches
  static Future<void> seedBranches(AppDatabase db) async {
    final branches = [
      BranchesCompanion.insert(
        branchId: 'BR001',
        companyId: 'COMP001', // ✅ เพิ่ม required field
        branchCode: 'HQ',
        branchName: 'สาขาหลัก',
        address: const Value('123 ถนนทดสอบ กรุงเทพฯ 10100'),
        phone: const Value('02-123-4567'),
      ),
      BranchesCompanion.insert(
        branchId: 'BR002',
        companyId: 'COMP001', // ✅ เพิ่ม required field
        branchCode: 'SIAM',
        branchName: 'สาขาสยาม',
        address: const Value('456 ถนนพระราม 1 กรุงเทพฯ 10330'),
        phone: const Value('02-234-5678'),
      ),
    ];

    for (var branch in branches) {
      try {
        await db
            .into(db.branches)
            .insert(branch, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Branch exists
      }
    }

    for (var branch in branches) {
      try {
        await db
            .into(db.branches)
            .insert(branch, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Branch exists
      }
    }
  }

  /// Seed Warehouses
  static Future<void> seedWarehouses(AppDatabase db) async {
    final warehouses = [
      WarehousesCompanion.insert(
        warehouseId: 'WH001',
        warehouseCode: 'WH-HQ',
        warehouseName: 'คลังสาขาหลัก',
        branchId: 'BR001',
        // ❌ ลบ isActive ออก
      ),
      WarehousesCompanion.insert(
        warehouseId: 'WH002',
        warehouseCode: 'WH-SIAM',
        warehouseName: 'คลังสาขาสยาม',
        branchId: 'BR002',
      ),
    ];

    for (var warehouse in warehouses) {
      try {
        await db
            .into(db.warehouses)
            .insert(warehouse, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Warehouse exists
      }
    }
  }

  /// Seed Users
  /// Seed Roles — ต้องทำก่อน seedUsers เพราะ users.role_id FK → roles.role_id
  static Future<void> seedRoles(AppDatabase db) async {
    final roles = [
      RolesCompanion.insert(
        roleId: 'ADMIN',
        roleName: 'ผู้ดูแลระบบ',
        permissions: const <String, dynamic>{},
      ),
      RolesCompanion.insert(
        roleId: 'MANAGER',
        roleName: 'ผู้จัดการ',
        permissions: const <String, dynamic>{},
      ),
      RolesCompanion.insert(
        roleId: 'CASHIER',
        roleName: 'แคชเชียร์',
        permissions: const <String, dynamic>{},
      ),
      RolesCompanion.insert(
        roleId: 'WAREHOUSE',
        roleName: 'คลังสินค้า',
        permissions: const <String, dynamic>{},
      ),
      RolesCompanion.insert(
        roleId: 'ACCOUNTANT',
        roleName: 'บัญชี',
        permissions: const <String, dynamic>{},
      ),
    ];
    for (final role in roles) {
      await db.into(db.roles).insert(role, mode: InsertMode.insertOrIgnore);
    }
    print('   ✅ Roles seeded');
  }

  static Future<void> seedUsers(AppDatabase db) async {
    final users = [
      UsersCompanion.insert(
        userId: 'USR001',
        // ❌ ลบ companyId ออก (ไม่มีใน schema)
        username: 'admin',
        passwordHash:
            '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', // SHA256('admin123')
        fullName: 'ผู้ดูแลระบบ',
        email: const Value('admin@pos.com'),
        roleId: const Value('ADMIN'),
        branchId: const Value('BR001'),
        // ❌ ลบ isActive ออก
      ),
      UsersCompanion.insert(
        userId: 'USR002',
        username: 'cashier',
        passwordHash:
            'b4c94003c562bb0d89535eca77f07284fe560fd48a7cc1ed99f0a56263d616ba', // SHA256('cashier123')
        fullName: 'แคชเชียร์',
        email: const Value('cashier@pos.com'),
        roleId: const Value('CASHIER'),
        branchId: const Value('BR001'),
      ),
    ];

    for (final user in users) {
      try {
        // insertOrReplace เพื่อให้ roleId/branchId อัปเดตได้ถ้า user มีอยู่แล้วแต่ role เป็น null
        await db.into(db.users).insertOnConflictUpdate(user);
      } catch (e) {
        print('⚠️ seedUsers error: $e');
      }
    }
    print('   ✅ Users seeded');
  }

  /// Seed Customer Groups (ระดับราคา 1-5)
  static Future<void> seedCustomerGroups(AppDatabase db) async {
    final groups = [
      CustomerGroupsCompanion.insert(
        customerGroupId: 'CG001',
        groupName: 'ลูกค้าทั่วไป',
        discountRate: const Value(0),
        priceLevel: const Value(1),
      ),
      CustomerGroupsCompanion.insert(
        customerGroupId: 'CG002',
        groupName: 'สมาชิก',
        discountRate: const Value(0),
        priceLevel: const Value(2),
      ),
      CustomerGroupsCompanion.insert(
        customerGroupId: 'CG003',
        groupName: 'ลูกค้าส่ง',
        discountRate: const Value(0),
        priceLevel: const Value(3),
      ),
      CustomerGroupsCompanion.insert(
        customerGroupId: 'CG004',
        groupName: 'ตัวแทน',
        discountRate: const Value(0),
        priceLevel: const Value(4),
      ),
      CustomerGroupsCompanion.insert(
        customerGroupId: 'CG005',
        groupName: 'VIP',
        discountRate: const Value(0),
        priceLevel: const Value(5),
      ),
    ];

    for (var group in groups) {
      try {
        await db
            .into(db.customerGroups)
            .insert(group, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Group exists
      }
    }
    print('✅ Seeded customer groups (price levels 1-5)');
  }

  /// Seed Customers
  static Future<void> seedCustomers(AppDatabase db) async {
    final customers = [
      // ✅ ลูกค้าระบบ — ห้ามลบ ห้ามแก้ไข (Walk-in / ไม่ระบุลูกค้า)
      CustomersCompanion.insert(
        customerId: 'WALK_IN',
        customerCode: 'WALK-IN',
        customerName: 'ลูกค้าทั่วไป',
        // ❌ ลบ isActive ออก
      ),
      CustomersCompanion.insert(
        customerId: 'CUS001',
        customerCode: 'CUS-001',
        customerName: 'คุณสมชาย ใจดี',
        phone: const Value('081-234-5678'),
        email: const Value('somchai@email.com'),
        creditLimit: const Value(10000.0),
      ),
      CustomersCompanion.insert(
        customerId: 'CUS002',
        customerCode: 'CUS-002',
        customerName: 'คุณสมหญิง รักดี',
        phone: const Value('082-345-6789'),
        email: const Value('somying@email.com'),
      ),
      CustomersCompanion.insert(
        customerId: 'CUS003',
        customerCode: 'CUS-003',
        customerName: 'บริษัท ทดสอบ จำกัด',
        phone: const Value('02-123-4567'),
        email: const Value('contact@testcompany.com'),
        address: const Value('123 ถนนทดสอบ กรุงเทพฯ 10100'),
        creditLimit: const Value(50000.0),
        taxId: const Value('0123456789012'),
      ),
    ];

    for (var customer in customers) {
      try {
        await db
            .into(db.customers)
            .insert(customer, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Customer exists
      }
    }
  }

  /// Seed Product Groups
  static Future<void> seedProductGroups(AppDatabase db) async {
    final groups = [
      ProductGroupsCompanion.insert(
        groupId: 'GRP001',
        groupCode: 'FOOD',
        groupName: 'อาหารและเครื่องดื่ม',
        // ❌ ลบ isActive ออก
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP002',
        groupCode: 'SNACK',
        groupName: 'ขนมและของว่าง',
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP003',
        groupCode: 'DAILY',
        groupName: 'ของใช้ประจำวัน',
      ),
    ];

    for (var group in groups) {
      try {
        await db
            .into(db.productGroups)
            .insert(group, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Group exists
      }
    }
  }

  /// Seed Products
  static Future<void> seedProducts(AppDatabase db) async {
    final products = [
      ProductsCompanion.insert(
        productId: 'PRD001',
        productCode: 'FOOD-001',
        productName: 'น้ำดื่ม 600ml',
        barcode: const Value('8850123456789'),
        // ❌ ลบ productGroupId, cost, price1, isStockControl, allowNegativeStock, isActive
        baseUnit: 'ขวด',
      ),
      ProductsCompanion.insert(
        productId: 'PRD002',
        productCode: 'FOOD-002',
        productName: 'กาแฟกระป๋อง',
        barcode: const Value('8850123456790'),
        baseUnit: 'กระป๋อง',
      ),
      ProductsCompanion.insert(
        productId: 'PRD003',
        productCode: 'FOOD-003',
        productName: 'ชาเขียวญี่ปุ่น',
        barcode: const Value('8850123456791'),
        baseUnit: 'ขวด',
      ),
      ProductsCompanion.insert(
        productId: 'PRD004',
        productCode: 'SNACK-001',
        productName: 'มันฝรั่งทอด รสออริจินัล',
        barcode: const Value('8850123456792'),
        baseUnit: 'ถุง',
      ),
      ProductsCompanion.insert(
        productId: 'PRD005',
        productCode: 'SNACK-002',
        productName: 'คุกกี้ช็อกโกแลต',
        barcode: const Value('8850123456793'),
        baseUnit: 'กล่อง',
      ),
      ProductsCompanion.insert(
        productId: 'PRD006',
        productCode: 'DAILY-001',
        productName: 'ยาสีฟัน',
        barcode: const Value('8850123456794'),
        baseUnit: 'หลอด',
      ),
      ProductsCompanion.insert(
        productId: 'PRD007',
        productCode: 'DAILY-002',
        productName: 'แชมพู',
        barcode: const Value('8850123456795'),
        baseUnit: 'ขวด',
      ),
      ProductsCompanion.insert(
        productId: 'PRD008',
        productCode: 'DAILY-003',
        productName: 'สบู่ก้อน',
        barcode: const Value('8850123456796'),
        baseUnit: 'ก้อน',
      ),
    ];

    for (var product in products) {
      try {
        await db
            .into(db.products)
            .insert(product, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Product exists
      }
    }

    await seedInitialStock(db);
  }

  /// Seed Initial Stock
  static Future<void> seedInitialStock(AppDatabase db) async {
    final stockMovements = [
      StockMovementsCompanion.insert(
        movementId: 'STK001',
        movementNo: 'INIT-001',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD001',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 100.0,
        referenceNo: const Value('INIT-001'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK002',
        movementNo: 'INIT-002',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD002',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 50.0,
        referenceNo: const Value('INIT-002'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK003',
        movementNo: 'INIT-003',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD003',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 75.0,
        referenceNo: const Value('INIT-003'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK004',
        movementNo: 'INIT-004',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD004',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 80.0,
        referenceNo: const Value('INIT-004'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK005',
        movementNo: 'INIT-005',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD005',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 60.0,
        referenceNo: const Value('INIT-005'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK006',
        movementNo: 'INIT-006',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD006',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 40.0,
        referenceNo: const Value('INIT-006'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK007',
        movementNo: 'INIT-007',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD007',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 30.0,
        referenceNo: const Value('INIT-007'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
      StockMovementsCompanion.insert(
        movementId: 'STK008',
        movementNo: 'INIT-008',
        movementDate: DateTime.now(),
        movementType: 'INIT',
        productId: 'PRD008',
        warehouseId: 'WH001',
        userId: 'USR001',
        quantity: 90.0,
        referenceNo: const Value('INIT-008'),
        remark: const Value('สต๊อกเริ่มต้น'),
      ),
    ];

    for (var stock in stockMovements) {
      try {
        await db
            .into(db.stockMovements)
            .insert(stock, mode: InsertMode.insertOrIgnore);
      } catch (e) {
        // Stock exists
      }
    }
  }

  /// Seed Suppliers
  static Future<void> seedSuppliers(AppDatabase db) async {
    print('🌱 Seeding suppliers...');

    // ✅ ลบข้อมูลเดิมทิ้งก่อน
    try {
      await db.delete(db.suppliers).go();
      print('   🗑️ Cleared existing suppliers');
    } catch (e) {
      print('   ⚠️ Could not clear suppliers: $e');
    }

    final suppliers = [
      SuppliersCompanion.insert(
        supplierId: 'SUP001',
        supplierCode: 'SUP-001',
        supplierName: 'บริษัท ซัพพลายเออร์ A จำกัด',
        contactPerson: const Value('คุณสมชาย'),
        phone: const Value('02-111-2222'),
        email: const Value('contact@supplier-a.com'),
        lineId: const Value('@supplierA'), // ✅ เพิ่มบรรทัดนี้
        address: const Value('123 ถนนพระราม 4 กรุงเทพฯ'),
        taxId: const Value('0105566001234'),
        creditTerm: const Value(30),
        creditLimit: const Value(100000.0),
        currentBalance: const Value(0.0),
      ),
      SuppliersCompanion.insert(
        supplierId: 'SUP002',
        supplierCode: 'SUP-002',
        supplierName: 'บริษัท ซัพพลายเออร์ B จำกัด',
        contactPerson: const Value('คุณสมหญิง'),
        phone: const Value('02-222-3333'),
        email: const Value('info@supplier-b.com'),
        lineId: const Value('@supplierB'), // ✅ เพิ่มบรรทัดนี้
        address: const Value('456 ถนนสุขุมวิท กรุงเทพฯ'),
        taxId: const Value('0105566005678'),
        creditTerm: const Value(45),
        creditLimit: const Value(200000.0),
        currentBalance: const Value(0.0),
      ),
      SuppliersCompanion.insert(
        supplierId: 'SUP003',
        supplierCode: 'SUP-003',
        supplierName: 'ร้านค้าส่ง C',
        contactPerson: const Value('คุณสมศักดิ์'),
        phone: const Value('081-444-5555'),
        email: const Value('sales@wholesale-c.com'),
        lineId: const Value('@supplierC'), // ✅ เพิ่มบรรทัดนี้
        creditTerm: const Value(7),
        creditLimit: const Value(50000.0),
        currentBalance: const Value(0.0),
      ),
    ];

    int inserted = 0;
    for (var supplier in suppliers) {
      try {
        await db.into(db.suppliers).insert(supplier);
        inserted++;
        print('   ✅ Inserted: ${supplier.supplierId.value}');
      } catch (e) {
        print('   ❌ Failed to insert ${supplier.supplierId.value}: $e');
      }
    }

    final count = await db.select(db.suppliers).get();
    print('✅ Seeded $inserted suppliers (total in DB: ${count.length})');
  }
}