import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/app_dialogs.dart';
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
import '../../../restaurant/presentation/pages/table_overview_page.dart';
import '../../../restaurant/presentation/pages/kitchen_display_page.dart';
import '../../../restaurant/presentation/pages/kitchen_analytics_page.dart';
import '../../../restaurant/presentation/pages/reservations_page.dart';
import '../../../restaurant/presentation/pages/takeaway_orders_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../inventory/presentation/pages/stock_adjustment_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../../core/shortcuts/keyboard_shortcuts.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/pages/role_permission_page.dart';
import '../../../users/presentation/pages/user_list_page.dart';
import '../../../../shared/permissions/app_permissions.dart';
import '../../../../shared/widgets/license_notice_banner.dart';
import '../../../../core/services/license/license_service.dart';
import '../../../../core/config/app_config.dart';

// ─────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String title;
  final Widget page;
  final String? badgeId;

  /// permission key — null หมายถึงแสดงเสมอ (เช่น Dashboard สำหรับ Admin)
  final String? permissionKey;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.page,
    this.permissionKey,
    this.badgeId,
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
  bool _sidebarCollapsed = false; // สำหรับหน้าจอใหญ่ (>= 1280px)
  bool _compactExpanded = false; // สำหรับหน้าจอ compact (< 1280px) user กดขยาย
  /// หน้า override สำหรับกรณีที่ต้องการแสดงหน้าพร้อม parameter พิเศษ
  /// (เช่น SalesHistoryPage กรองวันนี้) โดยยัง highlight เมนูที่ถูกต้อง
  Widget? _overridePage;

  List<_MenuSection> get _sections {
    final selectedBranch = ref.read(selectedBranchProvider);
    final showRestaurantSection = selectedBranch?.isRestaurantMode ?? true;
    final showRetailSection = selectedBranch?.isRetailMode ?? true;

    return [
      _MenuSection('หลัก', [
        _MenuItem(
          icon: Icons.dashboard,
          title: 'แดชบอร์ด',
          permissionKey: AppPermission.dashboard,
          page: _buildDashboardPage(),
        ),
      ]),
      if (showRestaurantSection)
        _MenuSection('ร้านอาหาร', [
          _MenuItem(
            icon: Icons.table_restaurant,
            title: 'โต๊ะอาหาร',
            page: const TableOverviewPage(),
            permissionKey: AppPermission.pos,
          ),
          _MenuItem(
            icon: Icons.kitchen,
            title: 'หน้าจอครัว (KDS)',
            page: const KitchenDisplayPage(),
            permissionKey: AppPermission.pos,
          ),
          _MenuItem(
            icon: Icons.event_note,
            title: 'การจองโต๊ะ',
            page: const ReservationsPage(),
            permissionKey: AppPermission.pos,
          ),
          _MenuItem(
            icon: Icons.receipt_long,
            title: 'บิลกลับบ้านค้าง',
            page: const TakeawayOrdersPage(),
            permissionKey: AppPermission.pos,
            badgeId: 'takeaway_pending',
          ),
          _MenuItem(
            icon: Icons.analytics,
            title: 'Kitchen Analytics',
            page: const KitchenAnalyticsPage(),
            permissionKey: AppPermission.pos,
          ),
        ]),
      _MenuSection('การขาย', [
        if (showRetailSection)
          _MenuItem(
            icon: Icons.shopping_cart,
            title: 'หน้าขาย (POS)',
            page: const PosPage(),
            permissionKey: AppPermission.pos,
          ),
        _MenuItem(
          icon: Icons.receipt_long,
          title: 'รายการขาย',
          page: const SalesHistoryPage(),
          permissionKey: AppPermission.salesHistory,
        ),
        _MenuItem(
          icon: Icons.local_offer,
          title: 'โปรโมชั่น',
          page: const PromotionListPage(),
          permissionKey: AppPermission.promotions,
        ),
      ]),
      _MenuSection('คลังสินค้า', [
        _MenuItem(
          icon: Icons.inventory,
          title: 'สินค้า',
          page: const ProductListPage(),
          permissionKey: AppPermission.products,
        ),
        _MenuItem(
          icon: Icons.warehouse,
          title: 'สต๊อกสินค้า',
          page: const StockBalancePage(),
          permissionKey: AppPermission.stock,
        ),
        _MenuItem(
          icon: Icons.tune,
          title: 'ปรับสต๊อก',
          page: const StockAdjustmentPage(),
          permissionKey: AppPermission.stockAdjust,
        ),
      ]),
      _MenuSection('ผู้ติดต่อ', [
        _MenuItem(
          icon: Icons.people,
          title: 'ลูกค้า',
          page: const CustomerListPage(),
          permissionKey: AppPermission.customers,
        ),
        _MenuItem(
          icon: Icons.business,
          title: 'ซัพพลายเออร์',
          page: const SupplierListPage(),
          permissionKey: AppPermission.suppliers,
        ),
      ]),
      _MenuSection('จัดซื้อ', [
        _MenuItem(
          icon: Icons.shopping_bag,
          title: 'ซื้อสินค้า',
          page: const PurchaseOrderListPage(),
          permissionKey: AppPermission.purchaseOrder,
        ),
        _MenuItem(
          icon: Icons.inventory_2,
          title: 'รับสินค้า',
          page: const GoodsReceiptListPage(),
          permissionKey: AppPermission.goodsReceipt,
        ),
        _MenuItem(
          icon: Icons.assignment_return,
          title: 'คืนสินค้า',
          page: const PurchaseReturnListPage(),
          permissionKey: AppPermission.purchaseReturn,
        ),
      ]),
      _MenuSection('บัญชี', [
        _MenuItem(
          icon: Icons.receipt,
          title: 'ใบแจ้งหนี้ AP(ซัพฯ)',
          page: const ApInvoiceListPage(),
          permissionKey: AppPermission.apInvoice,
        ),
        _MenuItem(
          icon: Icons.payments,
          title: 'จ่ายเงิน AP',
          page: const ApPaymentListPage(),
          permissionKey: AppPermission.apPayment,
        ),
        _MenuItem(
          icon: Icons.request_page,
          title: 'ใบแจ้งหนี้ AR(ลูกค้า)',
          page: const ArInvoiceListPage(),
          permissionKey: AppPermission.arInvoice,
        ),
        _MenuItem(
          icon: Icons.price_check,
          title: 'รับเงิน AR',
          page: const ArReceiptListPage(),
          permissionKey: AppPermission.arReceipt,
        ),
      ]),
      _MenuSection('ระบบ', [
        _MenuItem(
          icon: Icons.assessment,
          title: 'รายงาน',
          page: const ReportsPage(),
          permissionKey: AppPermission.reports,
        ),
        _MenuItem(
          icon: Icons.store,
          title: 'จัดการสาขา',
          page: const BranchListPage(),
          permissionKey: AppPermission.branch,
        ),
        _MenuItem(
          icon: Icons.sync_alt,
          title: 'การเชื่อมต่อ/ซิงก์',
          page: const SyncStatusPage(),
          permissionKey: AppPermission.sync,
        ),
        _MenuItem(
          icon: Icons.settings,
          title: 'ตั้งค่า',
          page: const SettingsPage(),
          permissionKey: AppPermission.settings,
        ),
        _MenuItem(
          icon: Icons.admin_panel_settings,
          title: 'จัดการสิทธิ์',
          page: const RolePermissionPage(),
          permissionKey: AppPermission.rolePermissions,
        ),
        _MenuItem(
          icon: Icons.manage_accounts,
          title: 'จัดการผู้ใช้งาน',
          page: const UserListPage(),
          permissionKey: AppPermission.userManagement,
        ),
      ]),
    ];
  }

  List<_MenuItem> get _allItems => _sections.expand((s) => s.items).toList();

  Widget get _currentPage => _overridePage ?? _allItems[_selectedIndex].page;

  DashboardPage _buildDashboardPage() {
    return DashboardPage(
      showBackButton: false,
      onGoToPos: _openPointOfSaleShortcut,
      onGoToSalesHistory: () =>
          _showOverridePageByTitle(const SalesHistoryPage(), 'รายการขาย'),
      onGoToProducts: () => _openShortcutByTitle(
        title: 'สินค้า',
        fallbackPage: const ProductListPage(),
      ),
      onGoToCustomers: () => _openShortcutByTitle(
        title: 'ลูกค้า',
        fallbackPage: const CustomerListPage(),
      ),
      onGoToTodaySales: () {
        final today = DateTime.now();
        _showOverridePageByTitle(
          SalesHistoryPage(
            initialDateFrom: DateTime(today.year, today.month, today.day),
            initialDateTo: DateTime(today.year, today.month, today.day),
          ),
          'รายการขาย',
        );
      },
      onGoToMonthSales: () {
        final today = DateTime.now();
        _showOverridePageByTitle(
          SalesHistoryPage(
            initialDateFrom: DateTime(today.year, today.month, 1),
            initialDateTo: DateTime(today.year, today.month, today.day),
          ),
          'รายการขาย',
        );
      },
    );
  }

  int? _findMenuIndexByTitle(String title) {
    final items = _allItems;
    for (var i = 0; i < items.length; i++) {
      if (items[i].title == title) return i;
    }
    return null;
  }

  void _openShortcutByTitle({
    required String title,
    required Widget fallbackPage,
  }) {
    final index = _findMenuIndexByTitle(title);
    if (context.hasPermanentSidebar && index != null) {
      _selectItem(index);
    } else {
      _push(context, fallbackPage);
    }
  }

  void _openFirstShortcutByTitle({
    required List<String> titles,
    required List<Widget> fallbackPages,
  }) {
    for (var i = 0; i < titles.length; i++) {
      final index = _findMenuIndexByTitle(titles[i]);
      if (index != null) {
        if (context.hasPermanentSidebar) {
          _selectItem(index);
        } else {
          _push(context, fallbackPages[i]);
        }
        return;
      }
    }
    _push(context, fallbackPages.first);
  }

  void _selectItem(int i) {
    // ปิด Drawer ก่อนเสมอ (tablet/mobile)
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();

    setState(() {
      _selectedIndex = i;
      _overridePage = null;
    });
  }

  /// แสดงหน้าพิเศษ (พร้อม parameter เฉพาะ) ใน content area โดย highlight เมนูจากชื่อ
  /// บน desktop (hasPermanentSidebar) → swap ใน content area (มี sidebar)
  /// บน mobile/tablet → push route ตามปกติ
  void _showOverridePageByTitle(Widget page, String highlightTitle) {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    final highlightIndex = _findMenuIndexByTitle(highlightTitle);
    if (context.hasPermanentSidebar) {
      setState(() {
        if (highlightIndex != null) _selectedIndex = highlightIndex;
        _overridePage = page;
      });
    } else {
      _push(context, page);
    }
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _openPointOfSaleShortcut() {
    _openFirstShortcutByTitle(
      titles: const ['หน้าขาย (POS)', 'โต๊ะอาหาร'],
      fallbackPages: const [PosPage(), TableOverviewPage()],
    );
  }

  Future<void> _handleAbout(BuildContext context) async {
    final licenseStatus = ref.read(licenseServiceProvider).asData?.value;
    final deviceId = licenseStatus?.deviceId ?? '-';

    String firstLaunch = '-';
    if (licenseStatus != null) {
      final days = licenseStatus.daysSinceFirstLaunch;
      final d = DateTime.now().subtract(Duration(days: days));
      firstLaunch =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo-deepos.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.point_of_sale, size: 36),
            ),
            const SizedBox(width: 12),
            const Text('เกี่ยวกับโปรแกรม'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AboutRow('ชื่อโปรแกรม', AppConfig.appName),
              _AboutRow(
                'เวอร์ชัน',
                '${AppConfig.appVersion} (build ${AppConfig.buildNumber})',
              ),
              const Divider(height: 20),
              _AboutRow('วันเปิดใช้งานครั้งแรก', firstLaunch),
              _AboutRow(
                'สถานะ License',
                licenseStatus == null
                    ? 'กำลังโหลด...'
                    : licenseStatus.isLicensed
                    ? '✅ ลงทะเบียนแล้ว'
                    : licenseStatus.isTrialActive
                    ? '⏳ ทดลองใช้ (${licenseStatus.trialPhaseLabel})'
                    : '❌ ทดลองใช้หมดอายุ',
              ),
              _AboutRow('Device ID', deviceId, mono: true),
              const Divider(height: 20),
              _AboutRow('เว็บไซต์', 'https://www.dee-pos.com'),
              const SizedBox(height: 4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('ปิด'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.of(context).pushNamed('/license');
            },
            child: const Text('ลงทะเบียน'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ออกจากระบบ',
          icon: Icons.logout_rounded,
          iconColor: Colors.orange,
        ),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
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
    ref.watch(takeawayPollingProvider(null));
    final user = ref.watch(authProvider).user;
    final syncAsync = ref.watch(syncStatusProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final takeawayPendingCount = ref.watch(takeawayOpenOrdersCountProvider);
    final roleId = user?.roleId?.toUpperCase();
    // watch provider (ไม่ใช่ notifier) เพื่อ rebuild เมื่อ async data โหลดเสร็จ
    final permData = ref.watch(rolePermissionsProvider).value;

    // คำนวณ indices ที่ user มีสิทธิ์เห็น
    final visibleIndices = <int>{};
    int idx = 0;
    for (final section in _sections) {
      for (final item in section.items) {
        final key = item.permissionKey;
        final canSee =
            key == null ||
            roleId == null ||
            roleId == 'ADMIN' ||
            (permData?[roleId] ?? defaultRolePermissions[roleId] ?? [])
                .contains(key);
        if (canSee) visibleIndices.add(idx);
        idx++;
      }
    }

    // large (>=1280px): ตาม _sidebarCollapsed
    // compact (<1280px): collapsed เสมอ ยกเว้น user กดขยายไว้
    final effectiveCollapsed = context.isLarge
        ? _sidebarCollapsed
        : !_compactExpanded;

    // ── Sidebar Widget ─────────────────────────────────────────
    Widget sidebarWidget = _SidebarContent(
      sections: _sections,
      allItems: _allItems,
      selectedIndex: _selectedIndex,
      visibleIndices: visibleIndices,
      menuBadges: {'takeaway_pending': takeawayPendingCount},
      user: user,
      syncAsync: syncAsync,
      connectionAsync: connectionAsync,
      isCollapsed: effectiveCollapsed,
      onItemSelected: _selectItem,
      onSyncTap: () => _push(context, const SyncStatusPage()),
      onTestTap: () => _push(context, const TestPage()),
      onAboutTap: () => _handleAbout(context),
      onLogout: () => _handleLogout(context),
      onToggleCollapse: () => setState(() {
        if (context.isLarge) {
          _sidebarCollapsed = !_sidebarCollapsed;
        } else {
          _compactExpanded = !_compactExpanded;
        }
      }),
    );

    return KeyboardShortcuts(
      onPosShortcut: _openPointOfSaleShortcut,
      onProductShortcut: () => _openShortcutByTitle(
        title: 'สินค้า',
        fallbackPage: const ProductListPage(),
      ),
      onCustomerShortcut: () => _openShortcutByTitle(
        title: 'ลูกค้า',
        fallbackPage: const CustomerListPage(),
      ),
      onSalesHistoryShortcut: () => _openShortcutByTitle(
        title: 'รายการขาย',
        fallbackPage: const SalesHistoryPage(),
      ),
      onDashboardShortcut: () => _openShortcutByTitle(
        title: 'แดชบอร์ด',
        fallbackPage: _buildDashboardPage(),
      ),
      onInventoryShortcut: () => _openShortcutByTitle(
        title: 'สต๊อกสินค้า',
        fallbackPage: const StockBalancePage(),
      ),
      onReportsShortcut: () => _openShortcutByTitle(
        title: 'รายงาน',
        fallbackPage: const ReportsPage(),
      ),
      child: context.hasPermanentSidebar
          // ── Desktop/Wide: Permanent sidebar ────────────────
          ? Scaffold(
              body: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: effectiveCollapsed ? 56 : context.sidebarWidth,
                    clipBehavior: Clip.none,
                    decoration: const BoxDecoration(),
                    child: sidebarWidget,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: LicenseNoticeBanner(child: _currentPage)),
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
              body: LicenseNoticeBanner(child: _currentPage),
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
    final takeawayPendingCount = ref.watch(takeawayOpenOrdersCountProvider);

    return AppBar(
      // Hamburger menu icon สำหรับเปิด Drawer
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'บิลกลับบ้านค้าง',
          onPressed: () => _push(context, const TakeawayOrdersPage()),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.receipt_long),
              if (takeawayPendingCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      takeawayPendingCount > 99
                          ? '99+'
                          : '$takeawayPendingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Sync badge
        connectionAsync.when(
          data: (connection) => IconButton(
            icon: Stack(
              children: [
                Icon(
                  connection.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: connection.isConnected
                      ? Colors.white70
                      : AppTheme.errorLight,
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
        if ((user?.fullName ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: context.isMobile ? 96 : 160,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: context.isMobile ? 8 : 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.isMobile ? 11 : 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
  final Set<int> visibleIndices;
  final Map<String, int> menuBadges;
  final dynamic user;
  final AsyncValue syncAsync;
  final AsyncValue connectionAsync;
  final bool isCollapsed;
  final void Function(int) onItemSelected;
  final VoidCallback onSyncTap;
  final VoidCallback onTestTap;
  final VoidCallback onAboutTap;
  final VoidCallback onLogout;
  final VoidCallback? onToggleCollapse;

  const _SidebarContent({
    required this.sections,
    required this.allItems,
    required this.selectedIndex,
    required this.visibleIndices,
    required this.menuBadges,
    required this.user,
    required this.syncAsync,
    required this.connectionAsync,
    required this.onItemSelected,
    required this.onSyncTap,
    required this.onTestTap,
    required this.onAboutTap,
    required this.onLogout,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navyColor,
      child: Column(
        children: [
          // Status bar padding (mobile safe area)
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Brand + collapse button
          _SidebarBrand(
            isCollapsed: isCollapsed,
            onToggleCollapse: onToggleCollapse,
          ),

          // User (ซ่อนเมื่อย่อ)
          if (!isCollapsed) _SidebarUser(user: user),

          // Menu
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: _buildMenuSections()),
            ),
          ),

          // Bottom
          _SidebarBottom(
            syncAsync: syncAsync,
            connectionAsync: connectionAsync,
            isCollapsed: isCollapsed,
            showTestTools: AppConfig.showTestingTools,
            onSyncTap: onSyncTap,
            onTestTap: onTestTap,
            onAboutTap: onAboutTap,
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
      final sectionStartIndex = globalIndex;
      final sectionVisibleIndices = <int>[];
      for (int i = 0; i < section.items.length; i++) {
        if (visibleIndices.contains(sectionStartIndex + i)) {
          sectionVisibleIndices.add(sectionStartIndex + i);
        }
      }

      if (sectionVisibleIndices.isEmpty) {
        globalIndex += section.items.length;
        continue;
      }

      // Section label (ซ่อนเมื่อย่อ)
      if (!isCollapsed) {
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
      } else {
        widgets.add(const SizedBox(height: 8));
      }

      for (final item in section.items) {
        final idx = globalIndex;
        if (visibleIndices.contains(idx)) {
          widgets.add(
            _SidebarItem(
              item: item,
              badgeCount: menuBadges[item.badgeId] ?? 0,
              isActive: selectedIndex == idx,
              isCollapsed: isCollapsed,
              onTap: () => onItemSelected(idx),
            ),
          );
        }
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
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const _SidebarBrand({this.isCollapsed = false, this.onToggleCollapse});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCollapsedLayout = isCollapsed || constraints.maxWidth < 140;

        if (useCollapsedLayout) {
          return Container(
            height: 68,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.navyBorder)),
            ),
            child: Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Container(
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
                    ),
                    if (onToggleCollapse != null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onToggleCollapse,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A3F6F),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.navyBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isCollapsed
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                                size: 12,
                                color: const Color(0xFF8A9BC0),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 8, 14),
          clipBehavior: Clip.hardEdge,
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
              const Expanded(
                child: Column(
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onToggleCollapse != null)
                IconButton(
                  onPressed: onToggleCollapse,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF8A9BC0),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        );
      },
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
    final name = user?.fullName ?? '';
    final initial = name.isNotEmpty ? name[0] : '?';
    final email = user?.email ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 120;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 14,
            vertical: 10,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.navyBorder)),
          ),
          child: compact
              ? Center(
                  child: Container(
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
                )
              : Row(
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
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(
                                color: Color(0xFF8A9BC0),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Item
// ─────────────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final _MenuItem item;
  final int badgeCount;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.badgeCount,
    required this.isActive,
    required this.onTap,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? Colors.white : const Color(0xFF8A9BC0);
    final child = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ตัดสินใจตามความกว้างจริง ณ ขณะนั้น (รวม animation)
          final wide = constraints.maxWidth > 100;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 10 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: wide
                  ? Border(
                      left: BorderSide(
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: wide
                ? Row(
                    children: [
                      Icon(item.icon, size: 16, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: iconColor,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeCount > 0)
                        _SidebarBadge(count: badgeCount, isActive: isActive),
                    ],
                  )
                : Center(child: Icon(item.icon, size: 18, color: iconColor)),
          );
        },
      ),
    );

    if (isCollapsed) {
      return _CollapsedSidebarHint(
        label: item.title,
        child: InkWell(onTap: onTap, child: child),
      );
    }
    return InkWell(onTap: onTap, child: child);
  }
}

class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({required this.count, required this.isActive});

  final int count;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: isActive ? AppTheme.primaryColor : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CollapsedSidebarHint extends StatefulWidget {
  final String label;
  final Widget child;

  const _CollapsedSidebarHint({required this.label, required this.child});

  @override
  State<_CollapsedSidebarHint> createState() => _CollapsedSidebarHintState();
}

class _CollapsedSidebarHintState extends State<_CollapsedSidebarHint> {
  bool _showHint = false;

  void _setHint(bool value) {
    if (!mounted || _showHint == value) return;
    setState(() => _showHint = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      tooltip: widget.label,
      child: MouseRegion(
        onEnter: (_) => _setHint(true),
        onExit: (_) => _setHint(false),
        child: FocusableActionDetector(
          onShowFocusHighlight: _setHint,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: (_) => _setHint(true),
            onLongPressEnd: (_) => _setHint(false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.child,
                Positioned(
                  left: 46,
                  top: 6,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _showHint ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 120),
                        offset: _showHint
                            ? Offset.zero
                            : const Offset(-0.08, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13213F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.navyBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  final bool isCollapsed;
  final bool showTestTools;
  final VoidCallback onSyncTap;
  final VoidCallback onTestTap;
  final VoidCallback onAboutTap;
  final VoidCallback onLogout;

  const _SidebarBottom({
    required this.syncAsync,
    required this.connectionAsync,
    required this.showTestTools,
    required this.onSyncTap,
    required this.onTestTap,
    required this.onAboutTap,
    required this.onLogout,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final syncValue = syncAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    if (isCollapsed) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.navyBorder)),
        ),
        padding: EdgeInsets.fromLTRB(
          6,
          6,
          6,
          MediaQuery.of(context).padding.bottom + 6,
        ),
        child: Column(
          children: [
            connectionAsync.when(
              data: (connection) => _CollapsedSidebarHint(
                label: connection.title,
                child: IconButton(
                  icon: Stack(
                    children: [
                      Icon(
                        connection.isConnected ? Icons.wifi : Icons.wifi_off,
                        size: 18,
                        color: connection.isConnected
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                      if (syncValue?.hasPending ?? false)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: onSyncTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
              loading: () => const SizedBox(height: 36),
              error: (_, _) => const SizedBox(height: 36),
            ),
            if (showTestTools)
              _CollapsedSidebarHint(
                label: 'ทดสอบระบบ',
                child: IconButton(
                  icon: const Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: Color(0xFF8A9BC0),
                  ),
                  onPressed: onTestTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            _CollapsedSidebarHint(
              label: 'เกี่ยวกับโปรแกรม',
              child: IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF8A9BC0),
                ),
                onPressed: onAboutTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
            _CollapsedSidebarHint(
              label: 'ออกจากระบบ',
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  size: 18,
                  color: AppTheme.errorLight,
                ),
                onPressed: onLogout,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.navyBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        MediaQuery.of(context).padding.bottom + 6,
      ),
      child: Column(
        children: [
          connectionAsync.when(
            data: (connection) => _BottomAction(
              icon: connection.isConnected ? Icons.wifi : Icons.wifi_off,
              label:
                  syncValue?.pendingCount != null && syncValue!.pendingCount > 0
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
          if (showTestTools)
            _BottomAction(
              icon: Icons.science_outlined,
              label: 'ทดสอบระบบ',
              iconColor: const Color(0xFF8A9BC0),
              onTap: onTestTap,
            ),
          _BottomAction(
            icon: Icons.info_outline,
            label: 'เกี่ยวกับโปรแกรม',
            iconColor: const Color(0xFF8A9BC0),
            onTap: onAboutTap,
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

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _AboutRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
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
      child: ClipRect(
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
      ),
    );
  }
}
