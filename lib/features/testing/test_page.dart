// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/seed_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/responsive_utils.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/mobile_home_button.dart';

class TestPage extends ConsumerWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ทดสอบระบบ'),
            Text(
              'จัดการข้อมูลทดสอบและตรวจสอบข้อมูลในระบบ',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: SingleChildScrollView(
            padding: context.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard(
                      context,
                      title: 'ข้อมูลทดสอบ',
                      value: '2',
                      icon: Icons.dataset_outlined,
                      color: AppTheme.successColor,
                    ),
                    _summaryCard(
                      context,
                      title: 'ตรวจสอบข้อมูล',
                      value: '3',
                      icon: Icons.fact_check_outlined,
                      color: AppTheme.infoColor,
                    ),
                    _summaryCard(
                      context,
                      title: 'งานเสี่ยง',
                      value: '1',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(
                  context,
                  'ข้อมูลทดสอบ',
                  Icons.data_object_outlined,
                  AppTheme.successColor,
                ),
                const SizedBox(height: 8),
                _panelCard(
                  context,
                  child: Padding(
                    padding: context.cardPadding,
                    child: Column(
                      children: [
                        _buildTestAction(
                          context,
                          icon: Icons.data_object,
                          title: 'Seed ข้อมูลทดสอบ',
                          subtitle:
                              'สร้างข้อมูลตัวอย่างทั้งหมดสำหรับการใช้งานและการทดลอง',
                          color: AppTheme.successColor,
                          onTap: () async => _seedData(context),
                        ),
                        Divider(
                          height: 20,
                          color: AppTheme.borderColorOf(context),
                        ),
                        _buildTestAction(
                          context,
                          icon: Icons.delete_forever_outlined,
                          title: 'ลบข้อมูลทั้งหมด',
                          subtitle:
                              'ระวัง! จะลบข้อมูลทั้งหมดในระบบ แต่เก็บ Users และ Roles ไว้',
                          color: AppTheme.errorColor,
                          onTap: () async => _clearData(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(
                  context,
                  'ตรวจสอบข้อมูล',
                  Icons.manage_search_rounded,
                  AppTheme.infoColor,
                ),
                const SizedBox(height: 8),
                _panelCard(
                  context,
                  child: Padding(
                    padding: context.cardPadding,
                    child: Column(
                      children: [
                        _buildTestAction(
                          context,
                          icon: Icons.people_alt_outlined,
                          title: 'ตรวจสอบ Users',
                          subtitle: 'ดูจำนวนผู้ใช้งานและข้อมูลผู้ใช้ในระบบ',
                          color: AppTheme.infoColor,
                          onTap: () async => _checkUsers(context),
                        ),
                        Divider(
                          height: 20,
                          color: AppTheme.borderColorOf(context),
                        ),
                        _buildTestAction(
                          context,
                          icon: Icons.inventory_2_outlined,
                          title: 'ตรวจสอบ Products',
                          subtitle: 'ดูจำนวนสินค้าและรายการตัวอย่างในระบบ',
                          color: Colors.orange,
                          onTap: () async => _checkProducts(context),
                        ),
                        Divider(
                          height: 20,
                          color: AppTheme.borderColorOf(context),
                        ),
                        _buildTestAction(
                          context,
                          icon: Icons.person_search_outlined,
                          title: 'ตรวจสอบ Customers',
                          subtitle: 'ดูจำนวนลูกค้าและรายการลูกค้าปัจจุบัน',
                          color: Colors.purple,
                          onTap: () async => _checkCustomers(context),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.isMobile ? 20 : 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.isMobile ? 40 : 44,
              height: context.isMobile ? 40 : 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _cardTitleStyle(context)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _cardSubtitleStyle(context)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.subtextColorOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final width = context.isMobile ? (context.screenWidth - 36) / 2 : 220.0;
    return SizedBox(
      width: width,
      child: _panelCard(
        context,
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            children: [
              Container(
                width: context.isMobile ? 38 : 42,
                height: context.isMobile ? 38 : 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: context.isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: context.isMobile ? 14 : 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: _cardSubtitleStyle(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: child,
    );
  }

  TextStyle _cardTitleStyle(BuildContext context, {double? fontSize}) {
    return TextStyle(
      fontSize: fontSize ?? (context.isMobile ? 13 : 14),
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  TextStyle _cardSubtitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: context.isMobile ? 11 : 12,
      color: AppTheme.subtextColorOf(context),
      fontWeight: FontWeight.w500,
    );
  }

  Future<void> _seedData(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'ยืนยัน',
      content: 'ต้องการสร้างข้อมูลทดสอบใช่หรือไม่?',
      confirmLabel: 'ยืนยัน',
    );

    if (confirmed != true) return;

    try {
      final db = AppDatabase();

      if (context.mounted) {
        LoadingOverlay.show(context, message: 'กำลังสร้างข้อมูลทดสอบ...');
      }

      await SeedData.seedAll(db);

      if (context.mounted) {
        LoadingOverlay.hide(context);
        context.showSuccess('สร้างข้อมูลทดสอบสำเร็จ');
      }
    } catch (e) {
      if (context.mounted) {
        LoadingOverlay.hide(context);
        context.showError('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '⚠️ คำเตือน',
      content: 'ต้องการลบข้อมูลทั้งหมดใช่หรือไม่?\n(จะเก็บ Users ไว้)',
      confirmLabel: 'ลบข้อมูล',
      destructive: true,
    );

    if (confirmed != true) return;

    try {
      final db = AppDatabase();

      if (context.mounted) {
        LoadingOverlay.show(context, message: 'กำลังลบข้อมูล...');
      }

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

      print('✅ Data cleared (kept users & roles)');

      if (context.mounted) {
        LoadingOverlay.hide(context);
        context.showWarning('ลบข้อมูลสำเร็จ (เก็บ Users ไว้)');
      }
    } catch (e) {
      print('❌ Clear data error: $e');
      if (context.mounted) {
        LoadingOverlay.hide(context);
        context.showError('เกิดข้อผิดพลาด: $e');
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
          builder: (context) => AppDialog(
            title: buildAppDialogTitle(
              context,
              title: 'Users',
              icon: Icons.people_alt_outlined,
            ),
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
      if (context.mounted) context.showError('Error: $e');
    }
  }

  Future<void> _checkProducts(BuildContext context) async {
    try {
      final db = AppDatabase();
      final products = await db.select(db.products).get();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AppDialog(
            title: buildAppDialogTitle(
              context,
              title: 'Products',
              icon: Icons.inventory_2_outlined,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวน: ${products.length} รายการ'),
                const SizedBox(height: 16),
                ...products
                    .take(5)
                    .map((p) => Text('• ${p.productCode}: ${p.productName}')),
                if (products.length > 5)
                  Text(
                    '... และอีก ${products.length - 5} รายการ',
                    style: const TextStyle(color: Colors.grey),
                  ),
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
      if (context.mounted) context.showError('Error: $e');
    }
  }

  Future<void> _checkCustomers(BuildContext context) async {
    try {
      final db = AppDatabase();
      final customers = await db.select(db.customers).get();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AppDialog(
            title: buildAppDialogTitle(
              context,
              title: 'Customers',
              icon: Icons.person_search_outlined,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวน: ${customers.length} คน'),
                const SizedBox(height: 16),
                ...customers.map(
                  (c) => Text('• ${c.customerCode}: ${c.customerName}'),
                ),
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
      if (context.mounted) context.showError('Error: $e');
    }
  }
}
