import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../branches/presentation/pages/sync_status_page.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/data/models/product_model.dart'; // ✅ สำหรับ bottom sheet
import '../../../customers/data/models/customer_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/hold_orders_dialog.dart';
import 'mobile_order_page.dart';
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ Phase 5
import '../../../../shared/widgets/barcode_listener.dart'; // ✅ USB Scanner
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart'; // ✅ Responsive
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/cart_toast.dart';
import '../../../promotions/data/models/promotion_model.dart';
import '../../../promotions/presentation/providers/promotion_provider.dart';

class PosPage extends ConsumerStatefulWidget {
  /// isCashierMode = true  → Cashier login โดยตรง
  ///   - leading = Logout (ไม่มี back button)
  ///   - PopScope ปิด back gesture
  /// isCashierMode = false → เข้าจาก HomePage ปกติ
  final bool isCashierMode;

  const PosPage({super.key, this.isCashierMode = false});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PromotionModel> _buyXGetYPromos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPromos());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPromos() async {
    final promos = await ref.read(activePromotionsProvider.future);
    if (!mounted) return;
    setState(() {
      _buyXGetYPromos = promos
          .where((p) => p.promotionType == 'BUY_X_GET_Y')
          .toList();
    });
    _syncFreeItems();
  }

  void _syncFreeItems() {
    if (_buyXGetYPromos.isEmpty) {
      ref.read(cartProvider.notifier).syncFreeItems([], []);
      return;
    }
    final products = ref.read(productListProvider).value ?? [];
    ref.read(cartProvider.notifier).syncFreeItems(_buyXGetYPromos, products);
  }

  // ── Logout (Cashier Mode) ────────────────────────────────────
  Future<void> _handleLogout() async {
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
    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  Future<void> _openConnectionSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncStatusPage()),
    );
  }

  Future<void> _holdCurrentOrder() async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _HoldOrderNameDialog(),
    );
    if (result == null || result.isEmpty) return;

    ref.read(cartProvider.notifier).hold(result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'พักบิล: $result',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showDesktopScanError(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('ไม่พบสินค้า: $value'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
          width: 320,
        ),
      );
  }

  void _showDesktopScanSuccess(String productName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เพิ่ม $productName แล้ว'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
        width: 300,
      ),
    );
  }

  bool _tryAddProductFromScan(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final products = ref.read(productListProvider).value ?? const <ProductModel>[];
    ProductModel? matchedProduct;
    for (final product in products) {
      if ((product.barcode?.trim().toLowerCase() == normalized) ||
          product.productCode.trim().toLowerCase() == normalized) {
        matchedProduct = product;
        break;
      }
    }

    if (matchedProduct == null) {
      _showDesktopScanError(rawValue);
      return false;
    }

    final priceLevel = ref.read(cartProvider).customerPriceLevel;
    final lookup = getPriceByLevel(matchedProduct, priceLevel);
    if (lookup.isFallback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠ ราคา Lv.${lookup.requestedLevel} ยังไม่ได้ตั้งค่า — ใช้ราคาปกติ ฿${lookup.price.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
    }

    ref.read(cartProvider.notifier).addItem(
          productId: matchedProduct.productId,
          productCode: matchedProduct.productCode,
          productName: matchedProduct.productName,
          unit: matchedProduct.baseUnit,
          unitPrice: lookup.price,
          groupId: matchedProduct.groupId,
          priceLevel1: matchedProduct.priceLevel1,
          priceLevel2: matchedProduct.priceLevel2,
          priceLevel3: matchedProduct.priceLevel3,
          priceLevel4: matchedProduct.priceLevel4,
          priceLevel5: matchedProduct.priceLevel5,
        );

    _searchController.clear();
    if (mounted) {
      setState(() => _searchQuery = '');
    }
    if (!lookup.isFallback) {
      _showDesktopScanSuccess(matchedProduct.productName);
    }
    return true;
  }

  // ── Filter products ───────────────────────────────────────────
  List<ProductModel> _filterProducts(List<ProductModel> src) {
    if (_searchQuery.isEmpty) return src;
    final q = _searchQuery.toLowerCase();
    return src
        .where(
          (p) =>
              p.productName.toLowerCase().contains(q) ||
              p.productCode.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // ฟัง cart changes → คำนวณของแถมใหม่เมื่อ regular items เปลี่ยน
    ref.listen<CartState>(cartProvider, (prev, next) {
      if (prev?.items != next.items) _syncFreeItems();
    });

    // ฟัง activePromotionsProvider → sync ทันทีเมื่อโปรโมชั่นถูก pause/resume
    ref.listen<AsyncValue<List<PromotionModel>>>(activePromotionsProvider, (
      prev,
      next,
    ) {
      next.whenData((promos) {
        if (!mounted) return;
        setState(() {
          _buyXGetYPromos = promos
              .where((p) => p.promotionType == 'BUY_X_GET_Y')
              .toList();
        });
        _syncFreeItems();
      });
    });

    final productAsync = ref.watch(productListProvider);
    final cartState = ref.watch(cartProvider);
    final holdOrdersState = ref.watch(holdOrdersProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final user = widget.isCashierMode ? ref.watch(authProvider).user : null;

    final hasCustomer =
        cartState.customerId != null && cartState.customerId != 'WALK_IN';

    // ── Responsive ───────────────────────────────────────────────
    final isMobile = context.isMobile;

    if (isMobile) {
      return const MobileOrderPage();
    }

    return PopScope(
      canPop: !widget.isCashierMode,
      // ✅ BarcodeListener ครอบทั้งหน้า
      child: BarcodeListener(
        onBarcodeScanned: (barcode) {
          if (_tryAddProductFromScan(barcode)) return;
          _searchController.text = barcode;
          setState(() => _searchQuery = barcode);
        },
        child: Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            // ── Leading ────────────────────────────────────
            automaticallyImplyLeading: !widget.isCashierMode,
            leading: widget.isCashierMode
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'ออกจากระบบ',
                    onPressed: _handleLogout,
                  )
                : null,

            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cashier badge
                if (widget.isCashierMode && user != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Text('จุดขาย'),
              ],
            ),

            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_outlined),
                    tooltip: 'บิลที่พัก',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const HoldOrdersDialog(),
                    ),
                  ),
                  if (holdOrdersState.orders.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${holdOrdersState.orders.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _CustomerChip(
                      cartState: cartState,
                      hasCustomer: hasCustomer,
                    ),
                    if (selectedBranch != null && selectedWarehouse != null)
                      InkWell(
                        onTap: _openConnectionSettings,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.border.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                selectedBranch.branchName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: _openConnectionSettings,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'ตั้งค่าสาขา',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (cartState.itemCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${cartState.itemCount} รายการ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────
          // Desktop/Tablet (>=768px): grid + cart split
          // Mobile (<768px): cart only
          body: Stack(
            children: [
              _buildDesktopBody(productAsync, cartState),
              const CartToastOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  // TABLET / DESKTOP BODY (>=768px): Grid(60%) + Cart(40%)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopBody(
    AsyncValue<List<ProductModel>> productAsync,
    CartState cartState,
  ) {
    return Column(
      children: [
        _buildSearchToolbar(cartState),

        // ── Main Content: Grid(60%) + Cart(40%) ───────────────
        Expanded(
          child: Row(
            children: [
              // Product Grid (60%)
              Expanded(
                flex: 60,
                child: productAsync.when(
                  data: (products) {
                    final filtered = _filterProducts(products);
                    if (filtered.isEmpty) return _buildEmptyProducts();
                    return ProductGrid(products: filtered);
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('กำลังโหลดสินค้า...'),
                      ],
                    ),
                  ),
                  error: (e, _) => _buildProductError(e),
                ),
              ),

              // Divider
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.border,
              ),

              // Cart Panel (40%)
              Expanded(
                flex: 40,
                child: CartPanel(
                  showHoldButton: true,
                  onHold: cartState.items.isEmpty ? null : _holdCurrentOrder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchToolbar(CartState cartState, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkTopBar
            : Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldStack = compact || constraints.maxWidth < 760;
          final searchField = SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า / บาร์โค้ด...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : ScannerButton(
                        tooltip: 'สแกนบาร์โค้ดสินค้า',
                        useSheet: true,
                        onScanned: (value) {
                          if (_tryAddProductFromScan(value)) return;
                          _searchController.text = value;
                          setState(() => _searchQuery = value);
                        },
                      ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
              onSubmitted: (value) {
                if (_tryAddProductFromScan(value)) return;
                if (mounted) {
                  setState(() => _searchQuery = value);
                }
                if (_filterProducts(
                  ref.read(productListProvider).value ?? const <ProductModel>[],
                ).isEmpty) {
                  _showDesktopScanError(value);
                }
              },
            ),
          );

          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [searchField],
            );
          }

          return Row(children: [Expanded(child: searchField)]);
        },
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmptyProducts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'ไม่มีสินค้า'
                : 'ไม่พบสินค้า "$_searchQuery"',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'กรุณาเพิ่มสินค้าในระบบก่อน'
                : 'ลองค้นหาด้วยคำอื่น',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSub),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(productListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('รีเฟรช'),
          ),
        ],
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────
  Widget _buildProductError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 12),
          Text('เกิดข้อผิดพลาด: $e'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => ref.read(productListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _CustomerChip extends ConsumerWidget {
  final CartState cartState;
  final bool hasCustomer;

  const _CustomerChip({
    required this.cartState,
    required this.hasCustomer,
  });

  Future<void> _selectCustomer(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<CustomerModel?>(
      context: context,
      builder: (_) => const CustomerSelectorDialog(),
    );
    if (result == null) return;

    final notifier = ref.read(cartProvider.notifier);
    final newLevel = result.priceLevel;

    if (notifier.hasItemsWithDifferentLevel(newLevel)) {
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AppDialog(
          title: buildAppDialogTitle(
            context,
            title: 'อัพเดทราคาสินค้า?',
            icon: Icons.sell_outlined,
            iconColor: AppTheme.warning,
          ),
          content: Text(
            'ลูกค้า "${result.customerName}" ใช้ระดับราคา Level $newLevel '
            'ต้องการคำนวณราคาสินค้าในตะกร้าใหม่ด้วยไหม?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('คงราคาเดิม'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.price_change, size: 16),
              label: const Text('อัพเดทราคา'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      notifier.setCustomer(
        result.customerId,
        result.customerName,
        priceLevel: newLevel,
      );
      if (confirm == true) notifier.repriceItems();
      return;
    }

    notifier.setCustomer(
      result.customerId,
      result.customerName,
      priceLevel: newLevel,
    );
  }

  Future<void> _clearCustomer(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cartProvider.notifier);
    if (notifier.hasItemsWithDifferentLevel(1)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AppDialog(
          title: buildAppDialogTitle(
            context,
            title: 'อัพเดทราคาสินค้า?',
            icon: Icons.sell_outlined,
            iconColor: AppTheme.warning,
          ),
          content: const Text(
            'เปลี่ยนเป็นลูกค้าทั่วไป (Level 1) '
            'ต้องการคำนวณราคาสินค้าในตะกร้าใหม่ด้วยไหม?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('คงราคาเดิม'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.price_change, size: 16),
              label: const Text('อัพเดทราคา'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      notifier.setCustomer(
        'WALK_IN',
        'ลูกค้าทั่วไป',
        priceLevel: 1,
      );
      if (confirm == true) notifier.repriceItems();
      return;
    }

    notifier.setCustomer(
      'WALK_IN',
      'ลูกค้าทั่วไป',
      priceLevel: 1,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCustomer(context, ref),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasCustomer
                ? AppTheme.infoContainer
                : const Color(0xFF1F2E54),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasCustomer
                  ? AppTheme.info.withValues(alpha: 0.5)
                  : AppTheme.navy,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person,
                size: 14,
                color: hasCustomer ? AppTheme.info : Colors.white60,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  cartState.customerName ?? 'ลูกค้าทั่วไป',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasCustomer ? AppTheme.info : Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasCustomer) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _clearCustomer(context, ref),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: AppTheme.info,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────
// Hold Order Name Dialog — รักษา logic เดิม
// ─────────────────────────────────────────────────────────────────
class _HoldOrderNameDialog extends StatefulWidget {
  @override
  State<_HoldOrderNameDialog> createState() => _HoldOrderNameDialogState();
}

class _HoldOrderNameDialogState extends State<_HoldOrderNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultName =
        'บิล ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _controller = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: buildAppDialogTitle(
        context,
        title: 'พักบิล',
        icon: Icons.pause_circle_outline_rounded,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'ชื่อบิล',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
