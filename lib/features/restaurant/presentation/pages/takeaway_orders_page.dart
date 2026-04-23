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
  _TakeawayDateFilter _dateFilter = _TakeawayDateFilter.all;
  _TakeawayStatusFilter _statusFilter = _TakeawayStatusFilter.open;
  _TakeawaySort _sort = _TakeawaySort.latest;
  Set<String> _knownOpenOrderIds = <String>{};
  Timer? _highlightClearTimer;
  bool _didPrimeOpenOrders = false;

  Future<void> _refresh() async {
    await ref.read(salesHistoryProvider.notifier).refresh();
  }

  @override
  void dispose() {
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
          previous?.map((order) => order.orderId).toSet() ?? _knownOpenOrderIds;
      final nextIds = next.map((order) => order.orderId).toSet();

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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 52,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 12),
                const Text(
                  'โหลดรายการไม่สำเร็จ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          final filteredOrders = _filterOrders(takeawayOrders);
          final emptyState = filteredOrders.isEmpty
              ? _EmptyTakeawayState(statusFilter: _statusFilter)
              : null;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SearchAndFilterBar(
                  controller: _searchController,
                  searchQuery: _searchQuery,
                  dateFilter: _dateFilter,
                  statusFilter: _statusFilter,
                  sort: _sort,
                  resultCount: filteredOrders.isEmpty
                      ? null
                      : filteredOrders.length,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  onDateFilterChanged: (filter) =>
                      setState(() => _dateFilter = filter),
                  onStatusFilterChanged: (filter) =>
                      setState(() => _statusFilter = filter),
                  onSortChanged: (sort) => setState(() => _sort = sort),
                ),
                if (emptyState != null) ...[
                  const SizedBox(height: 120),
                  emptyState,
                ] else ...[
                  const SizedBox(height: 12),
                  ...filteredOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TakeawayOrderCard(
                        order: order,
                        isHighlighted: _highlightedOrderIds.contains(
                          order.orderId,
                        ),
                        onTap: () => _openOrder(order),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<SalesOrderModel> _filterOrders(List<SalesOrderModel> orders) {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = orders.where((order) {
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

      final normalizedStatus = order.status.toUpperCase();
      final matchesStatus = switch (_statusFilter) {
        _TakeawayStatusFilter.all => true,
        _TakeawayStatusFilter.open => normalizedStatus == 'OPEN',
        _TakeawayStatusFilter.completed => normalizedStatus == 'COMPLETED',
        _TakeawayStatusFilter.cancelled => normalizedStatus == 'CANCELLED',
      };

      return matchesQuery && matchesDate && matchesStatus;
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

enum _TakeawayDateFilter { all, today }

enum _TakeawayStatusFilter { all, open, completed, cancelled }

enum _TakeawaySort { latest, highestAmount }

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.searchQuery,
    required this.dateFilter,
    required this.statusFilter,
    required this.sort,
    required this.onChanged,
    required this.onClear,
    required this.onDateFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSortChanged,
    this.resultCount,
  });

  final TextEditingController controller;
  final String searchQuery;
  final _TakeawayDateFilter dateFilter;
  final _TakeawayStatusFilter statusFilter;
  final _TakeawaySort sort;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_TakeawayDateFilter> onDateFilterChanged;
  final ValueChanged<_TakeawayStatusFilter> onStatusFilterChanged;
  final ValueChanged<_TakeawaySort> onSortChanged;
  final int? resultCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'ค้นหาเลขบิลหรือชื่อลูกค้า',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: 'ล้างคำค้น',
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('ทั้งหมด'),
              selected: dateFilter == _TakeawayDateFilter.all,
              onSelected: (_) => onDateFilterChanged(_TakeawayDateFilter.all),
            ),
            ChoiceChip(
              label: const Text('วันนี้'),
              selected: dateFilter == _TakeawayDateFilter.today,
              onSelected: (_) => onDateFilterChanged(_TakeawayDateFilter.today),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<_TakeawayStatusFilter>(
                value: statusFilter,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: _TakeawayStatusFilter.open,
                    child: Text('OPEN'),
                  ),
                  DropdownMenuItem(
                    value: _TakeawayStatusFilter.completed,
                    child: Text('COMPLETED'),
                  ),
                  DropdownMenuItem(
                    value: _TakeawayStatusFilter.cancelled,
                    child: Text('CANCELLED'),
                  ),
                  DropdownMenuItem(
                    value: _TakeawayStatusFilter.all,
                    child: Text('ทุกสถานะ'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onStatusFilterChanged(value);
                },
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<_TakeawaySort>(
                value: sort,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: _TakeawaySort.latest,
                    child: Text('ล่าสุด'),
                  ),
                  DropdownMenuItem(
                    value: _TakeawaySort.highestAmount,
                    child: Text('ยอดสูงสุด'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
            if (resultCount != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.navyColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('พบ $resultCount รายการ'),
              ),
          ],
        ),
      ],
    );
  }
}

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
        borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isHighlighted
                ? AppTheme.primaryColor.withValues(alpha: 0.75)
                : Colors.grey.shade200,
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
                        borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(color: Colors.black54),
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
                      borderRadius: BorderRadius.circular(10),
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
    final bg = backgroundColor ?? Colors.grey.shade100;
    final fg = foregroundColor ?? Colors.black54;
    final border = borderColor ?? Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
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

class _EmptyTakeawayState extends StatelessWidget {
  const _EmptyTakeawayState({required this.statusFilter});

  final _TakeawayStatusFilter statusFilter;

  @override
  Widget build(BuildContext context) {
    final title = switch (statusFilter) {
      _TakeawayStatusFilter.open => 'ไม่มีบิลซื้อกลับบ้านที่ค้างอยู่',
      _TakeawayStatusFilter.completed => 'ยังไม่มีบิลซื้อกลับบ้านที่ปิดแล้ว',
      _TakeawayStatusFilter.cancelled => 'ยังไม่มีบิลซื้อกลับบ้านที่ยกเลิก',
      _TakeawayStatusFilter.all => 'ยังไม่มีรายการซื้อกลับบ้าน',
    };
    final subtitle = switch (statusFilter) {
      _TakeawayStatusFilter.open =>
        'เมื่อมีออเดอร์ซื้อกลับบ้านที่ยังไม่ปิดบิล รายการจะแสดงที่นี่',
      _TakeawayStatusFilter.completed =>
        'เมื่อมีบิล takeaway ที่ชำระเสร็จ รายการจะขึ้นในสถานะ COMPLETED',
      _TakeawayStatusFilter.cancelled =>
        'เมื่อมีบิล takeaway ที่ยกเลิก รายการจะขึ้นในสถานะ CANCELLED',
      _TakeawayStatusFilter.all =>
        'เมื่อมีออเดอร์ซื้อกลับบ้าน รายการทั้งหมดจะแสดงที่นี่',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.takeout_dining, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
