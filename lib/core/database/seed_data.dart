import 'package:drift/drift.dart' hide Column;
import 'app_database.dart';
import '../utils/crypto_utils.dart';

class SeedData {
  final AppDatabase db;
  
  SeedData(this.db);
  
  /// เริ่มต้นข้อมูลทั้งหมด
  Future<void> seedAll() async {
    await seedCompanies();
    await seedBranches();
    await seedRoles();
    await seedUsers();
    await seedProductGroups();
    await seedProducts();
    await seedCustomers();
    await seedWarehouses();
  }
  
  /// สร้างข้อมูล Companies
  Future<void> seedCompanies() async {
    try {
      final exists = await (db.select(db.companies)
            ..where((t) => t.companyId.equals('COMP001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Companies already seeded');
        return;
      }
      
      await db.into(db.companies).insert(
        CompaniesCompanion.insert(
          companyId: 'COMP001',
          companyName: 'บริษัท ทดสอบ POS จำกัด',
          taxId: const Value('1234567890123'),
          address: const Value('123 ถนนทดสอบ แขวงทดสอบ เขททดสอบ กรุงเทพฯ 10100'),
          phone: const Value('02-123-4567'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Companies seeded');
    } catch (e) {
      print('❌ Seed companies error: $e');
    }
  }
  
  /// สร้างข้อมูล Branches
  Future<void> seedBranches() async {
    try {
      final exists = await (db.select(db.branches)
            ..where((t) => t.branchId.equals('BR001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Branches already seeded');
        return;
      }
      
      // ✅ เปลี่ยนจาก insertAll เป็น insert ทีละรายการ
      await db.into(db.branches).insert(
        BranchesCompanion.insert(
          branchId: 'BR001',
          companyId: 'COMP001',
          branchCode: '001',
          branchName: 'สาขาหลัก',
          address: const Value('123 ถนนทดสอบ กรุงเทพฯ'),
          phone: const Value('02-123-4567'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.branches).insert(
        BranchesCompanion.insert(
          branchId: 'BR002',
          companyId: 'COMP001',
          branchCode: '002',
          branchName: 'สาขาสยาม',
          address: const Value('456 สยามสแควร์ กรุงเทพฯ'),
          phone: const Value('02-234-5678'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Branches seeded');
    } catch (e) {
      print('❌ Seed branches error: $e');
    }
  }
  
  /// สร้างข้อมูล Roles
  Future<void> seedRoles() async {
    try {
      final exists = await (db.select(db.roles)
            ..where((t) => t.roleId.equals('ROLE001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Roles already seeded');
        return;
      }
      
      await db.into(db.roles).insert(
        RolesCompanion.insert(
          roleId: 'ROLE001',
          roleName: 'Administrator',
          permissions: {
            'sales': {'create': true, 'edit': true, 'delete': true, 'view': true},
            'products': {'create': true, 'edit': true, 'delete': true, 'view': true},
            'customers': {'create': true, 'edit': true, 'delete': true, 'view': true},
            'reports': {'view': true},
          },
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.roles).insert(
        RolesCompanion.insert(
          roleId: 'ROLE002',
          roleName: 'Cashier',
          permissions: {
            'sales': {'create': true, 'view': true},
            'products': {'view': true},
            'customers': {'view': true},
          },
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Roles seeded');
    } catch (e) {
      print('❌ Seed roles error: $e');
    }
  }
  
  /// สร้างข้อมูล Users
  Future<void> seedUsers() async {
    try {
      final exists = await (db.select(db.users)
            ..where((t) => t.userId.equals('USR001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Users already seeded');
        return;
      }
      
      await db.into(db.users).insert(
        UsersCompanion.insert(
          userId: 'USR001',
          username: 'admin',
          passwordHash: CryptoUtils.hashPassword('admin123'),
          fullName: 'ผู้ดูแลระบบ',
          email: const Value('admin@test.com'),
          roleId: const Value('ROLE001'),
          branchId: const Value('BR001'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.users).insert(
        UsersCompanion.insert(
          userId: 'USR002',
          username: 'cashier',
          passwordHash: CryptoUtils.hashPassword('cashier123'),
          fullName: 'แคชเชียร์',
          email: const Value('cashier@test.com'),
          roleId: const Value('ROLE002'),
          branchId: const Value('BR001'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Users seeded');
    } catch (e) {
      print('❌ Seed users error: $e');
    }
  }
  
  /// สร้างข้อมูล Product Groups
  Future<void> seedProductGroups() async {
    try {
      final exists = await (db.select(db.productGroups)
            ..where((t) => t.groupId.equals('GRP001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Product Groups already seeded');
        return;
      }
      
      await db.into(db.productGroups).insert(
        ProductGroupsCompanion.insert(
          groupId: 'GRP001',
          groupCode: 'FOOD',
          groupName: 'อาหาร',
          groupType: const Value('FOOD'),
          displayOrder: const Value(1),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.productGroups).insert(
        ProductGroupsCompanion.insert(
          groupId: 'GRP002',
          groupCode: 'DRINK',
          groupName: 'เครื่องดื่ม',
          groupType: const Value('DRINK'),
          displayOrder: const Value(2),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.productGroups).insert(
        ProductGroupsCompanion.insert(
          groupId: 'GRP003',
          groupCode: 'SNACK',
          groupName: 'ขนม',
          groupType: const Value('GENERAL'),
          displayOrder: const Value(3),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Product Groups seeded');
    } catch (e) {
      print('❌ Seed product groups error: $e');
    }
  }
  
  /// สร้างข้อมูล Products
  Future<void> seedProducts() async {
    try {
      final exists = await (db.select(db.products)
            ..where((t) => t.productId.equals('PRD001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Products already seeded');
        return;
      }
      
      // อาหาร
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD001',
          productCode: 'F001',
          productName: 'ข้าวผัดกุ้ง',
          groupId: const Value('GRP001'),
          baseUnit: 'จาน',
          priceLevel1: const Value(50.0),
          priceLevel2: const Value(55.0),
          standardCost: const Value(30.0),
          isStockControl: const Value(false),
          barcode: const Value('8850123456001'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD002',
          productCode: 'F002',
          productName: 'ผัดกะเพรา',
          groupId: const Value('GRP001'),
          baseUnit: 'จาน',
          priceLevel1: const Value(45.0),
          priceLevel2: const Value(50.0),
          standardCost: const Value(25.0),
          isStockControl: const Value(false),
          barcode: const Value('8850123456002'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD003',
          productCode: 'F003',
          productName: 'ต้มยำกุ้ง',
          groupId: const Value('GRP001'),
          baseUnit: 'ถ้วย',
          priceLevel1: const Value(60.0),
          priceLevel2: const Value(65.0),
          standardCost: const Value(35.0),
          isStockControl: const Value(false),
          barcode: const Value('8850123456003'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      // เครื่องดื่ม
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD004',
          productCode: 'D001',
          productName: 'น้ำเปล่า',
          groupId: const Value('GRP002'),
          baseUnit: 'ขวด',
          priceLevel1: const Value(10.0),
          priceLevel2: const Value(12.0),
          standardCost: const Value(7.0),
          isStockControl: const Value(true),
          allowNegativeStock: const Value(false),
          barcode: const Value('8850123456004'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD005',
          productCode: 'D002',
          productName: 'โค้ก',
          groupId: const Value('GRP002'),
          baseUnit: 'ขวด',
          priceLevel1: const Value(15.0),
          priceLevel2: const Value(18.0),
          standardCost: const Value(10.0),
          isStockControl: const Value(true),
          allowNegativeStock: const Value(false),
          barcode: const Value('8850123456005'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD006',
          productCode: 'D003',
          productName: 'กาแฟเย็น',
          groupId: const Value('GRP002'),
          baseUnit: 'แก้ว',
          priceLevel1: const Value(25.0),
          priceLevel2: const Value(30.0),
          standardCost: const Value(15.0),
          isStockControl: const Value(false),
          barcode: const Value('8850123456006'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      // ขนม
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD007',
          productCode: 'S001',
          productName: 'มาม่า',
          groupId: const Value('GRP003'),
          baseUnit: 'ซอง',
          priceLevel1: const Value(7.0),
          priceLevel2: const Value(8.0),
          standardCost: const Value(5.0),
          isStockControl: const Value(true),
          allowNegativeStock: const Value(false),
          barcode: const Value('8850123456007'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          productId: 'PRD008',
          productCode: 'S002',
          productName: 'เลย์',
          groupId: const Value('GRP003'),
          baseUnit: 'ถุง',
          priceLevel1: const Value(20.0),
          priceLevel2: const Value(22.0),
          standardCost: const Value(15.0),
          isStockControl: const Value(true),
          allowNegativeStock: const Value(false),
          barcode: const Value('8850123456008'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Products seeded (8 items)');
    } catch (e) {
      print('❌ Seed products error: $e');
    }
  }
  
  /// สร้างข้อมูล Customers
  Future<void> seedCustomers() async {
    try {
      final exists = await (db.select(db.customers)
            ..where((t) => t.customerId.equals('CUS001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Customers already seeded');
        return;
      }
      
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          customerId: 'CUS001',
          customerCode: 'C001',
          customerName: 'นายสมชาย ใจดี',
          phone: const Value('081-234-5678'),
          email: const Value('somchai@email.com'),
          address: const Value('123 ถนนสุขุมวิท กรุงเทพฯ'),
          creditLimit: const Value(50000),
          creditDays: const Value(30),
          memberNo: const Value('M001'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          customerId: 'CUS002',
          customerCode: 'C002',
          customerName: 'นางสาวสมหญิง รักดี',
          phone: const Value('082-345-6789'),
          email: const Value('somying@email.com'),
          address: const Value('456 ถนนพระราม 4 กรุงเทพฯ'),
          creditLimit: const Value(30000),
          creditDays: const Value(15),
          memberNo: const Value('M002'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          customerId: 'CUS003',
          customerCode: 'C003',
          customerName: 'บริษัท ทดสอบ จำกัด',
          phone: const Value('02-345-6789'),
          email: const Value('contact@company.com'),
          address: const Value('789 ถนนสาทร กรุงเทพฯ'),
          taxId: const Value('0123456789012'),
          creditLimit: const Value(100000),
          creditDays: const Value(60),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          customerId: 'CUS004',
          customerCode: 'WALK-IN',
          customerName: 'ลูกค้าทั่วไป',
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Customers seeded (4 customers)');
    } catch (e) {
      print('❌ Seed customers error: $e');
    }
  }
  
  /// สร้างข้อมูล Warehouses
  Future<void> seedWarehouses() async {
    try {
      final exists = await (db.select(db.warehouses)
            ..where((t) => t.warehouseId.equals('WH001')))
          .getSingleOrNull();
      
      if (exists != null) {
        print('✅ Warehouses already seeded');
        return;
      }
      
      await db.into(db.warehouses).insert(
        WarehousesCompanion.insert(
          warehouseId: 'WH001',
          warehouseCode: 'WH01',
          warehouseName: 'คลังสาขาหลัก',
          branchId: 'BR001',
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      await db.into(db.warehouses).insert(
        WarehousesCompanion.insert(
          warehouseId: 'WH002',
          warehouseCode: 'WH02',
          warehouseName: 'คลังสาขาสยาม',
          branchId: 'BR002',
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      print('✅ Warehouses seeded');
    } catch (e) {
      print('❌ Seed warehouses error: $e');
    }
  }
  
  /// ลบข้อมูลทั้งหมด (ระวัง!)
  Future<void> clearAll() async {
    try {
      await db.delete(db.customers).go();
      await db.delete(db.products).go();
      await db.delete(db.productGroups).go();
      await db.delete(db.warehouses).go();
      await db.delete(db.users).go();
      await db.delete(db.roles).go();
      await db.delete(db.branches).go();
      await db.delete(db.companies).go();
      
      print('✅ All data cleared');
    } catch (e) {
      print('❌ Clear data error: $e');
    }
  }
}