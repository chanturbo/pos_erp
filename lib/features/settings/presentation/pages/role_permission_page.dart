import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/permissions/app_permissions.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/mobile_home_button.dart';

// ─────────────────────────────────────────────────────────────────
// RolePermissionPage — จัดการสิทธิ์การเข้าถึงแต่ละหน้า/ฟีเจอร์
// ─────────────────────────────────────────────────────────────────
class RolePermissionPage extends ConsumerStatefulWidget {
  const RolePermissionPage({super.key});

  @override
  ConsumerState<RolePermissionPage> createState() => _RolePermissionPageState();
}

class _RolePermissionPageState extends ConsumerState<RolePermissionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Roles ที่แสดง tab (ADMIN แสดงแต่ read-only)
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: appRoles.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permAsync = ref.watch(rolePermissionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: const Text('จัดการสิทธิ์การใช้งาน'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: appRoles.map((role) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (role.roleId == 'ADMIN')
                    const Icon(Icons.shield_rounded, size: 14),
                  if (role.roleId != 'ADMIN')
                    _roleIcon(role.roleId),
                  const SizedBox(width: 6),
                  Text(role.label),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: permAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (permissions) => TabBarView(
          controller: _tabController,
          children: appRoles.map((role) {
            return _RolePermissionTab(
              role: role,
              permissions: permissions[role.roleId] ?? [],
              isAdmin: role.roleId == 'ADMIN',
              isDark: isDark,
              onToggle: (perm) => ref
                  .read(rolePermissionsProvider.notifier)
                  .toggle(role.roleId, perm),
              onReset: () => _confirmReset(role),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _roleIcon(String roleId) {
    final icon = switch (roleId) {
      'MANAGER'    => Icons.manage_accounts_rounded,
      'CASHIER'    => Icons.point_of_sale_rounded,
      'WAREHOUSE'  => Icons.warehouse_rounded,
      'ACCOUNTANT' => Icons.account_balance_rounded,
      _            => Icons.person_rounded,
    };
    return Icon(icon, size: 14);
  }

  Future<void> _confirmReset(AppRoleInfo role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'คืนค่าเริ่มต้น',
          icon: Icons.restore_rounded,
        ),
        content: Text(
          'คืนสิทธิ์ของ "${role.label}" กลับเป็นค่าเริ่มต้นใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('คืนค่า'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(rolePermissionsProvider.notifier).resetRole(role.roleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('คืนค่าเริ่มต้น "${role.label}" แล้ว'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// _RolePermissionTab — แสดง/แก้ไข permission ของแต่ละ role
// ─────────────────────────────────────────────────────────────────
class _RolePermissionTab extends StatelessWidget {
  final AppRoleInfo role;
  final List<String> permissions;
  final bool isAdmin;
  final bool isDark;
  final void Function(String permission) onToggle;
  final VoidCallback onReset;

  const _RolePermissionTab({
    required this.role,
    required this.permissions,
    required this.isAdmin,
    required this.isDark,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header strip ─────────────────────────────────────────
        _buildHeader(context),

        // ── Permission list ───────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: appPermissionGroups.length,
            itemBuilder: (context, i) =>
                _buildGroup(context, appPermissionGroups[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final enabledCount = isAdmin
        ? AppPermission.all.length
        : permissions.length;
    final totalCount = AppPermission.all.length;
    final color = _roleColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_roleIconData(), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'เข้าถึงได้ทั้งหมด',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
            )
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$enabledCount / $totalCount',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  'สิทธิ์ที่เปิด',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: const Text('คืนค่า', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, PermissionGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            group.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.subtextColorOf(context),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColorOf(context),
            ),
          ),
          child: Column(
            children: group.keys.asMap().entries.map((entry) {
              final i = entry.key;
              final key = entry.value;
              final isLast = i == group.keys.length - 1;
              return _buildPermRow(context, key, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPermRow(BuildContext context, String permKey, bool isLast) {
    final label = appPermissionLabels[permKey] ?? permKey;
    final isEnabled = isAdmin || permissions.contains(permKey);
    final roleColor = _roleColor();

    return Column(
      children: [
        InkWell(
          onTap: isAdmin ? null : () => onToggle(permKey),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Permission icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? roleColor.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _permIcon(permKey),
                    size: 16,
                    color: isEnabled
                        ? roleColor
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isEnabled
                          ? null
                          : AppTheme.subtextColorOf(context),
                    ),
                  ),
                ),
                if (isAdmin)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppTheme.successColor.withValues(alpha: 0.7),
                  )
                else
                  Switch.adaptive(
                    value: isEnabled,
                    onChanged: (_) => onToggle(permKey),
                    activeThumbColor: roleColor,
                    activeTrackColor: roleColor.withValues(alpha: 0.4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 60,
            color: AppTheme.borderColorOf(context),
          ),
      ],
    );
  }

  Color _roleColor() => switch (role.roleId) {
    'ADMIN'      => const Color(0xFF6C5CE7),
    'MANAGER'    => AppTheme.primaryColor,
    'CASHIER'    => AppTheme.successColor,
    'WAREHOUSE'  => const Color(0xFF0984E3),
    'ACCOUNTANT' => const Color(0xFF00B894),
    _            => Colors.grey,
  };

  IconData _roleIconData() => switch (role.roleId) {
    'ADMIN'      => Icons.shield_rounded,
    'MANAGER'    => Icons.manage_accounts_rounded,
    'CASHIER'    => Icons.point_of_sale_rounded,
    'WAREHOUSE'  => Icons.warehouse_rounded,
    'ACCOUNTANT' => Icons.account_balance_rounded,
    _            => Icons.person_rounded,
  };

  IconData _permIcon(String key) => switch (key) {
    AppPermission.dashboard      => Icons.dashboard_rounded,
    AppPermission.pos            => Icons.shopping_cart_rounded,
    AppPermission.salesHistory   => Icons.receipt_long_rounded,
    AppPermission.promotions     => Icons.local_offer_rounded,
    AppPermission.products       => Icons.inventory_rounded,
    AppPermission.stock          => Icons.warehouse_rounded,
    AppPermission.stockAdjust    => Icons.tune_rounded,
    AppPermission.customers      => Icons.people_rounded,
    AppPermission.suppliers      => Icons.business_rounded,
    AppPermission.purchaseOrder  => Icons.shopping_bag_rounded,
    AppPermission.goodsReceipt   => Icons.inventory_2_rounded,
    AppPermission.purchaseReturn => Icons.assignment_return_rounded,
    AppPermission.apInvoice      => Icons.receipt_rounded,
    AppPermission.apPayment      => Icons.payments_rounded,
    AppPermission.arInvoice      => Icons.request_page_rounded,
    AppPermission.arReceipt      => Icons.price_check_rounded,
    AppPermission.reports        => Icons.assessment_rounded,
    AppPermission.branch         => Icons.store_rounded,
    AppPermission.sync           => Icons.sync_alt_rounded,
    AppPermission.settings       => Icons.settings_rounded,
    AppPermission.rolePermissions => Icons.admin_panel_settings_rounded,
    _                            => Icons.circle_outlined,
  };
}
