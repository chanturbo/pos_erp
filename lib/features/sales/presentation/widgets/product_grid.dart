import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/data/models/product_model.dart';
import '../providers/cart_provider.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';

// ── OAG Tokens ────────────────────────────────────────────────────
const _navy    = AppTheme.navyColor;
const _orange  = AppTheme.primaryColor;
const _surface = AppTheme.surfaceColor;
const _border  = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _info    = AppTheme.infoColor;

// ── View Mode Provider ────────────────────────────────────────────
final productViewModeProvider =
    NotifierProvider<_ViewModeNotifier, ProductViewMode>(
        _ViewModeNotifier.new);

class _ViewModeNotifier extends Notifier<ProductViewMode> {
  @override
  ProductViewMode build() => ProductViewMode.grid;
  void set(ProductViewMode mode) => state = mode;
}

enum ProductViewMode { grid, list }

// ─────────────────────────────────────────────────────────────────
// ProductGrid — Grid/List toggle + responsive
// รักษา addItem + SnackBar logic จากไฟล์เดิม
// ─────────────────────────────────────────────────────────────────
class ProductGrid extends ConsumerWidget {
  final List<ProductModel> products;

  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(productViewModeProvider);

    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('ไม่พบสินค้า'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Toolbar: count + toggle ─────────────────────────
        _ProductToolbar(
          viewMode: viewMode,
          productCount: products.length,
        ),

        // ── Content ─────────────────────────────────────────
        Expanded(
          child: viewMode == ProductViewMode.grid
              ? _GridView(products: products)
              : _ListViewContent(products: products),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────
class _ProductToolbar extends ConsumerWidget {
  final ProductViewMode viewMode;
  final int productCount;

  const _ProductToolbar({
    required this.viewMode,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$productCount รายการ',
              style: const TextStyle(
                fontSize: 11,
                color: _navy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Spacer(),

          // View toggle
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleBtn(
                  icon: Icons.grid_view,
                  active: viewMode == ProductViewMode.grid,
                  tooltip: 'Grid View',
                  onTap: () => ref
                      .read(productViewModeProvider.notifier)
                      .set(ProductViewMode.grid),
                ),
                _ToggleBtn(
                  icon: Icons.view_list,
                  active: viewMode == ProductViewMode.list,
                  tooltip: 'List View',
                  onTap: () => ref
                      .read(productViewModeProvider.notifier)
                      .set(ProductViewMode.list),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _orange : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// GRID VIEW — responsive columns
// ─────────────────────────────────────────────────────────────────
class _GridView extends ConsumerWidget {
  final List<ProductModel> products;
  const _GridView({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Responsive columns — คิดจาก screen width ทั้งหมด
    // แต่ product grid อยู่ใน 60% ของหน้า จึงลด break point ลง
    final w = context.screenWidth;
    int cols;
    if (w < 900) {
      cols = 2;
    } else if (w < 1280) {
      cols = 3;
    } else if (w < 1600) {
      cols = 4;
    } else {
      cols = 5;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductGridCard(product: products[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LIST VIEW — compact row เหมาะสินค้าเยอะ
// ─────────────────────────────────────────────────────────────────
class _ListViewContent extends ConsumerWidget {
  final List<ProductModel> products;
  const _ListViewContent({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductListRow(
        product: products[i],
        isEven: i.isEven,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Grid Card — รักษา addItem + SnackBar จากไฟล์เดิม
// ─────────────────────────────────────────────────────────────────
class _ProductGridCard extends ConsumerWidget {
  final ProductModel product;
  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── ใช้สีขาวเสมอ ไม่ว่าจะ light/dark mode ──
    // เพราะ Card บน POS page มี background สีอ่อน (white/surface)
    // ไม่ได้ใช้ dark theme background
    const nameColor  = Color(0xFF1A1A1A); // เข้มเสมอ
    const codeColor  = AppTheme.subtextColor;

    return Card(
      elevation: 0,
      color: Colors.white, // Card สีขาวเสมอในหน้า POS
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: _orange.withValues(alpha: 0.06),
        splashColor: _orange.withValues(alpha: 0.12),
        onTap: () => _addToCart(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปสินค้า
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10)),
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 40,
                    color: _orange.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),

            // ข้อมูลสินค้า
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productCode,
                    style: const TextStyle(
                        fontSize: 10,
                        color: codeColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: nameColor, // ✅ กำหนดสีเข้มเสมอ
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '฿${product.priceLevel1.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _info,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add,
                            size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).addItem(
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      unitPrice: product.priceLevel1,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เพิ่ม ${product.productName} แล้ว'),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _success,
        width: 300,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// List Row — compact single line
// ─────────────────────────────────────────────────────────────────
class _ProductListRow extends ConsumerWidget {
  final ProductModel product;
  final bool isEven;

  const _ProductListRow({
    required this.product,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _addToCart(context, ref),
      hoverColor: _orange.withValues(alpha: 0.05),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          // ✅ สีขาวเสมอใน POS — ไม่ใช้ dark mode color
          color: isEven ? Colors.white : const Color(0xFFF9F9F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: _border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            // Initials box
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _orange.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  product.productCode.length >= 2
                      ? product.productCode.substring(0, 2)
                      : product.productCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _orange,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + Code
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A), // ✅ เข้มเสมอ
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    product.productCode,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtextColor),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              '฿${product.priceLevel1.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _info,
              ),
            ),
            const SizedBox(width: 10),

            // Add button
            InkWell(
              onTap: () => _addToCart(context, ref),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add,
                    size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ รักษา addItem + SnackBar จากไฟล์เดิม
  void _addToCart(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).addItem(
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      unitPrice: product.priceLevel1,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เพิ่ม ${product.productName} แล้ว'),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _success,
        width: 300,
      ),
    );
  }
}