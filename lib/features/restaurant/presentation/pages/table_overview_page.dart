import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/busy_overlay.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/providers/cart_provider.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../data/models/dining_table_model.dart';
import '../../data/models/restaurant_order_context.dart';
import '../../data/models/table_session_model.dart';
import '../providers/table_provider.dart';
import '../widgets/table_card.dart';
import '../widgets/open_table_dialog.dart';
import 'billing_page.dart';
import 'floor_plan_page.dart';
import 'reservations_page.dart';
import 'takeaway_orders_page.dart';
import 'table_timeline_page.dart';
import 'waiter_management_page.dart';

class TableOverviewPage extends ConsumerStatefulWidget {
  const TableOverviewPage({super.key});

  @override
  ConsumerState<TableOverviewPage> createState() => _TableOverviewPageState();
}

class _TableOverviewPageState extends ConsumerState<TableOverviewPage> {
  String? _busyMessage;

  bool get _isBusy => _busyMessage != null;

  @override
  Widget build(BuildContext context) {
    ref.watch(tableStatusPollingProvider);
    ref.watch(takeawayPollingProvider(null));
    final tablesAsync = ref.watch(tableListProvider);
    final zonesAsync = ref.watch(zoneListProvider);
    final selectedZone = ref.watch(selectedZoneFilterProvider);
    final takeawayPendingCount = ref.watch(takeawayOpenOrdersCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('โต๊ะอาหาร'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.takeout_dining),
            tooltip: 'ซื้อกลับบ้าน',
            onPressed: _isBusy ? null : _startTakeawayOrder,
          ),
          IconButton(
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
                        borderRadius: AppRadius.pill,
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
            tooltip: 'บิลซื้อกลับบ้านค้าง',
            onPressed: _isBusy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TakeawayOrdersPage(),
                    ),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'การจองโต๊ะ',
            onPressed: _isBusy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReservationsPage()),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isBusy
                ? null
                : () => _runBusy('กำลังรีเฟรชข้อมูลโต๊ะ...', () async {
                    final branchId = ref.read(selectedBranchProvider)?.branchId;
                    await ref
                        .read(tableListProvider.notifier)
                        .refresh(branchId: branchId);
                    await ref.read(zoneListProvider.notifier).refresh();
                  }),
            tooltip: 'รีเฟรช',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'zones') _showZoneManagerDialog(context);
              if (v == 'floor_plan') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FloorPlanPage()),
                );
              }
              if (v == 'waiters') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WaiterManagementPage(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'floor_plan',
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('ผังโต๊ะ / รวมโต๊ะ'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'waiters',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('จัดการพนักงานเสิร์ฟ'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'zones',
                child: Row(
                  children: [
                    Icon(Icons.layers, size: 18),
                    SizedBox(width: 8),
                    Text('จัดการโซน'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: Column(
              children: [
                // ── Status Legend ──────────────────────────────────────────
                _StatusLegend(),
                const SizedBox(height: 4),

                // ── Zone Filter ────────────────────────────────────────────
                zonesAsync.when(
                  data: (zones) => zones.isEmpty
                      ? const SizedBox.shrink()
                      : _ZoneFilterBar(zones: zones),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // ── Table Grid ────────────────────────────────────────────
                Expanded(
                  child: tablesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ไม่สามารถโหลดข้อมูลได้',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => ref
                                .read(tableListProvider.notifier)
                                .refresh(
                                  branchId: ref
                                      .read(selectedBranchProvider)
                                      ?.branchId,
                                ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    ),
                    data: (tables) {
                      final filtered = selectedZone == null
                          ? tables
                          : tables
                                .where((t) => t.zoneId == selectedZone)
                                .toList();

                      if (filtered.isEmpty) {
                        return _EmptyState(
                          onAdd: () => _showAddTableDialog(context),
                        );
                      }

                      final byZone = <String, List<DiningTableModel>>{};
                      for (final t in filtered) {
                        (byZone[t.zoneId] ??= []).add(t);
                      }

                      return RefreshIndicator(
                        onRefresh: () => ref
                            .read(tableListProvider.notifier)
                            .refresh(
                              branchId: ref
                                  .read(selectedBranchProvider)
                                  ?.branchId,
                            ),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // ── ซื้อกลับ section ──────────────────────────
                            _TakeawaySectionPanel(
                              onStartNew: _isBusy ? null : _startTakeawayOrder,
                              onResume: _isBusy ? null : _resumeTakeawayHold,
                            ),
                            const SizedBox(height: 20),
                            // ── Zone sections ─────────────────────────────
                            ...byZone.entries.map((entry) {
                              final zoneName =
                                  entry.value.first.zoneName ?? entry.key;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ZoneHeader(zoneName: zoneName),
                                  const SizedBox(height: 8),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 160,
                                          mainAxisExtent: 150,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                    itemCount: entry.value.length,
                                    itemBuilder: (ctx, i) {
                                      final table = entry.value[i];
                                      return TableCard(
                                        table: table,
                                        onTap: table.isCleaning
                                            ? null
                                            : () => _handleTableTap(
                                                context,
                                                table,
                                              ),
                                        onCleaningCompleted: table.isCleaning
                                            ? () => _markTableCleaningCompleted(
                                                context,
                                                table,
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          BusyOverlay(message: _busyMessage),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : () => _showAddTableDialog(context),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มโต๊ะ'),
      ),
    );
  }

  Future<T> _runBusy<T>(String message, Future<T> Function() action) async {
    setState(() => _busyMessage = message);
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _busyMessage = null);
      }
    }
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  Future<void> _handleTableTap(
    BuildContext context,
    DiningTableModel table,
  ) async {
    if (table.isDisabled) return;

    if (table.isAvailable) {
      await _openTable(context, table);
    } else if (table.isOccupied) {
      await _showOccupiedOptions(context, table);
    }
  }

  Future<void> _markTableCleaningCompleted(
    BuildContext context,
    DiningTableModel table,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ทำความสะอาดเสร็จแล้ว'),
        content: Text(
          'ยืนยันว่าโต๊ะ ${table.displayName} พร้อมใช้งานแล้ว และต้องการเปลี่ยนสถานะเป็นว่างหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('ทำความสะอาดเสร็จแล้ว'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _runBusy(
      'กำลังเปลี่ยนสถานะโต๊ะ ${table.displayName} เป็นว่าง...',
      () => ref
          .read(tableListProvider.notifier)
          .updateTable(table.tableId, status: 'AVAILABLE'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'โต๊ะ ${table.displayName} พร้อมใช้งานแล้ว'
              : 'เปลี่ยนสถานะโต๊ะไม่สำเร็จ',
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openTable(BuildContext context, DiningTableModel table) async {
    final branchId = ref.read(selectedBranchProvider)?.branchId ?? '';
    final authState = ref.read(authProvider);
    final openedBy = authState.user?.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OpenTableDialog(
        table: table,
        branchId: branchId,
        onConfirm: (guestCount) async {
          final session = await _runBusy(
            'กำลังเปิดโต๊ะ ${table.displayName}...',
            () => ref
                .read(tableListProvider.notifier)
                .openTable(
                  tableId: table.tableId,
                  guestCount: guestCount,
                  branchId: branchId,
                  openedBy: openedBy,
                ),
          );
          return session != null;
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      final session = await _runBusy(
        'กำลังโหลด session โต๊ะ...',
        () => ref
            .read(tableListProvider.notifier)
            .getActiveSession(table.tableId),
      );
      if (!mounted) return;
      if (session != null) {
        _openOrderPage(table, session);
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('เปิดโต๊ะ ${table.displayName} แล้ว'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showOccupiedOptions(
    BuildContext context,
    DiningTableModel table,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.topLg),
      builder: (_) => _TableOptionsSheet(
        table: table,
        onViewBill: () {
          Navigator.pop(context);
          _openBillingPage(table);
        },
        onTakeOrder: () {
          Navigator.pop(context);
          _openOrderPage(
            table,
            TableSessionModel(
              sessionId: table.activeSessionId ?? '',
              tableId: table.tableId,
              branchId: ref.read(selectedBranchProvider)?.branchId ?? '',
              openedAt: table.sessionOpenedAt ?? DateTime.now(),
              guestCount: table.activeGuestCount ?? 1,
              status: 'OPEN',
            ),
          );
        },
        onTransfer: () async {
          Navigator.pop(context);
          await _showTransferTableDialog(context, table);
        },
        onClose: () async {
          Navigator.pop(context);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('ยืนยันการปิดโต๊ะ'),
              content: Text(
                'ปิดโต๊ะ ${table.displayName} ตอนนี้หรือไม่?\nหากยังมีบิลเปิดอยู่ ระบบจะไม่อนุญาตให้ปิดโต๊ะ',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                  ),
                  child: const Text('ปิดโต๊ะ'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;

          final result = await _runBusy(
            'กำลังปิดโต๊ะ ${table.displayName}...',
            () =>
                ref.read(tableListProvider.notifier).closeTable(table.tableId),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? 'ปิดโต๊ะ ${table.displayName} แล้ว'
                      : (result.message?.trim().isNotEmpty ?? false)
                      ? result.message!
                      : 'ปิดโต๊ะไม่สำเร็จ',
                ),
                backgroundColor: result.success
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onAssignWaiter: () {
          Navigator.pop(context);
          _showAssignWaiterDialog(context, table);
        },
        onViewTimeline: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TableTimelinePage(
                tableId: table.tableId,
                tableName: table.displayName,
              ),
            ),
          );
        },
        onUpdateGuestCount: () {
          Navigator.pop(context);
          _showUpdateGuestCountDialog(context, table);
        },
      ),
    );
  }

  Future<void> _showUpdateGuestCountDialog(
    BuildContext context,
    DiningTableModel table,
  ) async {
    int count = table.activeGuestCount ?? 1;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('จำนวนลูกค้า — ${table.displayName}'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: count > 1 ? () => setS(() => count--) : null,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: count < (table.capacity)
                    ? () => setS(() => count++)
                    : null,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await _runBusy(
                  'กำลังอัปเดตจำนวนลูกค้า...',
                  () => ref
                      .read(tableListProvider.notifier)
                      .updateGuestCount(table.tableId, count),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'อัปเดตจำนวนลูกค้าเป็น $count คนแล้ว'
                          : 'อัปเดตไม่สำเร็จ',
                    ),
                    backgroundColor: ok
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignWaiterDialog(
    BuildContext context,
    DiningTableModel table,
  ) async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('กำหนดพนักงาน — ${table.displayName}'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อพนักงานเสิร์ฟ',
            prefixIcon: Icon(Icons.badge),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              try {
                await _runBusy(
                  'กำลังกำหนดพนักงานเสิร์ฟ...',
                  () => ref
                      .read(tableListProvider.notifier)
                      .assignWaiter(table.tableId, name),
                );
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('กำหนดพนักงาน $name แล้ว'),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('เกิดข้อผิดพลาด: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _openBillingPage(DiningTableModel table) async {
    final ctx = RestaurantOrderContext(
      tableId: table.tableId,
      tableName: table.displayName,
      sessionId: table.activeSessionId ?? '',
      branchId: ref.read(selectedBranchProvider)?.branchId ?? '',
      guestCount: table.activeGuestCount ?? 1,
    );
    final didCompletePayment = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BillingPage(tableContext: ctx)),
    );
    if (didCompletePayment != true || !mounted) return;
    final branchId = ref.read(selectedBranchProvider)?.branchId;
    await ref.read(tableListProvider.notifier).refresh(branchId: branchId);
  }

  Future<void> _startTakeawayOrder() async {
    final skipKitchen = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _TakeawayTypeDialog(),
    );
    if (skipKitchen == null || !mounted) return;

    final cartState = ref.read(cartProvider);
    final hasPendingCart =
        cartState.items.isNotEmpty ||
        cartState.freeItems.isNotEmpty ||
        cartState.appliedCoupons.isNotEmpty ||
        cartState.discountAmount > 0 ||
        cartState.discountPercent > 0;

    String? autoHoldName;
    if (hasPendingCart) {
      // Auto-hold the current order instead of asking to clear
      final now = DateTime.now();
      final baseName =
          'ซื้อกลับ ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      autoHoldName = _uniqueHoldName(baseName);
      ref
          .read(cartProvider.notifier)
          .hold(autoHoldName, isTakeaway: true, skipKitchen: skipKitchen);
      // hold() clears the cart internally
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PosPage()));
  }

  /// คืนชื่อที่ไม่ซ้ำกับ hold orders ที่มีอยู่แล้ว
  /// ถ้า "ซื้อกลับ 14:30" มีอยู่แล้ว → คืน "ซื้อกลับ 14:30 (2)", "(3)", ...
  String _uniqueHoldName(String base) {
    final existing = ref
        .read(holdOrdersProvider)
        .orders
        .map((o) => o.name)
        .toSet();
    if (!existing.contains(base)) return base;
    int counter = 2;
    while (existing.contains('$base ($counter)')) {
      counter++;
    }
    return '$base ($counter)';
  }

  Future<void> _resumeTakeawayHold(int index) async {
    // อ่าน skipKitchen จาก hold order ก่อน recall เพื่อ restore context ได้ถูกต้อง
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
      // Auto-hold current cart before recalling — prevents merging two customers' orders
      final existingCtx = ref.read(restaurantOrderContextProvider);
      final existingIsTakeaway = existingCtx?.isTakeaway ?? false;
      final existingSkipKitchen = existingCtx?.skipKitchen ?? false;
      final now = DateTime.now();
      final holdName = _uniqueHoldName(
        'ซื้อกลับ ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );
      ref
          .read(cartProvider.notifier)
          .hold(
            holdName,
            isTakeaway: existingIsTakeaway,
            skipKitchen: existingSkipKitchen,
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PosPage()));
  }

  void _openOrderPage(DiningTableModel table, TableSessionModel session) {
    ref
        .read(restaurantOrderContextProvider.notifier)
        .state = RestaurantOrderContext(
      tableId: table.tableId,
      tableName: table.displayName,
      sessionId: session.sessionId,
      branchId: session.branchId,
      guestCount: session.guestCount,
      serviceType: 'DINE_IN',
      currentOrderId: table.currentOrderId,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PosPage()));
  }

  Future<void> _showTransferTableDialog(
    BuildContext context,
    DiningTableModel table,
  ) async {
    final tables = ref.read(tableListProvider).asData?.value ?? [];
    final availableTargets =
        tables
            .where((item) => item.tableId != table.tableId && item.isAvailable)
            .toList()
          ..sort((a, b) => a.tableNo.compareTo(b.tableNo));

    if (availableTargets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีโต๊ะว่างสำหรับย้ายโต๊ะ')),
      );
      return;
    }

    String selectedTableId = availableTargets.first.tableId;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: Text('ย้ายโต๊ะ ${table.displayName}'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedTableId,
            decoration: const InputDecoration(
              labelText: 'เลือกโต๊ะปลายทาง',
              border: OutlineInputBorder(),
            ),
            items: availableTargets
                .map(
                  (item) => DropdownMenuItem(
                    value: item.tableId,
                    child: Text(
                      '${item.displayName} (${item.zoneName ?? 'ไม่ระบุโซน'})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setStateDialog(() => selectedTableId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final session = await _runBusy(
                  'กำลังย้ายโต๊ะ...',
                  () => ref
                      .read(tableListProvider.notifier)
                      .transferTable(
                        fromTableId: table.tableId,
                        targetTableId: selectedTableId,
                      ),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      session != null ? 'ย้ายโต๊ะสำเร็จ' : 'ย้ายโต๊ะไม่สำเร็จ',
                    ),
                    backgroundColor: session != null
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                );
              },
              child: const Text('ย้ายโต๊ะ'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add table dialog ──────────────────────────────────────────────────────

  Future<void> _showAddTableDialog(BuildContext context) async {
    final zonesAsync = ref.read(zoneListProvider);
    final zones = zonesAsync.asData?.value ?? [];

    if (zones.isEmpty) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('ยังไม่มีโซน'),
            content: const Text('กรุณาเพิ่มโซนก่อนเพิ่มโต๊ะ'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final tableNoCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    String selectedZoneId = zones.first.zoneId;
    int capacity = 4;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
          title: const Text('เพิ่มโต๊ะ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tableNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'หมายเลขโต๊ะ *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อแสดง (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedZoneId,
                decoration: const InputDecoration(
                  labelText: 'โซน',
                  border: OutlineInputBorder(),
                ),
                items: zones
                    .map(
                      (z) => DropdownMenuItem(
                        value: z.zoneId,
                        child: Text(z.zoneName),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setS(() => selectedZoneId = v ?? selectedZoneId),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('ที่นั่ง:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: capacity,
                    items: [2, 4, 6, 8, 10, 12]
                        .map(
                          (n) => DropdownMenuItem(
                            value: n,
                            child: Text('$n ที่นั่ง'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => capacity = v ?? capacity),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () async {
                final no = tableNoCtrl.text.trim();
                if (no.isEmpty) return;
                final ok = await ref
                    .read(tableListProvider.notifier)
                    .createTable(
                      tableNo: no,
                      zoneId: selectedZoneId,
                      tableDisplayName: displayNameCtrl.text.trim().isEmpty
                          ? null
                          : displayNameCtrl.text.trim(),
                      capacity: capacity,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เพิ่มโต๊ะไม่สำเร็จ')),
                  );
                }
              },
              child: const Text('เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Zone Manager dialog ───────────────────────────────────────────────────

  Future<void> _showZoneManagerDialog(BuildContext context) async {
    final branchId = ref.read(selectedBranchProvider)?.branchId ?? '';
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final zonesAsync = ref.watch(zoneListProvider);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
            title: const Text('จัดการโซน'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // รายการโซนที่มีอยู่
                  zonesAsync.when(
                    data: (zones) => zones.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'ยังไม่มีโซน',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: zones.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              title: Text(zones[i].zoneName),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(zoneListProvider.notifier)
                                      .deleteZone(zones[i].zoneId);
                                },
                              ),
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text('โหลดไม่สำเร็จ'),
                  ),
                  const Divider(),
                  // เพิ่มโซนใหม่
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ชื่อโซนใหม่',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addZone(nameCtrl, branchId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(48, 40),
                        ),
                        onPressed: () => _addZone(nameCtrl, branchId),
                        child: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ปิด'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addZone(TextEditingController ctrl, String branchId) async {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final ok = await ref
        .read(zoneListProvider.notifier)
        .createZone(zoneName: name, branchId: branchId);
    if (ok) ctrl.clear();
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _StatusLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.cardColor(context),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        _LegendDot(color: AppTheme.successColor, label: 'ว่าง'),
        const SizedBox(width: 16),
        const _LegendDot(color: Color(0xFFFF9800), label: 'มีลูกค้า'),
        const SizedBox(width: 16),
        _LegendDot(color: AppTheme.infoColor, label: 'จอง'),
        const SizedBox(width: 16),
        _LegendDot(color: AppTheme.warningColor, label: 'กำลังเก็บ'),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _ZoneFilterBar extends ConsumerWidget {
  final List<ZoneModel> zones;
  const _ZoneFilterBar({required this.zones});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedZoneFilterProvider);
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _ZoneChip(
            label: 'ทั้งหมด',
            selected: selected == null,
            onTap: () =>
                ref.read(selectedZoneFilterProvider.notifier).state = null,
          ),
          ...zones.map(
            (z) => _ZoneChip(
              label: z.zoneName,
              selected: selected == z.zoneId,
              onTap: () => ref.read(selectedZoneFilterProvider.notifier).state =
                  z.zoneId,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ZoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryColor : AppTheme.surface3Of(context),
        borderRadius: AppRadius.xl,
        border: Border.all(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.borderColorOf(context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : AppTheme.textColorOf(context),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

class _ZoneHeader extends StatelessWidget {
  final String zoneName;
  const _ZoneHeader({required this.zoneName});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        zoneName,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

// ── Takeaway Section Panel ─────────────────────────────────────────────────────
class _TakeawaySectionPanel extends ConsumerWidget {
  final VoidCallback? onStartNew;
  final void Function(int index)? onResume;

  const _TakeawaySectionPanel({this.onStartNew, this.onResume});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int originalIndex,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกบิล'),
        content: Text('ต้องการยกเลิกบิล "$name" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ใช่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยกเลิกบิล'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(holdOrdersProvider.notifier).removeOrder(originalIndex);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdOrders = ref.watch(holdOrdersProvider);
    final takeawayEntries = holdOrders.orders
        .asMap()
        .entries
        .where((e) => e.value.isTakeaway)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(Icons.takeout_dining, color: Colors.orange.shade700, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ซื้อกลับบ้าน',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
                if (takeawayEntries.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      '${takeawayEntries.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: onStartNew,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ออเดอร์ใหม่', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                  ),
                ),
              ],
            ),
          ),
          // ── Hold order list ────────────────────────────────────────
          if (takeawayEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 16, color: AppTheme.mutedTextOf(context)),
                  const SizedBox(width: 8),
                  Text(
                    'ยังไม่มีออเดอร์ที่พักไว้',
                    style: TextStyle(fontSize: 13, color: AppTheme.mutedTextOf(context)),
                  ),
                ],
              ),
            )
          else
            ...takeawayEntries.map((entry) {
              final order = entry.value;
              final cart = order.cartState;
              final isLast = entry == takeawayEntries.last;
              return Column(
                children: [
                  InkWell(
                    onTap: onResume != null ? () => onResume!(entry.key) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.10),
                              borderRadius: AppRadius.sm,
                            ),
                            child: Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 16,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cart.items.length} รายการ · ฿${cart.total.toStringAsFixed(2)} · ${DateFormat('HH:mm').format(order.timestamp)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.mutedTextOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: AppRadius.pill,
                            ),
                            child: const Text(
                              'ต่อ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _confirmDelete(context, ref, entry.key, order.name),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: AppTheme.borderColorOf(context),
                    ),
                ],
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.table_restaurant,
          size: 64,
          color: AppTheme.iconSubtleOf(context),
        ),
        const SizedBox(height: 16),
        Text(
          'ยังไม่มีโต๊ะ',
          style: TextStyle(fontSize: 18, color: AppTheme.textColorOf(context)),
        ),
        const SizedBox(height: 8),
        Text(
          'กดปุ่ม + เพื่อเพิ่มโต๊ะ',
          style: TextStyle(color: AppTheme.mutedTextOf(context)),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มโต๊ะ'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        ),
      ],
    ),
  );
}

class _TableOptionsSheet extends StatelessWidget {
  final DiningTableModel table;
  final VoidCallback onViewBill;
  final VoidCallback onTakeOrder;
  final VoidCallback onTransfer;
  final VoidCallback onClose;
  final VoidCallback onAssignWaiter;
  final VoidCallback onViewTimeline;
  final VoidCallback onUpdateGuestCount;
  const _TableOptionsSheet({
    required this.table,
    required this.onViewBill,
    required this.onTakeOrder,
    required this.onTransfer,
    required this.onClose,
    required this.onAssignWaiter,
    required this.onViewTimeline,
    required this.onUpdateGuestCount,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'โต๊ะ ${table.displayName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (table.activeGuestCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${table.activeGuestCount} คน • เปิดเมื่อ ${_formatTime(table.sessionOpenedAt)}',
                style: TextStyle(color: AppTheme.subtextColorOf(context)),
              ),
            ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(Icons.receipt, color: AppTheme.successColor),
            ),
            title: const Text('ดูบิล / ชำระเงิน'),
            subtitle: const Text('pre-bill, service charge, แยกบิล'),
            onTap: onViewBill,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            title: const Text('รับออเดอร์ต่อ'),
            subtitle: const Text('เปิดหน้า POS สำหรับโต๊ะนี้'),
            onTap: onTakeOrder,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(Icons.close, color: AppTheme.errorColor),
            ),
            title: const Text('ปิดโต๊ะ'),
            subtitle: const Text('ปิดรอบและเปลี่ยนสถานะเป็นกำลังเก็บ'),
            onTap: onClose,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(Icons.swap_horiz, color: AppTheme.infoColor),
            ),
            title: const Text('ย้ายโต๊ะ'),
            subtitle: const Text('ย้าย session ไปยังโต๊ะว่าง'),
            onTap: onTransfer,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(Icons.badge, color: Colors.purple),
            ),
            title: const Text('กำหนดพนักงาน'),
            subtitle: const Text('ระบุพนักงานเสิร์ฟดูแลโต๊ะนี้'),
            onTap: onAssignWaiter,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(Icons.timeline, color: Colors.teal),
            ),
            title: const Text('ดู Timeline'),
            subtitle: const Text('ประวัติการสั่งอาหารในรอบนี้'),
            onTap: onViewTimeline,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(Icons.people_outline, color: Colors.indigo),
            ),
            title: const Text('อัปเดตจำนวนลูกค้า'),
            subtitle: Text('ปัจจุบัน: ${table.activeGuestCount ?? 1} คน'),
            onTap: onUpdateGuestCount,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────
// Dialog: เลือกประเภทออเดอร์ Takeaway
// คืน true = ข้ามครัว (อาหารพร้อม), false = ส่งครัวก่อน (สั่งทำ)
// ─────────────────────────────────────────────────────────────────
class _TakeawayTypeDialog extends StatelessWidget {
  const _TakeawayTypeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ซื้อกลับบ้าน'),
      content: const Text('อาหารต้องส่งเข้าครัวหรือพร้อมเสิร์ฟแล้ว?'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.all(12),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.kitchen_outlined),
            label: const Text('ส่งเข้าครัวก่อน\n(สั่งทำ)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('ชำระได้เลย\n(อาหารพร้อมแล้ว)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
      ],
    );
  }
}
