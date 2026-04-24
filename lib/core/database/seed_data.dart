// ignore_for_file: avoid_print

import 'package:drift/drift.dart';
import 'app_database.dart';

enum DemoMode { posOnly, restaurantOnly, both, none }

class SeedData {
  /// Seed essential base data (always required — no demo products)
  static Future<void> seedEssential(AppDatabase db) async {
    print('🌱 Seeding essential data...');
    await seedCompanies(db);
    await seedBranches(db);
    await seedWarehouses(db);
    await seedRoles(db);
    await seedUsers(db);
    await seedCustomerGroups(db);
    await seedCustomers(db);
    await seedSuppliers(db);
    print('✅ Essential data seeded');
  }

  /// Seed POS demo: product groups + products + initial stock
  static Future<void> seedPosDemo(AppDatabase db) async {
    print('🌱 Seeding POS demo data...');
    await seedProductGroups(db);
    await seedProducts(db);
    print('✅ POS demo seeded');
  }

  /// Seed demo data by mode
  static Future<void> seedByMode(AppDatabase db, DemoMode mode) async {
    await seedEssential(db);
    switch (mode) {
      case DemoMode.posOnly:
        await seedPosDemo(db);
      case DemoMode.restaurantOnly:
        await seedRestaurantDemo(db);
      case DemoMode.both:
        await seedPosDemo(db);
        await seedRestaurantDemo(db);
      case DemoMode.none:
        break;
    }
    print('✅ Seed by mode ($mode) completed');
  }

  /// Seed All Data (backward-compatible — seeds everything)
  static Future<void> seedAll(AppDatabase db) async {
    print('🌱 Starting seed data...');
    await seedEssential(db);
    await seedPosDemo(db);
    await seedRestaurantDemo(db);
    print('✅ Seed data completed');
  }

  /// Seed Companies
  static Future<void> seedCompanies(AppDatabase db) async {
    final companies = [
      CompaniesCompanion.insert(
        companyId: 'COMP001',
        companyName: 'DEE POS Demo',
        taxId: const Value('0105566000000'),
        address: const Value('123 ถนนทดสอบ กรุงเทพฯ 10100'),
        phone: const Value('02-123-4567'),
      ),
    ];

    for (final company in companies) {
      await db
          .into(db.companies)
          .insert(company, mode: InsertMode.insertOrIgnore);
    }
  }

  /// Seed Branches
  static Future<void> seedBranches(AppDatabase db) async {
    final branches = [
      BranchesCompanion.insert(
        branchId: 'BR001',
        companyId: 'COMP001',
        branchCode: 'HQ',
        branchName: 'สาขาหลัก',
        address: const Value('123 ถนนทดสอบ กรุงเทพฯ 10100'),
        phone: const Value('02-123-4567'),
        businessMode: const Value('RESTAURANT'),
      ),
    ];

    for (var branch in branches) {
      await db.into(db.branches).insertOnConflictUpdate(branch);
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
      ),
    ];

    for (var warehouse in warehouses) {
      await db.into(db.warehouses).insertOnConflictUpdate(warehouse);
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
        await db.into(db.users).insert(user, mode: InsertMode.insertOrIgnore);
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
        groupName: 'อาหาร',
        displayOrder: const Value(10),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP002',
        groupCode: 'DESSERT',
        groupName: 'ของหวาน',
        displayOrder: const Value(20),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP003',
        groupCode: 'DRINK',
        groupName: 'เครื่องดื่ม',
        displayOrder: const Value(30),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP004',
        groupCode: 'SNACK',
        groupName: 'ของทานเล่น',
        displayOrder: const Value(40),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP005',
        groupCode: 'BAKERY',
        groupName: 'เบเกอรี่',
        displayOrder: const Value(50),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP006',
        groupCode: 'BUFFET',
        groupName: 'บุฟเฟต์',
        displayOrder: const Value(60),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP007',
        groupCode: 'HEALTHY',
        groupName: 'อาหารสุขภาพ',
        displayOrder: const Value(70),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'GRP008',
        groupCode: 'OTHER',
        groupName: 'อื่นๆ',
        displayOrder: const Value(80),
      ),
    ];

    for (var group in groups) {
      await db.into(db.productGroups).insertOnConflictUpdate(group);
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
        baseUnit: 'ขวด',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD002',
        productCode: 'FOOD-002',
        productName: 'กาแฟกระป๋อง',
        barcode: const Value('8850123456790'),
        baseUnit: 'กระป๋อง',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD003',
        productCode: 'FOOD-003',
        productName: 'ชาเขียวญี่ปุ่น',
        barcode: const Value('8850123456791'),
        baseUnit: 'ขวด',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD004',
        productCode: 'SNACK-001',
        productName: 'มันฝรั่งทอด รสออริจินัล',
        barcode: const Value('8850123456792'),
        baseUnit: 'ถุง',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD005',
        productCode: 'SNACK-002',
        productName: 'คุกกี้ช็อกโกแลต',
        barcode: const Value('8850123456793'),
        baseUnit: 'กล่อง',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD006',
        productCode: 'DAILY-001',
        productName: 'ยาสีฟัน',
        barcode: const Value('8850123456794'),
        baseUnit: 'หลอด',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD007',
        productCode: 'DAILY-002',
        productName: 'แชมพู',
        barcode: const Value('8850123456795'),
        baseUnit: 'ขวด',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'PRD008',
        productCode: 'DAILY-003',
        productName: 'สบู่ก้อน',
        barcode: const Value('8850123456796'),
        baseUnit: 'ก้อน',
        serviceMode: const Value('BOTH'),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
    ];

    for (var product in products) {
      await db.into(db.products).insertOnConflictUpdate(product);
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

  /// Seed Restaurant Demo Data
  static Future<void> seedRestaurantDemo(AppDatabase db) async {
    print('🌱 Seeding restaurant demo...');

    final restaurantGroups = [
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-FOOD',
        groupCode: 'RST-FOOD',
        groupName: 'อาหาร',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(10),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-DESSERT',
        groupCode: 'RST-DESSERT',
        groupName: 'ของหวาน',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(20),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-DRINK',
        groupCode: 'RST-DRINK',
        groupName: 'เครื่องดื่ม',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(30),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-SNACK',
        groupCode: 'RST-SNACK',
        groupName: 'ของทานเล่น',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(40),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-BAKERY',
        groupCode: 'RST-BAKERY',
        groupName: 'เบเกอรี่',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(50),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-BUFFET',
        groupCode: 'RST-BUFFET',
        groupName: 'บุฟเฟต์',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(60),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-HEALTHY',
        groupCode: 'RST-HEALTHY',
        groupName: 'อาหารสุขภาพ',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(70),
      ),
      ProductGroupsCompanion.insert(
        groupId: 'RST-GRP-OTHER',
        groupCode: 'RST-OTHER',
        groupName: 'อื่นๆ',
        groupType: const Value('RESTAURANT'),
        displayOrder: const Value(80),
      ),
    ];

    for (final group in restaurantGroups) {
      await db.into(db.productGroups).insertOnConflictUpdate(group);
    }

    final restaurantProducts = [
      ProductsCompanion.insert(
        productId: 'RST-PRD-001',
        productCode: 'RST-FOOD-001',
        productName: 'ผัดไทยกุ้งสด',
        barcode: const Value('8859001000011'),
        groupId: const Value('RST-GRP-FOOD'),
        baseUnit: 'จาน',
        priceLevel1: const Value(129),
        standardCost: const Value(48),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(20),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('kitchen'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-002',
        productCode: 'RST-FOOD-002',
        productName: 'ต้มยำกุ้งน้ำข้น',
        barcode: const Value('8859001000028'),
        groupId: const Value('RST-GRP-FOOD'),
        baseUnit: 'ชาม',
        priceLevel1: const Value(159),
        standardCost: const Value(62),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(15),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('kitchen'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-003',
        productCode: 'RST-FOOD-003',
        productName: 'ข้าวกะเพราไก่ไข่ดาว',
        barcode: const Value('8859001000035'),
        groupId: const Value('RST-GRP-FOOD'),
        baseUnit: 'จาน',
        priceLevel1: const Value(89),
        standardCost: const Value(35),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(25),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('kitchen'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-004',
        productCode: 'RST-DRINK-001',
        productName: 'ชาไทยเย็น',
        barcode: const Value('8859001000042'),
        groupId: const Value('RST-GRP-DRINK'),
        baseUnit: 'แก้ว',
        priceLevel1: const Value(55),
        standardCost: const Value(18),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(30),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('bar'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-005',
        productCode: 'RST-DRINK-002',
        productName: 'อเมริกาโน่เย็น',
        barcode: const Value('8859001000059'),
        groupId: const Value('RST-GRP-DRINK'),
        baseUnit: 'แก้ว',
        priceLevel1: const Value(65),
        standardCost: const Value(22),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(30),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('bar'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-006',
        productCode: 'RST-DESSERT-001',
        productName: 'บัวลอยมะพร้าวอ่อน',
        barcode: const Value('8859001000066'),
        groupId: const Value('RST-GRP-DESSERT'),
        baseUnit: 'ถ้วย',
        priceLevel1: const Value(69),
        standardCost: const Value(24),
        isStockControl: const Value(false),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(15),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('dessert'),
        requiresPreparation: const Value(true),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'RST-PRD-007',
        productCode: 'RST-DRINK-003',
        productName: 'น้ำเปล่า',
        barcode: const Value('8859001000073'),
        groupId: const Value('RST-GRP-DRINK'),
        baseUnit: 'ขวด',
        priceLevel1: const Value(15),
        standardCost: const Value(6),
        isStockControl: const Value(true),
        allowNegativeStock: const Value(true),
        reorderPoint: const Value(48),
        serviceMode: const Value('BOTH'),
        prepStation: const Value('cashier'),
        requiresPreparation: const Value(false),
        dineInAvailable: const Value(true),
        takeawayAvailable: const Value(true),
      ),
    ];

    for (final product in restaurantProducts) {
      await db.into(db.products).insertOnConflictUpdate(product);
    }

    final zones = [
      ZonesCompanion.insert(
        zoneId: 'RST-ZONE-FRONT',
        zoneName: 'หน้าร้าน',
        branchId: 'BR001',
        displayOrder: const Value(10),
      ),
      ZonesCompanion.insert(
        zoneId: 'RST-ZONE-AIR',
        zoneName: 'ห้องแอร์',
        branchId: 'BR001',
        displayOrder: const Value(20),
      ),
    ];

    for (final zone in zones) {
      await db.into(db.zones).insertOnConflictUpdate(zone);
    }

    final tables = [
      for (var i = 1; i <= 6; i++)
        DiningTablesCompanion.insert(
          tableId: 'RST-TBL-A$i',
          tableNo: 'A$i',
          tableDisplayName: Value('โต๊ะ A$i'),
          zoneId: 'RST-ZONE-FRONT',
          capacity: const Value(4),
        ),
      for (var i = 1; i <= 4; i++)
        DiningTablesCompanion.insert(
          tableId: 'RST-TBL-B$i',
          tableNo: 'B$i',
          tableDisplayName: Value('โต๊ะ B$i'),
          zoneId: 'RST-ZONE-AIR',
          capacity: const Value(6),
        ),
    ];

    for (final table in tables) {
      await db
          .into(db.diningTables)
          .insert(table, mode: InsertMode.insertOrIgnore);
    }

    final stockMovements = [
      for (var i = 0; i < restaurantProducts.length; i++)
        StockMovementsCompanion.insert(
          movementId: 'RST-STK-${(i + 1).toString().padLeft(3, '0')}',
          movementNo: 'RST-INIT-${(i + 1).toString().padLeft(3, '0')}',
          movementDate: DateTime.now(),
          movementType: 'INIT',
          productId: restaurantProducts[i].productId.value,
          warehouseId: 'WH001',
          userId: 'USR001',
          quantity: i >= 3 ? 120 : 80,
          unitCost: Value(i >= 3 ? 10.0 : 30.0),
          referenceNo: const Value('RST-DEMO'),
          remark: const Value('สต๊อกเริ่มต้นสำหรับ demo ร้านอาหาร'),
        ),
    ];

    for (final stock in stockMovements) {
      await db
          .into(db.stockMovements)
          .insert(stock, mode: InsertMode.insertOrIgnore);
    }

    print('   ✅ Restaurant demo seeded');
  }

  /// Seed Suppliers
  static Future<void> seedSuppliers(AppDatabase db) async {
    print('🌱 Seeding suppliers...');

    final existing = await db.select(db.suppliers).get();
    if (existing.isNotEmpty) {
      print('   ⏭️ Suppliers already exist, skipping');
      return;
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
