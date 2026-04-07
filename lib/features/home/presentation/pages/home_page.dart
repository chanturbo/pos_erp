import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../ap/presentation/pages/ap_payment_list_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../purchases/presentation/pages/purchase_return_list_page.dart';
import '../../../suppliers/presentation/pages/supplier_list_page.dart';
import '../../../purchases/presentation/pages/purchase_order_list_page.dart';
import '../../../purchases/presentation/pages/goods_receipt_list_page.dart';
import '../../../ap/presentation/pages/ap_invoice_list_page.dart';
import '../../../ar/presentation/pages/ar_invoice_list_page.dart';
import '../../../ar/presentation/pages/ar_receipt_list_page.dart';
import '../../../promotions/presentation/pages/promotion_list_page.dart';
import '../../../branches/presentation/pages/branch_list_page.dart';
import '../../../branches/presentation/pages/sync_status_page.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../testing/test_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../inventory/presentation/pages/stock_adjustment_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../../core/shortcuts/keyboard_shortcuts.dart';
import '../../../settings/presentation/pages/settings_page.dart';

// ─────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String title;
  final Widget page;
  /// true = push เป็น full route (ไม่ swap ใน content area)
  /// ใช้กับหน้าที่ใช้ Navigator ภายใน หรือต้องการ back button เช่น PosPage
  final bool pushAsRoute;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.page,
    this.pushAsRoute = false,
  });
}

class _MenuSection {
  final String label;
  final List<_MenuItem> items;
  const _MenuSection(this.label, this.items);
}

// ─────────────────────────────────────────────────────────────────
// HomePage
// ─────────────────────────────────────────────────────────────────
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  /// หน้า override สำหรับกรณีที่ต้องการแสดงหน้าพร้อม parameter พิเศษ
  /// (เช่น SalesHistoryPage กรองวันนี้) โดยยัง highlight เมนูที่ถูกต้อง
  Widget? _overridePage;

  List<_MenuSection> get _sections => [
        _MenuSection('หลัก', [
          _MenuItem(
            icon: Icons.dashboard,
            title: 'แดชบอร์ด',
            page: DashboardPage(
              onGoToPos: () => context.hasPermanentSidebar
                  ? _selectItem(1)
                  : _push(context, const PosPage()),
              onGoToSalesHistory: () => context.hasPermanentSidebar
                  ? _selectItem(2)
                  : _push(context, const SalesHistoryPage()),
              onGoToProducts: () => context.hasPermanentSidebar
                  ? _selectItem(4)
                  : _push(context, const ProductListPage()),
              onGoToCustomers: () => context.hasPermanentSidebar
                  ? _selectItem(7)
                  : _push(context, const CustomerListPage()),
              onGoToTodaySales: () {
                final today = DateTime.now();
                _showOverridePage(
                  SalesHistoryPage(
                    initialDateFrom:
                        DateTime(today.year, today.month, today.day),
                    initialDateTo:
                        DateTime(today.year, today.month, today.day),
                  ),
                  2, // highlight "รายการขาย"
                );
              },
            ),
          ),
        ]),
        _MenuSection('การขาย', [
          _MenuItem(icon: Icons.shopping_cart,  title: 'หน้าขาย (POS)',  page: const PosPage(), pushAsRoute: true),
          _MenuItem(icon: Icons.receipt_long,   title: 'รายการขาย',      page: const SalesHistoryPage()),
          _MenuItem(icon: Icons.local_offer,    title: 'โปรโมชั่น',      page: const PromotionListPage()),
        ]),
        _MenuSection('คลังสินค้า', [
          _MenuItem(icon: Icons.inventory,   title: 'สินค้า',      page: const ProductListPage()),
          _MenuItem(icon: Icons.warehouse,   title: 'สต๊อกสินค้า', page: const StockBalancePage()),
          _MenuItem(icon: Icons.tune,        title: 'ปรับสต๊อก',   page: const StockAdjustmentPage()),
        ]),
        _MenuSection('ผู้ติดต่อ', [
          _MenuItem(icon: Icons.people,   title: 'ลูกค้า',      page: const CustomerListPage()),
          _MenuItem(icon: Icons.business, title: 'ซัพพลายเออร์', page: const SupplierListPage()),
        ]),
        _MenuSection('จัดซื้อ', [
          _MenuItem(icon: Icons.shopping_bag,      title: 'ซื้อสินค้า',  page: const PurchaseOrderListPage()),
          _MenuItem(icon: Icons.inventory_2,        title: 'รับสินค้า',   page: const GoodsReceiptListPage()),
          _MenuItem(icon: Icons.assignment_return,  title: 'คืนสินค้า',   page: const PurchaseReturnListPage()),
        ]),
        _MenuSection('บัญชี', [
          _MenuItem(icon: Icons.receipt,       title: 'ใบแจ้งหนี้ AP(ซัพฯ)', page: const ApInvoiceListPage()),
          _MenuItem(icon: Icons.payments,      title: 'จ่ายเงิน AP',   page: const ApPaymentListPage()),
          _MenuItem(icon: Icons.request_page,  title: 'ใบแจ้งหนี้ AR(ลูกค้า)', page: const ArInvoiceListPage()),
          _MenuItem(icon: Icons.price_check,   title: 'รับเงิน AR',    page: const ArReceiptListPage()),
        ]),
        _MenuSection('ระบบ', [
          _MenuItem(icon: Icons.assessment, title: 'รายงาน',      page: const ReportsPage()),
          _MenuItem(icon: Icons.store,      title: 'จัดการสาขา',  page: const BranchListPage()),
          _MenuItem(icon: Icons.sync_alt,   title: 'การเชื่อมต่อ/ซิงก์',  page: const SyncStatusPage()),
          _MenuItem(icon: Icons.settings,   title: 'ตั้งค่า',      page: const SettingsPage()),
        ]),
      ];

  List<_MenuItem> get _allItems =>
      _sections.expand((s) => s.items).toList();

  Widget get _currentPage => _overridePage ?? _allItems[_selectedIndex].page;

  void _selectItem(int i) {
    final item = _allItems[i];

    // ปิด Drawer ก่อนเสมอ (tablet/mobile)
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();

    // บนหน้าจอใหญ่ (permanent sidebar) → swap content area เสมอ แม้ pushAsRoute = true
    // บนมือถือ/แท็บเล็ต → push เป็น route ใหม่ตามเดิม
    if (item.pushAsRoute && !context.hasPermanentSidebar) {
      _push(context, item.page);
    } else {
      setState(() {
        _selectedIndex = i;
        _overridePage = null;
      });
    }
  }

  /// แสดงหน้าพิเศษ (พร้อม parameter เฉพาะ) ใน content area โดย highlight เมนู [highlightIndex]
  /// บน desktop (hasPermanentSidebar) → swap ใน content area (มี sidebar)
  /// บน mobile/tablet → push route ตามปกติ
  void _showOverridePage(Widget page, int highlightIndex) {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    if (context.hasPermanentSidebar) {
      setState(() {
        _selectedIndex = highlightIndex;
        _overridePage = page;
      });
    } else {
      _push(context, page);
    }
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(posContextBootstrapProvider);
    final user      = ref.watch(authProvider).user;
    final syncAsync = ref.watch(syncStatusProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);

    // ── Sidebar Widget ─────────────────────────────────────────
    Widget sidebarWidget = _SidebarContent(
      sections: _sections,
      allItems: _allItems,
      selectedIndex: _selectedIndex,
      user: user,
      syncAsync: syncAsync,
      connectionAsync: connectionAsync,
      onItemSelected: _selectItem,
      onSyncTap: () => _push(context, const SyncStatusPage()),
      onTestTap: () => _push(context, const TestPage()),
      onLogout: () => _handleLogout(context),
    );

    return KeyboardShortcuts(
      onPosShortcut:          () => _push(context, const PosPage()),
      onProductShortcut:      () => _push(context, const ProductListPage()),
      onCustomerShortcut:     () => _push(context, const CustomerListPage()),
      onSalesHistoryShortcut: () => _push(context, const SalesHistoryPage()),
      onDashboardShortcut:    () => setState(() => _selectedIndex = 0),
      onInventoryShortcut:    () => _push(context, const StockBalancePage()),
      onReportsShortcut:      () => _push(context, const ReportsPage()),
      child: context.hasPermanentSidebar
          // ── Desktop/Wide: Permanent sidebar ────────────────
          ? Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: context.sidebarWidth,
                    child: sidebarWidget,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: _currentPage),
                ],
              ),
            )
          // ── Tablet/Mobile: Drawer + AppBar ─────────────────
          : Scaffold(
              appBar: _buildMobileAppBar(
                context,
                user,
                syncAsync,
                connectionAsync,
              ),
              drawer: Drawer(
                width: context.sidebarWidth,
                backgroundColor: AppTheme.navyColor,
                child: sidebarWidget,
              ),
              body: _currentPage,
            ),
    );
  }

  // ── Mobile AppBar ──────────────────────────────────────────────
  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    dynamic user,
    AsyncValue syncAsync,
    AsyncValue connectionAsync,
  ) {
    final syncValue = syncAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final sectionTitle =
        _sections.expand((s) => s.items).toList()[_selectedIndex].title;

    return AppBar(
      // Hamburger menu icon สำหรับเปิด Drawer
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          Text(sectionTitle),
        ],
      ),
      actions: [
        // Sync badge
        connectionAsync.when(
          data: (connection) => IconButton(
            icon: Stack(
              children: [
                Icon(
                  connection.isConnected ? Icons.wifi : Icons.wifi_off,
                  color:
                      connection.isConnected ? Colors.white70 : AppTheme.errorLight,
                ),
                if (syncValue?.hasPending == true)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: connection.detail,
            onPressed: () => _push(context, const SyncStatusPage()),
          ),
          loading: () => const SizedBox(width: 48),
          error: (_, _) => const SizedBox(width: 48),
        ),
        // User name (ซ่อนบน mobile เล็กมาก)
        if (!context.isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                user?.fullName ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'ออกจากระบบ',
          onPressed: () => _handleLogout(context),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SidebarContent — ใช้ทั้งใน permanent sidebar และ Drawer
// ─────────────────────────────────────────────────────────────────
class _SidebarContent extends StatelessWidget {
  final List<_MenuSection> sections;
  final List<_MenuItem> allItems;
  final int selectedIndex;
  final dynamic user;
  final AsyncValue syncAsync;
  final AsyncValue connectionAsync;
  final void Function(int) onItemSelected;
  final VoidCallback onSyncTap;
  final VoidCallback onTestTap;
  final VoidCallback onLogout;

  const _SidebarContent({
    required this.sections,
    required this.allItems,
    required this.selectedIndex,
    required this.user,
    required this.syncAsync,
    required this.connectionAsync,
    required this.onItemSelected,
    required this.onSyncTap,
    required this.onTestTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navyColor,
      child: Column(
        children: [
          // Status bar padding (mobile safe area)
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Brand
          _SidebarBrand(),

          // User
          _SidebarUser(user: user),

          // Menu
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _buildMenuSections(),
              ),
            ),
          ),

          // Bottom
          _SidebarBottom(
            syncAsync: syncAsync,
            connectionAsync: connectionAsync,
            onSyncTap: onSyncTap,
            onTestTap: onTestTap,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSections() {
    final widgets = <Widget>[];
    int globalIndex = 0;

    for (final section in sections) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Text(
            section.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A9BC0),
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
      for (final item in section.items) {
        final idx = globalIndex;
        widgets.add(_SidebarItem(
          item: item,
          isActive: selectedIndex == idx,
          onTap: () => onItemSelected(idx),
        ));
        globalIndex++;
      }
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────
// Brand
// ─────────────────────────────────────────────────────────────────
class _SidebarBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.navyBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEE POS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'POINT OF SALE SYSTEM',
                style: TextStyle(
                  color: Color(0xFF8A9BC0),
                  fontSize: 8,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// User
// ─────────────────────────────────────────────────────────────────
class _SidebarUser extends StatelessWidget {
  final dynamic user;
  const _SidebarUser({required this.user});

  @override
  Widget build(BuildContext context) {
    final name    = user?.fullName ?? '';
    final initial = name.isNotEmpty ? name[0] : '?';
    final email   = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.navyBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          color: Color(0xFF8A9BC0), fontSize: 10),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Item
// ─────────────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final _MenuItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF8A9BC0),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      isActive ? Colors.white : const Color(0xFF8A9BC0),
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Bottom actions
// ─────────────────────────────────────────────────────────────────
class _SidebarBottom extends StatelessWidget {
  final AsyncValue syncAsync;
  final AsyncValue connectionAsync;
  final VoidCallback onSyncTap;
  final VoidCallback onTestTap;
  final VoidCallback onLogout;

  const _SidebarBottom({
    required this.syncAsync,
    required this.connectionAsync,
    required this.onSyncTap,
    required this.onTestTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final syncValue = syncAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.navyBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
          8, 6, 8, MediaQuery.of(context).padding.bottom + 6),
      child: Column(
        children: [
          connectionAsync.when(
            data: (connection) => _BottomAction(
              icon: connection.isConnected ? Icons.wifi : Icons.wifi_off,
              label: syncValue?.pendingCount != null &&
                      syncValue!.pendingCount > 0
                  ? '${connection.title} • รอส่ง ${syncValue.pendingCount} รายการ'
                  : connection.title,
              iconColor: connection.isConnected
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
              badge: syncValue?.hasPending ?? false,
              onTap: onSyncTap,
            ),
            loading: () => const SizedBox(height: 32),
            error: (_, _) => const SizedBox(height: 32),
          ),
          _BottomAction(
            icon: Icons.science_outlined,
            label: 'ทดสอบระบบ',
            iconColor: const Color(0xFF8A9BC0),
            onTap: onTestTap,
          ),
          _BottomAction(
            icon: Icons.logout,
            label: 'ออกจากระบบ',
            iconColor: AppTheme.errorLight,
            onTap: onLogout,
          ),
          const SizedBox(height: 4),
          const Text(
            'DEE POS v1.0.0',
            style: TextStyle(fontSize: 9, color: Color(0xFF4A5A7A)),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final bool badge;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(icon, size: 16, color: iconColor),
                if (badge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF8A9BC0),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
