// ignore_for_file: avoid_print
// promotion_usage_report_page.dart
// รายงานการใช้งานโปรโมชั่น

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/theme/app_theme.dart';

// ─── Models ──────────────────────────────────────────────────────────────────
class _PromoOrderUsage {
  final String  usageId;
  final String  orderNo;
  final DateTime orderDate;
  final String  customerName;
  final double  totalAmount;
  final double  discountAmount;
  final DateTime usedAt;

  const _PromoOrderUsage({
    required this.usageId,
    required this.orderNo,
    required this.orderDate,
    required this.customerName,
    required this.totalAmount,
    required this.discountAmount,
    required this.usedAt,
  });

  factory _PromoOrderUsage.fromJson(Map<String, dynamic> j) => _PromoOrderUsage(
        usageId:        j['usage_id']       as String,
        orderNo:        j['order_no']        as String,
        orderDate:      DateTime.parse(j['order_date'] as String),
        customerName:   j['customer_name']  as String? ?? 'ลูกค้าทั่วไป',
        totalAmount:    (j['total_amount']   as num?)?.toDouble() ?? 0,
        discountAmount: (j['discount_amount'] as num?)?.toDouble() ?? 0,
        usedAt:         DateTime.parse(j['used_at'] as String),
      );
}

class _PromoUsage {
  final String promotionId;
  final String promotionCode;
  final String promotionName;
  final String promotionType;
  final int    currentUses;
  final int?   maxUses;
  final bool   isActive;
  final DateTime startDate;
  final DateTime endDate;

  const _PromoUsage({
    required this.promotionId,
    required this.promotionCode,
    required this.promotionName,
    required this.promotionType,
    required this.currentUses,
    required this.maxUses,
    required this.isActive,
    required this.startDate,
    required this.endDate,
  });

  factory _PromoUsage.fromJson(Map<String, dynamic> j) => _PromoUsage(
        promotionId:   j['promotion_id']   as String,
        promotionCode: j['promotion_code'] as String,
        promotionName: j['promotion_name'] as String,
        promotionType: j['promotion_type'] as String,
        currentUses:   (j['current_uses'] as num?)?.toInt() ?? 0,
        maxUses:       (j['max_uses']      as num?)?.toInt(),
        isActive:      j['is_active']      as bool? ?? false,
        startDate:     DateTime.parse(j['start_date'] as String),
        endDate:       DateTime.parse(j['end_date']   as String),
      );
}

// ─── Provider ────────────────────────────────────────────────────────────────
final _promotionUsageProvider = FutureProvider<List<_PromoUsage>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/promotions/usage');
  if (res.statusCode == 200 && res.data != null) {
    final list = res.data['data'] as List;
    return list
        .map((j) => _PromoUsage.fromJson(j as Map<String, dynamic>))
        .toList();
  }
  return [];
});

// ─── Page ─────────────────────────────────────────────────────────────────────
class PromotionUsageReportPage extends ConsumerStatefulWidget {
  const PromotionUsageReportPage({super.key});

  @override
  ConsumerState<PromotionUsageReportPage> createState() =>
      _PromotionUsageReportPageState();
}

class _PromotionUsageReportPageState
    extends ConsumerState<PromotionUsageReportPage> {
  String _filterType   = 'ALL';   // ALL / BUY_X_GET_Y / DISCOUNT_PERCENT / ...
  String _filterStatus = 'ALL';   // ALL / ACTIVE / INACTIVE
  String _search       = '';

  final _dateFmt  = DateFormat('dd/MM/yy');
  final _numFmt   = NumberFormat('#,##0');

  static const _typeLabels = {
    'ALL':              'ทุกประเภท',
    'BUY_X_GET_Y':      'ซื้อ X แถม Y',
    'DISCOUNT_PERCENT': 'ลด %',
    'DISCOUNT_AMOUNT':  'ลดเงิน',
    'FREE_ITEM':        'ของแถม',
  };

  List<_PromoUsage> _filter(List<_PromoUsage> all) {
    return all.where((p) {
      if (_filterType != 'ALL' && p.promotionType != _filterType) { return false; }
      if (_filterStatus == 'ACTIVE'   && !p.isActive) { return false; }
      if (_filterStatus == 'INACTIVE' && p.isActive)  { return false; }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!p.promotionName.toLowerCase().contains(q) &&
            !p.promotionCode.toLowerCase().contains(q)) { return false; }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final usageAsync = ref.watch(_promotionUsageProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildFilters(isDark),
          Expanded(
            child: usageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data:    (all) {
                final list = _filter(all);
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_outlined,
                            size: 56,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text('ไม่พบข้อมูล',
                            style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  );
                }
                // ── Summary cards ───────────────────────────────
                final totalUses  = all.fold<int>(0, (s, p) => s + p.currentUses);
                final activeCount = all.where((p) => p.isActive).length;
                return Column(
                  children: [
                    _buildSummaryRow(all.length, activeCount, totalUses, isDark),
                    Expanded(child: _buildTable(list, isDark)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.arrow_back,
                    size: 20,
                    color: isDark ? Colors.white70 : AppTheme.textSub),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.infoContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart, color: AppTheme.infoColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'รายงานการใช้งานโปรโมชั่น',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () => ref.invalidate(_promotionUsageProvider),
          ),
        ],
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────────────────
  Widget _buildFilters(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkCard : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ / รหัสโปรโมชั่น...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Type filter
          DropdownButton<String>(
            value: _filterType,
            isDense: true,
            onChanged: (v) => setState(() => _filterType = v!),
            items: _typeLabels.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
          ),
          const SizedBox(width: 12),
          // Status filter
          DropdownButton<String>(
            value: _filterStatus,
            isDense: true,
            onChanged: (v) => setState(() => _filterStatus = v!),
            items: const [
              DropdownMenuItem(value: 'ALL',      child: Text('ทุกสถานะ',     style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'ACTIVE',   child: Text('เปิดใช้งาน',   style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'INACTIVE', child: Text('ปิดการใช้งาน', style: TextStyle(fontSize: 13))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Row ──────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(int total, int active, int totalUses, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _summaryCard('โปรโมชั่นทั้งหมด', '$total', Icons.local_offer,
              AppTheme.infoColor, isDark),
          const SizedBox(width: 12),
          _summaryCard('เปิดใช้งาน', '$active', Icons.check_circle,
              AppTheme.successColor, isDark),
          const SizedBox(width: 12),
          _summaryCard('ใช้งานรวม (ครั้ง)', _numFmt.format(totalUses),
              Icons.analytics, const Color(0xFF9C27B0), isDark),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color,
      bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSub)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────
  Widget _buildTable(List<_PromoUsage> list, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.headerBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: _tableRow(
                cells: const [
                  _Cell('รหัส', flex: 2),
                  _Cell('ชื่อโปรโมชั่น', flex: 4),
                  _Cell('ประเภท', flex: 2),
                  _Cell('ช่วงเวลา', flex: 3),
                  _Cell('ใช้งานแล้ว', flex: 2, align: TextAlign.center),
                  _Cell('สูงสุด', flex: 2, align: TextAlign.center),
                  _Cell('สถานะ', flex: 2, align: TextAlign.center),
                ],
                isHeader: true,
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            // Rows
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.border),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final now = DateTime.now();
                  final isRunning = p.isActive &&
                      now.isAfter(p.startDate) &&
                      now.isBefore(p.endDate);
                  final usageRatio = p.maxUses != null && p.maxUses! > 0
                      ? p.currentUses / p.maxUses!
                      : null;

                  return InkWell(
                    onTap: () => _showOrdersSheet(context, p),
                    child: _tableRow(
                    cells: [
                      _Cell(p.promotionCode, flex: 2,
                          style: const TextStyle(fontSize: 12,
                              fontFamily: 'monospace')),
                      _Cell(p.promotionName, flex: 4,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      _Cell(_typeLabel(p.promotionType), flex: 2,
                          style: TextStyle(fontSize: 11,
                              color: _typeColor(p.promotionType))),
                      _Cell(
                          '${_dateFmt.format(p.startDate)} –\n${_dateFmt.format(p.endDate)}',
                          flex: 3,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSub)),
                      _Cell('${_numFmt.format(p.currentUses)} ครั้ง',
                          flex: 2,
                          align: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: p.currentUses > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSub),
                          extra: usageRatio != null
                              ? LinearProgressIndicator(
                                  value: usageRatio.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor:
                                      AppTheme.border.withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      usageRatio >= 0.9
                                          ? AppTheme.errorColor
                                          : AppTheme.successColor),
                                )
                              : null),
                      _Cell(
                          p.maxUses != null
                              ? _numFmt.format(p.maxUses!)
                              : '∞',
                          flex: 2,
                          align: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSub)),
                      _Cell('', flex: 2, align: TextAlign.center,
                          extra: _statusBadge(isRunning, p.isActive)),
                    ],
                    isHeader: false,
                  ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Drill-down: bottom sheet แสดงรายการใบเสร็จที่ใช้โปรโมชั่นนี้ ────────────
  void _showOrdersSheet(BuildContext ctx, _PromoUsage promo) {
    final api      = ref.read(apiClientProvider);
    final moneyFmt = NumberFormat('#,##0.00');
    final dateFmt  = DateFormat('dd/MM/yy HH:mm');
    final isDark   = Theme.of(ctx).brightness == Brightness.dark;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.infoContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long,
                          color: AppTheme.infoColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(promo.promotionName,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          Text('${promo.promotionCode} · ${promo.currentUses} ครั้ง',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSub)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              // content
              Expanded(
                child: FutureBuilder<List<_PromoOrderUsage>>(
                  future: api
                      .get('/api/promotions/usage/${promo.promotionId}/orders')
                      .then((res) {
                    if (res.statusCode == 200 && res.data != null) {
                      final list = res.data['data'] as List;
                      return list
                          .map((j) => _PromoOrderUsage.fromJson(
                              j as Map<String, dynamic>))
                          .toList();
                    }
                    return <_PromoOrderUsage>[];
                  }),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                    }
                    final orders = snap.data ?? [];
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_outlined,
                                size: 48,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black26),
                            const SizedBox(height: 8),
                            const Text('ยังไม่มีการใช้งาน',
                                style: TextStyle(color: AppTheme.textSub)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppTheme.border),
                      itemBuilder: (_, i) {
                        final o = orders[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              // icon
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt,
                                    size: 18,
                                    color: AppTheme.primaryColor),
                              ),
                              const SizedBox(width: 12),
                              // order info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(o.orderNo,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(o.customerName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSub)),
                                    Text(dateFmt.format(o.usedAt),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSub)),
                                  ],
                                ),
                              ),
                              // amounts
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '฿${moneyFmt.format(o.totalAmount)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (o.discountAmount > 0)
                                    Text(
                                      'ลด ฿${moneyFmt.format(o.discountAmount)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.successColor),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow({required List<_Cell> cells, required bool isHeader}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: cells.map((c) {
          Widget content = c.extra != null
              ? Column(
                  crossAxisAlignment: c.align == TextAlign.center
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(c.text,
                        textAlign: c.align,
                        style: c.style ??
                            (isHeader
                                ? const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A))
                                : const TextStyle(fontSize: 13))),
                    const SizedBox(height: 4),
                    c.extra!,
                  ],
                )
              : Text(
                  c.text,
                  textAlign: c.align,
                  style: c.style ??
                      (isHeader
                          ? const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A))
                          : const TextStyle(fontSize: 13)),
                );
          return Expanded(
            flex: c.flex,
            child: content,
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBadge(bool isRunning, bool isActive) {
    final color = isRunning
        ? AppTheme.successColor
        : isActive
            ? Colors.orange
            : AppTheme.textSub;
    final label = isRunning
        ? 'กำลังใช้งาน'
        : isActive
            ? 'รอเวลา'
            : 'ปิด';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'BUY_X_GET_Y'      => 'ซื้อ X แถม Y',
        'DISCOUNT_PERCENT' => 'ลด %',
        'DISCOUNT_AMOUNT'  => 'ลดเงิน',
        'FREE_ITEM'        => 'ของแถม',
        _                  => type,
      };

  Color _typeColor(String type) => switch (type) {
        'BUY_X_GET_Y'      => AppTheme.errorColor,
        'DISCOUNT_PERCENT' => const Color(0xFF9C27B0),
        'DISCOUNT_AMOUNT'  => AppTheme.successColor,
        'FREE_ITEM'        => const Color(0xFF009688),
        _                  => AppTheme.textSub,
      };
}

// ─── Helper data class ───────────────────────────────────────────────────────
class _Cell {
  final String     text;
  final int        flex;
  final TextAlign  align;
  final TextStyle? style;
  final Widget?    extra; // e.g. LinearProgressIndicator

  const _Cell(this.text, {
    this.flex  = 1,
    this.align = TextAlign.start,
    this.style,
    this.extra,
  });
}
