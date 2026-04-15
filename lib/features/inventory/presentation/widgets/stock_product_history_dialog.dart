import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/models/stock_balance_model.dart';
import '../pages/stock_product_history_pdf_report.dart';

// ── helpers ────────────────────────────────────────────────────────
Color _typeColor(String t) {
  switch (t) {
    case 'IN':
      return const Color(0xFF2E7D32);
    case 'OUT':
      return const Color(0xFFE65100);
    case 'ADJUST':
      return const Color(0xFF1565C0);
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
      return const Color(0xFF6A1B9A);
    case 'SALE':
      return const Color(0xFFC62828);
    default:
      return Colors.grey;
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'IN':
      return Icons.add_box_rounded;
    case 'OUT':
      return Icons.remove_circle_rounded;
    case 'ADJUST':
      return Icons.tune_rounded;
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
      return Icons.swap_horiz_rounded;
    case 'SALE':
      return Icons.shopping_cart_rounded;
    default:
      return Icons.history;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'IN':
      return 'รับเข้า';
    case 'OUT':
      return 'เบิกออก';
    case 'ADJUST':
      return 'ปรับสต๊อก';
    case 'TRANSFER_IN':
      return 'รับโอน';
    case 'TRANSFER_OUT':
      return 'โอนออก';
    case 'SALE':
      return 'ขาย';
    default:
      return t;
  }
}

// ── Model ──────────────────────────────────────────────────────────
class _Movement {
  final String movementId;
  final DateTime movementDate;
  final String movementType;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final String? referenceNo;
  final String? remark;
  final String? baseUnit;

  _Movement({
    required this.movementId,
    required this.movementDate,
    required this.movementType,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    this.referenceNo,
    this.remark,
    this.baseUnit,
  });

  factory _Movement.fromJson(Map<String, dynamic> j) => _Movement(
    movementId: j['movement_id'] as String,
    movementDate: DateTime.parse(j['movement_date'] as String),
    movementType: j['movement_type'] as String,
    warehouseId: j['warehouse_id'] as String,
    warehouseName:
        j['warehouse_name'] as String? ?? j['warehouse_id'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    referenceNo: j['reference_no'] as String?,
    remark: j['remark'] as String?,
    baseUnit: j['base_unit'] as String?,
  );
}

// ── Provider ───────────────────────────────────────────────────────
final _productHistoryProvider = FutureProvider.family<List<_Movement>, String>((
  ref,
  productId,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/stock/movements/product/$productId');
  if (res.statusCode == 200) {
    final data = res.data['data'] as List;
    return data
        .map((j) => _Movement.fromJson(j as Map<String, dynamic>))
        .toList();
  }
  return [];
});

// ── Dialog ─────────────────────────────────────────────────────────
class StockProductHistoryDialog extends ConsumerStatefulWidget {
  final StockBalanceModel stock;
  const StockProductHistoryDialog({super.key, required this.stock});

  @override
  ConsumerState<StockProductHistoryDialog> createState() =>
      _StockProductHistoryDialogState();
}

class _StockProductHistoryDialogState
    extends ConsumerState<StockProductHistoryDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    ('ALL', 'ทั้งหมด', Icons.history, Colors.blueGrey),
    ('IN', 'รับเข้า', Icons.add_box_rounded, Color(0xFF2E7D32)),
    ('OUT', 'เบิกออก', Icons.remove_circle_rounded, Color(0xFFE65100)),
    ('ADJUST', 'ปรับสต๊อก', Icons.tune_rounded, Color(0xFF1565C0)),
    ('SALE', 'ขาย', Icons.shopping_cart_rounded, Color(0xFFC62828)),
  ];

  int _tabIndex = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _tabIndex = _tabController.index;
        _currentPage = 1; // reset หน้าเมื่อเปลี่ยน tab
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_Movement> _filter(List<_Movement> all, String type) {
    if (type == 'ALL') return all;
    return all.where((m) => m.movementType == type).toList();
  }

  int _countByType(List<_Movement> all, String type) =>
      _filter(all, type).length;

  @override
  Widget build(BuildContext context) {
    final productId = widget.stock.productId;
    final historyAsync = ref.watch(_productHistoryProvider(productId));
    final dialogPageSize = ref.watch(settingsProvider).dialogPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkCard : Colors.white;
    final border = isDark ? const Color(0xFF333333) : AppTheme.border;
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub;
    final summaryBg = isDark
        ? const Color(0xFF181818)
        : const Color(0xFFFFF8F5);
    final summaryChipBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.navyDark : AppTheme.navy,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: AppTheme.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ประวัติสต๊อกสินค้า',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.stock.productCode}  ${widget.stock.productName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // สต๊อกคงเหลือ badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'คงเหลือ ${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  buildMobileCloseCompactButton(context),
                ],
              ),
            ),

            // ── Filter Bar ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkTopBar : Colors.white,
                border: Border(bottom: BorderSide(color: border)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: subtextColor,
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: _tabs.map((t) {
                    final (type, label, icon, color) = t;
                    return Tab(
                      child: historyAsync.when(
                        loading: () => Text(label),
                        error: (_, _) => Text(label),
                        data: (all) {
                          final cnt = _countByType(all, type);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _tabs[_tabIndex].$1 == type
                                  ? color.withValues(alpha: 0.12)
                                  : (isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _tabs[_tabIndex].$1 == type
                                    ? color
                                    : border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 13, color: color),
                                const SizedBox(width: 4),
                                Text(label),
                                if (cnt > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$cnt',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight: FontWeight.bold,
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
                  }).toList(),
                ),
              ),
            ),

            // ── Summary Bar ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: summaryBg),
              child: historyAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (all) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HistorySummaryChip(
                      icon: Icons.receipt_long,
                      label: '${all.length} รายการ',
                      color: AppTheme.info,
                      bg: summaryChipBg,
                      border: border,
                    ),
                    _HistorySummaryChip(
                      icon: Icons.add_box_rounded,
                      label: '${_countByType(all, 'IN')} รับเข้า',
                      color: const Color(0xFF2E7D32),
                      bg: summaryChipBg,
                      border: border,
                    ),
                    _HistorySummaryChip(
                      icon: Icons.remove_circle_rounded,
                      label: '${_countByType(all, 'OUT')} เบิกออก',
                      color: const Color(0xFFE65100),
                      bg: summaryChipBg,
                      border: border,
                    ),
                    _HistorySummaryChip(
                      icon: Icons.tune_rounded,
                      label: '${_countByType(all, 'ADJUST')} ปรับสต๊อก',
                      color: const Color(0xFF1565C0),
                      bg: summaryChipBg,
                      border: border,
                    ),
                  ],
                ),
              ),
            ),

            // ── Content + Pagination (เหมือน product list) ──────
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'เกิดข้อผิดพลาด: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(_productHistoryProvider(productId)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final (tabType, tabLabel, _, _) = _tabs[_tabIndex];
                  final filtered = _filter(all, tabType);
                  final totalPages = filtered.isEmpty
                      ? 1
                      : (filtered.length / dialogPageSize).ceil();
                  final safePage = _currentPage.clamp(1, totalPages);

                  return Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: _tabs.map((t) {
                            final (type, _, _, _) = t;
                            final tabFiltered = _filter(all, type);

                            // คำนวณ page เฉพาะ active tab เพื่อ performance
                            final tStart = (safePage - 1) * dialogPageSize;
                            final tEnd = (tStart + dialogPageSize).clamp(
                              0,
                              tabFiltered.length,
                            );
                            final pageItems = tabFiltered.isEmpty
                                ? <_Movement>[]
                                : tabFiltered.sublist(tStart, tEnd);

                            if (tabFiltered.isEmpty) return _buildEmpty();
                            return ListView.separated(
                              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                              itemCount: pageItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, i) => _HistoryCard(
                                movement: pageItems[i],
                                baseUnit: widget.stock.baseUnit,
                                isDark: isDark,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // ── PaginationBar (แบบเดียวกับ product list) ──
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: dialogPageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีรายการประวัติสต๊อก',
                          title: 'ประวัติสต๊อก ${widget.stock.productName}',
                          filename: () => PdfFilename.generate(
                            'stock_history_${widget.stock.productCode}',
                          ),
                          hasData: filtered.isNotEmpty,
                          buildPdf: () => StockProductHistoryPdfBuilder.build(
                            productCode: widget.stock.productCode,
                            productName: widget.stock.productName,
                            baseUnit: widget.stock.baseUnit,
                            currentBalance: widget.stock.balance,
                            filterLabel: tabLabel,
                            items: filtered
                                .map(
                                  (m) => StockHistoryPdfItem(
                                    movementDate: m.movementDate,
                                    movementType: m.movementType,
                                    warehouseName: m.warehouseName,
                                    quantity: m.quantity,
                                    referenceNo: m.referenceNo,
                                    remark: m.remark,
                                  ),
                                )
                                .toList(),
                          ),
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

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: const Icon(Icons.history, size: 28, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const Text(
          'ไม่มีประวัติในหมวดนี้',
          style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
        ),
      ],
    ),
  );
}

class _HistorySummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final Color border;

  const _HistorySummaryChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── HistoryCard ────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _Movement movement;
  final String baseUnit;
  final bool isDark;
  const _HistoryCard({
    required this.movement,
    required this.baseUnit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(movement.movementType);
    final icon = _typeIcon(movement.movementType);
    final isPositive = movement.quantity >= 0;
    final qtyColor = isPositive
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE8E8E8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // type badge + qty
                Row(
                  children: [
                    _TypeBadge(type: movement.movementType),
                    const Spacer(),
                    Text(
                      '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(0)} $baseUnit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: qtyColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // date + warehouse
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 11,
                      color: isDark
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF9E9E9E),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(movement.movementDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.warehouse_outlined,
                      size: 11,
                      color: isDark
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF9E9E9E),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      movement.warehouseName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF777777),
                      ),
                    ),
                  ],
                ),

                // reference / remark
                if (movement.referenceNo != null &&
                    movement.referenceNo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 11,
                        color: isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          movement.referenceNo!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFD0D0D0)
                                : const Color(0xFF555555),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (movement.remark != null && movement.remark!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 11,
                        color: isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          movement.remark!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF888888),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ── TypeBadge ──────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
