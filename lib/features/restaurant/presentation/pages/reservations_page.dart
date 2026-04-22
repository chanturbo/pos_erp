import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/busy_overlay.dart';
import '../../data/models/reservation_model.dart';
import '../providers/reservation_provider.dart';
import '../providers/table_provider.dart';
import 'reservation_form_page.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  String? _busyMessage;

  bool get _isBusy => _busyMessage != null;

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(reservationsProvider);
    final date = ref.watch(reservationDateProvider);
    final statusFilter = ref.watch(reservationStatusFilterProvider);
    final searchQuery = ref.watch(reservationSearchQueryProvider);
    final fmt = DateFormat('d MMM yyyy', 'th');

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('การจองโต๊ะ'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isBusy
                ? null
                : () => _runBusy(
                    'กำลังรีเฟรชรายการจอง...',
                    () => ref.read(reservationsProvider.notifier).refresh(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isBusy ? null : () => _openForm(context, ref),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: Column(
              children: [
                _DateBar(date: date, fmt: fmt),
                _SearchBar(searchQuery: searchQuery),
                _StatusFilterBar(statusFilter: statusFilter),
                Expanded(
                  child: reservationsAsync.when(
                    data: (list) => list.isEmpty
                        ? _EmptyState(onAdd: () => _openForm(context, ref))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _ReservationCard(
                              reservation: list[i],
                              onAction: (action) =>
                                  _handleAction(context, ref, list[i], action),
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                  ),
                ),
              ],
            ),
          ),
          BusyOverlay(message: _busyMessage),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    ReservationModel? existing,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormPage(existing: existing),
      ),
    );
    if (!mounted) return;
    await ref.read(reservationsProvider.notifier).refresh();
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ReservationModel r,
    String action,
  ) async {
    final notifier = ref.read(reservationsProvider.notifier);
    if (action == 'edit') {
      await _openForm(context, ref, existing: r);
      return;
    }
    if (action == 'confirm') {
      final ok = await _runBusy(
        'กำลังอัปเดตการจอง...',
        () => notifier.confirm(r.reservationId),
      );
      if (!mounted) return;
      _showFeedback(
        ok ? 'ยืนยันการจอง ${r.customerName} แล้ว' : 'ยืนยันการจองไม่สำเร็จ',
        success: ok,
      );
      return;
    }
    if (action == 'cancel') {
      final confirmed = await _confirmDialog(
        context,
        'ยืนยันการยกเลิก',
        'ยกเลิกการจองของ ${r.customerName}?',
      );
      if (!confirmed) return;
      final ok = await _runBusy(
        'กำลังยกเลิกการจอง...',
        () => notifier.cancel(r.reservationId),
      );
      if (!mounted) return;
      _showFeedback(
        ok ? 'ยกเลิกการจอง ${r.customerName} แล้ว' : 'ยกเลิกการจองไม่สำเร็จ',
        success: ok,
      );
      return;
    }
    if (action == 'no_show') {
      final ok = await _runBusy(
        'กำลังบันทึกสถานะไม่มาตามนัด...',
        () => notifier.noShow(r.reservationId),
      );
      if (!mounted) return;
      _showFeedback(
        ok ? 'บันทึกสถานะไม่มาตามนัดแล้ว' : 'บันทึกสถานะไม่มาตามนัดไม่สำเร็จ',
        success: ok,
      );
      return;
    }
    if (action == 'seat') {
      await _seatDialog(context, ref, r);
    }
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

  void _showFeedback(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDialog(
    BuildContext context,
    String title,
    String msg,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _seatDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationModel r,
  ) async {
    final tablesAsync = ref.read(tableListProvider);
    final tables = tablesAsync.asData?.value ?? [];
    final available =
        tables.where((t) => t.isAvailable || t.tableId == r.tableId).toList()
          ..sort((a, b) => a.tableNo.compareTo(b.tableNo));

    if (available.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่มีโต๊ะว่าง')));
      }
      return;
    }

    String? selectedId =
        r.tableId ?? (available.isNotEmpty ? available.first.tableId : null);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('นำลูกค้า ${r.customerName} เข้านั่ง'),
          content: DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: selectedId,
            decoration: const InputDecoration(
              labelText: 'เลือกโต๊ะ',
              border: OutlineInputBorder(),
            ),
            items: available
                .map(
                  (t) => DropdownMenuItem(
                    value: t.tableId,
                    child: Text(
                      '${t.displayName}${t.zoneName != null ? ' (${t.zoneName})' : ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setSt(() => selectedId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final branch = r.branchId;
                      final result = await _runBusy(
                        'กำลังนำลูกค้าเข้านั่ง...',
                        () => ref
                            .read(reservationsProvider.notifier)
                            .seat(r.reservationId, selectedId!, branch),
                      );
                      if (!context.mounted) return;
                      _showFeedback(
                        result != null
                            ? 'นำลูกค้า ${r.customerName} เข้านั่งแล้ว'
                            : 'เกิดข้อผิดพลาดระหว่างนำลูกค้าเข้านั่ง',
                        success: result != null,
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('เข้านั่ง'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  final String searchQuery;
  const _SearchBar({required this.searchQuery});

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child: TextField(
      controller: _controller,
      onChanged: (value) =>
          ref.read(reservationSearchQueryProvider.notifier).state = value,
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อลูกค้า หรือเบอร์โทร',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                onPressed: () =>
                    ref.read(reservationSearchQueryProvider.notifier).state =
                        '',
                icon: const Icon(Icons.close),
              ),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

// ── Date Bar ──────────────────────────────────────────────────────────────────

class _DateBar extends ConsumerWidget {
  final DateTime date;
  final DateFormat fmt;
  const _DateBar({required this.date, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(reservationDateProvider.notifier).state =
              date.subtract(const Duration(days: 1)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) {
                ref.read(reservationDateProvider.notifier).state = picked;
              }
            },
            child: Text(
              fmt.format(date),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => ref.read(reservationDateProvider.notifier).state =
              date.add(const Duration(days: 1)),
        ),
      ],
    ),
  );
}

// ── Status Filter ─────────────────────────────────────────────────────────────

class _StatusFilterBar extends ConsumerWidget {
  final String? statusFilter;
  const _StatusFilterBar({required this.statusFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      (null, 'ทั้งหมด'),
      ('PENDING', 'รอยืนยัน'),
      ('CONFIRMED', 'ยืนยันแล้ว'),
      ('SEATED', 'เข้านั่งแล้ว'),
      ('CANCELLED', 'ยกเลิก'),
      ('NO_SHOW', 'ไม่มา'),
    ];
    return Container(
      height: 40,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters
            .map(
              (f) => _FilterChip(
                label: f.$2,
                selected: statusFilter == f.$1,
                onTap: () =>
                    ref.read(reservationStatusFilterProvider.notifier).state =
                        f.$1,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

// ── Reservation Card ──────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final void Function(String action) onAction;
  const _ReservationCard({required this.reservation, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final timeFmt = DateFormat('HH:mm');
    final statusInfo = _statusInfo(r.status);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusInfo.$1.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusInfo.$2,
                    style: TextStyle(
                      color: statusInfo.$1,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeFmt.format(r.reservationTime),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  r.customerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.group, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${r.partySize} คน',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            if (r.customerPhone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    r.customerPhone!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (r.tableName != null || r.tableId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.table_restaurant,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.tableName ?? r.tableId!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _ActionButtons(reservation: r, onAction: onAction),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) => switch (status) {
    'PENDING' => (Colors.orange, 'รอยืนยัน'),
    'CONFIRMED' => (AppTheme.primaryColor, 'ยืนยันแล้ว'),
    'SEATED' => (AppTheme.successColor, 'เข้านั่งแล้ว'),
    'CANCELLED' => (AppTheme.errorColor, 'ยกเลิก'),
    'NO_SHOW' => (Colors.grey, 'ไม่มา'),
    _ => (Colors.grey, status),
  };
}

class _ActionButtons extends StatelessWidget {
  final ReservationModel reservation;
  final void Function(String) onAction;
  const _ActionButtons({required this.reservation, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    if (r.isSeated || r.isCancelled || r.isNoShow) {
      return Text(
        r.isSeated
            ? 'ลูกค้าเข้านั่งแล้ว'
            : r.isCancelled
            ? 'ยกเลิกการจอง'
            : 'ไม่มาตามนัด',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onAction('edit'),
          icon: const Icon(Icons.edit, size: 14),
          label: const Text('แก้ไข'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        if (r.isPending)
          FilledButton.icon(
            onPressed: () => onAction('confirm'),
            icon: const Icon(Icons.check, size: 14),
            label: const Text('ยืนยัน'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        FilledButton.icon(
          onPressed: () => onAction('seat'),
          icon: const Icon(Icons.chair, size: 14),
          label: const Text('เข้านั่ง'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        TextButton(
          onPressed: () => onAction('no_show'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('ไม่มา'),
        ),
        TextButton(
          onPressed: () => onAction('cancel'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.event_seat, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'ไม่มีการจองในวันนี้',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มการจอง'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        ),
      ],
    ),
  );
}
