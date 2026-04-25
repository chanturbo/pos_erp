import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_alert_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/async_state_widgets.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../sales/data/models/sales_order_model.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../data/models/restaurant_order_context.dart';
import 'billing_page.dart';

const _kTakeawayRefreshSeconds = 30;

// ─── Page ─────────────────────────────────────────────────────────────────────

class TakeawayOrdersPage extends ConsumerStatefulWidget {
  const TakeawayOrdersPage({
    super.key,
    this.enableAutoRefresh = true,
    this.pollingIntervalOverride,
  });

  final bool enableAutoRefresh;
  final Duration? pollingIntervalOverride;

  @override
  ConsumerState<TakeawayOrdersPage> createState() => _TakeawayOrdersPageState();
}

class _TakeawayOrdersPageState extends ConsumerState<TakeawayOrdersPage> {
  final _searchController = TextEditingController();
  final Set<String> _highlightedOrderIds = <String>{};
  String _searchQuery = '';
  _TakeawayDateFilter _dateFilter = _TakeawayDateFilter.today;
  _TakeawayStatusFilter _statusFilter = _TakeawayStatusFilter.open;
  final _TakeawaySort _sort = _TakeawaySort.latest;
  Set<String> _knownOpenOrderIds = <String>{};
  Timer? _highlightClearTimer;
  Timer? _countdownTimer;
  bool _didPrimeOpenOrders = false;
  int _countdown = _kTakeawayRefreshSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _kTakeawayRefreshSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdown = _kTakeawayRefreshSeconds;
          unawaited(ref.read(salesHistoryProvider.notifier).refresh());
        }
      });
    });
  }

  void _refreshAll() {
    _startCountdown();
    unawaited(ref.read(salesHistoryProvider.notifier).refresh());
  }

  Future<void> _pullRefresh() =>
      ref.read(salesHistoryProvider.notifier).refresh();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _highlightClearTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableAutoRefresh) {
      ref.watch(takeawayPollingProvider(widget.pollingIntervalOverride));
    }

    ref.listen<List<SalesOrderModel>>(takeawayOpenOrdersProvider, (
      previous,
      next,
    ) {
      final previousIds =
          previous?.map((o) => o.orderId).toSet() ?? _knownOpenOrderIds;
      final nextIds = next.map((o) => o.orderId).toSet();

      if (!_didPrimeOpenOrders) {
        _knownOpenOrderIds = nextIds;
        _didPrimeOpenOrders = true;
        return;
      }

      final newIds = nextIds.difference(previousIds);
      _knownOpenOrderIds = nextIds;

      if (newIds.isNotEmpty && mounted) {
        _highlightNewOrders(newIds, next);
      }
    });

    final ordersAsync = ref.watch(salesHistoryProvider);
    final takeawayOrders = ref.watch(takeawayOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('บิลซื้อกลับบ้านค้าง'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          _CountdownRefreshButton(
            countdown: _countdown,
            total: _kTakeawayRefreshSeconds,
            onTap: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TakeawayMessageState(
          icon: Icons.receipt_long_outlined,
          title: 'โหลดรายการไม่สำเร็จ',
          message: '$error',
          iconColor: AppTheme.errorColor,
        ),
        data: (_) {
          final dateSearchFiltered = _applyDateAndSearch(takeawayOrders);
          final filteredOrders = _applyStatusAndSort(dateSearchFiltered);

          final openCount = dateSearchFiltered
              .where((o) => o.status.toUpperCase() == 'OPEN')
              .length;
          final completedCount = dateSearchFiltered
              .where((o) => o.status.toUpperCase() == 'COMPLETED')
              .length;
          final cancelledCount = dateSearchFiltered
              .where((o) => o.status.toUpperCase() == 'CANCELLED')
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _TakeawaySummaryPanel(
                  openCount: openCount,
                  completedCount: completedCount,
                  cancelledCount: cancelledCount,
                  dateFilter: _dateFilter,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onDateFilterChanged: (f) => setState(() => _dateFilter = f),
                  onSearchChanged: (v) =>
                      setState(() => _searchQuery = v.trim()),
                  onSearchClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TakeawayStatusFilterBar(
                  statusFilter: _statusFilter,
                  openCount: openCount,
                  completedCount: completedCount,
                  cancelledCount: cancelledCount,
                  allCount: dateSearchFiltered.length,
                  onChanged: (f) => setState(() => _statusFilter = f),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _TakeawayOrderColumn(
                    orders: filteredOrders,
                    highlightedIds: _highlightedOrderIds,
                    statusFilter: _statusFilter,
                    onTap: _openOrder,
                    onRefresh: _pullRefresh,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<SalesOrderModel> _applyDateAndSearch(List<SalesOrderModel> orders) {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    return orders.where((order) {
      final matchesQuery =
          query.isEmpty ||
          order.orderNo.toLowerCase().contains(query) ||
          (order.customerName?.toLowerCase().contains(query) ?? false);
      final matchesDate = switch (_dateFilter) {
        _TakeawayDateFilter.all => true,
        _TakeawayDateFilter.today =>
          order.orderDate.year == now.year &&
          order.orderDate.month == now.month &&
          order.orderDate.day == now.day,
      };
      return matchesQuery && matchesDate;
    }).toList();
  }

  List<SalesOrderModel> _applyStatusAndSort(List<SalesOrderModel> orders) {
    final filtered = orders.where((order) {
      final s = order.status.toUpperCase();
      return switch (_statusFilter) {
        _TakeawayStatusFilter.all => true,
        _TakeawayStatusFilter.open => s == 'OPEN',
        _TakeawayStatusFilter.completed => s == 'COMPLETED',
        _TakeawayStatusFilter.cancelled => s == 'CANCELLED',
      };
    }).toList();

    switch (_sort) {
      case _TakeawaySort.latest:
        filtered.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      case _TakeawaySort.highestAmount:
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    }
    return filtered;
  }

  void _highlightNewOrders(
    Set<String> newIds,
    List<SalesOrderModel> openOrders,
  ) {
    setState(() {
      _highlightedOrderIds.addAll(newIds);
    });

    final count = newIds.length;
    final newestOrder = openOrders.firstWhere(
      (order) => newIds.contains(order.orderId),
      orElse: () => openOrders.first,
    );
    final message = count == 1
        ? 'มีบิลซื้อกลับบ้านใหม่: ${newestOrder.orderNo}'
        : 'มีบิลซื้อกลับบ้านค้างใหม่ $count รายการ';
    context.showInfo(message);
    if (ref.read(settingsProvider).restaurantAlertSoundEnabled) {
      unawaited(ref.read(appAlertServiceProvider).playTakeawayNewOrderAlert());
    }

    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _highlightedOrderIds.removeAll(newIds);
      });
    });
  }

  void _openOrder(SalesOrderModel order) {
    final branchId = ref.read(selectedBranchProvider)?.branchId ?? '';
    final context =
        RestaurantOrderContext.takeaway(
          branchId: branchId,
          currentOrderId: order.orderId,
          currentOrderNo: order.orderNo,
        ).copyWith(
          branchId: branchId,
          guestCount: order.partySize ?? 1,
          tableName: 'ซื้อกลับบ้าน',
          serviceType: order.serviceType ?? 'TAKEAWAY',
        );

    Navigator.push(
      this.context,
      MaterialPageRoute(builder: (_) => BillingPage(tableContext: context)),
    );
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum _TakeawayDateFilter { all, today }

enum _TakeawayStatusFilter { all, open, completed, cancelled }

enum _TakeawaySort { latest, highestAmount }

// ─── Summary Panel ────────────────────────────────────────────────────────────

class _TakeawaySummaryPanel extends StatelessWidget {
  const _TakeawaySummaryPanel({
    required this.openCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.dateFilter,
    required this.searchController,
    required this.searchQuery,
    required this.onDateFilterChanged,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  final int openCount;
  final int completedCount;
  final int cancelledCount;
  final _TakeawayDateFilter dateFilter;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<_TakeawayDateFilter> onDateFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  @override
  Widget build(BuildContext context) {
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
                  Icons.takeout_dining,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ภาพรวมซื้อกลับบ้าน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyColor,
                  ),
                ),
              ),
              _DateToggle(
                selected: dateFilter,
                onChanged: onDateFilterChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SummaryCard(
                  label: 'ค้างอยู่',
                  value: '$openCount',
                  icon: Icons.hourglass_top_rounded,
                  color: AppTheme.warningColor,
                  background: AppTheme.warningContainer,
                  compact: true,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'ปิดแล้ว',
                  value: '$completedCount',
                  icon: Icons.done_all_rounded,
                  color: AppTheme.successColor,
                  background: AppTheme.successContainer,
                  compact: true,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'ยกเลิก',
                  value: '$cancelledCount',
                  icon: Icons.cancel_outlined,
                  color: AppTheme.errorColor,
                  background: AppTheme.errorColor.withValues(alpha: 0.10),
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ค้นหาเลขบิลหรือชื่อลูกค้า',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedTextOf(context),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: AppTheme.iconOf(context),
              ),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onSearchClear,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'ล้างคำค้น',
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
          ),
        ],
      ),
    );
  }
}

class _DateToggle extends StatelessWidget {
  const _DateToggle({required this.selected, required this.onChanged});

  final _TakeawayDateFilter selected;
  final ValueChanged<_TakeawayDateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface3Of(context),
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            label: 'วันนี้',
            selected: selected == _TakeawayDateFilter.today,
            onTap: () => onChanged(_TakeawayDateFilter.today),
          ),
          _ToggleOption(
            label: 'ทั้งหมด',
            selected: selected == _TakeawayDateFilter.all,
            onTap: () => onChanged(_TakeawayDateFilter.all),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.mutedTextOf(context),
          ),
        ),
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
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.md,
      ),
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

class _TakeawayStatusFilterBar extends StatelessWidget {
  const _TakeawayStatusFilterBar({
    required this.statusFilter,
    required this.openCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.allCount,
    required this.onChanged,
  });

  final _TakeawayStatusFilter statusFilter;
  final int openCount;
  final int completedCount;
  final int cancelledCount;
  final int allCount;
  final ValueChanged<_TakeawayStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (
        label: 'ค้างอยู่',
        filter: _TakeawayStatusFilter.open,
        count: openCount,
        color: AppTheme.warningColor,
      ),
      (
        label: 'ปิดแล้ว',
        filter: _TakeawayStatusFilter.completed,
        count: completedCount,
        color: AppTheme.successColor,
      ),
      (
        label: 'ยกเลิก',
        filter: _TakeawayStatusFilter.cancelled,
        count: cancelledCount,
        color: AppTheme.errorColor,
      ),
      (
        label: 'ทั้งหมด',
        filter: _TakeawayStatusFilter.all,
        count: allCount,
        color: AppTheme.navyColor,
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = tab.filter == statusFilter;
          return GestureDetector(
            onTap: () => onChanged(tab.filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? tab.color.withValues(alpha: 0.14)
                    : AppTheme.cardColor(context),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: selected
                      ? tab.color
                      : AppTheme.borderColorOf(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tab.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? tab.color
                          : AppTheme.textColorOf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? tab.color.withValues(alpha: 0.18)
                          : AppTheme.surface3Of(context),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      '${tab.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? tab.color
                            : AppTheme.mutedTextOf(context),
                      ),
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

// ─── Order Column (mirrors _QueueColumn from KDS) ─────────────────────────────

class _TakeawayOrderColumn extends StatelessWidget {
  const _TakeawayOrderColumn({
    required this.orders,
    required this.highlightedIds,
    required this.statusFilter,
    required this.onTap,
    required this.onRefresh,
  });

  final List<SalesOrderModel> orders;
  final Set<String> highlightedIds;
  final _TakeawayStatusFilter statusFilter;
  final ValueChanged<SalesOrderModel> onTap;
  final Future<void> Function() onRefresh;

  (Color, Color, String) get _headerStyle => switch (statusFilter) {
    _TakeawayStatusFilter.open => (
      AppTheme.warningContainer,
      AppTheme.warningColor,
      'ค้างอยู่',
    ),
    _TakeawayStatusFilter.completed => (
      AppTheme.successContainer,
      AppTheme.successColor,
      'ปิดแล้ว',
    ),
    _TakeawayStatusFilter.cancelled => (
      AppTheme.errorColor.withValues(alpha: 0.10),
      AppTheme.errorColor,
      'ยกเลิก',
    ),
    _TakeawayStatusFilter.all => (
      AppTheme.headerBg,
      AppTheme.navyColor,
      'ทั้งหมด',
    ),
  };

  IconData get _emptyIcon => switch (statusFilter) {
    _TakeawayStatusFilter.open => Icons.check_circle_outline,
    _TakeawayStatusFilter.completed => Icons.receipt_long_outlined,
    _TakeawayStatusFilter.cancelled => Icons.block_outlined,
    _TakeawayStatusFilter.all => Icons.takeout_dining,
  };

  Color get _emptyIconColor => switch (statusFilter) {
    _TakeawayStatusFilter.open => AppTheme.successColor,
    _ => AppTheme.subtextColor,
  };

  String get _emptyTitle => switch (statusFilter) {
    _TakeawayStatusFilter.open => 'ไม่มีบิลซื้อกลับบ้านที่ค้างอยู่',
    _TakeawayStatusFilter.completed => 'ยังไม่มีบิลซื้อกลับบ้านที่ปิดแล้ว',
    _TakeawayStatusFilter.cancelled => 'ยังไม่มีบิลซื้อกลับบ้านที่ยกเลิก',
    _TakeawayStatusFilter.all => 'ยังไม่มีรายการซื้อกลับบ้าน',
  };

  String get _emptyMessage => switch (statusFilter) {
    _TakeawayStatusFilter.open =>
      'เมื่อมีออเดอร์ซื้อกลับบ้านที่ยังไม่ปิดบิล รายการจะแสดงที่นี่',
    _TakeawayStatusFilter.completed =>
      'เมื่อมีบิล takeaway ที่ชำระเสร็จ รายการจะขึ้นในสถานะ COMPLETED',
    _TakeawayStatusFilter.cancelled =>
      'เมื่อมีบิล takeaway ที่ยกเลิก รายการจะขึ้นในสถานะ CANCELLED',
    _TakeawayStatusFilter.all =>
      'เมื่อมีออเดอร์ซื้อกลับบ้าน รายการทั้งหมดจะแสดงที่นี่',
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
                  child: Text(
                    headerTitle,
                    style: const TextStyle(
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w700,
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
                    color: headerColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '${orders.length}',
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
            child: orders.isEmpty
                ? _TakeawayMessageState(
                    icon: _emptyIcon,
                    title: _emptyTitle,
                    message: _emptyMessage,
                    iconColor: _emptyIconColor,
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: orders.length,
                      itemBuilder: (_, i) {
                        final order = orders[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TakeawayOrderCard(
                            order: order,
                            isHighlighted: highlightedIds.contains(
                              order.orderId,
                            ),
                            onTap: () => onTap(order),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Message State (mirrors _KdsMessageState from KDS) ────────────────────────

class _TakeawayMessageState extends StatelessWidget {
  const _TakeawayMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 160;
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

// ─── Countdown Refresh Button (mirrors _CountdownRefreshButton from KDS) ───────

class _CountdownRefreshButton extends StatefulWidget {
  const _CountdownRefreshButton({
    required this.countdown,
    required this.total,
    required this.onTap,
  });

  final int countdown;
  final int total;
  final VoidCallback onTap;

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
    _spinCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.countdown / widget.total;
    final isUrgent = widget.countdown <= 5;

    return Tooltip(
      message: 'อัพเดทใน ${widget.countdown} วิ  (กดเพื่อรีเฟรชทันที)',
      child: InkWell(
        onTap: _tap,
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

// ─── Order Card ───────────────────────────────────────────────────────────────

class _TakeawayOrderCard extends StatelessWidget {
  const _TakeawayOrderCard({
    required this.order,
    required this.onTap,
    required this.isHighlighted,
  });

  final SalesOrderModel order;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final status = order.status.toUpperCase();
    final (statusBackground, statusForeground) = _statusColors(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: isHighlighted
            ? const Color(0xFFFFF8E6)
            : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(
            color: isHighlighted
                ? AppTheme.primaryColor.withValues(alpha: 0.75)
                : AppTheme.borderColorOf(context),
            width: isHighlighted ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.md,
                      ),
                      child: Icon(
                        isHighlighted
                            ? Icons.notifications_active_outlined
                            : Icons.takeout_dining,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.customerName?.trim().isNotEmpty == true
                                ? order.customerName!
                                : 'ลูกค้าทั่วไป',
                            style: TextStyle(
                              color: AppTheme.mutedTextOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                if (isHighlighted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.md,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_new_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'บิลใหม่',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.payments_outlined,
                      label: '฿${order.totalAmount.toStringAsFixed(2)}',
                    ),
                    _MetaChip(
                      icon: Icons.schedule,
                      label: _formatOrderDate(order.orderDate),
                    ),
                    _MetaChip(
                      icon: Icons.flag_outlined,
                      label: status,
                      backgroundColor: statusBackground,
                      foregroundColor: statusForeground,
                      borderColor: statusForeground.withValues(alpha: 0.18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'COMPLETED':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'CANCELLED':
        return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
      case 'OPEN':
      default:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
    }
  }

  String _formatOrderDate(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$dd/$month/${date.year} $hh:$mm';
  }
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.surface3Of(context);
    final fg = foregroundColor ?? AppTheme.mutedTextOf(context);
    final border = borderColor ?? AppTheme.inputBorderOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pill,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg)),
        ],
      ),
    );
  }
}
