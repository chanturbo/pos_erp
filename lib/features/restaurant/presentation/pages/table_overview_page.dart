import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/providers/cart_provider.dart';
import '../../data/models/dining_table_model.dart';
import '../../data/models/restaurant_order_context.dart';
import '../../data/models/table_session_model.dart';
import '../providers/table_provider.dart';
import '../widgets/table_card.dart';
import '../widgets/open_table_dialog.dart';
import 'billing_page.dart';
import 'reservations_page.dart';
import 'table_timeline_page.dart';

class TableOverviewPage extends ConsumerStatefulWidget {
  const TableOverviewPage({super.key});

  @override
  ConsumerState<TableOverviewPage> createState() => _TableOverviewPageState();
}

class _TableOverviewPageState extends ConsumerState<TableOverviewPage> {
  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tableListProvider);
    final zonesAsync = ref.watch(zoneListProvider);
    final selectedZone = ref.watch(selectedZoneFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('โต๊ะอาหาร'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'การจองโต๊ะ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReservationsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final branchId = ref.read(selectedBranchProvider)?.branchId;
              ref.read(tableListProvider.notifier).refresh(branchId: branchId);
              ref.read(zoneListProvider.notifier).refresh();
            },
            tooltip: 'รีเฟรช',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'zones') _showZoneManagerDialog(context);
            },
            itemBuilder: (_) => const [
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
      body: Column(
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    Text('ไม่สามารถโหลดข้อมูลได้',
                        style: TextStyle(color: AppTheme.errorColor)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(tableListProvider.notifier)
                          .refresh(
                            branchId:
                                ref.read(selectedBranchProvider)?.branchId,
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

                // จัดกลุ่มตาม zone
                final byZone = <String, List<DiningTableModel>>{};
                for (final t in filtered) {
                  (byZone[t.zoneId] ??= []).add(t);
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(tableListProvider.notifier)
                      .refresh(
                        branchId: ref.read(selectedBranchProvider)?.branchId,
                      ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: byZone.entries.map((entry) {
                      final zoneName =
                          entry.value.first.zoneName ?? entry.key;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ZoneHeader(zoneName: zoneName),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                                onTap: () =>
                                    _handleTableTap(context, table),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTableDialog(context),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มโต๊ะ'),
      ),
    );
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  Future<void> _handleTableTap(
      BuildContext context, DiningTableModel table) async {
    if (table.isDisabled) return;

    if (table.isAvailable || table.isCleaning) {
      await _openTable(context, table);
    } else if (table.isOccupied) {
      await _showOccupiedOptions(context, table);
    }
  }

  Future<void> _openTable(
      BuildContext context, DiningTableModel table) async {
    final branchId = ref.read(selectedBranchProvider)?.branchId ?? '';
    final authState = ref.read(authProvider);
    final openedBy = authState.user?.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OpenTableDialog(
        table: table,
        branchId: branchId,
        onConfirm: (guestCount) async {
          final session = await ref.read(tableListProvider.notifier).openTable(
                tableId: table.tableId,
                guestCount: guestCount,
                branchId: branchId,
                openedBy: openedBy,
              );
          if (session == null && context.mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('เปิดโต๊ะไม่สำเร็จ'),
                content: const Text('กรุณาลองใหม่อีกครั้ง'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ตกลง')),
                ],
              ),
            );
          }
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      final session = await ref
          .read(tableListProvider.notifier)
          .getActiveSession(table.tableId);
      if (!mounted) return;
      if (session != null) {
        _openOrderPage(table, session);
      }
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('เปิดโต๊ะ ${table.displayName} แล้ว'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showOccupiedOptions(
      BuildContext context, DiningTableModel table) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
          final ok = await ref
              .read(tableListProvider.notifier)
              .closeTable(table.tableId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok
                    ? 'ปิดโต๊ะ ${table.displayName} แล้ว'
                    : 'ปิดโต๊ะไม่สำเร็จ'),
                backgroundColor:
                    ok ? AppTheme.successColor : AppTheme.errorColor,
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
      BuildContext context, DiningTableModel table) async {
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                final ok = await ref
                    .read(tableListProvider.notifier)
                    .updateGuestCount(table.tableId, count);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                  content: Text(ok ? 'อัปเดตจำนวนลูกค้าเป็น $count คนแล้ว' : 'อัปเดตไม่สำเร็จ'),
                  backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignWaiterDialog(
      BuildContext context, DiningTableModel table) async {
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
                await ref
                    .read(tableListProvider.notifier)
                    .assignWaiter(table.tableId, name);
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
                backgroundColor: AppTheme.primaryColor),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
  }

  void _openBillingPage(DiningTableModel table) {
    final ctx = RestaurantOrderContext(
      tableId: table.tableId,
      tableName: table.displayName,
      sessionId: table.activeSessionId ?? '',
      branchId: ref.read(selectedBranchProvider)?.branchId ?? '',
      guestCount: table.activeGuestCount ?? 1,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillingPage(tableContext: ctx)),
    );
  }

  void _openOrderPage(DiningTableModel table, TableSessionModel session) {
    ref.read(restaurantOrderContextProvider.notifier).state =
        RestaurantOrderContext(
      tableId: table.tableId,
      tableName: table.displayName,
      sessionId: session.sessionId,
      branchId: session.branchId,
      guestCount: session.guestCount,
      serviceType: 'DINE_IN',
      currentOrderId: table.currentOrderId,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosPage()),
    );
  }

  Future<void> _showTransferTableDialog(
    BuildContext context,
    DiningTableModel table,
  ) async {
    final tables = ref.read(tableListProvider).asData?.value ?? [];
    final availableTargets = tables
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
                final session = await ref
                    .read(tableListProvider.notifier)
                    .transferTable(
                      fromTableId: table.tableId,
                      targetTableId: selectedTableId,
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
                  child: const Text('ตกลง')),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    .map((z) => DropdownMenuItem(
                        value: z.zoneId, child: Text(z.zoneName)))
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
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n ที่นั่ง')))
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
                  backgroundColor: AppTheme.primaryColor),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('เพิ่มโต๊ะไม่สำเร็จ')));
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            child: Text('ยังไม่มีโซน',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: zones.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              title: Text(zones[i].zoneName),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
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
                            minimumSize: const Size(48, 40)),
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
                  child: const Text('ปิด')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addZone(TextEditingController ctrl, String branchId) async {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final ok = await ref.read(zoneListProvider.notifier).createZone(
          zoneName: name,
          branchId: branchId,
        );
    if (ok) ctrl.clear();
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _StatusLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
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
          ...zones.map((z) => _ZoneChip(
                label: z.zoneName,
                selected: selected == z.zoneId,
                onTap: () => ref
                    .read(selectedZoneFilterProvider.notifier)
                    .state = z.zoneId,
              )),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ZoneChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected ? AppTheme.primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : Colors.black87,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
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
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('ยังไม่มีโต๊ะ',
                style: TextStyle(
                    fontSize: 18, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('กดปุ่ม + เพื่อเพิ่มโต๊ะ',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มโต๊ะ'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'โต๊ะ ${table.displayName}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (table.activeGuestCount != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${table.activeGuestCount} คน • เปิดเมื่อ ${_formatTime(table.sessionOpenedAt)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
      );

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
