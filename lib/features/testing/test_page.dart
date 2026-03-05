// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/seed_data.dart';

class TestPage extends ConsumerWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบระบบ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'ข้อมูลทดสอบ',
            children: [
              _buildTestButton(
                context,
                icon: Icons.data_object,
                title: 'Seed ข้อมูลทดสอบ',
                subtitle: 'สร้างข้อมูลตัวอย่างทั้งหมด',
                color: Colors.green,
                onTap: () async {
                  await _seedData(context);
                },
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                context,
                icon: Icons.delete_forever,
                title: 'ลบข้อมูลทั้งหมด',
                subtitle: 'ระวัง! จะลบข้อมูลทั้งหมด (เก็บ Users)',
                color: Colors.red,
                onTap: () async {
                  await _clearData(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'ตรวจสอบข้อมูล',
            children: [
              _buildTestButton(
                context,
                icon: Icons.people,
                title: 'ตรวจสอบ Users',
                subtitle: 'ดูจำนวน Users ในระบบ',
                color: Colors.blue,
                onTap: () async {
                  await _checkUsers(context);
                },
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                context,
                icon: Icons.inventory,
                title: 'ตรวจสอบ Products',
                subtitle: 'ดูจำนวน Products ในระบบ',
                color: Colors.orange,
                onTap: () async {
                  await _checkProducts(context);
                },
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                context,
                icon: Icons.person,
                title: 'ตรวจสอบ Customers',
                subtitle: 'ดูจำนวน Customers ในระบบ',
                color: Colors.purple,
                onTap: () async {
                  await _checkCustomers(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
  
  Widget _buildTestButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  Future<void> _seedData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยัน'),
        content: const Text('ต้องการสร้างข้อมูลทดสอบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final db = AppDatabase();
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // ✅ เรียกแบบ static method
      await SeedData.seedAll(db);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ สร้างข้อมูลทดสอบสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ คำเตือน'),
        content: const Text('ต้องการลบข้อมูลทั้งหมดใช่หรือไม่?\n(จะเก็บ Users ไว้)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final db = AppDatabase();
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // ✅ ลบข้อมูลทีละตาราง (เรียงลำดับตาม foreign key)
      print('🗑️ Deleting stock movements...');
      await db.delete(db.stockMovements).go();
      
      print('🗑️ Deleting sales order items...');
      await db.delete(db.salesOrderItems).go();
      
      print('🗑️ Deleting sales orders...');
      await db.delete(db.salesOrders).go();
      
      print('🗑️ Deleting products...');
      await db.delete(db.products).go();
      
      print('🗑️ Deleting product groups...');
      await db.delete(db.productGroups).go();
      
      print('🗑️ Deleting customers...');
      await db.delete(db.customers).go();
      
      print('🗑️ Deleting warehouses...');
      await db.delete(db.warehouses).go();
      
      print('🗑️ Deleting branches...');
      await db.delete(db.branches).go();
      
      // ✅ ไม่ลบ users และ roles เพื่อให้ยัง login ได้
      print('✅ Data cleared (kept users & roles)');
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ลบข้อมูลสำเร็จ (เก็บ Users ไว้)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Clear data error: $e');
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _checkUsers(BuildContext context) async {
    try {
      final db = AppDatabase();
      final users = await db.select(db.users).get();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Users'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวน: ${users.length} คน'),
                const SizedBox(height: 16),
                ...users.map((u) => Text('• ${u.username} (${u.fullName})')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _checkProducts(BuildContext context) async {
    try {
      final db = AppDatabase();
      final products = await db.select(db.products).get();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Products'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวน: ${products.length} รายการ'),
                const SizedBox(height: 16),
                ...products.take(5).map((p) => Text('• ${p.productCode}: ${p.productName}')),
                if (products.length > 5) const Text('...'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _checkCustomers(BuildContext context) async {
    try {
      final db = AppDatabase();
      final customers = await db.select(db.customers).get();
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Customers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวน: ${customers.length} คน'),
                const SizedBox(height: 16),
                ...customers.map((c) => Text('• ${c.customerCode}: ${c.customerName}')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}