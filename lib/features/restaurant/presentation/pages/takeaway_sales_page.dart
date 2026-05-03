import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/providers/cart_provider.dart';
import '../../data/models/restaurant_order_context.dart';
import 'takeaway_orders_page.dart';

class TakeawaySalesPage extends ConsumerStatefulWidget {
  final bool? autoStartSkipKitchen;

  const TakeawaySalesPage({super.key, this.autoStartSkipKitchen});

  @override
  ConsumerState<TakeawaySalesPage> createState() => _TakeawaySalesPageState();
}

class _TakeawaySalesPageState extends ConsumerState<TakeawaySalesPage> {
  bool _didAutoStart = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartSkipKitchen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoStart) return;
        _didAutoStart = true;
        _startTakeawayOrder(skipKitchen: widget.autoStartSkipKitchen!);
      });
    }
  }

  Future<void> _startTakeawayOrder({required bool skipKitchen}) async {
    final cartState = ref.read(cartProvider);
    final hasPendingCart =
        cartState.items.isNotEmpty ||
        cartState.freeItems.isNotEmpty ||
        cartState.appliedCoupons.isNotEmpty ||
        cartState.discountAmount > 0 ||
        cartState.discountPercent > 0;

    String? autoHoldName;
    if (hasPendingCart) {
      final now = DateTime.now();
      final baseName =
          'ซื้อกลับ ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      autoHoldName = _uniqueHoldName(baseName);
      ref
          .read(cartProvider.notifier)
          .hold(autoHoldName, isTakeaway: true, skipKitchen: skipKitchen);
    }

    ref
        .read(restaurantOrderContextProvider.notifier)
        .state = RestaurantOrderContext.takeaway(
      branchId: ref.read(selectedBranchProvider)?.branchId ?? '',
      skipKitchen: skipKitchen,
    );

    if (!mounted) return;
    if (autoHoldName != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('พักบิล "$autoHoldName" ไว้แล้ว'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosPage()),
    );
  }

  Future<void> _resumeTakeawayHold(int index) async {
    final holdOrders = ref.read(holdOrdersProvider).orders;
    final recalledSkipKitchen = index < holdOrders.length
        ? holdOrders[index].skipKitchen
        : false;

    final cartState = ref.read(cartProvider);
    final hasPendingCart =
        cartState.items.isNotEmpty ||
        cartState.freeItems.isNotEmpty ||
        cartState.appliedCoupons.isNotEmpty ||
        cartState.discountAmount > 0 ||
        cartState.discountPercent > 0;

    if (hasPendingCart) {
      final existingCtx = ref.read(restaurantOrderContextProvider);
      final now = DateTime.now();
      final holdName = _uniqueHoldName(
        'ซื้อกลับ ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );
      ref
          .read(cartProvider.notifier)
          .hold(
            holdName,
            isTakeaway: existingCtx?.isTakeaway ?? true,
            skipKitchen: existingCtx?.skipKitchen ?? false,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('พักบิล "$holdName" ไว้แล้ว'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    ref.read(holdOrdersProvider.notifier).recallOrder(index);
    ref
        .read(restaurantOrderContextProvider.notifier)
        .state = RestaurantOrderContext.takeaway(
      branchId: ref.read(selectedBranchProvider)?.branchId ?? '',
      skipKitchen: recalledSkipKitchen,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosPage()),
    );
  }

  String _uniqueHoldName(String base) {
    final existing = ref
        .read(holdOrdersProvider)
        .orders
        .map((order) => order.name)
        .toSet();
    if (!existing.contains(base)) return base;
    var counter = 2;
    while (existing.contains('$base ($counter)')) {
      counter++;
    }
    return '$base ($counter)';
  }

  Future<void> _confirmDeleteHold(int index, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายการพักไว้'),
        content: Text(
          'ต้องการลบ "$name" ออกจากรายการพักไว้ใช่หรือไม่?\n'
          'การลบนี้ไม่ยกเลิกบิลที่ส่งเข้าครัวหรือบิลซื้อกลับบ้านค้าง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ใช่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบรายการพักไว้'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(holdOrdersProvider.notifier).removeOrder(index);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบรายการพักไว้แล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdOrders = ref.watch(holdOrdersProvider);
    // บิลพักไว้ฝั่งส่งครัว (skipKitchen=false)
    final kitchenEntries = holdOrders.orders
        .asMap()
        .entries
        .where((e) => e.value.isTakeaway && !e.value.skipKitchen)
        .toList();
    // บิลพักไว้ฝั่งจำหน่ายเลย (skipKitchen=true)
    final directEntries = holdOrders.orders
        .asMap()
        .entries
        .where((e) => e.value.isTakeaway && e.value.skipKitchen)
        .toList();

    const kitchenColor = Color(0xFF2C82C9);
    const directColor = Color(0xFFFF9224);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ขายกลับบ้าน'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TakeawayOrdersPage()),
            ),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text('บิลค้าง', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final cards = [
                _TakeawayModeCard(
                  icon: Icons.soup_kitchen_rounded,
                  title: 'ส่งเข้าครัวก่อน',
                  subtitle:
                      'เหมาะกับเมนูที่ต้องปรุง รอครัว แล้วค่อยปิดบิลจากบิลกลับบ้านค้าง',
                  buttonLabel: 'เริ่มขายแบบส่งครัว',
                  color: kitchenColor,
                  onTap: () => _startTakeawayOrder(skipKitchen: false),
                ),
                _TakeawayModeCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'จำหน่ายเลย',
                  subtitle:
                      'เหมาะกับอาหารพร้อมขายหรือหยิบส่งได้ทันที ชำระเงินได้เลยโดยไม่ต้องส่งครัว',
                  buttonLabel: 'เริ่มขายและชำระได้ทันที',
                  color: directColor,
                  onTap: () => _startTakeawayOrder(skipKitchen: true),
                ),
              ];
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [cards[0], const SizedBox(height: 12), cards[1]],
              );
            },
          ),
          const SizedBox(height: 18),
          if (kitchenEntries.isNotEmpty) ...[
            _TakeawayHoldPanel(
              entries: kitchenEntries,
              color: kitchenColor,
              title: 'พักไว้ (ส่งครัว)',
              emptyLabel: 'ยังไม่มีบิลส่งครัวที่พักไว้',
              onResume: _resumeTakeawayHold,
              onDelete: _confirmDeleteHold,
            ),
            const SizedBox(height: 14),
          ],
          _TakeawayHoldPanel(
            entries: directEntries,
            color: directColor,
            title: 'พักไว้ (จำหน่ายเลย)',
            emptyLabel: 'ยังไม่มีบิลจำหน่ายเลยที่พักไว้',
            onResume: _resumeTakeawayHold,
            onDelete: _confirmDeleteHold,
          ),
        ],
      ),
    );
  }
}

class _TakeawayModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _TakeawayModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardColor = AppTheme.cardColor(context);
    final softColor = color.withValues(alpha: isDark ? 0.18 : 0.10);
    final borderColor = color.withValues(alpha: isDark ? 0.55 : 0.24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: AppRadius.lg,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.10 : 0.14),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.84),
                            Color.lerp(color, Colors.black, 0.18)!,
                          ],
                        ),
                        borderRadius: AppRadius.md,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppTheme.textColorOf(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: softColor,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'แตะเพื่อเริ่ม',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.mutedTextOf(context),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
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

class _TakeawayHoldPanel extends StatelessWidget {
  final List<MapEntry<int, HoldOrder>> entries;
  final Color color;
  final String title;
  final String emptyLabel;
  final void Function(int index) onResume;
  final Future<void> Function(int index, String name) onDelete;

  const _TakeawayHoldPanel({
    required this.entries,
    required this.color,
    required this.title,
    required this.emptyLabel,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textColorOf(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      '${entries.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderColorOf(context)),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 18,
                    color: AppTheme.mutedTextOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    emptyLabel,
                    style: TextStyle(color: AppTheme.mutedTextOf(context)),
                  ),
                ],
              ),
            )
          else
            ...entries.map((entry) {
              final order = entry.value;
              final cart = order.cartState;
              final isLast = entry == entries.last;
              return Column(
                children: [
                  InkWell(
                    onTap: () => onResume(entry.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.10),
                              borderRadius: AppRadius.sm,
                            ),
                            child: Icon(
                              order.skipKitchen
                                  ? Icons.shopping_bag_rounded
                                  : Icons.kitchen_outlined,
                              size: 17,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textColorOf(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${cart.items.length} รายการ · ฿${cart.total.toStringAsFixed(2)} · ${DateFormat('HH:mm').format(order.timestamp)}',
                                  style: TextStyle(
                                    color: AppTheme.mutedTextOf(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => onResume(entry.key),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('ต่อ'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () => onDelete(entry.key, order.name),
                            icon: const Icon(Icons.close, size: 15),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(28, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppTheme.borderColorOf(context),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
