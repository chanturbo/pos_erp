import 'package:flutter/material.dart';
import 'package:drift/drift.dart';  // ✅ เพิ่มบรรทัดนี้
import 'app_database.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  final db = AppDatabase();
  String _result = 'กำลังทดสอบ...';

  @override
  void initState() {
    super.initState();
    _testDatabase();
  }

  Future<void> _testDatabase() async {
    try {
      // ทดสอบสร้างข้อมูล
      
      // 1. สร้าง Company
      await db.into(db.companies).insert(CompaniesCompanion.insert(
        companyId: 'COMP001',
        companyName: 'บริษัท ทดสอบ จำกัด',
        taxId: const Value('1234567890123'),
      ));
      
      // 2. สร้าง Branch
      await db.into(db.branches).insert(BranchesCompanion.insert(
        branchId: 'BR001',
        companyId: 'COMP001',
        branchCode: '001',
        branchName: 'สาขาหลัก',
      ));
      
      // 3. สร้าง Role
      await db.into(db.roles).insert(RolesCompanion.insert(
        roleId: 'ROLE001',
        roleName: 'Administrator',
        permissions: {'sales': {'create': true, 'edit': true, 'delete': true}},
      ));
      
      // 4. สร้าง User
      await db.into(db.users).insert(UsersCompanion.insert(
        userId: 'USR001',
        username: 'admin',
        passwordHash: 'admin123',  // ในระบบจริงต้อง hash
        fullName: 'ผู้ดูแลระบบ',
        roleId: const Value('ROLE001'),
        branchId: const Value('BR001'),
      ));
      
      // 5. สร้าง Product Group
      await db.into(db.productGroups).insert(ProductGroupsCompanion.insert(
        groupId: 'GRP001',
        groupCode: 'FOOD',
        groupName: 'อาหาร',
      ));
      
      // 6. สร้าง Product
      await db.into(db.products).insert(ProductsCompanion.insert(
        productId: 'PRD001',
        productCode: 'F001',
        productName: 'ข้าวผัดกุ้ง',
        baseUnit: 'จาน',
        priceLevel1: const Value(50.0),
        groupId: const Value('GRP001'),
        isStockControl: const Value(false),  // ไม่ควบคุมสต๊อก
      ));
      
      // 7. อ่านข้อมูลกลับมา
      final companies = await db.select(db.companies).get();
      final branches = await db.select(db.branches).get();
      final users = await db.select(db.users).get();
      final products = await db.select(db.products).get();
      
      setState(() {
        _result = '''
✅ ทดสอบสำเร็จ!

📊 ข้อมูลที่สร้าง:
- บริษัท: ${companies.length} รายการ
  ${companies.map((c) => '  • ${c.companyName}').join('\n')}

- สาขา: ${branches.length} รายการ
  ${branches.map((b) => '  • ${b.branchName}').join('\n')}

- ผู้ใช้: ${users.length} รายการ
  ${users.map((u) => '  • ${u.username} (${u.fullName})').join('\n')}

- สินค้า: ${products.length} รายการ
  ${products.map((p) => '  • ${p.productCode}: ${p.productName} (${p.priceLevel1} บาท)').join('\n')}

🎉 Database พร้อมใช้งาน!
        ''';
      });
      
    } catch (e) {
      setState(() {
        _result = '❌ เกิดข้อผิดพลาด:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบ Database'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          _result,
          style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    db.close();
    super.dispose();
  }
}