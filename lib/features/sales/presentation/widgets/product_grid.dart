import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../products/data/models/product_model.dart';
import '../providers/cart_provider.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/cart_toast.dart';

// ── Color Tokens ──────────────────────────────────────────────────
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
  ProductViewMode build() {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pos_product_view_mode') ?? 'grid';
      state = saved == 'list' ? ProductViewMode.list : ProductViewMode.grid;
    });
    return ProductViewMode.grid;
  }

  void set(ProductViewMode mode) => state = mode;
}

enum ProductViewMode { grid, list }

// ─────────────────────────────────────────────────────────────────
// Helper: เลือกราคาตาม priceLevel (1-5)
//
// ✅ คืนค่า PriceLookupResult เพื่อให้ UI รู้ว่า fallback เกิดขึ้นหรือไม่
// → ถ้า fallback = true: แสดง warning badge แจ้ง cashier
//   "ราคา Lv.X ไม่ได้ตั้งค่า ใช้ราคาปกติ"
// → ไม่ fallback เงียบๆ อีกต่อไป เพื่อป้องกันการเก็บเงินผิด
// ─────────────────────────────────────────────────────────────────
class PriceLookupResult {
  final double price;
  final bool isFallback; // true = ใช้ราคา Lv.1 แทนเพราะ Lv.X = 0
  final int requestedLevel;

  const PriceLookupResult({
    required this.price,
    required this.isFallback,
    required this.requestedLevel,
  });
}

PriceLookupResult getPriceByLevel(ProductModel product, int level) {
  switch (level) {
    case 2:
      if (product.priceLevel2 > 0) {
        return PriceLookupResult(
            price: product.priceLevel2,
            isFallback: false,
            requestedLevel: level);
      }
    case 3:
      if (product.priceLevel3 > 0) {
        return PriceLookupResult(
            price: product.priceLevel3,
            isFallback: false,
            requestedLevel: level);
      }
    case 4:
      if (product.priceLevel4 > 0) {
        return PriceLookupResult(
            price: product.priceLevel4,
            isFallback: false,
            requestedLevel: level);
      }
    case 5:
      if (product.priceLevel5 > 0) {
        return PriceLookupResult(
            price: product.priceLevel5,
            isFallback: false,
            requestedLevel: level);
      }
  }

  // ✅ Fallback → priceLevel1 แต่ flag isFallback = true เพื่อแจ้ง cashier
  return PriceLookupResult(
    price: product.priceLevel1,
    isFallback: level > 1, // fallback เฉพาะตอนขอ Lv.2-5 แต่ไม่มีราคา
    requestedLevel: level,
  );
}

// ─────────────────────────────────────────────────────────────────
// ProductGrid — Grid/List toggle + responsive + priceLevel
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
        // ── Toolbar: count + toggle ──────────────────────────
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
    final priceLevel = ref.watch(cartProvider).customerPriceLevel;
    final customerName = ref.watch(cartProvider).customerName;
    final hasSpecialPrice = priceLevel > 1;

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

          // ✅ Price level badge
          if (hasSpecialPrice) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _success.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.loyalty,
                      size: 11, color: _success.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    'ราคา Lv.$priceLevel · ${customerName ?? ''}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _success.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
// _ProductImage
// ─────────────────────────────────────────────────────────────────
class _ProductImage extends StatelessWidget {
  final String? imagePath;
  final double size;
  final BorderRadius borderRadius;

  const _ProductImage({
    required this.imagePath,
    required this.size,
    required this.borderRadius,
  });

  bool get _isExpand => size <= 0;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final file = hasImage ? File(imagePath!) : null;
    final exists = file != null && file.existsSync();

    Widget content;
    if (hasImage && exists) {
      if (_isExpand) {
        // Card view: แสดงภาพเต็ม มี padding 5pt และขอบมน
        // ใช้ FittedBox ห่อ ClipRRect เพื่อให้ clip ตรงขอบรูปจริง (ไม่ใช่ขอบ widget)
        content = Container(
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.06),
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.all(5),
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                file,
                errorBuilder: (_, _, _) => _placeholder(),
              ),
            ),
          ),
        );
      } else {
        // List view: thumbnail เล็ก เห็นภาพครบ
        content = Container(
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.06),
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.all(2),
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        );
      }
    } else {
      content = _placeholder();
    }

    if (_isExpand) return SizedBox.expand(child: content);
    return SizedBox(width: size, height: size, child: content);
  }

  Widget _placeholder() {
    final iconSize = _isExpand ? 36.0 : (size * 0.38).clamp(14.0, 48.0);
    return Container(
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.06),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: iconSize,
          color: _orange.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// GRID VIEW
// ─────────────────────────────────────────────────────────────────
class _GridView extends ConsumerWidget {
  final List<ProductModel> products;
  const _GridView({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth;
        int cols;
        if (panelWidth < 380) {
          cols = 2;
        } else if (panelWidth < 580) {
          cols = 3;
        } else if (panelWidth < 820) {
          cols = 4;
        } else if (panelWidth < 1080) {
          cols = 5;
        } else {
          cols = 6;
        }

        const childAspectRatio = 0.82;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductGridCard(product: products[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LIST VIEW
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
// Grid Card
// ─────────────────────────────────────────────────────────────────
class _ProductGridCard extends ConsumerWidget {
  final ProductModel product;
  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceLevel = ref.watch(cartProvider).customerPriceLevel;
    final lookup = getPriceByLevel(product, priceLevel);
    final unitPrice = lookup.price;
    final hasDiscount = priceLevel > 1 &&
        !lookup.isFallback &&
        unitPrice < product.priceLevel1;

    const nameColor = Color(0xFF1A1A1A);
    const codeColor = AppTheme.subtextColor;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: _orange.withValues(alpha: 0.06),
        splashColor: _orange.withValues(alpha: 0.12),
        onTap: () => _addToCart(context, ref, lookup),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปสินค้า
            Expanded(
              child: Stack(
                children: [
                  _ProductImage(
                    imagePath: product.imagePath,
                    size: 0,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                  ),
                  // ✅ Warning badge: ราคา Lv.X ยังไม่ได้ตั้งค่า
                  if (lookup.isFallback)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message:
                            'ราคา Lv.${lookup.requestedLevel} ยังไม่ได้ตั้งค่า\nใช้ราคาปกติ (Lv.1) แทน',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ราคาปกติ',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ข้อมูลสินค้า
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.productCode,
                      style:
                          const TextStyle(fontSize: 10, color: codeColor)),
                  const SizedBox(height: 2),
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: nameColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount)
                            Text(
                              '฿${product.priceLevel1.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSub,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '฿${unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: lookup.isFallback
                                  ? Colors.orange.shade700
                                  : hasDiscount
                                      ? _success
                                      : _info,
                            ),
                          ),
                        ],
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

  void _addToCart(
      BuildContext context, WidgetRef ref, PriceLookupResult lookup) {
    ref.read(cartProvider.notifier).addItem(
          productId: product.productId,
          productCode: product.productCode,
          productName: product.productName,
          unit: product.baseUnit,
          unitPrice: lookup.price,
          groupId: product.groupId,
          // ✅ ส่งราคาทุก level เก็บไว้ใน CartItem เพื่อ re-price ได้
          priceLevel1: product.priceLevel1,
          priceLevel2: product.priceLevel2,
          priceLevel3: product.priceLevel3,
          priceLevel4: product.priceLevel4,
          priceLevel5: product.priceLevel5,
        );

    if (lookup.isFallback) {
      ref.read(cartToastProvider.notifier).show(
        '⚠ ราคา Lv.${lookup.requestedLevel} ยังไม่ได้ตั้งค่า '
        '— ใช้ราคาปกติ ฿${lookup.price.toStringAsFixed(2)}',
        backgroundColor: Colors.orange.shade700,
        icon: Icons.warning_amber_rounded,
        duration: const Duration(seconds: 3),
      );
    } else {
      ref.read(cartToastProvider.notifier).show(
        'เพิ่ม ${product.productName} แล้ว',
        duration: const Duration(milliseconds: 1500),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// List Row
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
    final priceLevel = ref.watch(cartProvider).customerPriceLevel;
    final lookup = getPriceByLevel(product, priceLevel);
    final unitPrice = lookup.price;
    final hasDiscount = priceLevel > 1 &&
        !lookup.isFallback &&
        unitPrice < product.priceLevel1;

    return InkWell(
      onTap: () => _addToCart(context, ref, lookup),
      hoverColor: _orange.withValues(alpha: 0.05),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          // ✅ พื้นหลังสีส้มอ่อนถ้า fallback เพื่อให้ cashier สังเกตเห็น
          color: lookup.isFallback
              ? Colors.orange.shade50
              : isEven
                  ? Colors.white
                  : const Color(0xFFF9F9F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: lookup.isFallback
                ? Colors.orange.shade200
                : _border.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            _ProductImage(
              imagePath: product.imagePath,
              size: 40,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        product.productCode,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtextColor),
                      ),
                      // ✅ Warning label ในแถว
                      if (lookup.isFallback) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Lv.${lookup.requestedLevel} ไม่มีราคา',
                            style: const TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDiscount)
                  Text(
                    '฿${product.priceLevel1.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSub,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  '฿${unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: lookup.isFallback
                        ? Colors.orange.shade700
                        : hasDiscount
                            ? _success
                            : _info,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Add button
            InkWell(
              onTap: () => _addToCart(context, ref, lookup),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(
      BuildContext context, WidgetRef ref, PriceLookupResult lookup) {
    if (lookup.isFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠ ราคา Lv.${lookup.requestedLevel} ยังไม่ได้ตั้งค่า '
            '— ใช้ราคาปกติ ฿${lookup.price.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
    }

    ref.read(cartProvider.notifier).addItem(
          productId: product.productId,
          productCode: product.productCode,
          productName: product.productName,
          unit: product.baseUnit,
          unitPrice: lookup.price,
          groupId: product.groupId,
          // ✅ ส่งราคาทุก level เก็บไว้ใน CartItem เพื่อ re-price ได้
          priceLevel1: product.priceLevel1,
          priceLevel2: product.priceLevel2,
          priceLevel3: product.priceLevel3,
          priceLevel4: product.priceLevel4,
          priceLevel5: product.priceLevel5,
        );

    if (!lookup.isFallback) {
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
}
