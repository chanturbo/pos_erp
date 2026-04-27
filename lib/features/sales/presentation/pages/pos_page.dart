import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateController;
import '../../../branches/presentation/pages/sync_status_page.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/data/models/product_model.dart'; // ✅ สำหรับ bottom sheet
import '../../../restaurant/data/models/restaurant_order_context.dart';
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
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../providers/sales_provider.dart';

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
  static const _groupPalette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF5D4037),
    Color(0xFFAD1457),
  ];

  static const _groupIconList = <IconData>[
    Icons.local_drink_outlined,
    Icons.fastfood_outlined,
    Icons.icecream_outlined,
    Icons.shopping_basket_outlined,
    Icons.spa_outlined,
    Icons.kitchen_outlined,
    Icons.inventory_2_outlined,
    Icons.sell_outlined,
  ];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  final Map<String?, GlobalKey> _chipKeys = {};
  String _searchQuery = '';
  List<PromotionModel> _buyXGetYPromos = [];
  bool _restoredRestaurantOrder = false;
  String? _selectedGroupId; // restaurant category filter
  late final CartNotifier _cartNotifier;
  late final HoldOrdersNotifier _holdOrdersNotifier;
  late final StateController<RestaurantOrderContext?>
  _restaurantOrderContextNotifier;
  CartState _latestCart = CartState();
  RestaurantOrderContext? _latestRestaurantOrderContext;

  @override
  void initState() {
    super.initState();
    _cartNotifier = ref.read(cartProvider.notifier);
    _holdOrdersNotifier = ref.read(holdOrdersProvider.notifier);
    _restaurantOrderContextNotifier = ref.read(
      restaurantOrderContextProvider.notifier,
    );
    _latestCart = ref.read(cartProvider);
    _latestRestaurantOrderContext = ref.read(restaurantOrderContextProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPromos();
      await _restoreOpenRestaurantOrder();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    // Takeaway back-navigation guard (payment flow clears context first → ctx null → no-op).
    final ctx = _latestRestaurantOrderContext;
    final cart = _latestCart;
    Future<void>(() {
      if (ctx != null && ctx.isTakeaway && cart.items.isNotEmpty) {
        if (cart.hasKitchenSentItems) {
          // Items already sent to kitchen → tracked server-side via salesHistoryProvider.
          // Just clear local cart; do NOT put in hold list (would lose currentOrderId).
          _cartNotifier.clear();
        } else {
          // Nothing sent yet → preserve in local hold list so order reappears on overview.
          final now = DateTime.now();
          final name =
              'ซื้อกลับ ${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}';
          _holdOrdersNotifier.addOrder(
            name,
            cart,
            isTakeaway: true,
            skipKitchen: ctx.skipKitchen,
          );
          _cartNotifier.clear();
        }
      }
      _restaurantOrderContextNotifier.state = null;
    });
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

  Future<void> _restoreOpenRestaurantOrder() async {
    if (_restoredRestaurantOrder) return;
    _restoredRestaurantOrder = true;

    final restaurantContext = ref.read(restaurantOrderContextProvider);
    final currentOrderId = restaurantContext?.currentOrderId;
    final cartState = ref.read(cartProvider);
    if (restaurantContext == null ||
        currentOrderId == null ||
        currentOrderId.isEmpty ||
        cartState.items.isNotEmpty ||
        cartState.freeItems.isNotEmpty) {
      return;
    }

    final order = await ref
        .read(salesHistoryProvider.notifier)
        .getOrderDetails(currentOrderId);
    if (!mounted || order == null || order.items == null) return;

    final regularItems = order.items!
        .where((item) => !item.isFreeItem)
        .map(
          (item) => CartItem(
            productId: item.productId,
            productCode: item.productCode,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            amount: item.amount,
            priceLevel1: item.unitPrice,
            note: item.specialInstructions,
            modifiers: item.modifiers
                .map(
                  (modifier) => CartItemModifier(
                    modifierId: modifier.modifierId,
                    modifierName: modifier.modifierName,
                    priceAdjustment: modifier.priceAdjustment,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final freeItems = order.items!
        .where((item) => item.isFreeItem)
        .map(
          (item) => CartItem(
            productId: item.productId,
            productCode: item.productCode,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            amount: item.amount,
            promotionName: item.promotionName,
            priceLevel1: item.unitPrice,
          ),
        )
        .toList();

    final totalDiscount = (order.subtotal - order.totalAmount).clamp(
      0,
      double.infinity,
    );

    ref
        .read(cartProvider.notifier)
        .replaceCart(
          CartState(
            items: regularItems,
            freeItems: freeItems,
            customerId: order.customerId ?? 'WALK_IN',
            customerName: order.customerName ?? 'ลูกค้าทั่วไป',
            discountAmount: totalDiscount.toDouble(),
          ),
        );

    ref.read(restaurantOrderContextProvider.notifier).state = restaurantContext
        .copyWith(currentOrderId: order.orderId, currentOrderNo: order.orderNo);
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

    final ctx = ref.read(restaurantOrderContextProvider);
    final isTakeaway = ctx?.isTakeaway ?? false;
    final skipKitchen = ctx?.skipKitchen ?? false;
    ref
        .read(cartProvider.notifier)
        .hold(result, isTakeaway: isTakeaway, skipKitchen: skipKitchen);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('พักบิล: $result', overflow: TextOverflow.ellipsis),
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

    final products =
        ref.read(productListProvider).value ?? const <ProductModel>[];
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

    ref
        .read(cartProvider.notifier)
        .addItem(
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
  List<ProductModel> _filterProducts(
    List<ProductModel> src, {
    Map<String, double> stockMap = const {},
  }) {
    final restaurantContext = ref.read(restaurantOrderContextProvider);

    // ซ่อนสินค้าหมด (เฉพาะสินค้าที่ควบคุม stock และไม่อนุญาต stock ติดลบ)
    var result = src.where((p) {
      if (restaurantContext != null) {
        final serviceMode = p.serviceMode.toUpperCase();
        final supportsRestaurant =
            serviceMode == 'RESTAURANT' || serviceMode == 'BOTH';
        if (!supportsRestaurant) return false;
        if (restaurantContext.isTakeaway) {
          if (!p.takeawayAvailable) return false;
        } else {
          if (!p.dineInAvailable) return false;
        }
      }
      if (p.isStockControl && !p.allowNegativeStock) {
        final qty = stockMap[p.productId] ?? 0;
        if (qty <= 0) return false;
      }
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (p) =>
                p.productName.toLowerCase().contains(q) ||
                p.productCode.toLowerCase().contains(q) ||
                (p.barcode?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // ฟัง cart changes → คำนวณของแถมใหม่เมื่อ regular items เปลี่ยน
    ref.listen<CartState>(cartProvider, (prev, next) {
      _latestCart = next;
      if (prev?.items != next.items) _syncFreeItems();
    });

    // Clear category filter when restaurant context changes (new table / back to retail)
    ref.listen<RestaurantOrderContext?>(restaurantOrderContextProvider, (
      prev,
      next,
    ) {
      _latestRestaurantOrderContext = next;
      if (prev?.tableId != next?.tableId || (prev != null) != (next != null)) {
        if (mounted) setState(() => _selectedGroupId = null);
      }
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
    final restaurantContext = ref.watch(restaurantOrderContextProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final user = widget.isCashierMode ? ref.watch(authProvider).user : null;

    // ── Stock map: productId → balance สำหรับ warehouse ที่เลือก ──
    final warehouseId = selectedWarehouse?.warehouseId ?? '';
    final stockMap = <String, double>{
      for (final s in (ref.watch(stockBalanceProvider).asData?.value ?? []))
        if (s.warehouseId == warehouseId) s.productId: s.balance,
    };

    final hasCustomer =
        cartState.customerId != null && cartState.customerId != 'WALK_IN';

    // ── Responsive ───────────────────────────────────────────────
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final hideTabletTopBar = isTablet && !widget.isCashierMode;

    if (isMobile) {
      return const MobileOrderPage();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          backgroundColor: isDark ? AppTheme.darkBg : AppTheme.surface,
          appBar: AppBar(
            toolbarHeight: hideTabletTopBar ? 0 : (isTablet ? 40 : null),
            backgroundColor: isDark ? AppTheme.navyDark : AppTheme.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            // ── Leading ────────────────────────────────────
            automaticallyImplyLeading: hideTabletTopBar
                ? false
                : !widget.isCashierMode,
            leading: hideTabletTopBar
                ? null
                : widget.isCashierMode
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'ออกจากระบบ',
                    onPressed: _handleLogout,
                  )
                : null,

            title: hideTabletTopBar
                ? null
                : Row(
                    children: [
                      // Page icon
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.18),
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.point_of_sale,
                          size: 18,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            borderRadius: AppRadius.sm,
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
                      // Title
                      const Text(
                        'ขายสินค้า',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // Desktop: chips อยู่ใน toolbar โดยตรง
                      if (!isTablet) ...[
                        if (restaurantContext != null) ...[
                          _RestaurantContextChip(
                            contextData: restaurantContext,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _CustomerChip(
                          cartState: cartState,
                          hasCustomer: hasCustomer,
                        ),
                        const SizedBox(width: 8),
                        if (selectedBranch != null && selectedWarehouse != null)
                          InkWell(
                            onTap: _openConnectionSettings,
                            borderRadius: AppRadius.xl,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: AppRadius.xl,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    selectedBranch.branchName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: _openConnectionSettings,
                            borderRadius: AppRadius.xl,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: AppRadius.xl,
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
                        if (cartState.itemCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: AppRadius.pill,
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
                        const SizedBox(width: 8),
                      ],
                      // POS module badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'POS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),

            actions: const [],
            bottom: isTablet
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(40),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (restaurantContext != null)
                            _RestaurantContextChip(
                              contextData: restaurantContext,
                            ),
                          _CustomerChip(
                            cartState: cartState,
                            hasCustomer: hasCustomer,
                          ),
                          if (selectedBranch != null &&
                              selectedWarehouse != null)
                            InkWell(
                              onTap: _openConnectionSettings,
                              borderRadius: AppRadius.xl,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: AppRadius.xl,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.storefront_outlined,
                                      size: 13,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      selectedBranch.branchName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: _openConnectionSettings,
                              borderRadius: AppRadius.xl,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.xl,
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
                                borderRadius: AppRadius.pill,
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
                  )
                : null,
          ),

          // ── Body ─────────────────────────────────────────────
          // Desktop/Tablet (>=768px): grid + cart split
          // Mobile (<768px): cart only
          body: Stack(
            children: [
              _buildDesktopBody(productAsync, cartState, stockMap),
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
    Map<String, double> stockMap,
  ) {
    return Column(
      children: [
        _buildSearchToolbar(cartState, stockMap: stockMap),

        // ── Main Content: Grid(60%) + Cart(40%) ───────────────
        Expanded(
          child: Row(
            children: [
              // Product Grid (60%)
              Expanded(
                flex: 60,
                child: productAsync.when(
                  data: (products) {
                    final filtered = _filterProducts(
                      products,
                      stockMap: stockMap,
                    );
                    final displayed = _selectedGroupId != null
                        ? filtered
                              .where((p) => p.groupId == _selectedGroupId)
                              .toList()
                        : filtered;
                    return Column(
                      children: [
                        _buildCategoryBar(filtered),
                        Expanded(
                          child: displayed.isEmpty
                              ? _buildEmptyProducts()
                              : ProductGrid(products: displayed),
                        ),
                      ],
                    );
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
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.borderColorOf(context),
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

  Widget _buildSearchToolbar(
    CartState cartState, {
    bool compact = false,
    Map<String, double> stockMap = const {},
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColorOf(context)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final shouldStack = compact || constraints.maxWidth < 760;
          final searchField = SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า / บาร์โค้ด...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
                ),
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
                filled: true,
                fillColor: isDark ? AppTheme.darkElement : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.sm,
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF333333) : AppTheme.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.sm,
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF333333) : AppTheme.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.sm,
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
                  stockMap: stockMap,
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

          final holdOrdersState = ref.watch(holdOrdersProvider);
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 8),
              Tooltip(
                message: 'บิลที่พัก',
                waitDuration: const Duration(milliseconds: 400),
                child: InkWell(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const HoldOrdersDialog(),
                  ),
                  borderRadius: AppRadius.sm,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          size: 17,
                          color: isDark ? Colors.white70 : AppTheme.primary,
                        ),
                      ),
                      if (holdOrdersState.orders.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scrollChipIntoView(String? groupId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[groupId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Group color / icon helpers (mirrors mobile_order_page) ────────

  int _groupSeed(String? groupId) {
    final key = (groupId == null || groupId.isEmpty) ? 'ungrouped' : groupId;
    return key.codeUnits.fold<int>(0, (sum, code) => sum + code);
  }

  Color _parseConfiguredColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return Colors.transparent;
    final value = raw.trim();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6 || hex.length == 8) {
        final normalized = hex.length == 6 ? 'FF$hex' : hex;
        final parsed = int.tryParse(normalized, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }
    switch (value.toLowerCase()) {
      case 'red':       return Colors.red;
      case 'pink':      return Colors.pink;
      case 'purple':    return Colors.purple;
      case 'indigo':    return Colors.indigo;
      case 'blue':      return Colors.blue;
      case 'cyan':      return Colors.cyan;
      case 'teal':      return Colors.teal;
      case 'green':     return Colors.green;
      case 'lime':      return Colors.lime;
      case 'yellow':    return Colors.yellow;
      case 'amber':     return Colors.amber;
      case 'orange':    return Colors.orange;
      case 'brown':     return Colors.brown;
      case 'grey':
      case 'gray':      return Colors.grey;
      default:          return Colors.transparent;
    }
  }

  IconData _iconFromKey(String? key) {
    switch (key?.trim().toLowerCase()) {
      case 'apps':              return Icons.apps_rounded;
      case 'inventory':         return Icons.inventory_outlined;
      case 'inventory_2':       return Icons.inventory_2_outlined;
      case 'shopping_basket':   return Icons.shopping_basket_outlined;
      case 'sell':              return Icons.sell_outlined;
      case 'local_drink':       return Icons.local_drink_outlined;
      case 'fastfood':          return Icons.fastfood_outlined;
      case 'icecream':          return Icons.icecream_outlined;
      case 'kitchen':           return Icons.kitchen_outlined;
      case 'spa':               return Icons.spa_outlined;
      case 'bakery_dining':     return Icons.bakery_dining_outlined;
      case 'lunch_dining':      return Icons.lunch_dining_outlined;
      case 'local_cafe':        return Icons.local_cafe_outlined;
      case 'storefront':        return Icons.storefront_outlined;
      default:                  return _groupIcon(null);
    }
  }

  Color _groupColor(String? groupId) {
    final groups = ref.read(productGroupsProvider).value ?? const [];
    final group = groups.cast<dynamic>().firstWhere(
      (g) => g.groupId == groupId,
      orElse: () => null,
    );
    final configured = _parseConfiguredColor(group?.mobileColor as String?);
    if (configured != Colors.transparent) return configured;
    final index = _groupSeed(groupId) % _groupPalette.length;
    return _groupPalette[index];
  }

  IconData _groupIcon(String? groupId) {
    if (groupId == null) {
      final index = _groupSeed(null) % _groupIconList.length;
      return _groupIconList[index];
    }
    final groups = ref.read(productGroupsProvider).value ?? const [];
    final group = groups.cast<dynamic>().firstWhere(
      (g) => g.groupId == groupId,
      orElse: () => null,
    );
    final configured = group?.mobileIcon as String?;
    if (configured != null && configured.trim().isNotEmpty) {
      return _iconFromKey(configured);
    }
    final index = _groupSeed(groupId) % _groupIconList.length;
    return _groupIconList[index];
  }

  // ── Category filter bar — navy background + pill chips (mirrors mobile) ──
  Widget _buildCategoryBar(List<ProductModel> filteredProducts) {
    final groups = ref.watch(productGroupsProvider).value ?? [];

    if (groups.isEmpty) return const SizedBox.shrink();

    if (_selectedGroupId != null &&
        !groups.any((g) => g.groupId == _selectedGroupId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedGroupId = null);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? AppTheme.navyDark : AppTheme.navy;

    return Container(
      height: 46,
      color: barBg,
      child: ListView(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        children: [
          _navyChip(
            label: 'ทั้งหมด',
            icon: Icons.apps_rounded,
            color: AppTheme.primary,
            selected: _selectedGroupId == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedGroupId = null);
              _scrollChipIntoView(null);
            },
          ),
          for (final group in groups)
            _navyChip(
              label: group.groupName,
              icon: _groupIcon(group.groupId),
              color: _groupColor(group.groupId),
              selected: _selectedGroupId == group.groupId,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedGroupId =
                      _selectedGroupId == group.groupId ? null : group.groupId;
                });
                _scrollChipIntoView(
                  _selectedGroupId == null ? null : group.groupId,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _navyChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.08),
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
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
            child: Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: AppTheme.iconSubtleOf(context),
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

  const _CustomerChip({required this.cartState, required this.hasCustomer});

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

      notifier.setCustomer('WALK_IN', 'ลูกค้าทั่วไป', priceLevel: 1);
      if (confirm == true) notifier.repriceItems();
      return;
    }

    notifier.setCustomer('WALK_IN', 'ลูกค้าทั่วไป', priceLevel: 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCustomer(context, ref),
        borderRadius: AppRadius.xl,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasCustomer
                ? AppTheme.infoContainer
                : const Color(0xFF1F2E54),
            borderRadius: AppRadius.xl,
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
                  child: Icon(Icons.close, size: 13, color: AppTheme.info),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantContextChip extends StatelessWidget {
  final RestaurantOrderContext contextData;

  const _RestaurantContextChip({required this.contextData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: AppRadius.xl,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            contextData.isTakeaway
                ? Icons.takeout_dining
                : Icons.table_restaurant,
            size: 13,
            color: Colors.orange,
          ),
          const SizedBox(width: 5),
          Text(
            contextData.isTakeaway
                ? contextData.displayName
                : '${contextData.displayName} • ${contextData.guestCount} คน',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
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
          border: OutlineInputBorder(borderRadius: AppRadius.sm),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
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
