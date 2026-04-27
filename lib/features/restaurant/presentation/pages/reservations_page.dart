import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/busy_overlay.dart';
import '../../data/models/reservation_model.dart';
import '../providers/reservation_provider.dart';
import '../providers/table_provider.dart';
import 'reservation_form_page.dart';

const _kReservationsRefreshSeconds = 30;

// ─── Page ─────────────────────────────────────────────────────────────────────

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  String? _busyMessage;
  Timer? _countdownTimer;
  int _countdown = _kReservationsRefreshSeconds;
  bool _showDailyList = false;

  bool get _isBusy => _busyMessage != null;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _kReservationsRefreshSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdown = _kReservationsRefreshSeconds;
          unawaited(ref.read(reservationsProvider.notifier).refresh());
          unawaited(ref.read(reservationCalendarProvider.notifier).refresh());
        }
      });
    });
  }

  void _refreshAll() {
    _startCountdown();
    unawaited(
      _runBusy('กำลังรีเฟรชรายการจอง...', () async {
        await Future.wait([
          ref.read(reservationsProvider.notifier).refresh(),
          ref.read(reservationCalendarProvider.notifier).refresh(),
        ]);
      }),
    );
  }

  Future<void> _pullRefresh() =>
      ref.read(reservationsProvider.notifier).refresh();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(reservationsProvider);
    final calendarAsync = ref.watch(reservationCalendarProvider);
    final date = ref.watch(reservationDateProvider);
    final calendarMonth = ref.watch(reservationCalendarMonthProvider);
    final statusFilter = ref.watch(reservationStatusFilterProvider);
    final searchQuery = ref.watch(reservationSearchQueryProvider);
    final fmt = DateFormat('d MMM yyyy', 'th');
    final monthFmt = DateFormat('MMMM yyyy', 'th');
    final reservations = _showDailyList
        ? reservationsAsync.asData?.value ?? const []
        : calendarAsync.asData?.value ?? const [];

    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.navyDark : AppTheme.navyColor,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: _ReservationTitleBar(
          countdown: _countdown,
          onAdd: _isBusy ? null : () => _openForm(context, ref),
          onRefresh: _isBusy ? null : _refreshAll,
          searchQuery: searchQuery,
          searchFillColor: isDark ? AppTheme.darkElement : Colors.white,
        ),
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isBusy,
            child: Column(
              children: [
                _ReservationSummaryBar(reservations: reservations),
                if (_showDailyList)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _DateBar(date: date, fmt: fmt),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _showDailyList
                        ? reservationsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => _ReservationMessageState(
                              icon: Icons.event_busy,
                              title: 'โหลดรายการจองไม่สำเร็จ',
                              message: '$e',
                              iconColor: AppTheme.errorColor,
                              action: TextButton.icon(
                                onPressed: () => ref
                                    .read(reservationsProvider.notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('ลองใหม่'),
                              ),
                            ),
                            data: (list) => _ReservationListColumn(
                              reservations: list,
                              statusFilter: statusFilter,
                              dateLabel: fmt.format(date),
                              onBackToMonth: () =>
                                  setState(() => _showDailyList = false),
                              onAction: (r, action) =>
                                  _handleAction(context, ref, r, action),
                              onAdd: () => _openForm(context, ref),
                              onRefresh: _pullRefresh,
                            ),
                          )
                        : calendarAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => _ReservationMessageState(
                              icon: Icons.calendar_month,
                              title: 'โหลดปฏิทินการจองไม่สำเร็จ',
                              message: '$e',
                              iconColor: AppTheme.errorColor,
                              action: TextButton.icon(
                                onPressed: () => ref
                                    .read(reservationCalendarProvider.notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('ลองใหม่'),
                              ),
                            ),
                            data: (list) => _ReservationMonthCalendar(
                              month: calendarMonth,
                              reservations: list,
                              monthFmt: monthFmt,
                              onSelectDay: (picked) {
                                ref
                                        .read(reservationDateProvider.notifier)
                                        .state =
                                    picked;
                                setState(() => _showDailyList = true);
                              },
                            ),
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
    await ref.read(reservationCalendarProvider.notifier).refresh();
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
      if (ok) await ref.read(reservationCalendarProvider.notifier).refresh();
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
      if (ok) await ref.read(reservationCalendarProvider.notifier).refresh();
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
      if (ok) await ref.read(reservationCalendarProvider.notifier).refresh();
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
      if (mounted) setState(() => _busyMessage = null);
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
                      if (result != null) {
                        await ref
                            .read(reservationCalendarProvider.notifier)
                            .refresh();
                      }
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

class _ReservationTitleBar extends StatelessWidget {
  const _ReservationTitleBar({
    required this.countdown,
    required this.onAdd,
    required this.onRefresh,
    required this.searchQuery,
    required this.searchFillColor,
  });

  final int countdown;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;
  final String searchQuery;
  final Color searchFillColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final veryCompact = constraints.maxWidth < 430;

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.event_note,
                size: 18,
                color: AppTheme.primaryLight,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ภาพรวมการจอง',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 160 : 200),
              child: _SearchBar(
                searchQuery: searchQuery,
                fillColor: searchFillColor,
              ),
            ),
            const SizedBox(width: 8),
            _ReservationAddButton(onTap: onAdd, compact: veryCompact),
            const SizedBox(width: 6),
            _CountdownRefreshButton(
              countdown: countdown,
              total: _kReservationsRefreshSeconds,
              onTap: onRefresh,
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

class _ReservationAddButton extends StatelessWidget {
  const _ReservationAddButton({required this.onTap, required this.compact});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: compact
          ? const SizedBox.shrink()
          : const Text(
              'เพิ่มการจอง',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
      style: ElevatedButton.styleFrom(
        backgroundColor: compact
            ? (isDark ? AppTheme.darkElement : AppTheme.navyLight)
            : AppTheme.primaryColor,
        foregroundColor: compact ? Colors.white70 : Colors.white,
        disabledBackgroundColor: compact
            ? (isDark ? AppTheme.darkElement : AppTheme.navyLight).withValues(
                alpha: 0.45,
              )
            : AppTheme.primaryColor.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white38,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 13,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: compact
            ? BorderSide(color: Colors.white.withValues(alpha: 0.16))
            : null,
        elevation: 0,
      ),
    );
  }
}

// ─── Summary Bar ─────────────────────────────────────────────────────────────

class _ReservationSummaryBar extends ConsumerWidget {
  const _ReservationSummaryBar({required this.reservations});

  final List<ReservationModel> reservations;

  static const _tabs = [
    (value: null as String?, label: 'ทั้งหมด'),
    (value: 'PENDING' as String?, label: 'รอยืนยัน'),
    (value: 'CONFIRMED' as String?, label: 'ยืนยันแล้ว'),
    (value: 'SEATED' as String?, label: 'เข้านั่งแล้ว'),
    (value: 'CANCELLED' as String?, label: 'ยกเลิก'),
    (value: 'NO_SHOW' as String?, label: 'ไม่มา'),
  ];

  static Color _tabColor(String? status, BuildContext context) =>
      switch (status) {
        'PENDING' => AppTheme.warningColor,
        'CONFIRMED' => AppTheme.primaryColor,
        'SEATED' => AppTheme.successColor,
        'CANCELLED' => AppTheme.errorColor,
        'NO_SHOW' => AppTheme.subtextColor,
        _ =>
          AppTheme.isDark(context)
              ? const Color(0xFFE0E0E0)
              : AppTheme.navyColor,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(reservationStatusFilterProvider);
    final isDark = AppTheme.isDark(context);

    final pending = reservations.where((r) => r.isPending).length;
    final confirmed = reservations.where((r) => r.isConfirmed).length;
    final seated = reservations.where((r) => r.isSeated).length;

    final chipBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = AppTheme.borderColorOf(context);

    Widget filterChip(String? value, String label) {
      final selected = statusFilter == value;
      final color = _tabColor(value, context);
      return GestureDetector(
        onTap: () =>
            ref.read(reservationStatusFilterProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppTheme.textColorOf(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget statChip(String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? color.withValues(alpha: 0.78)
                    : color.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.88) : color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (int i = 0; i < _tabs.length; i++) ...[
                  filterChip(_tabs[i].value, _tabs[i].label),
                  if (i < _tabs.length - 1) const SizedBox(width: 8),
                ],
                const SizedBox(width: 16),
                statChip('รอยืนยัน', pending, AppTheme.warningColor),
                const SizedBox(width: 8),
                statChip('ยืนยันแล้ว', confirmed, AppTheme.primaryColor),
                const SizedBox(width: 8),
                statChip('เข้านั่งแล้ว', seated, AppTheme.successColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reservation List Column (mirrors _TakeawayOrderColumn / _QueueColumn) ────

class _ReservationListColumn extends StatelessWidget {
  const _ReservationListColumn({
    required this.reservations,
    required this.statusFilter,
    required this.onAction,
    required this.onAdd,
    required this.onRefresh,
    this.dateLabel,
    this.onBackToMonth,
  });

  final List<ReservationModel> reservations;
  final String? statusFilter;
  final void Function(ReservationModel r, String action) onAction;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;
  final String? dateLabel;
  final VoidCallback? onBackToMonth;

  (Color, Color, String) _headerStyleOf(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return switch (statusFilter) {
      'PENDING' => (
        isDark
            ? AppTheme.warningColor.withValues(alpha: 0.16)
            : AppTheme.warningContainer,
        AppTheme.warningColor,
        'รอยืนยัน',
      ),
      'CONFIRMED' => (
        isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.16)
            : AppTheme.primaryContainer,
        AppTheme.primaryColor,
        'ยืนยันแล้ว',
      ),
      'SEATED' => (
        isDark
            ? AppTheme.successColor.withValues(alpha: 0.16)
            : AppTheme.successContainer,
        AppTheme.successColor,
        'เข้านั่งแล้ว',
      ),
      'CANCELLED' => (
        AppTheme.errorColor.withValues(alpha: 0.10),
        AppTheme.errorColor,
        'ยกเลิก',
      ),
      'NO_SHOW' => (
        AppTheme.subtextColor.withValues(alpha: 0.10),
        AppTheme.subtextColor,
        'ไม่มา',
      ),
      _ => (
        isDark ? AppTheme.darkCard : AppTheme.headerBg,
        isDark ? const Color(0xFFE0E0E0) : AppTheme.navyColor,
        'ทั้งหมด',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (headerBg, headerColor, headerTitle) = _headerStyleOf(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                if (onBackToMonth != null) ...[
                  IconButton(
                    tooltip: 'กลับไปมุมมองเดือน',
                    onPressed: onBackToMonth,
                    icon: const Icon(Icons.arrow_back),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: headerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: TextStyle(
                          color: AppTheme.textColorOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (dateLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateLabel!,
                          style: TextStyle(
                            color: AppTheme.mutedTextOf(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '${reservations.length}',
                    style: TextStyle(
                      color: headerColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: reservations.isEmpty
                ? _ReservationMessageState(
                    icon: Icons.event_seat,
                    title: 'ไม่มีการจองในช่วงนี้',
                    message:
                        'เพิ่มการจองล่วงหน้าเพื่อให้ทีมหน้าร้านเตรียมโต๊ะได้ทัน',
                    iconColor: AppTheme.iconSubtleOf(context),
                    action: FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มการจอง'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: reservations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ReservationCard(
                        reservation: reservations[i],
                        onAction: (action) => onAction(reservations[i], action),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Message State (mirrors _KdsMessageState) ─────────────────────────────────

class _ReservationMessageState extends StatelessWidget {
  const _ReservationMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.iconColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 200;
        final iconSize = compactHeight ? 40.0 : 56.0;
        final padding = compactHeight ? 16.0 : 24.0;
        final gapLarge = compactHeight ? 10.0 : 14.0;
        final gapSmall = compactHeight ? 6.0 : 8.0;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppTheme.borderColorOf(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: iconSize, color: iconColor),
                    SizedBox(height: gapLarge),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compactHeight ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColorOf(context),
                      ),
                    ),
                    SizedBox(height: gapSmall),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compactHeight ? 12 : 13,
                        color: AppTheme.mutedTextOf(context),
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 20),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Date Bar ─────────────────────────────────────────────────────────────────

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date, required this.fmt});

  final DateTime date;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(reservationDateProvider.notifier).state =
              date.subtract(const Duration(days: 1)),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: InkWell(
            borderRadius: AppRadius.md,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface3Of(context),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppTheme.borderColorOf(context)),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColorOf(context),
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
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _ReservationMonthCalendar extends ConsumerWidget {
  const _ReservationMonthCalendar({
    required this.month,
    required this.reservations,
    required this.monthFmt,
    required this.onSelectDay,
  });

  final DateTime month;
  final List<ReservationModel> reservations;
  final DateFormat monthFmt;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdayLabels = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  Color _statusColor(ReservationModel reservation) {
    if (reservation.isPending) return AppTheme.warningColor;
    if (reservation.isConfirmed) return AppTheme.primaryColor;
    if (reservation.isSeated) return AppTheme.successColor;
    if (reservation.isCancelled) return AppTheme.errorColor;
    return AppTheme.subtextColor;
  }

  String _timeText(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Map<DateTime, List<ReservationModel>> _groupByDay() {
    final grouped = <DateTime, List<ReservationModel>>{};
    for (final reservation in reservations) {
      final time = reservation.reservationTime;
      final day = DateTime(time.year, time.month, time.day);
      grouped.putIfAbsent(day, () => []).add(reservation);
    }
    for (final dayReservations in grouped.values) {
      dayReservations.sort(
        (a, b) => a.reservationTime.compareTo(b.reservationTime),
      );
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedMonth = DateTime(month.year, month.month);
    final firstDay = DateTime(normalizedMonth.year, normalizedMonth.month);
    final daysInMonth = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    final leadingEmptyDays = firstDay.weekday % 7;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rowCount = totalCells <= 35 ? 5 : 6;
    final grouped = _groupByDay();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? AppTheme.navyDark
                  : AppTheme.headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'เดือนก่อนหน้า',
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () =>
                      ref
                          .read(reservationCalendarMonthProvider.notifier)
                          .state = DateTime(
                        normalizedMonth.year,
                        normalizedMonth.month - 1,
                      ),
                  visualDensity: VisualDensity.compact,
                  color: AppTheme.textColorOf(context),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: AppRadius.sm,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: normalizedMonth,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        ref
                            .read(reservationCalendarMonthProvider.notifier)
                            .state = DateTime(
                          picked.year,
                          picked.month,
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          monthFmt.format(normalizedMonth),
                          style: TextStyle(
                            color: AppTheme.textColorOf(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '${reservations.length} จอง',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'เดือนถัดไป',
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () =>
                      ref
                          .read(reservationCalendarMonthProvider.notifier)
                          .state = DateTime(
                        normalizedMonth.year,
                        normalizedMonth.month + 1,
                      ),
                  visualDensity: VisualDensity.compact,
                  color: AppTheme.textColorOf(context),
                ),
              ],
            ),
          ),
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surface3Of(context),
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColorOf(context)),
              ),
            ),
            child: Row(
              children: _weekdayLabels
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppTheme.mutedTextOf(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = constraints.maxHeight / rowCount;
                final ratio = cellWidth / cellHeight;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: ratio,
                  ),
                  itemCount: rowCount * 7,
                  itemBuilder: (context, index) {
                    final dayNumber = index - leadingEmptyDays + 1;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.isDark(context)
                              ? AppTheme.darkBg
                              : AppTheme.surfaceColor,
                          border: Border(
                            right: BorderSide(
                              color: AppTheme.borderColorOf(context),
                            ),
                            bottom: BorderSide(
                              color: AppTheme.borderColorOf(context),
                            ),
                          ),
                        ),
                      );
                    }

                    final day = DateTime(
                      normalizedMonth.year,
                      normalizedMonth.month,
                      dayNumber,
                    );
                    final dayReservations = grouped[day] ?? const [];
                    final isToday = day == todayDate;

                    return InkWell(
                      onTap: () => onSelectDay(day),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.primaryColor.withValues(alpha: 0.05)
                              : AppTheme.cardColor(context),
                          border: Border(
                            right: BorderSide(
                              color: AppTheme.borderColorOf(context),
                            ),
                            bottom: BorderSide(
                              color: AppTheme.borderColorOf(context),
                            ),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, cellConstraints) {
                            final compact = cellConstraints.maxHeight < 48;
                            final dayLabel = Container(
                              width: compact ? 18 : 24,
                              height: compact ? 18 : 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$dayNumber',
                                style: TextStyle(
                                  color: isToday
                                      ? Colors.white
                                      : AppTheme.textColorOf(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 10 : 12,
                                ),
                              ),
                            );

                            if (compact) {
                              return Row(
                                children: [
                                  dayLabel,
                                  if (dayReservations.isNotEmpty) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${dayReservations.length}',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                dayLabel,
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Column(
                                    children: [
                                      ...dayReservations
                                          .take(3)
                                          .map(
                                            (
                                              reservation,
                                            ) => _CalendarReservationChip(
                                              text:
                                                  '${_timeText(reservation.reservationTime)} '
                                                  '${reservation.customerName}',
                                              color: _statusColor(reservation),
                                            ),
                                          ),
                                      if (dayReservations.length > 3)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            '+${dayReservations.length - 3} เพิ่มเติม',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.mutedTextOf(
                                                context,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarReservationChip extends StatelessWidget {
  const _CalendarReservationChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.xs,
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.searchQuery, this.fillColor});

  final String searchQuery;
  final Color? fillColor;

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
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) =>
          ref.read(reservationSearchQueryProvider.notifier).state = value,
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อลูกค้า หรือเบอร์โทร',
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppTheme.mutedTextOf(context),
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: AppTheme.iconOf(context),
        ),
        suffixIcon: widget.searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                onPressed: () =>
                    ref.read(reservationSearchQueryProvider.notifier).state =
                        '',
                icon: const Icon(Icons.close, size: 18),
              ),
        filled: true,
        fillColor: widget.fillColor ?? AppTheme.surface3Of(context),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}

// ─── Countdown Refresh Button (mirrors KDS) ───────────────────────────────────

class _CountdownRefreshButton extends StatefulWidget {
  const _CountdownRefreshButton({
    required this.countdown,
    required this.total,
    required this.onTap,
  });

  final int countdown;
  final int total;
  final VoidCallback? onTap;

  @override
  State<_CountdownRefreshButton> createState() =>
      _CountdownRefreshButtonState();
}

class _CountdownRefreshButtonState extends State<_CountdownRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onTap == null) return;
    _spinCtrl.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.countdown / widget.total;
    final isUrgent = widget.countdown <= 5;

    return Tooltip(
      message: 'อัพเดทใน ${widget.countdown} วิ  (กดเพื่อรีเฟรชทันที)',
      child: InkWell(
        onTap: widget.onTap != null ? _tap : null,
        borderRadius: AppRadius.sm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: RotationTransition(
                  turns: _spinCtrl,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white24,
                        color: isUrgent ? Colors.orangeAccent : Colors.white,
                      ),
                      const Icon(Icons.refresh, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.countdown}s',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? Colors.orangeAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reservation Card ─────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onAction});

  final ReservationModel reservation;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final timeFmt = DateFormat('HH:mm');
    final statusInfo = _statusInfo(r.status);
    final isDark = AppTheme.isDark(context);
    final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = AppTheme.borderColorOf(context);
    final initial = r.customerName.trim().isNotEmpty
        ? r.customerName.trim().characters.first.toUpperCase()
        : '?';
    final avatarPalette = [
      AppTheme.primaryColor,
      AppTheme.infoColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.purpleColor,
      AppTheme.tealColor,
    ];
    final avatarColor =
        avatarPalette[r.customerName.isEmpty
            ? 0
            : r.customerName.codeUnitAt(0) % avatarPalette.length];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: avatarColor,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusInfo.$1,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBg, width: 1.5),
                        ),
                        child: Icon(
                          statusInfo.$3,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.customerName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColorOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ReservationStatusBadge(
                            label: statusInfo.$2,
                            color: statusInfo.$1,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            timeFmt.format(r.reservationTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.primaryLight
                                  : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${r.partySize} คน',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedTextOf(context),
                            ),
                          ),
                          if (r.tableName != null || r.tableId != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'โต๊ะ: ${r.tableName ?? r.tableId!}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mutedTextOf(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (r.customerPhone != null &&
                          r.customerPhone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _InfoChip(
                          icon: Icons.phone_outlined,
                          label: r.customerPhone!,
                        ),
                      ],
                      if (r.notes != null && r.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 12,
                              color: AppTheme.warningColor.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                r.notes!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mutedTextOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionButtons(reservation: r, onAction: onAction),
          ],
        ),
      ),
    );
  }

  (Color, String, IconData) _statusInfo(String status) => switch (status) {
    'PENDING' => (AppTheme.warningColor, 'รอยืนยัน', Icons.schedule_rounded),
    'CONFIRMED' => (AppTheme.primaryColor, 'ยืนยันแล้ว', Icons.check_rounded),
    'SEATED' => (
      AppTheme.successColor,
      'เข้านั่งแล้ว',
      Icons.event_seat_rounded,
    ),
    'CANCELLED' => (AppTheme.errorColor, 'ยกเลิก', Icons.close_rounded),
    'NO_SHOW' => (AppTheme.subtextColor, 'ไม่มา', Icons.person_off_outlined),
    _ => (AppTheme.subtextColor, status, Icons.info_outline),
  };
}

class _ReservationStatusBadge extends StatelessWidget {
  const _ReservationStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (bg, textColor) = _statusBadgeColors(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusBadgeColors(Color color) {
    if (color == AppTheme.successColor) {
      return (AppTheme.successContainer, const Color(0xFF2E7D32));
    }
    if (color == AppTheme.errorColor) {
      return (AppTheme.errorContainer, const Color(0xFFC62828));
    }
    if (color == AppTheme.warningColor) {
      return (AppTheme.warningContainer, const Color(0xFFE65100));
    }
    if (color == AppTheme.primaryColor) {
      return (AppTheme.primaryContainer, AppTheme.primaryDark);
    }
    return (color.withValues(alpha: 0.12), color);
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: AppTheme.mutedTextOf(context)),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppTheme.mutedTextOf(context)),
        ),
      ),
    ],
  );
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.reservation, required this.onAction});

  final ReservationModel reservation;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    if (r.isSeated || r.isCancelled || r.isNoShow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface3Of(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColorOf(context)),
        ),
        child: Text(
          r.isSeated
              ? 'ลูกค้าเข้านั่งแล้ว'
              : r.isCancelled
              ? 'ยกเลิกการจอง'
              : 'ไม่มาตามนัด',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedTextOf(context), fontSize: 11),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _ReservationActionPill(
          icon: Icons.edit_outlined,
          label: 'แก้ไข',
          color: AppTheme.infoColor,
          onTap: () => onAction('edit'),
        ),
        if (r.isPending) ...[
          _ReservationActionPill(
            icon: Icons.check_rounded,
            label: 'ยืนยัน',
            color: AppTheme.primaryColor,
            onTap: () => onAction('confirm'),
          ),
        ],
        _ReservationActionPill(
          icon: Icons.chair_outlined,
          label: 'เข้านั่ง',
          color: AppTheme.successColor,
          onTap: () => onAction('seat'),
        ),
        _ReservationActionPill(
          icon: Icons.person_off_outlined,
          label: 'ไม่มา',
          color: AppTheme.subtextColor,
          onTap: () => onAction('no_show'),
        ),
        _ReservationActionPill(
          icon: Icons.close_rounded,
          label: 'ยกเลิก',
          color: AppTheme.errorColor,
          onTap: () => onAction('cancel'),
        ),
      ],
    );
  }
}

class _ReservationActionPill extends StatelessWidget {
  const _ReservationActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
