import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/data/models/product_model.dart';          // ✅ สำหรับ bottom sheet
import '../../../customers/data/models/customer_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/hold_orders_dialog.dart';
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ Phase 5
import '../../../../shared/widgets/barcode_listener.dart';        // ✅ USB Scanner
import '../../../../shared/theme/app_theme.dart';

import '../../../../shared/utils/responsive_utils.dart';           // ✅ Responsive



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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Logout (Cashier Mode) ────────────────────────────────────
  Future<void> _handleLogout() async {
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
    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  // ── Filter products ───────────────────────────────────────────
  List<ProductModel> _filterProducts(List<ProductModel> src) {
    if (_searchQuery.isEmpty) return src;
    final q = _searchQuery.toLowerCase();
    return src.where((p) =>
        p.productName.toLowerCase().contains(q) ||
        p.productCode.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false)).toList();
  }

  // ── Mobile: เปิด product search bottom sheet ─────────────────
  void _showProductSearchSheet(List<ProductModel> allProducts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSearchSheet(
        allProducts: allProducts,
        initialQuery: _searchQuery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync    = ref.watch(productListProvider);
    final cartState       = ref.watch(cartProvider);
    final holdOrdersState = ref.watch(holdOrdersProvider);
    final user            = widget.isCashierMode
        ? ref.watch(authProvider).user
        : null;

    final hasCustomer = cartState.customerId != null &&
        cartState.customerId != 'WALK_IN';

    // ── Responsive: compact = tablet/mobile ─────────────────────
    final isCompact = !context.isDesktopOrWider;

    return PopScope(
      canPop: !widget.isCashierMode,
      // ✅ BarcodeListener ครอบทั้งหน้า
      child: BarcodeListener(
        onBarcodeScanned: (barcode) {
          if (isCompact) {
            // Mobile: scan → set query แล้วเปิด sheet
            setState(() => _searchQuery = barcode);
            productAsync.whenData(
                (products) => _showProductSearchSheet(products));
          } else {
            // Desktop: scan → filter grid ปกติ
            _searchController.text = barcode;
            setState(() => _searchQuery = barcode);
          }
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
                        horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5)),
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
              // ── Mobile: ปุ่ม Search เปิด bottom sheet ────────
              if (isCompact)
                productAsync.maybeWhen(
                  data: (products) => IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'ค้นหาสินค้า',
                    onPressed: () => _showProductSearchSheet(products),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),

              // ── Mobile: ScannerButton ────────────────────────
              if (isCompact)
                ScannerButton(
                  tooltip: 'สแกนบาร์โค้ด',
                  onScanned: (value) {
                    setState(() => _searchQuery = value);
                    productAsync.whenData(
                        (p) => _showProductSearchSheet(p));
                  },
                ),

              // ── Customer chip (ย้ายมาจาก title) ────────────
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<CustomerModel?>(
                    context: context,
                    builder: (_) => const CustomerSelectorDialog(),
                  );
                  if (result != null) {
                    final notifier = ref.read(cartProvider.notifier);
                    final newLevel = result.priceLevel;

                    // ✅ ถ้ามีสินค้าในตะกร้าและ priceLevel เปลี่ยน → ถามก่อน
                    if (notifier.hasItemsWithDifferentLevel(newLevel)) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.sell_outlined,
                                  color: AppTheme.warning, size: 22),
                              SizedBox(width: 8),
                              Text('อัพเดทราคาสินค้า?'),
                            ],
                          ),
                          content: Text(
                            'ลูกค้า "${result.customerName}" '
                            'ใช้ระดับราคา Level $newLevel'
                            'ต้องการคำนวณราคาสินค้าในตะกร้าใหม่ด้วยไหม?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('คงราคาเดิม'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, true),
                              icon: const Icon(Icons.price_change, size: 16),
                              label: const Text('อัพเดทราคา'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );

                      // set customer ก่อนเสมอ
                      notifier.setCustomer(
                        result.customerId,
                        result.customerName,
                        priceLevel: newLevel,
                      );

                      // re-price เฉพาะเมื่อกด "อัพเดทราคา"
                      if (confirm == true) {
                        notifier.repriceItems();
                      }
                    } else {
                      // ตะกร้าว่าง หรือ priceLevel เดิม → set ตรงๆ
                      notifier.setCustomer(
                        result.customerId,
                        result.customerName,
                        priceLevel: newLevel,
                      );
                    }
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 160),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
                      Icon(Icons.person,
                          size: 14,
                          color: hasCustomer ? AppTheme.info : Colors.white60),
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
                          onTap: () async {
                            final notifier = ref.read(cartProvider.notifier);
                            // ✅ ถ้ามีสินค้าในตะกร้า → ถามก่อน reset ราคา
                            if (notifier.hasItemsWithDifferentLevel(1)) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.sell_outlined,
                                          color: AppTheme.warning, size: 22),
                                      SizedBox(width: 8),
                                      Text('อัพเดทราคาสินค้า?'),
                                    ],
                                  ),
                                  content: const Text(
                                    'เปลี่ยนเป็นลูกค้าทั่วไป (Level 1)'
                                    'ต้องการคำนวณราคาสินค้าในตะกร้าใหม่ด้วยไหม?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('คงราคาเดิม'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      icon: const Icon(
                                          Icons.price_change, size: 16),
                                      label: const Text('อัพเดทราคา'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              notifier.setCustomer(
                                  'WALK_IN', 'ลูกค้าทั่วไป',
                                  priceLevel: 1);
                              if (confirm == true) notifier.repriceItems();
                            } else {
                              // ตะกร้าว่าง หรือ level เดิมเป็น 1 อยู่แล้ว
                              notifier.setCustomer(
                                  'WALK_IN', 'ลูกค้าทั่วไป',
                                  priceLevel: 1);
                            }
                          },
                          child: Icon(Icons.close,
                              size: 13, color: AppTheme.info),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Cart badge ────────────────────────────────
              if (cartState.itemCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cartState.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

              // Hold Orders Button
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
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary, // Orange แทน red
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
                ],
              ),
            ],
          ),

          // ── Body ─────────────────────────────────────────────
          body: isCompact
              ? _buildCompactBody(cartState)
              : _buildDesktopBody(productAsync, cartState),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DESKTOP BODY — layout เดิมทุกอย่าง: Grid(60%) + Cart(40%)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopBody(AsyncValue productAsync, CartState cartState) {
    return Column(
      children: [
        // ── Toolbar: Search + Hold button ─────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkTopBar
                : Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
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
                          // ✅ ScannerButton เมื่อช่องว่าง
                          : ScannerButton(
                              tooltip: 'สแกนบาร์โค้ดสินค้า',
                              onScanned: (value) {
                                _searchController.text = value;
                                setState(() => _searchQuery = value);
                              },
                            ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HoldButton(cartState: cartState),
            ],
          ),
        ),

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
                  width: 1, thickness: 1, color: AppTheme.border),

              // Cart Panel (40%)
              const Expanded(flex: 40, child: CartPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COMPACT BODY (Mobile/Tablet) — Cart เต็มหน้า
  // Search/Scan อยู่ใน AppBar → เปิด bottom sheet
  // ─────────────────────────────────────────────────────────────
  Widget _buildCompactBody(CartState cartState) {
    return Column(
      children: [
        // Compact toolbar: hint + Hold button
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkTopBar
                : Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'กด 🔍 หรือสแกน เพื่อเพิ่มสินค้า',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              _HoldButton(cartState: cartState),
            ],
          ),
        ),

        // Cart Panel เต็มพื้นที่
        const Expanded(child: CartPanel()),
      ],
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
            child: const Icon(Icons.inventory_2_outlined,
                size: 38, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'ไม่มีสินค้า' : 'ไม่พบสินค้า "$_searchQuery"',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'กรุณาเพิ่มสินค้าในระบบก่อน'
                : 'ลองค้นหาด้วยคำอื่น',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSub),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(productListProvider.notifier).refresh(),
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
            onPressed: () =>
                ref.read(productListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _HoldButton — แยก widget ใช้ทั้ง desktop และ compact toolbar
// ─────────────────────────────────────────────────────────────────
class _HoldButton extends ConsumerWidget {
  final CartState cartState;
  const _HoldButton({required this.cartState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: cartState.items.isEmpty
          ? null
          : () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => _HoldOrderNameDialog(),
              );
              if (result != null && result.isNotEmpty) {
                ref.read(cartProvider.notifier).hold(result);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('พักบิล: $result'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
      label: const Text('พักบิล'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ProductSearchSheet — Bottom sheet สำหรับ Mobile/Tablet
// ─────────────────────────────────────────────────────────────────
class _ProductSearchSheet extends ConsumerStatefulWidget {
  final List<ProductModel> allProducts;
  final String initialQuery;

  const _ProductSearchSheet({
    required this.allProducts,
    this.initialQuery = '',
  });

  @override
  ConsumerState<_ProductSearchSheet> createState() =>
      _ProductSearchSheetState();
}

class _ProductSearchSheetState
    extends ConsumerState<_ProductSearchSheet> {
  late TextEditingController _ctrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _ctrl  = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ProductModel> get _filtered {
    if (_query.isEmpty) return widget.allProducts;
    final q = _query.toLowerCase();
    return widget.allProducts.where((p) =>
        p.productName.toLowerCase().contains(q) ||
        p.productCode.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false)).toList();
  }

  // ✅ Helper: เลือกราคาตาม priceLevel (1-5), fallback = priceLevel1
  double _getPriceByLevel(ProductModel product, int level) {
    switch (level) {
      case 2: return product.priceLevel2 > 0 ? product.priceLevel2 : product.priceLevel1;
      case 3: return product.priceLevel3 > 0 ? product.priceLevel3 : product.priceLevel1;
      case 4: return product.priceLevel4 > 0 ? product.priceLevel4 : product.priceLevel1;
      case 5: return product.priceLevel5 > 0 ? product.priceLevel5 : product.priceLevel1;
      default: return product.priceLevel1;
    }
  }

  void _addProduct(ProductModel product) {
    // ✅ ใช้ราคาตาม priceLevel ของลูกค้าที่เลือกไว้ใน cart
    final priceLevel = ref.read(cartProvider).customerPriceLevel;
    final unitPrice  = _getPriceByLevel(product, priceLevel);
    ref.read(cartProvider.notifier).addItem(
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      unitPrice: unitPrice,
      // ✅ ส่งราคาทุก level เก็บไว้ใน CartItem เพื่อ re-price ได้
      priceLevel1: product.priceLevel1,
      priceLevel2: product.priceLevel2,
      priceLevel3: product.priceLevel3,
      priceLevel4: product.priceLevel4,
      priceLevel5: product.priceLevel5,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('เพิ่ม ${product.productName} แล้ว'),
      duration: const Duration(milliseconds: 600),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.success,
      width: 280,
    ));
    // ไม่ปิด sheet — เพิ่มต่อได้เรื่อยๆ
  }

  @override
  Widget build(BuildContext context) {
    final filtered    = _filtered;
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard
            : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.navy, size: 18),
                const SizedBox(width: 8),
                Text(
                  'ค้นหาสินค้า',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filtered.length} รายการ',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.navy),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ชื่อสินค้า / รหัส / บาร์โค้ด...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : ScannerButton(
                          tooltip: 'สแกนบาร์โค้ด',
                          onScanned: (v) {
                            _ctrl.text = v;
                            setState(() => _query = v);
                          },
                        ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppTheme.primary, width: 1.5),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // Product list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          _query.isEmpty
                              ? 'ไม่มีสินค้า'
                              : 'ไม่พบสินค้า "$_query"',
                          style:
                              TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final priceLevel =
                          ref.read(cartProvider).customerPriceLevel;
                      final price = _getPriceByLevel(filtered[i], priceLevel);
                      return _SheetProductRow(
                        product: filtered[i],
                        isEven: i.isEven,
                        displayPrice: price, // ✅
                        onAdd: () => _addProduct(filtered[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _SheetProductRow — compact row ใน bottom sheet
// ─────────────────────────────────────────────────────────────────
class _SheetProductRow extends StatelessWidget {
  final ProductModel product;
  final bool isEven;
  final double displayPrice; // ✅ ราคาตาม priceLevel
  final VoidCallback onAdd;

  const _SheetProductRow({
    required this.product,
    required this.isEven,
    required this.displayPrice,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isEven
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkCard
                  : Colors.white)
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkElement
                  : const Color(0xFFF9F9F7)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            // Initials
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  p.productCode.length >= 2
                      ? p.productCode.substring(0, 2)
                      : p.productCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + code
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.productName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    p.productCode,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSub),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              '฿${displayPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.info,
              ),
            ),
            const SizedBox(width: 10),

            // Add button
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add,
                  size: 16, color: Colors.white),
            ),
          ],
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
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('พักบิล'),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'ชื่อบิล',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
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