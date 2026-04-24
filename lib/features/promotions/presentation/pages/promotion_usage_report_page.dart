// promotion_usage_report_page.dart
// รายงานการใช้งานโปรโมชั่น

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../../settings/presentation/pages/settings_page.dart' show settingsProvider;

// ─── Models ──────────────────────────────────────────────────────────────────
class _PromoOrderUsage {
  final String usageId;
  final String orderNo;
  final DateTime orderDate;
  final String customerName;
  final double totalAmount;
  final double discountAmount;
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
    usageId: j['usage_id'] as String,
    orderNo: j['order_no'] as String,
    orderDate: DateTime.parse(j['order_date'] as String),
    customerName: j['customer_name'] as String? ?? 'ลูกค้าทั่วไป',
    totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
    discountAmount: (j['discount_amount'] as num?)?.toDouble() ?? 0,
    usedAt: DateTime.parse(j['used_at'] as String),
  );
}

class _PromoUsage {
  final String promotionId;
  final String promotionCode;
  final String promotionName;
  final String promotionType;
  final int currentUses;
  final int? maxUses;
  final bool isActive;
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
    promotionId: j['promotion_id'] as String,
    promotionCode: j['promotion_code'] as String,
    promotionName: j['promotion_name'] as String,
    promotionType: j['promotion_type'] as String,
    currentUses: (j['current_uses'] as num?)?.toInt() ?? 0,
    maxUses: (j['max_uses'] as num?)?.toInt(),
    isActive: j['is_active'] as bool? ?? false,
    startDate: DateTime.parse(j['start_date'] as String),
    endDate: DateTime.parse(j['end_date'] as String),
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
  String _filterType = 'ALL'; // ALL / BUY_X_GET_Y / DISCOUNT_PERCENT / ...
  String _filterStatus = 'ALL'; // ALL / ACTIVE / INACTIVE
  String _search = '';
  int _currentPage = 1;

  final _dateFmt = DateFormat('dd/MM/yy');
  final _numFmt = NumberFormat('#,##0');

  static const _typeLabels = {
    'ALL': 'ทุกประเภท',
    'BUY_X_GET_Y': 'ซื้อ X แถม Y',
    'DISCOUNT_PERCENT': 'ลด %',
    'DISCOUNT_AMOUNT': 'ลดเงิน',
    'FREE_ITEM': 'ของแถม',
  };

  List<_PromoUsage> _filter(List<_PromoUsage> all) {
    return all.where((p) {
      if (_filterType != 'ALL' && p.promotionType != _filterType) {
        return false;
      }
      if (_filterStatus == 'ACTIVE' && !p.isActive) {
        return false;
      }
      if (_filterStatus == 'INACTIVE' && p.isActive) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!p.promotionName.toLowerCase().contains(q) &&
            !p.promotionCode.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usageAsync = ref.watch(_promotionUsageProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.surface,
      body: EscapePopScope(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildFilters(isDark),
            Expanded(
              child: usageAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart_outlined,
                            size: 56,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ไม่พบข้อมูล',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // ── Summary ─────────────────────────────────────
                  final totalUses = all.fold<int>(
                    0,
                    (s, p) => s + p.currentUses,
                  );
                  final activeCount = all.where((p) => p.isActive).length;
                  // ── Pagination ──────────────────────────────────
                  final pageSize = ref.watch(settingsProvider).listPageSize;
                  final totalPages = ((list.length / pageSize).ceil()).clamp(1, 99999);
                  final safePage = _currentPage.clamp(1, totalPages);
                  final pageStart = (safePage - 1) * pageSize;
                  final pageEnd = (pageStart + pageSize).clamp(0, list.length);
                  final pageItems = list.sublist(pageStart, pageEnd);
                  return Column(
                    children: [
                      _buildSummaryRow(
                        all.length,
                        activeCount,
                        totalUses,
                        isDark,
                      ),
                      Expanded(child: _buildTable(pageItems, isDark)),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: list.length,
                        pageSize: pageSize,
                        onPageChanged: (p) =>
                            setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลรายงาน',
                          title: 'รายงานการใช้งานโปรโมชั่น',
                          filename: () => PdfFilename.generate(
                            'promo_usage_report',
                          ),
                          buildPdf: () =>
                              _PromoUsageReportPdfBuilder.build(list),
                          hasData: list.isNotEmpty,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final navBg = isDark ? AppTheme.navyDark : AppTheme.navy;
    final navButtonBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.15);
    final navButtonBorder = isDark ? Colors.white24 : Colors.white30;

    return Container(
      decoration: BoxDecoration(color: navBg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            context.isMobile
                ? buildMobileHomeCompactButton(context, isDark: isDark)
                : Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: navButtonBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: navButtonBorder),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bar_chart,
              color: AppTheme.primaryLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'รายงานการใช้งานโปรโมชั่น',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'รีเฟรช',
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: navButtonBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: navButtonBorder),
              ),
              child: InkWell(
                onTap: () => ref.invalidate(_promotionUsageProvider),
                borderRadius: BorderRadius.circular(8),
                child: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'Usage Report',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────────────────
  Widget _buildFilters(bool isDark) {
    final borderColor = isDark ? const Color(0xFF333333) : AppTheme.border;
    final inputFill = isDark ? AppTheme.darkElement : Colors.white;
    final inputBorder = isDark ? const Color(0xFF444444) : AppTheme.border;
    final chipBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final textStyle = TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
    );

    Widget dropdownChip({
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged,
    }) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            style: textStyle,
            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
            icon: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isDark ? Colors.white54 : AppTheme.textSub,
            ),
            onChanged: onChanged,
            items: items,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                style: textStyle,
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ / รหัสโปรโมชั่น...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : AppTheme.textSub,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                  filled: true,
                  fillColor: inputFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() { _search = v; _currentPage = 1; }),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Type filter
          dropdownChip(
            value: _filterType,
            onChanged: (v) => setState(() { _filterType = v!; _currentPage = 1; }),
            items: _typeLabels.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
          // Status filter
          dropdownChip(
            value: _filterStatus,
            onChanged: (v) => setState(() { _filterStatus = v!; _currentPage = 1; }),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ทุกสถานะ')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('เปิดใช้งาน')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('ปิดการใช้งาน')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Row ──────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(int total, int active, int totalUses, bool isDark) {
    final summaryBg = isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5);
    final borderColor = isDark ? const Color(0xFF333333) : AppTheme.border;

    final chips = [
      _summaryChip(
        'โปรโมชั่นทั้งหมด',
        '$total',
        Icons.local_offer_outlined,
        AppTheme.infoColor,
        isDark,
        borderColor,
      ),
      const SizedBox(width: 8),
      _summaryChip(
        'เปิดใช้งาน',
        '$active',
        Icons.check_circle_outline,
        AppTheme.successColor,
        isDark,
        borderColor,
      ),
      const SizedBox(width: 8),
      _summaryChip(
        'ใช้งานรวม (ครั้ง)',
        _numFmt.format(totalUses),
        Icons.analytics_outlined,
        const Color(0xFF9C27B0),
        isDark,
        borderColor,
      ),
    ];

    return Container(
      color: summaryBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: chips,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color borderColor,
  ) {
    final chipBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : AppTheme.textSub,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────
  Widget _buildTable(List<_PromoUsage> list, bool isDark) {
    final borderColor = isDark ? const Color(0xFF333333) : AppTheme.border;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.navyDark : AppTheme.navy,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
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
                isDark: isDark,
              ),
            ),
            Divider(height: 1, color: borderColor),
            // Rows
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final now = DateTime.now();
                  final isRunning =
                      p.isActive &&
                      now.isAfter(p.startDate) &&
                      now.isBefore(p.endDate);
                  final usageRatio = p.maxUses != null && p.maxUses! > 0
                      ? p.currentUses / p.maxUses!
                      : null;

                  return _HoverableRow(
                    isDark: isDark,
                    onTap: () => _showOrdersSheet(context, p),
                    child: _tableRow(
                      cells: [
                        _Cell(
                          p.promotionCode,
                          flex: 2,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        _Cell(
                          p.promotionName,
                          flex: 4,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _Cell(
                          _typeLabel(p.promotionType),
                          flex: 2,
                          style: TextStyle(
                            fontSize: 11,
                            color: _typeColor(p.promotionType),
                          ),
                        ),
                        _Cell(
                          '${_dateFmt.format(p.startDate)} –\n${_dateFmt.format(p.endDate)}',
                          flex: 3,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSub,
                          ),
                        ),
                        _Cell(
                          '${_numFmt.format(p.currentUses)} ครั้ง',
                          flex: 2,
                          align: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: p.currentUses > 0
                                ? AppTheme.primaryColor
                                : AppTheme.textSub,
                          ),
                          extra: usageRatio != null
                              ? LinearProgressIndicator(
                                  value: usageRatio.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: AppTheme.border.withValues(
                                    alpha: 0.5,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    usageRatio >= 0.9
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                  ),
                                )
                              : null,
                        ),
                        _Cell(
                          p.maxUses != null ? _numFmt.format(p.maxUses!) : '∞',
                          flex: 2,
                          align: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSub,
                          ),
                        ),
                        _Cell(
                          '',
                          flex: 2,
                          align: TextAlign.center,
                          extra: _statusBadge(isRunning, p.isActive),
                        ),
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
    final api = ref.read(apiClientProvider);
    final moneyFmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : AppTheme.border;

    // fetch ครั้งเดียว ใช้ร่วมกันระหว่าง UI และ PDF
    final ordersFuture = api
        .get('/api/promotions/usage/${promo.promotionId}/orders')
        .then((res) {
          if (res.statusCode == 200 && res.data != null) {
            final list = res.data['data'] as List;
            return list
                .map((j) => _PromoOrderUsage.fromJson(j as Map<String, dynamic>))
                .toList();
          }
          return <_PromoOrderUsage>[];
        });

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<List<_PromoOrderUsage>>(
            future: ordersFuture,
            builder: (_, snap) {
              final orders =
                  snap.connectionState == ConnectionState.done &&
                          !snap.hasError
                      ? (snap.data ?? <_PromoOrderUsage>[])
                      : <_PromoOrderUsage>[];
              final loaded = snap.connectionState == ConnectionState.done;

              // คำนวณ summary
              final totalRevenue =
                  orders.fold(0.0, (s, o) => s + o.totalAmount);
              final totalDiscount =
                  orders.fold(0.0, (s, o) => s + o.discountAmount);
              final completedCount = orders.length;
              final cancelledCount = promo.currentUses - completedCount;

              return Column(
                children: [
                  // handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.infoContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppTheme.infoColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promo.promotionName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                promo.promotionCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── ปุ่ม PDF ────────────────────────────
                        PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลคำสั่งซื้อ',
                          title: 'รายงาน: ${promo.promotionName}',
                          filename: () => PdfFilename.generate(
                            'promo_detail_${promo.promotionCode}',
                          ),
                          hasData: loaded && orders.isNotEmpty,
                          buildPdf: () =>
                              _PromoOrdersDetailPdfBuilder.build(
                            promo: promo,
                            orders: orders,
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
                    child: !loaded
                        ? snap.hasError
                            ? Center(
                                child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
                              )
                            : const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: scrollCtrl,
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            children: [
                              // ── Summary cards ───────────────────
                              Row(
                                children: [
                                  _SummaryTile(
                                    label: 'ใช้งานทั้งหมด',
                                    value: '${promo.currentUses} ครั้ง',
                                    icon: Icons.confirmation_number_outlined,
                                    color: AppTheme.infoColor,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _SummaryTile(
                                    label: 'คำสั่งซื้อสำเร็จ',
                                    value: '$completedCount รายการ',
                                    icon: Icons.check_circle_outline,
                                    color: AppTheme.successColor,
                                    isDark: isDark,
                                  ),
                                  if (cancelledCount > 0) ...[
                                    const SizedBox(width: 8),
                                    _SummaryTile(
                                      label: 'ยกเลิก/อื่นๆ',
                                      value: '$cancelledCount ครั้ง',
                                      icon: Icons.cancel_outlined,
                                      color: AppTheme.errorColor,
                                      isDark: isDark,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _SummaryTile(
                                    label: 'ยอดขายรวม',
                                    value: '฿${moneyFmt.format(totalRevenue)}',
                                    icon: Icons.monetization_on_outlined,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _SummaryTile(
                                    label: 'ส่วนลดรวม',
                                    value:
                                        '฿${moneyFmt.format(totalDiscount)}',
                                    icon: Icons.discount_outlined,
                                    color: AppTheme.successColor,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                              // ── หมายเหตุ (เมื่อ count ต่างกัน) ─
                              if (cancelledCount > 0) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2C2A1A)
                                        : const Color(0xFFFFFBE6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF6B5800)
                                          : const Color(0xFFFFD666),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 15,
                                        color: Color(0xFFD48806),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'แสดงเฉพาะคำสั่งซื้อที่สำเร็จ ($completedCount รายการ) '
                                          'จากทั้งหมด ${promo.currentUses} ครั้ง '
                                          '($cancelledCount ครั้งอาจถูกยกเลิกหรือใช้ผ่านคูปอง)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFAD6800),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── รายการ ──────────────────────────
                              const SizedBox(height: 14),
                              if (orders.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_outlined,
                                        size: 48,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black26,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'ยังไม่มีคำสั่งซื้อที่สำเร็จ',
                                        style: TextStyle(
                                          color: AppTheme.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                Text(
                                  'รายการคำสั่งซื้อที่สำเร็จ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white54
                                        : AppTheme.textSub,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    children: [
                                      for (var i = 0;
                                          i < orders.length;
                                          i++) ...[
                                        if (i > 0)
                                          Divider(
                                            height: 1,
                                            color: borderColor,
                                            indent: 16,
                                            endIndent: 16,
                                          ),
                                        _OrderTile(
                                          order: orders[i],
                                          index: i + 1,
                                          moneyFmt: moneyFmt,
                                          dateFmt: dateFmt,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tableRow({
    required List<_Cell> cells,
    required bool isHeader,
    bool isDark = false,
  }) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : Colors.white70,
    );
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
                    Text(
                      c.text,
                      textAlign: c.align,
                      style: c.style ??
                          (isHeader
                              ? headerStyle
                              : const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 4),
                    c.extra!,
                  ],
                )
              : Text(
                  c.text,
                  textAlign: c.align,
                  style: c.style ??
                      (isHeader
                          ? headerStyle
                          : const TextStyle(fontSize: 13)),
                );
          return Expanded(flex: c.flex, child: content);
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'BUY_X_GET_Y' => 'ซื้อ X แถม Y',
    'DISCOUNT_PERCENT' => 'ลด %',
    'DISCOUNT_AMOUNT' => 'ลดเงิน',
    'FREE_ITEM' => 'ของแถม',
    _ => type,
  };

  Color _typeColor(String type) => switch (type) {
    'BUY_X_GET_Y' => AppTheme.errorColor,
    'DISCOUNT_PERCENT' => const Color(0xFF9C27B0),
    'DISCOUNT_AMOUNT' => AppTheme.successColor,
    'FREE_ITEM' => const Color(0xFF009688),
    _ => AppTheme.textSub,
  };
}

// ─── PDF Builder ─────────────────────────────────────────────────────────────
class _PromoUsageReportPdfBuilder {
  static const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
  static const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
  static const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
  static const _kText = PdfColors.black;
  static const _kPrimary = PdfColor.fromInt(0xFFE57200);
  static const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
  static const _kSub = PdfColor.fromInt(0xFF555555);

  static Future<pw.Document> build(List<_PromoUsage> items) async {
    final companyName = await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานการใช้งานโปรโมชั่น',
      author: companyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final dateFmt = DateFormat('dd/MM/yy');
    final numFmt = NumberFormat('#,##0');
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // summary
    final running = items.where((p) {
      final now = DateTime.now();
      return p.isActive && now.isAfter(p.startDate) && now.isBefore(p.endDate);
    }).length;
    final inactive = items.where((p) => !p.isActive).length;
    final summaryLine =
        'ทั้งหมด ${items.length} รายการ   กำลังใช้งาน $running   รอเวลา ${items.length - running - inactive}   ปิด $inactive';

    final rowsPerPage = await SettingsStorage.getReportRowsPerPage();
    final batches = <List<_PromoUsage>>[];
    for (var i = 0; i < items.length; i += rowsPerPage) {
      batches.add(items.sublist(
        i,
        (i + rowsPerPage) > items.length ? items.length : i + rowsPerPage,
      ));
    }
    if (batches.isEmpty) batches.add([]);
    final totalPages = batches.length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => _buildPageHeader(
          companyName: companyName,
          reportTitle: 'รายงานการใช้งานโปรโมชั่น',
          printedAt: printedAt,
          page: ctx.pageNumber,
          totalPages: totalPages,
          ttf: ttf,
          ttfRegular: ttfRegular,
          summaryLine: summaryLine,
        ),
        footer: (ctx) => _buildFooter(
          companyName: companyName,
          ttfRegular: ttfRegular,
        ),
        build: (ctx) => [
          for (var i = 0; i < batches.length; i++)
            _buildTable(
              batches[i],
              startNo: i * rowsPerPage + 1,
              ttf: ttf,
              ttfRegular: ttfRegular,
              dateFmt: dateFmt,
              numFmt: numFmt,
            ),
        ],
      ),
    );

    return doc;
  }

  // ── Page Header ──────────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String companyName,
    required String reportTitle,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String? summaryLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'หน้าที่ $page / $totalPages',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            reportTitle,
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              summaryLine,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<_PromoUsage> pageItems, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    required DateFormat dateFmt,
    required NumberFormat numFmt,
  }) {
    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
      double fontSize = 8.5,
    }) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            color: color ?? _kText,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),    // #
        1: pw.FixedColumnWidth(70),    // รหัส
        2: pw.FlexColumnWidth(1),      // ชื่อโปรโมชั่น
        3: pw.FixedColumnWidth(55),    // ประเภท
        4: pw.FixedColumnWidth(90),    // ช่วงเวลา
        5: pw.FixedColumnWidth(50),    // ใช้งานแล้ว
        6: pw.FixedColumnWidth(40),    // สูงสุด
        7: pw.FixedColumnWidth(55),    // สถานะ
      },
      children: [
        // header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children: [
            '#',
            'รหัส',
            'ชื่อโปรโมชั่น',
            'ประเภท',
            'ช่วงเวลา',
            'ใช้แล้ว',
            'สูงสุด',
            'สถานะ',
          ]
              .map(
                (h) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: _kText,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // data rows
        ...pageItems.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final now = DateTime.now();
          final isRunning = p.isActive &&
              now.isAfter(p.startDate) &&
              now.isBefore(p.endDate);
          final statusLabel =
              isRunning ? 'กำลังใช้งาน' : p.isActive ? 'รอเวลา' : 'ปิด';
          final statusColor =
              isRunning ? _kSuccess : p.isActive ? _kPrimary : _kSub;
          final rowBg = i.isEven ? _kAltRow : null;

          return pw.TableRow(
            children: [
              cell('${startNo + i}', ttfRegular,
                  align: pw.Alignment.center, bgColor: rowBg),
              cell(p.promotionCode, ttf, bgColor: rowBg, fontSize: 7.5),
              cell(p.promotionName, ttfRegular, bgColor: rowBg),
              cell(_typeLabel(p.promotionType), ttfRegular,
                  bgColor: rowBg, color: _kSub, fontSize: 8),
              cell(
                '${dateFmt.format(p.startDate)}\n– ${dateFmt.format(p.endDate)}',
                ttfRegular,
                bgColor: rowBg,
                color: _kSub,
                fontSize: 7.5,
              ),
              cell(
                '${numFmt.format(p.currentUses)} ครั้ง',
                ttf,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(
                p.maxUses != null ? numFmt.format(p.maxUses!) : '∞',
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
                color: _kSub,
              ),
              cell(
                statusLabel,
                ttf,
                align: pw.Alignment.center,
                color: statusColor,
                bgColor: rowBg,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          companyName,
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
        ),
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
        'BUY_X_GET_Y' => 'ซื้อ X แถม Y',
        'DISCOUNT_PERCENT' => 'ลด %',
        'DISCOUNT_AMOUNT' => 'ลดเงิน',
        'FREE_ITEM' => 'ของแถม',
        _ => type,
      };
}

// ─── PDF Builder: รายละเอียดการใช้โปรโมชั่น ─────────────────────────────────
class _PromoOrdersDetailPdfBuilder {
  static const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
  static const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
  static const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
  static const _kText = PdfColors.black;
  static const _kSub = PdfColor.fromInt(0xFF555555);
  static const _kSuccess = PdfColor.fromInt(0xFF1B5E20);

  static final _moneyFmt = NumberFormat('#,##0.00', 'th');
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  static Future<pw.Document> build({
    required _PromoUsage promo,
    required List<_PromoOrderUsage> orders,
  }) async {
    final companyName = await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงาน: ${promo.promotionName}',
      author: companyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalRevenue = orders.fold(0.0, (s, o) => s + o.totalAmount);
    final totalDiscount = orders.fold(0.0, (s, o) => s + o.discountAmount);
    final completedCount = orders.length;
    final cancelledCount = promo.currentUses - completedCount;

    final shortFmt = DateFormat('dd/MM/yyyy');
    final subtitle =
        '${promo.promotionCode}  ·  ${_typeLabel(promo.promotionType)}'
        '  ·  ${shortFmt.format(promo.startDate)} – ${shortFmt.format(promo.endDate)}';
    final summaryLine =
        'ใช้งานทั้งหมด ${promo.currentUses} ครั้ง   '
        'สำเร็จ $completedCount รายการ'
        '${cancelledCount > 0 ? '   ยกเลิก/อื่นๆ $cancelledCount ครั้ง' : ''}   '
        'ยอดขายรวม ฿${_moneyFmt.format(totalRevenue)}   '
        'ส่วนลดรวม ฿${_moneyFmt.format(totalDiscount)}';

    final rowsPerPage = await SettingsStorage.getReportRowsPerPage();
    final batches = <List<_PromoOrderUsage>>[];
    for (var i = 0; i < orders.length; i += rowsPerPage) {
      batches.add(orders.sublist(
        i,
        (i + rowsPerPage) > orders.length ? orders.length : i + rowsPerPage,
      ));
    }
    if (batches.isEmpty) batches.add([]);
    final totalPages = batches.length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => _buildPageHeader(
          companyName: companyName,
          reportTitle: promo.promotionName,
          printedAt: printedAt,
          page: ctx.pageNumber,
          totalPages: totalPages,
          ttf: ttf,
          ttfRegular: ttfRegular,
          subtitle: subtitle,
          summaryLine: summaryLine,
        ),
        footer: (ctx) => _buildFooter(
          companyName: companyName,
          promotionName: promo.promotionName,
          ttfRegular: ttfRegular,
        ),
        build: (ctx) => [
          for (var i = 0; i < batches.length; i++)
            _buildTable(
              batches[i],
              startNo: i * rowsPerPage + 1,
              ttf: ttf,
              ttfRegular: ttfRegular,
            ),
        ],
      ),
    );

    return doc;
  }

  // ── Page Header ──────────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String companyName,
    required String reportTitle,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String? subtitle,
    String? summaryLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'หน้าที่ $page / $totalPages',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            reportTitle,
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              summaryLine,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<_PromoOrderUsage> orders, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
      double fontSize = 8.5,
    }) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            color: color ?? _kText,
          ),
        ),
      );
    }

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(24),  // #
        1: pw.FixedColumnWidth(80),  // วันที่
        2: pw.FlexColumnWidth(1.5),  // เลขที่ใบขาย
        3: pw.FlexColumnWidth(1),    // ลูกค้า
        4: pw.FixedColumnWidth(75),  // ยอดรวม
        5: pw.FixedColumnWidth(65),  // ส่วนลด
      },
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children: ['#', 'วันที่-เวลา', 'เลขที่ใบขาย', 'ลูกค้า', 'ยอดรวม', 'ส่วนลด']
              .map(
                (h) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: _kText),
                  ),
                ),
              )
              .toList(),
        ),
        // data rows
        ...orders.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          final rowBg = i.isEven ? _kAltRow : null;

          return pw.TableRow(
            children: [
              cell('${startNo + i}', ttfRegular,
                  align: pw.Alignment.center, bgColor: rowBg),
              cell(_dateFmt.format(o.usedAt), ttfRegular,
                  fontSize: 7.5, color: _kSub, bgColor: rowBg),
              cell(o.orderNo, ttf, bgColor: rowBg),
              cell(o.customerName, ttfRegular, bgColor: rowBg),
              cell('฿${_moneyFmt.format(o.totalAmount)}', ttf,
                  align: pw.Alignment.centerRight, bgColor: rowBg),
              cell(
                o.discountAmount > 0
                    ? '฿${_moneyFmt.format(o.discountAmount)}'
                    : '-',
                ttfRegular,
                align: pw.Alignment.centerRight,
                color: o.discountAmount > 0 ? _kSuccess : _kSub,
                bgColor: rowBg,
              ),
            ],
          );
        }),
        // total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: pw.SizedBox(),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: pw.SizedBox(),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: pw.SizedBox(),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'รวม',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: _kText),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '฿${_moneyFmt.format(orders.fold(0.0, (s, o) => s + o.totalAmount))}',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: _kText),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '฿${_moneyFmt.format(orders.fold(0.0, (s, o) => s + o.discountAmount))}',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: _kSuccess),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required String companyName,
    required String promotionName,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          companyName,
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
        ),
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
        'BUY_X_GET_Y' => 'ซื้อ X แถม Y',
        'DISCOUNT_PERCENT' => 'ลด %',
        'DISCOUNT_AMOUNT' => 'ลดเงิน',
        'FREE_ITEM' => 'ของแถม',
        _ => type,
      };
}

// ─── Hoverable row wrapper ────────────────────────────────────────────────────
class _HoverableRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isDark;

  const _HoverableRow({
    required this.child,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final normalBg =
        widget.isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final hoverBg = widget.isDark
        ? AppTheme.primaryLight.withValues(alpha: 0.15)
        : AppTheme.primaryLight;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? hoverBg : normalBg,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Summary tile ────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8);
    final border = isDark ? const Color(0xFF3A3A3A) : AppTheme.border;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : AppTheme.textSub,
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
}

// ─── Order tile ──────────────────────────────────────────────────────────────
class _OrderTile extends StatelessWidget {
  final _PromoOrderUsage order;
  final int index;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;
  final bool isDark;

  const _OrderTile({
    required this.order,
    required this.index,
    required this.moneyFmt,
    required this.dateFmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // ลำดับ
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 11),
          // order info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                ),
                Text(
                  dateFmt.format(order.usedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          // amounts
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${moneyFmt.format(order.totalAmount)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.discountAmount > 0)
                Text(
                  'ลด ฿${moneyFmt.format(order.discountAmount)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.successColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helper data class ───────────────────────────────────────────────────────
class _Cell {
  final String text;
  final int flex;
  final TextAlign align;
  final TextStyle? style;
  final Widget? extra; // e.g. LinearProgressIndicator

  const _Cell(
    this.text, {
    this.flex = 1,
    this.align = TextAlign.start,
    this.style,
    this.extra,
  });
}
