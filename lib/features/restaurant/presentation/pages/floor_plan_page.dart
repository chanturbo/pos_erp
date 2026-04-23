import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/busy_overlay.dart';
import '../../data/models/dining_table_model.dart';
import '../providers/billing_provider.dart';
import '../providers/table_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';

class FloorPlanPage extends ConsumerStatefulWidget {
  const FloorPlanPage({super.key});

  @override
  ConsumerState<FloorPlanPage> createState() => _FloorPlanPageState();
}

class _FloorPlanPageState extends ConsumerState<FloorPlanPage> {
  String? _busyMessage;
  bool get _isBusy => _busyMessage != null;

  // Merge mode state
  bool _mergeMode = false;
  DiningTableModel? _mergeSource;
  DiningTableModel? _mergeTarget;

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tableListProvider);
    final zonesAsync = ref.watch(zoneListProvider);
    final selectedZone = ref.watch(selectedZoneFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('ผังโต๊ะ'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          if (_mergeMode)
            TextButton.icon(
              onPressed: _cancelMerge,
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('ยกเลิกรวม',
                  style: TextStyle(color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _isBusy ? null : _startMergeMode,
              icon: const Icon(Icons.merge_type, color: Colors.white),
              label: const Text('รวมโต๊ะ',
                  style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _isBusy
                ? null
                : () async {
                    final branchId =
                        ref.read(selectedBranchProvider)?.branchId;
                    setState(() => _busyMessage = 'กำลังรีเฟรช...');
                    await ref
                        .read(tableListProvider.notifier)
                        .refresh(branchId: branchId);
                    if (mounted) setState(() => _busyMessage = null);
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: Column(
              children: [
                // ── Merge mode banner ────────────────────────────────────
                if (_mergeMode) _MergeBanner(source: _mergeSource, target: _mergeTarget),

                // ── Status legend ────────────────────────────────────────
                if (!_mergeMode) _StatusLegend(),

                // ── Zone filter ──────────────────────────────────────────
                zonesAsync.when(
                  data: (zones) => zones.isEmpty
                      ? const SizedBox.shrink()
                      : _ZoneFilterBar(zones: zones),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // ── Floor plan grid ──────────────────────────────────────
                Expanded(
                  child: tablesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('เกิดข้อผิดพลาด: $e')),
                    data: (tables) {
                      final filtered = selectedZone == null
                          ? tables
                          : tables
                                .where((t) => t.zoneId == selectedZone)
                                .toList();

                      final byZone = <String, List<DiningTableModel>>{};
                      for (final t in filtered) {
                        (byZone[t.zoneId] ??= []).add(t);
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          final branchId =
                              ref.read(selectedBranchProvider)?.branchId;
                          await ref
                              .read(tableListProvider.notifier)
                              .refresh(branchId: branchId);
                        },
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: byZone.entries.map((entry) {
                            final zoneName =
                                entry.value.first.zoneName ?? entry.key;
                            return _ZoneSection(
                              zoneName: zoneName,
                              tables: entry.value,
                              mergeMode: _mergeMode,
                              mergeSource: _mergeSource,
                              mergeTarget: _mergeTarget,
                              onTableTap: (t) => _handleTableTap(t),
                              onCleaningCompleted: (t) =>
                                  _markTableCleaningCompleted(t),
                            );
                          }).toList(),
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

      // ── Merge confirm FAB ─────────────────────────────────────────────
      floatingActionButton: (_mergeMode &&
              _mergeSource != null &&
              _mergeTarget != null)
          ? FloatingActionButton.extended(
              onPressed: _confirmMerge,
              backgroundColor: Colors.deepOrange,
              icon: const Icon(Icons.merge_type),
              label: const Text('ยืนยันรวมโต๊ะ'),
            )
          : null,
    );
  }

  void _startMergeMode() {
    setState(() {
      _mergeMode = true;
      _mergeSource = null;
      _mergeTarget = null;
    });
  }

  void _cancelMerge() {
    setState(() {
      _mergeMode = false;
      _mergeSource = null;
      _mergeTarget = null;
    });
  }

  void _handleTableTap(DiningTableModel table) {
    if (!_mergeMode) return;

    // ในโหมด merge เฉพาะโต๊ะ OCCUPIED เท่านั้น
    if (!table.isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เลือกได้เฉพาะโต๊ะที่มีลูกค้าอยู่เท่านั้น'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      if (_mergeSource == null) {
        _mergeSource = table;
      } else if (_mergeSource!.tableId == table.tableId) {
        // deselect source
        _mergeSource = null;
      } else if (_mergeTarget == null) {
        _mergeTarget = table;
      } else if (_mergeTarget!.tableId == table.tableId) {
        // deselect target
        _mergeTarget = null;
      } else {
        // เปลี่ยน target เป็นโต๊ะใหม่
        _mergeTarget = table;
      }
    });
  }

  Future<void> _markTableCleaningCompleted(DiningTableModel table) async {
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
    if (confirmed != true || !mounted) return;

    setState(() => _busyMessage = 'กำลังเปลี่ยนสถานะโต๊ะ ${table.displayName} เป็นว่าง...');
    try {
      final ok = await ref.read(tableListProvider.notifier).updateTable(
            table.tableId,
            status: 'AVAILABLE',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
    } finally {
      if (mounted) {
        setState(() => _busyMessage = null);
      }
    }
  }

  Future<void> _confirmMerge() async {
    final source = _mergeSource!;
    final target = _mergeTarget!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันรวมโต๊ะ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายการออเดอร์ของโต๊ะต้นทางจะถูกย้ายไปยังโต๊ะปลายทาง'),
            const SizedBox(height: 16),
            _MergePreviewRow(
              label: 'ต้นทาง (จะปิด)',
              table: source,
              color: AppTheme.errorColor,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Icon(Icons.arrow_downward, color: Colors.grey),
            ),
            _MergePreviewRow(
              label: 'ปลายทาง (รับออเดอร์)',
              table: target,
              color: AppTheme.successColor,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange),
            child: const Text('รวมโต๊ะ'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _busyMessage = 'กำลังรวมโต๊ะ...');
    final messenger = ScaffoldMessenger.of(context);
    try {
      final merged = await ref
          .read(mergeTablesProvider.notifier)
          .merge(
            sourceTableId: source.tableId,
            targetTableId: target.tableId,
          );

      if (mounted) {
        final branchId = ref.read(selectedBranchProvider)?.branchId;
        await ref
            .read(tableListProvider.notifier)
            .refresh(branchId: branchId);
        setState(() {
          _busyMessage = null;
          _mergeMode = false;
          _mergeSource = null;
          _mergeTarget = null;
        });
        messenger.showSnackBar(SnackBar(
          content: Text(
            merged
                ? 'รวมโต๊ะ ${source.displayName} → ${target.displayName} สำเร็จ'
                : 'รวมโต๊ะไม่สำเร็จ กรุณาลองใหม่',
          ),
          backgroundColor:
              merged ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busyMessage = null);
        messenger.showSnackBar(const SnackBar(
          content: Text('เกิดข้อผิดพลาดระหว่างรวมโต๊ะ'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }
}

// ── Merge Banner ───────────────────────────────────────────────────────────────

class _MergeBanner extends StatelessWidget {
  final DiningTableModel? source;
  final DiningTableModel? target;
  const _MergeBanner({required this.source, required this.target});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.deepOrange.shade50,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.merge_type, color: Colors.deepOrange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                source == null
                    ? 'เลือกโต๊ะต้นทาง (ที่จะย้ายออก)'
                    : target == null
                        ? 'เลือกโต๊ะต้นทาง: ${source!.displayName}\nเลือกโต๊ะปลายทาง (ที่จะรับออเดอร์)'
                        : 'ต้นทาง: ${source!.displayName}  →  ปลายทาง: ${target!.displayName}',
                style: const TextStyle(
                    fontSize: 13, color: Colors.deepOrange),
              ),
            ),
          ],
        ),
      );
}

// ── Zone Section ───────────────────────────────────────────────────────────────

class _ZoneSection extends StatelessWidget {
  final String zoneName;
  final List<DiningTableModel> tables;
  final bool mergeMode;
  final DiningTableModel? mergeSource;
  final DiningTableModel? mergeTarget;
  final void Function(DiningTableModel) onTableTap;
  final void Function(DiningTableModel)? onCleaningCompleted;

  const _ZoneSection({
    required this.zoneName,
    required this.tables,
    required this.mergeMode,
    required this.mergeSource,
    required this.mergeTarget,
    required this.onTableTap,
    this.onCleaningCompleted,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ZoneHeader(zoneName: zoneName),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tables
                .map((t) => _FloorTableCard(
                      table: t,
                      mergeMode: mergeMode,
                      isSource: mergeSource?.tableId == t.tableId,
                      isTarget: mergeTarget?.tableId == t.tableId,
                      onTap: t.isCleaning && !mergeMode
                          ? () {}
                          : () => onTableTap(t),
                      onCleaningCompleted: t.isCleaning && !mergeMode
                          ? () => onCleaningCompleted?.call(t)
                          : null,
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
      );
}

// ── Floor Table Card ───────────────────────────────────────────────────────────

class _FloorTableCard extends StatelessWidget {
  final DiningTableModel table;
  final bool mergeMode;
  final bool isSource;
  final bool isTarget;
  final VoidCallback onTap;
  final VoidCallback? onCleaningCompleted;

  const _FloorTableCard({
    required this.table,
    required this.mergeMode,
    required this.isSource,
    required this.isTarget,
    required this.onTap,
    this.onCleaningCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor();
    final bool selectable = !mergeMode || table.isOccupied;
    final bool highlighted = isSource || isTarget;

    return GestureDetector(
      onTap: selectable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100,
        height: 110,
        decoration: BoxDecoration(
          color: highlighted
              ? (isSource
                  ? AppTheme.errorColor.withValues(alpha: 0.15)
                  : AppTheme.successColor.withValues(alpha: 0.15))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? (isSource ? AppTheme.errorColor : AppTheme.successColor)
                : mergeMode && !table.isOccupied
                    ? Colors.grey.shade200
                    : statusColor.withValues(alpha: 0.6),
            width: highlighted ? 2.5 : 1.5,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: (isSource
                            ? AppTheme.errorColor
                            : AppTheme.successColor)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Stack(
          children: [
            // Dimmed overlay when in merge mode and not selectable
            if (mergeMode && !table.isOccupied)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            // Badge ต้นทาง/ปลายทาง
            if (isSource || isTarget)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSource
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isSource ? 'ต้นทาง' : 'ปลายทาง',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status dot + table name
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: mergeMode && !table.isOccupied
                              ? Colors.grey.shade300
                              : statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          table.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: mergeMode && !table.isOccupied
                                ? Colors.grey.shade400
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Capacity
                  Row(
                    children: [
                      Icon(Icons.chair,
                          size: 11,
                          color: mergeMode && !table.isOccupied
                              ? Colors.grey.shade300
                              : Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        '${table.capacity} ที่',
                        style: TextStyle(
                          fontSize: 11,
                          color: mergeMode && !table.isOccupied
                              ? Colors.grey.shade300
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  if (table.isOccupied) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people,
                            size: 11,
                            color: mergeMode && !table.isOccupied
                                ? Colors.grey.shade300
                                : Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          '${table.activeGuestCount ?? 0} คน',
                          style: TextStyle(
                            fontSize: 11,
                            color: mergeMode && !table.isOccupied
                                ? Colors.grey.shade300
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (table.waiterName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.badge,
                              size: 11,
                              color: Colors.purple.shade200),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              table.waiterName!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple.shade300,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  const Spacer(),

                  // Status label
                  if (table.isCleaning && onCleaningCompleted != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onCleaningCompleted,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successColor,
                          side: BorderSide(color: AppTheme.successColor),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: const Size(0, 28),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('ทำความสะอาดเสร็จแล้ว'),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (mergeMode && !table.isOccupied
                                ? Colors.grey
                                : statusColor)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 10,
                          color: mergeMode && !table.isOccupied
                              ? Colors.grey.shade400
                              : statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor() => switch (table.status) {
        'AVAILABLE' => AppTheme.successColor,
        'OCCUPIED' => const Color(0xFFFF9800),
        'RESERVED' => AppTheme.infoColor,
        'CLEANING' => AppTheme.warningColor,
        'DISABLED' => Colors.grey,
        _ => Colors.grey,
      };

  String _statusLabel() => switch (table.status) {
        'AVAILABLE' => 'ว่าง',
        'OCCUPIED' => 'มีลูกค้า',
        'RESERVED' => 'จอง',
        'CLEANING' => 'กำลังเก็บ',
        'DISABLED' => 'ปิด',
        _ => table.status,
      };
}

// ── Merge Preview Row ──────────────────────────────────────────────────────────

class _MergePreviewRow extends StatelessWidget {
  final String label;
  final DiningTableModel table;
  final Color color;
  const _MergePreviewRow({
    required this.label,
    required this.table,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.table_restaurant, color: color, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                Text(table.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${table.activeGuestCount ?? 0} คน${table.waiterName != null ? ' • ${table.waiterName}' : ''}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Status Legend ──────────────────────────────────────────────────────────────

class _StatusLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Dot(color: AppTheme.successColor, label: 'ว่าง'),
            const SizedBox(width: 14),
            const _Dot(color: Color(0xFFFF9800), label: 'มีลูกค้า'),
            const SizedBox(width: 14),
            _Dot(color: AppTheme.infoColor, label: 'จอง'),
            const SizedBox(width: 14),
            _Dot(color: AppTheme.warningColor, label: 'กำลังเก็บ'),
          ],
        ),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

// ── Zone Filter Bar ────────────────────────────────────────────────────────────

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
          _Chip(
            label: 'ทั้งหมด',
            selected: selected == null,
            onTap: () =>
                ref.read(selectedZoneFilterProvider.notifier).state = null,
          ),
          ...zones.map((z) => _Chip(
                label: z.zoneName,
                selected: selected == z.zoneId,
                onTap: () =>
                    ref.read(selectedZoneFilterProvider.notifier).state =
                        z.zoneId,
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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
              color: selected
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
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

// ── Zone Header ────────────────────────────────────────────────────────────────

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
          Text(zoneName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );
}
