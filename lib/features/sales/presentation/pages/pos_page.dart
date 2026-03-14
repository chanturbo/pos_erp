import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/hold_orders_dialog.dart';
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ Phase 5
import '../../../../shared/widgets/barcode_listener.dart';        // ✅ USB Scanner
import '../../../../shared/theme/app_theme.dart';

// ── OAG Identity tokens ──────────────────────────────────────────
const _navy    = AppTheme.navyColor;
const _orange  = AppTheme.primaryColor;
const _surface = AppTheme.surfaceColor;
const _border  = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _error   = AppTheme.errorColor;
const _info    = AppTheme.infoColor;

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

    return PopScope(
      canPop: !widget.isCashierMode,
      // ✅ BarcodeListener ครอบทั้งหน้า
      child: BarcodeListener(
        onBarcodeScanned: (barcode) {
          _searchController.text = barcode;
          setState(() => _searchQuery = barcode);
        },
        child: Scaffold(
          backgroundColor: _surface,
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
              children: [
                // Cashier badge
                if (widget.isCashierMode && user != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _orange.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                ],

                const Text('จุดขาย'),
                const SizedBox(width: 12),

                // ── Customer chip ───────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final result = await showDialog<CustomerModel?>(
                        context: context,
                        builder: (_) => const CustomerSelectorDialog(),
                      );
                      if (result != null) {
                        ref.read(cartProvider.notifier).setCustomer(
                          result.customerId,
                          result.customerName,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        // ลูกค้าที่เลือก = info tint, ลูกค้าทั่วไป = navy tint
                        color: hasCustomer
                            ? AppTheme.infoContainer
                            : const Color(0xFF1F2E54),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasCustomer
                              ? _info.withValues(alpha: 0.5)
                              : AppTheme.navyBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: hasCustomer
                                ? _info
                                : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cartState.customerName ?? 'ลูกค้าทั่วไป',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasCustomer
                                    ? _info
                                    : Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasCustomer) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => ref
                                  .read(cartProvider.notifier)
                                  .setCustomer('WALK_IN', 'ลูกค้าทั่วไป'),
                              borderRadius: BorderRadius.circular(8),
                              child: Icon(Icons.close,
                                  size: 14, color: _info),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Cart count badge — Orange แทน red
                if (cartState.itemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _orange,
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
              ],
            ),

            actions: [
              // Customer Button
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'เลือกลูกค้า',
                onPressed: () async {
                  final result = await showDialog<CustomerModel?>(
                    context: context,
                    builder: (_) => const CustomerSelectorDialog(),
                  );
                  if (result != null) {
                    ref.read(cartProvider.notifier).setCustomer(
                      result.customerId,
                      result.customerName,
                    );
                  }
                },
              ),

              // Discount Button
              IconButton(
                icon: const Icon(Icons.discount_outlined),
                tooltip: 'ส่วนลด',
                onPressed: () async {
                  final result = await showDialog<Map<String, double>>(
                    context: context,
                    builder: (_) => const DiscountDialog(),
                  );
                  if (result != null) {
                    ref.read(cartProvider.notifier).setDiscount(
                      percent: result['percent'],
                      amount: result['amount'],
                    );
                  }
                },
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
                          color: _orange, // Orange แทน red
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
          body: Column(
            children: [
              // ── Toolbar: Search + Hold button ───────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: _border),
                  ),
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
                            prefixIcon:
                                const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon:
                                        const Icon(Icons.clear, size: 16),
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
                                      setState(
                                          () => _searchQuery = value);
                                    },
                                  ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: _orange, width: 1.5),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // พักบิล button — OAG Orange
                    ElevatedButton.icon(
                      onPressed: cartState.items.isEmpty
                          ? null
                          : () async {
                              final result = await showDialog<String>(
                                context: context,
                                builder: (_) => _HoldOrderNameDialog(),
                              );
                              if (result != null && result.isNotEmpty) {
                                ref
                                    .read(cartProvider.notifier)
                                    .hold(result);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text('พักบิล: $result'),
                                    backgroundColor: _orange,
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                }
                              }
                            },
                      icon: const Icon(Icons.bookmark_add_outlined,
                          size: 16),
                      label: const Text('พักบิล'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main Content ─────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    // Product Grid (60%) — Navy header ใน product_grid
                    Expanded(
                      flex: 60,
                      child: productAsync.when(
                        data: (products) {
                          final filtered = products.where((p) {
                            if (_searchQuery.isEmpty) return true;
                            final q = _searchQuery.toLowerCase();
                            return p.productName
                                    .toLowerCase()
                                    .contains(q) ||
                                p.productCode
                                    .toLowerCase()
                                    .contains(q) ||
                                (p.barcode
                                        ?.toLowerCase()
                                        .contains(q) ??
                                    false);
                          }).toList();

                          if (filtered.isEmpty) {
                            return _buildEmptyProducts();
                          }

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
                        width: 1, thickness: 1, color: _border),

                    // Cart Panel (40%)
                    const Expanded(
                      flex: 40,
                      child: CartPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
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
                fontSize: 13, color: AppTheme.subtextColor),
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
          const Icon(Icons.error_outline, size: 64, color: _error),
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
              color: AppTheme.primaryColor,
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
                color: AppTheme.primaryColor, width: 1.5),
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
            backgroundColor: AppTheme.primaryColor,
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