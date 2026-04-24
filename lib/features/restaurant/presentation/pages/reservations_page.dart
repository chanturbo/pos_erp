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
    final reservations = reservationsAsync.asData?.value ?? const [];

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : () => _openForm(context, ref),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('เพิ่มการจอง', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ReservationSummaryPanel(
                    date: date,
                    fmt: fmt,
                    reservations: reservations,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _ReservationFiltersPanel(
                    date: date,
                    fmt: fmt,
                    searchQuery: searchQuery,
                    statusFilter: statusFilter,
                  ),
                ),
                Expanded(
                  child: reservationsAsync.when(
                    data: (list) => list.isEmpty
                        ? _EmptyState(onAdd: () => _openForm(context, ref))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ReservationCard(
                              reservation: list[i],
                              onAction: (action) =>
                                  _handleAction(context, ref, list[i], action),
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorState(
                      message: '$e',
                      onRetry: () =>
                          ref.read(reservationsProvider.notifier).refresh(),
                    ),
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
            initialValue: selectedId,
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

class _ReservationSummaryPanel extends StatelessWidget {
  const _ReservationSummaryPanel({
    required this.date,
    required this.fmt,
    required this.reservations,
  });

  final DateTime date;
  final DateFormat fmt;
  final List<ReservationModel> reservations;

  @override
  Widget build(BuildContext context) {
    final pending = reservations.where((r) => r.isPending).length;
    final confirmed = reservations.where((r) => r.isConfirmed).length;
    final seated = reservations.where((r) => r.isSeated).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ภาพรวมการจอง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'รายการจองประจำวันที่ ${fmt.format(date)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryMetric(
                label: 'รอยืนยัน',
                value: '$pending',
                icon: Icons.hourglass_top_rounded,
                color: AppTheme.warningColor,
                background: AppTheme.warningContainer,
              ),
              _SummaryMetric(
                label: 'ยืนยันแล้ว',
                value: '$confirmed',
                icon: Icons.check_circle_outline,
                color: AppTheme.primaryColor,
                background: AppTheme.primaryContainer,
              ),
              _SummaryMetric(
                label: 'เข้านั่งแล้ว',
                value: '$seated',
                icon: Icons.event_seat,
                color: AppTheme.successColor,
                background: AppTheme.successContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationFiltersPanel extends StatelessWidget {
  const _ReservationFiltersPanel({
    required this.date,
    required this.fmt,
    required this.searchQuery,
    required this.statusFilter,
  });

  final DateTime date;
  final DateFormat fmt;
  final String searchQuery;
  final String? statusFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _DateBar(date: date, fmt: fmt),
          const SizedBox(height: 12),
          _SearchBar(searchQuery: searchQuery),
          const SizedBox(height: 12),
          _StatusFilterBar(statusFilter: statusFilter),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.searchQuery});

  final String searchQuery;

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
  Widget build(BuildContext context) => TextField(
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
                  ref.read(reservationSearchQueryProvider.notifier).state = '',
              icon: const Icon(Icons.close),
            ),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date, required this.fmt});

  final DateTime date;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(reservationDateProvider.notifier).state =
              date.subtract(const Duration(days: 1)),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.headerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmt.format(date),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyColor,
                    ),
                  ),
                ],
              ),
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

class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar({required this.statusFilter});

  final String? statusFilter;

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
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
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
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.12)
            : AppTheme.headerBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? AppTheme.primaryColor : AppTheme.navyColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onAction});

  final ReservationModel reservation;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final timeFmt = DateFormat('HH:mm');
    final statusInfo = _statusInfo(r.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusInfo.$1.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusInfo.$2,
                              style: TextStyle(
                                color: statusInfo.$1,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (r.tableName != null || r.tableId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.infoContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                r.tableName ?? r.tableId!,
                                style: const TextStyle(
                                  color: AppTheme.infoColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.headerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    timeFmt.format(r.reservationTime),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.group_outlined,
                  label: '${r.partySize} คน',
                ),
                if (r.customerPhone != null && r.customerPhone!.isNotEmpty)
                  _InfoChip(
                    icon: Icons.phone_outlined,
                    label: r.customerPhone!,
                  ),
                if (r.tableName != null || r.tableId != null)
                  _InfoChip(
                    icon: Icons.table_restaurant_outlined,
                    label: r.tableName ?? r.tableId!,
                  ),
              ],
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.navyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _ActionButtons(reservation: r, onAction: onAction),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) => switch (status) {
    'PENDING' => (AppTheme.warningColor, 'รอยืนยัน'),
    'CONFIRMED' => (AppTheme.primaryColor, 'ยืนยันแล้ว'),
    'SEATED' => (AppTheme.successColor, 'เข้านั่งแล้ว'),
    'CANCELLED' => (AppTheme.errorColor, 'ยกเลิก'),
    'NO_SHOW' => (AppTheme.subtextColor, 'ไม่มา'),
    _ => (AppTheme.subtextColor, status),
  };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppTheme.subtextColor),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppTheme.subtextColor),
      ),
    ],
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.reservation, required this.onAction});

  final ReservationModel reservation;
  final void Function(String) onAction;

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
        style: const TextStyle(color: AppTheme.subtextColor, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
            foregroundColor: AppTheme.subtextColor,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_seat, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'ไม่มีการจองในวันนี้',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'เพิ่มการจองล่วงหน้าเพื่อให้ทีมหน้าร้านเตรียมโต๊ะได้ทัน',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.subtextColor),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มการจอง'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          const Text(
            'โหลดรายการจองไม่สำเร็จ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.subtextColor),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    ),
  );
}
