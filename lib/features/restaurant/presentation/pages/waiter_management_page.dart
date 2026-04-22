import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/busy_overlay.dart';
import '../../data/models/dining_table_model.dart';
import '../providers/table_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';

class WaiterManagementPage extends ConsumerStatefulWidget {
  const WaiterManagementPage({super.key});

  @override
  ConsumerState<WaiterManagementPage> createState() =>
      _WaiterManagementPageState();
}

class _WaiterManagementPageState extends ConsumerState<WaiterManagementPage> {
  String? _busyMessage;
  bool get _isBusy => _busyMessage != null;

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tableListProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('จัดการพนักงานเสิร์ฟ'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _isBusy
                ? null
                : () async {
                    final branchId =
                        ref.read(selectedBranchProvider)?.branchId;
                    await ref
                        .read(tableListProvider.notifier)
                        .refresh(branchId: branchId);
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: tablesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data: (tables) {
                final occupiedTables =
                    tables.where((t) => t.isOccupied).toList();

                if (occupiedTables.isEmpty) {
                  return _EmptyState();
                }

                // จัดกลุ่มตามพนักงาน
                final grouped = <String, List<DiningTableModel>>{};
                for (final t in occupiedTables) {
                  final key = t.waiterName ?? '_unassigned';
                  (grouped[key] ??= []).add(t);
                }

                // เรียงกลุ่ม: unassigned ขึ้นก่อน
                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) {
                    if (a == '_unassigned') return -1;
                    if (b == '_unassigned') return 1;
                    return a.compareTo(b);
                  });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryBar(
                      totalTables: occupiedTables.length,
                      assignedCount: occupiedTables
                          .where((t) => t.waiterName != null)
                          .length,
                      waiterCount: grouped.keys
                          .where((k) => k != '_unassigned')
                          .length,
                    ),
                    const SizedBox(height: 16),
                    ...sortedKeys.map((key) => _WaiterGroup(
                          waiterName:
                              key == '_unassigned' ? null : key,
                          tables: grouped[key]!,
                          onAssign: (table) =>
                              _showAssignDialog(context, table),
                        )),
                  ],
                );
              },
            ),
          ),
          BusyOverlay(message: _busyMessage),
        ],
      ),
    );
  }

  Future<void> _showAssignDialog(
      BuildContext context, DiningTableModel table) async {
    final nameCtrl =
        TextEditingController(text: table.waiterName ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              setState(() => _busyMessage = 'กำลังกำหนดพนักงานเสิร์ฟ...');
              try {
                await ref
                    .read(tableListProvider.notifier)
                    .assignWaiter(table.tableId, name);
                final branchId =
                    ref.read(selectedBranchProvider)?.branchId;
                await ref
                    .read(tableListProvider.notifier)
                    .refresh(branchId: branchId);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text('กำหนดพนักงาน $name แล้ว'),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                    content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง'),
                    backgroundColor: AppTheme.errorColor,
                  ));
                }
              } finally {
                if (mounted) setState(() => _busyMessage = null);
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
  }
}

// ── Summary Bar ────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int totalTables;
  final int assignedCount;
  final int waiterCount;
  const _SummaryBar({
    required this.totalTables,
    required this.assignedCount,
    required this.waiterCount,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatCard(
            label: 'โต๊ะที่เปิด',
            value: '$totalTables',
            color: AppTheme.primaryColor,
            icon: Icons.table_restaurant,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'มีพนักงาน',
            value: '$assignedCount',
            color: AppTheme.successColor,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'พนักงาน',
            value: '$waiterCount คน',
            color: AppTheme.infoColor,
            icon: Icons.people,
          ),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Waiter Group ───────────────────────────────────────────────────────────────

class _WaiterGroup extends StatelessWidget {
  final String? waiterName;
  final List<DiningTableModel> tables;
  final void Function(DiningTableModel) onAssign;
  const _WaiterGroup({
    required this.waiterName,
    required this.tables,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isUnassigned = waiterName == null;
    final headerColor =
        isUnassigned ? AppTheme.warningColor : AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border.all(color: headerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isUnassigned ? Icons.person_off : Icons.badge,
                  size: 18,
                  color: headerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isUnassigned
                      ? 'ยังไม่ได้กำหนดพนักงาน'
                      : waiterName!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tables.length} โต๊ะ',
                    style: TextStyle(
                        fontSize: 12,
                        color: headerColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Table cards
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border.all(color: headerColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: tables
                  .asMap()
                  .entries
                  .map((e) => _TableRow(
                        table: e.value,
                        isLast: e.key == tables.length - 1,
                        onAssign: () => onAssign(e.value),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final DiningTableModel table;
  final bool isLast;
  final VoidCallback onAssign;
  const _TableRow({
    required this.table,
    required this.isLast,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final seatedDuration = table.sessionOpenedAt != null
        ? DateTime.now().difference(table.sessionOpenedAt!)
        : null;

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: Text(
              table.displayName.length > 3
                  ? table.displayName.substring(0, 3)
                  : table.displayName,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor),
            ),
          ),
          title: Text(
            table.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.people, size: 12, color: Colors.grey),
              const SizedBox(width: 3),
              Text(
                '${table.activeGuestCount ?? 0} คน',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (seatedDuration != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 3),
                Text(
                  _formatDuration(seatedDuration),
                  style: TextStyle(
                    fontSize: 12,
                    color: seatedDuration.inMinutes > 90
                        ? AppTheme.errorColor
                        : Colors.grey,
                  ),
                ),
              ],
              if (table.zoneName != null) ...[
                const SizedBox(width: 8),
                Text(
                  table.zoneName!,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ],
          ),
          trailing: TextButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('เปลี่ยน'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, color: Colors.grey.shade100),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$hชม. $mน.';
    return '$mน.';
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโต๊ะที่เปิดอยู่',
              style: TextStyle(
                  fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'พนักงานเสิร์ฟจะแสดงขึ้นเมื่อมีโต๊ะที่เปิดอยู่',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
}
