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

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('การจองโต๊ะ'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          _CountdownRefreshButton(
            countdown: _countdown,
            total: _kReservationsRefreshSeconds,
            onTap: _isBusy ? null : _refreshAll,
          ),
          const SizedBox(width: 8),
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
                    month: calendarMonth,
                    fmt: fmt,
                    monthFmt: monthFmt,
                    isMonthView: !_showDailyList,
                    reservations: reservations,
                    searchQuery: searchQuery,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: const _ReservationStatusFilterBar(),
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

// ─── Summary Panel ────────────────────────────────────────────────────────────

class _ReservationSummaryPanel extends StatelessWidget {
  const _ReservationSummaryPanel({
    required this.date,
    required this.month,
    required this.fmt,
    required this.monthFmt,
    required this.isMonthView,
    required this.reservations,
    required this.searchQuery,
  });

  final DateTime date;
  final DateTime month;
  final DateFormat fmt;
  final DateFormat monthFmt;
  final bool isMonthView;
  final List<ReservationModel> reservations;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final pending = reservations.where((r) => r.isPending).length;
    final confirmed = reservations.where((r) => r.isConfirmed).length;
    final seated = reservations.where((r) => r.isSeated).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.event_note,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ภาพรวมการจอง',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isMonthView)
            _MonthBar(month: month, fmt: monthFmt)
          else
            _DateBar(date: date, fmt: fmt),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SummaryCard(
                  label: 'รอยืนยัน',
                  value: '$pending',
                  icon: Icons.hourglass_top_rounded,
                  color: AppTheme.warningColor,
                  background: AppTheme.warningContainer,
                  compact: true,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'ยืนยันแล้ว',
                  value: '$confirmed',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.primaryColor,
                  background: AppTheme.primaryContainer,
                  compact: true,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'เข้านั่งแล้ว',
                  value: '$seated',
                  icon: Icons.event_seat,
                  color: AppTheme.successColor,
                  background: AppTheme.successContainer,
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SearchBar(searchQuery: searchQuery),
        ],
      ),
    );
  }
}

// ─── Summary Card (mirrors _SummaryCard from KDS) ─────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 132 : 160,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.md),
      child: Row(
        children: [
          Icon(icon, color: color, size: compact ? 16 : 18),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    color: AppTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
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

// ─── Status Filter Bar (mirrors _MobileQueueFilterBar from KDS) ───────────────

class _ReservationStatusFilterBar extends ConsumerWidget {
  const _ReservationStatusFilterBar();

  static const _tabs = [
    (value: null, label: 'ทั้งหมด'),
    (value: 'PENDING', label: 'รอยืนยัน'),
    (value: 'CONFIRMED', label: 'ยืนยันแล้ว'),
    (value: 'SEATED', label: 'เข้านั่งแล้ว'),
    (value: 'CANCELLED', label: 'ยกเลิก'),
    (value: 'NO_SHOW', label: 'ไม่มา'),
  ];

  Color _colorOf(String? status) => switch (status) {
    'PENDING' => AppTheme.warningColor,
    'CONFIRMED' => AppTheme.primaryColor,
    'SEATED' => AppTheme.successColor,
    'CANCELLED' => AppTheme.errorColor,
    'NO_SHOW' => AppTheme.subtextColor,
    _ => AppTheme.navyColor,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(reservationStatusFilterProvider);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final selected = statusFilter == tab.value;
          final color = _colorOf(tab.value);

          return GestureDetector(
            onTap: () =>
                ref.read(reservationStatusFilterProvider.notifier).state =
                    tab.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.14)
                    : AppTheme.cardColor(context),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: selected ? color : AppTheme.borderColorOf(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : AppTheme.textColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  (Color, Color, String) get _headerStyle => switch (statusFilter) {
    'PENDING' => (AppTheme.warningContainer, AppTheme.warningColor, 'รอยืนยัน'),
    'CONFIRMED' => (
      AppTheme.primaryContainer,
      AppTheme.primaryColor,
      'ยืนยันแล้ว',
    ),
    'SEATED' => (
      AppTheme.successContainer,
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
    _ => (AppTheme.headerBg, AppTheme.navyColor, 'ทั้งหมด'),
  };

  @override
  Widget build(BuildContext context) {
    final (headerBg, headerColor, headerTitle) = _headerStyle;

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
                        style: const TextStyle(
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (dateLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateLabel!,
                          style: const TextStyle(
                            color: AppTheme.subtextColor,
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

class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.month, required this.fmt});

  final DateTime month;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedMonth = DateTime(month.year, month.month);

    return Row(
      children: [
        IconButton(
          tooltip: 'เดือนก่อนหน้า',
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              ref.read(reservationCalendarMonthProvider.notifier).state =
                  DateTime(normalizedMonth.year, normalizedMonth.month - 1),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: normalizedMonth,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                ref.read(reservationCalendarMonthProvider.notifier).state =
                    DateTime(picked.year, picked.month);
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
                    Icons.calendar_month,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmt.format(normalizedMonth),
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
          tooltip: 'เดือนถัดไป',
          icon: const Icon(Icons.chevron_right),
          onPressed: () =>
              ref.read(reservationCalendarMonthProvider.notifier).state =
                  DateTime(normalizedMonth.year, normalizedMonth.month + 1),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _ReservationMonthCalendar extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    monthFmt.format(normalizedMonth),
                    style: const TextStyle(
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
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
                          style: const TextStyle(
                            color: AppTheme.subtextColor,
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
                          color: AppTheme.surfaceColor,
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
                                            style: const TextStyle(
                                              color: AppTheme.subtextColor,
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
        fillColor: AppTheme.surface3Of(context),
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

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
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
                              borderRadius: AppRadius.pill,
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
                                borderRadius: AppRadius.pill,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColorOf(context),
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
                    color: AppTheme.surface3Of(context),
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppTheme.borderColorOf(context)),
                  ),
                  child: Text(
                    timeFmt.format(r.reservationTime),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColorOf(context),
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
                  borderRadius: AppRadius.md,
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

// ─── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppTheme.mutedTextOf(context)),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(fontSize: 13, color: AppTheme.mutedTextOf(context)),
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
      return Text(
        r.isSeated
            ? 'ลูกค้าเข้านั่งแล้ว'
            : r.isCancelled
            ? 'ยกเลิกการจอง'
            : 'ไม่มาตามนัด',
        style: TextStyle(color: AppTheme.mutedTextOf(context), fontSize: 13),
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
