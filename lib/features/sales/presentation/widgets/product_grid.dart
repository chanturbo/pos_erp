import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/models/modifier_model.dart';
import '../../../products/presentation/providers/modifier_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/cart_toast.dart';

// ── Color Tokens ──────────────────────────────────────────────────
const _navy = AppTheme.navyColor;
const _orange = AppTheme.primaryColor;
const _surface = AppTheme.surfaceColor;
const _border = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _info = AppTheme.infoColor;

const _categoryPalette = <Color>[
  Color(0xFF39A9E8),
  Color(0xFF6B4122),
  Color(0xFFFF9224),
  Color(0xFF63B946),
  Color(0xFFB45628),
  Color(0xFFE65D90),
  Color(0xFFFF4338),
  Color(0xFFF7B912),
  Color(0xFF159AA4),
  Color(0xFF2C82C9),
];

const _categoryIcons = <IconData>[
  Icons.inventory_2_outlined,
  Icons.local_drink_outlined,
  Icons.local_cafe_outlined,
  Icons.bakery_dining_outlined,
  Icons.fastfood_outlined,
  Icons.icecream_outlined,
  Icons.spa_outlined,
  Icons.storefront_outlined,
];

const _drinkCategoryColor = Color(0xFF39A9E8);
const _drinkCategoryIcon = Icons.emoji_food_beverage_rounded;
const _dessertCategoryColor = Color(0xFFE65D90);
const _dessertCategoryIcon = Icons.cake_rounded;

// ── View Mode Provider ────────────────────────────────────────────
final productViewModeProvider =
    NotifierProvider<_ViewModeNotifier, ProductViewMode>(_ViewModeNotifier.new);

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
          requestedLevel: level,
        );
      }
    case 3:
      if (product.priceLevel3 > 0) {
        return PriceLookupResult(
          price: product.priceLevel3,
          isFallback: false,
          requestedLevel: level,
        );
      }
    case 4:
      if (product.priceLevel4 > 0) {
        return PriceLookupResult(
          price: product.priceLevel4,
          isFallback: false,
          requestedLevel: level,
        );
      }
    case 5:
      if (product.priceLevel5 > 0) {
        return PriceLookupResult(
          price: product.priceLevel5,
          isFallback: false,
          requestedLevel: level,
        );
      }
  }

  // ✅ Fallback → priceLevel1 แต่ flag isFallback = true เพื่อแจ้ง cashier
  return PriceLookupResult(
    price: product.priceLevel1,
    isFallback: level > 1, // fallback เฉพาะตอนขอ Lv.2-5 แต่ไม่มีราคา
    requestedLevel: level,
  );
}

int _categorySeed(String? groupId) {
  final key = (groupId == null || groupId.isEmpty) ? 'ungrouped' : groupId;
  return key.codeUnits.fold<int>(0, (sum, code) => sum + code);
}

Color _parseCategoryColor(String? raw) {
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
    case 'red':
      return Colors.red;
    case 'pink':
      return Colors.pink;
    case 'purple':
      return Colors.purple;
    case 'indigo':
      return Colors.indigo;
    case 'blue':
      return Colors.blue;
    case 'cyan':
      return Colors.cyan;
    case 'teal':
      return Colors.teal;
    case 'green':
      return Colors.green;
    case 'lime':
      return Colors.lime;
    case 'yellow':
      return Colors.yellow;
    case 'amber':
      return Colors.amber;
    case 'orange':
      return Colors.orange;
    case 'brown':
      return Colors.brown;
    case 'grey':
    case 'gray':
      return Colors.grey;
    default:
      return Colors.transparent;
  }
}

bool _isDrinkCategory(ProductGroupModel? group, String? groupId) {
  final text = [
    group?.groupId,
    group?.groupCode,
    group?.groupName,
    group?.mobileIcon,
    groupId,
  ].whereType<String>().join(' ').toLowerCase();

  return text.contains('drink') ||
      text.contains('beverage') ||
      text.contains('local_drink') ||
      text.contains('เครื่องดื่ม');
}

bool _isDessertCategory(ProductGroupModel? group, String? groupId) {
  final text = [
    group?.groupId,
    group?.groupCode,
    group?.groupName,
    group?.mobileIcon,
    groupId,
  ].whereType<String>().join(' ').toLowerCase();

  return text.contains('dessert') ||
      text.contains('sweet') ||
      text.contains('icecream') ||
      text.contains('cake') ||
      text.contains('ของหวาน') ||
      text.contains('ขนมหวาน');
}

IconData _categoryIconFromKey(
  String? key,
  String? groupId, {
  ProductGroupModel? group,
}) {
  if (_isDrinkCategory(group, groupId)) return _drinkCategoryIcon;
  if (_isDessertCategory(group, groupId)) return _dessertCategoryIcon;

  switch (key?.trim().toLowerCase()) {
    case 'apps':
      return Icons.apps_rounded;
    case 'inventory':
      return Icons.inventory_outlined;
    case 'inventory_2':
      return Icons.inventory_2_outlined;
    case 'shopping_basket':
      return Icons.shopping_basket_outlined;
    case 'sell':
      return Icons.sell_outlined;
    case 'local_drink':
      return Icons.local_drink_outlined;
    case 'fastfood':
      return Icons.fastfood_outlined;
    case 'icecream':
      return Icons.icecream_outlined;
    case 'kitchen':
      return Icons.kitchen_outlined;
    case 'spa':
      return Icons.spa_outlined;
    case 'bakery_dining':
      return Icons.bakery_dining_outlined;
    case 'lunch_dining':
      return Icons.lunch_dining_outlined;
    case 'local_cafe':
      return Icons.local_cafe_outlined;
    case 'storefront':
      return Icons.storefront_outlined;
    default:
      final index = _categorySeed(groupId) % _categoryIcons.length;
      return _categoryIcons[index];
  }
}

ProductGroupModel? _productGroupFor(
  List<ProductGroupModel> groups,
  String? groupId,
) {
  if (groupId == null || groupId.isEmpty) return null;
  for (final group in groups) {
    if (group.groupId == groupId) return group;
  }
  return null;
}

Color _categoryColorFor(ProductGroupModel? group, String? groupId) {
  if (_isDrinkCategory(group, groupId)) return _drinkCategoryColor;
  if (_isDessertCategory(group, groupId)) return _dessertCategoryColor;

  final configured = _parseCategoryColor(group?.mobileColor);
  if (configured != Colors.transparent) return configured;
  final index = _categorySeed(groupId) % _categoryPalette.length;
  return _categoryPalette[index];
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppTheme.iconSubtleOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบสินค้า',
              style: TextStyle(color: AppTheme.subtextColorOf(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Toolbar: count + toggle ──────────────────────────
        _ProductToolbar(viewMode: viewMode, productCount: products.length),

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

  const _ProductToolbar({required this.viewMode, required this.productCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceLevel = ref.watch(cartProvider).customerPriceLevel;
    final customerName = ref.watch(cartProvider).customerName;
    final hasSpecialPrice = priceLevel > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColorOf(context)),
        ),
      ),
      child: Row(
        children: [
          // Count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: AppRadius.md,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.12),
                borderRadius: AppRadius.md,
                border: Border.all(color: _success.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.loyalty,
                    size: 11,
                    color: _success.withValues(alpha: 0.8),
                  ),
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
              borderRadius: AppRadius.sm,
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
        borderRadius: AppRadius.sm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _orange : Colors.transparent,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? Colors.white : AppTheme.iconOf(context),
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
  final Color accentColor;
  final IconData placeholderIcon;

  const _ProductImage({
    required this.imagePath,
    required this.size,
    required this.borderRadius,
    this.accentColor = _orange,
    this.placeholderIcon = Icons.inventory_2_outlined,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.14),
                accentColor.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.all(5),
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRRect(
              borderRadius: AppRadius.sm,
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
            color: accentColor.withValues(alpha: 0.08),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.34),
            accentColor.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Container(
          width: iconSize + 18,
          height: iconSize + 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            shape: BoxShape.circle,
          ),
          child: Icon(
            placeholderIcon,
            size: iconSize,
            color: accentColor.withValues(alpha: 0.78),
          ),
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
      itemBuilder: (_, i) =>
          _ProductListRow(product: products[i], isEven: i.isEven),
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
    final productGroups = ref.watch(productGroupsProvider).value ?? const [];
    final productGroup = _productGroupFor(productGroups, product.groupId);
    final categoryColor = _categoryColorFor(productGroup, product.groupId);
    final categoryIcon = _categoryIconFromKey(
      productGroup?.mobileIcon,
      product.groupId,
      group: productGroup,
    );
    final lookup = getPriceByLevel(product, priceLevel);
    final unitPrice = lookup.price;
    final hasDiscount =
        priceLevel > 1 && !lookup.isFallback && unitPrice < product.priceLevel1;

    final nameColor = AppTheme.textColorOf(context);
    final codeColor = AppTheme.subtextColorOf(context);

    return Card(
      elevation: 1,
      shadowColor: categoryColor.withValues(alpha: 0.12),
      color: AppTheme.cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: categoryColor.withValues(alpha: 0.26)),
      ),
      child: InkWell(
        borderRadius: AppRadius.md,
        hoverColor: categoryColor.withValues(alpha: 0.07),
        splashColor: categoryColor.withValues(alpha: 0.13),
        onTap: () => _addToCart(context, ref, lookup),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปสินค้า
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryColor.withValues(alpha: 0.28),
                            categoryColor.withValues(alpha: 0.11),
                            AppTheme.cardColor(context),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  _ProductImage(
                    imagePath: product.imagePath,
                    size: 0,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    accentColor: categoryColor,
                    placeholderIcon: categoryIcon,
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.92),
                        borderRadius: AppRadius.sm,
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withValues(alpha: 0.24),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(categoryIcon, size: 15, color: Colors.white),
                    ),
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
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: AppRadius.xs,
                          ),
                          child: const Text(
                            'ราคาปกติ',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ข้อมูลสินค้า
            Container(height: 3, color: categoryColor.withValues(alpha: 0.75)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productCode,
                    style: TextStyle(fontSize: 10, color: codeColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.productName,
                    style: TextStyle(
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
                          color: categoryColor,
                          borderRadius: AppRadius.sm,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
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

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    PriceLookupResult lookup,
  ) async {
    final groups = await ref.read(
      productModifierGroupsProvider(product.productId).future,
    );

    List<CartItemModifier> modifiers = const [];
    if (groups.isNotEmpty && context.mounted) {
      final picked = await showModalBottomSheet<List<CartItemModifier>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ModifierPickerSheet(
          groups: groups,
          productName: product.productName,
          basePrice: lookup.price,
        ),
      );
      if (picked == null) return; // user dismissed
      modifiers = picked;
    }

    ref
        .read(cartProvider.notifier)
        .addItem(
          productId: product.productId,
          productCode: product.productCode,
          productName: product.productName,
          unit: product.baseUnit,
          unitPrice: lookup.price,
          groupId: product.groupId,
          modifiers: modifiers,
          priceLevel1: product.priceLevel1,
          priceLevel2: product.priceLevel2,
          priceLevel3: product.priceLevel3,
          priceLevel4: product.priceLevel4,
          priceLevel5: product.priceLevel5,
        );

    if (!context.mounted) return;
    if (lookup.isFallback) {
      ref
          .read(cartToastProvider.notifier)
          .show(
            '⚠ ราคา Lv.${lookup.requestedLevel} ยังไม่ได้ตั้งค่า '
            '— ใช้ราคาปกติ ฿${lookup.price.toStringAsFixed(2)}',
            backgroundColor: Colors.orange.shade700,
            icon: Icons.warning_amber_rounded,
            duration: const Duration(seconds: 3),
          );
    } else {
      ref
          .read(cartToastProvider.notifier)
          .show(
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

  const _ProductListRow({required this.product, required this.isEven});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceLevel = ref.watch(cartProvider).customerPriceLevel;
    final lookup = getPriceByLevel(product, priceLevel);
    final unitPrice = lookup.price;
    final hasDiscount =
        priceLevel > 1 && !lookup.isFallback && unitPrice < product.priceLevel1;

    return InkWell(
      onTap: () => _addToCart(context, ref, lookup),
      hoverColor: _orange.withValues(alpha: 0.05),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          // fallback = orange tint; otherwise alternating row stripe
          color: lookup.isFallback
              ? (AppTheme.isDark(context)
                    ? const Color(0xFF3A2800)
                    : Colors.orange.shade50)
              : (isEven
                    ? AppTheme.rowEvenOf(context)
                    : AppTheme.rowOddOf(context)),
          borderRadius: AppRadius.sm,
          border: Border.all(
            color: lookup.isFallback
                ? (AppTheme.isDark(context)
                      ? Colors.orange.shade800
                      : Colors.orange.shade200)
                : AppTheme.borderColorOf(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            _ProductImage(
              imagePath: product.imagePath,
              size: 40,
              borderRadius: AppRadius.sm,
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textColorOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        product.productCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.subtextColorOf(context),
                        ),
                      ),
                      // ✅ Warning label ในแถว
                      if (lookup.isFallback) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Lv.${lookup.requestedLevel} ไม่มีราคา',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
              borderRadius: AppRadius.sm,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: AppRadius.sm,
                ),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    PriceLookupResult lookup,
  ) async {
    final groups = await ref.read(
      productModifierGroupsProvider(product.productId).future,
    );

    List<CartItemModifier> modifiers = const [];
    if (groups.isNotEmpty && context.mounted) {
      final picked = await showModalBottomSheet<List<CartItemModifier>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ModifierPickerSheet(
          groups: groups,
          productName: product.productName,
          basePrice: lookup.price,
        ),
      );
      if (picked == null) return;
      modifiers = picked;
    }

    ref
        .read(cartProvider.notifier)
        .addItem(
          productId: product.productId,
          productCode: product.productCode,
          productName: product.productName,
          unit: product.baseUnit,
          unitPrice: lookup.price,
          groupId: product.groupId,
          modifiers: modifiers,
          priceLevel1: product.priceLevel1,
          priceLevel2: product.priceLevel2,
          priceLevel3: product.priceLevel3,
          priceLevel4: product.priceLevel4,
          priceLevel5: product.priceLevel5,
        );

    if (!context.mounted) return;
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
    } else {
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

// ─────────────────────────────────────────────────────────────────
// Modifier Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _ModifierPickerSheet extends StatefulWidget {
  final List<ModifierGroupModel> groups;
  final String productName;
  final double basePrice;

  const _ModifierPickerSheet({
    required this.groups,
    required this.productName,
    required this.basePrice,
  });

  @override
  State<_ModifierPickerSheet> createState() => _ModifierPickerSheetState();
}

class _ModifierPickerSheetState extends State<_ModifierPickerSheet> {
  // groupId → selected modifierId(s)
  late final Map<String, Set<String>> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};
    for (final g in widget.groups) {
      final defaults = g.options
          .where((o) => o.isDefault)
          .map((o) => o.modifierId)
          .toSet();
      _selections[g.modifierGroupId] = defaults.isNotEmpty ? defaults : {};
    }
  }

  double get _totalAdj {
    double adj = 0;
    for (final g in widget.groups) {
      final sel = _selections[g.modifierGroupId] ?? {};
      for (final opt in g.options) {
        if (sel.contains(opt.modifierId)) adj += opt.priceAdjustment;
      }
    }
    return adj;
  }

  bool get _canConfirm {
    for (final g in widget.groups) {
      if (!g.isRequired) continue;
      final sel = _selections[g.modifierGroupId] ?? {};
      if (sel.isEmpty) return false;
    }
    return true;
  }

  List<CartItemModifier> _buildModifiers() {
    final result = <CartItemModifier>[];
    for (final g in widget.groups) {
      final sel = _selections[g.modifierGroupId] ?? {};
      for (final opt in g.options) {
        if (sel.contains(opt.modifierId)) {
          result.add(
            CartItemModifier(
              modifierId: opt.modifierId,
              modifierName: opt.modifierName,
              priceAdjustment: opt.priceAdjustment,
            ),
          );
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.basePrice + _totalAdj;
    final isDark = AppTheme.isDark(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColorOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColorOf(context),
                          ),
                        ),
                        Text(
                          'เลือกตัวเลือกเพิ่มเติม',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtextColorOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '฿${totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? _orange : _navy,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Groups
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: widget.groups.map(_buildGroup).toList(),
              ),
            ),

            // Confirm button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canConfirm
                        ? () => Navigator.pop(context, _buildModifiers())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _orange,
                      disabledBackgroundColor: _orange.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                    ),
                    child: Text(
                      'เพิ่มลงตะกร้า · ฿${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(ModifierGroupModel group) {
    final sel = _selections[group.modifierGroupId] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              group.groupName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColorOf(context),
              ),
            ),
            const SizedBox(width: 6),
            if (group.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xs,
                ),
                child: Text(
                  'บังคับเลือก',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.subtextColorOf(
                    context,
                  ).withValues(alpha: 0.1),
                  borderRadius: AppRadius.xs,
                ),
                child: Text(
                  'ไม่บังคับ',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...group.options.map((opt) {
          final isSelected = sel.contains(opt.modifierId);
          return _OptionTile(
            option: opt,
            isSelected: isSelected,
            isSingle: group.isSingle,
            onTap: () => setState(() {
              if (group.isSingle) {
                _selections[group.modifierGroupId] = isSelected
                    ? {}
                    : {opt.modifierId};
              } else {
                final updated = Set<String>.from(sel);
                isSelected
                    ? updated.remove(opt.modifierId)
                    : updated.add(opt.modifierId);
                _selections[group.modifierGroupId] = updated;
              }
            }),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final ModifierOptionModel option;
  final bool isSelected;
  final bool isSingle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isSingle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final adj = option.priceAdjustment;
    final adjText = adj == 0
        ? ''
        : adj > 0
        ? '+฿${adj.toStringAsFixed(2)}'
        : '-฿${adj.abs().toStringAsFixed(2)}';
    final adjColor = adj > 0
        ? _success
        : (adj < 0 ? AppTheme.errorColor : null);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? _orange.withValues(alpha: 0.08)
              : AppTheme.surfaceColorOf(context),
          borderRadius: AppRadius.sm,
          border: Border.all(
            color: isSelected ? _orange : AppTheme.borderColorOf(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSingle
                  ? (isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                  : (isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
              size: 18,
              color: isSelected ? _orange : AppTheme.subtextColorOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.modifierName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: AppTheme.textColorOf(context),
                ),
              ),
            ),
            if (adjText.isNotEmpty)
              Text(
                adjText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: adjColor ?? AppTheme.subtextColorOf(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
