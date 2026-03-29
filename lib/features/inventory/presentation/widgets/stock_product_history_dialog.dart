import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../data/models/stock_balance_model.dart';
import '../pages/stock_product_history_pdf_report.dart';

// ── helpers ────────────────────────────────────────────────────────
Color _typeColor(String t) {
  switch (t) {
    case 'IN':           return const Color(0xFF2E7D32);
    case 'OUT':          return const Color(0xFFE65100);
    case 'ADJUST':       return const Color(0xFF1565C0);
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT': return const Color(0xFF6A1B9A);
    case 'SALE':         return const Color(0xFFC62828);
    default:             return Colors.grey;
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'IN':           return Icons.add_box_rounded;
    case 'OUT':          return Icons.remove_circle_rounded;
    case 'ADJUST':       return Icons.tune_rounded;
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT': return Icons.swap_horiz_rounded;
    case 'SALE':         return Icons.shopping_cart_rounded;
    default:             return Icons.history;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'IN':           return 'รับเข้า';
    case 'OUT':          return 'เบิกออก';
    case 'ADJUST':       return 'ปรับสต๊อก';
    case 'TRANSFER_IN':  return 'รับโอน';
    case 'TRANSFER_OUT': return 'โอนออก';
    case 'SALE':         return 'ขาย';
    default:             return t;
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
        movementId:   j['movement_id'] as String,
        movementDate: DateTime.parse(j['movement_date'] as String),
        movementType: j['movement_type'] as String,
        warehouseId:  j['warehouse_id'] as String,
        warehouseName: j['warehouse_name'] as String? ?? j['warehouse_id'] as String,
        quantity:     (j['quantity'] as num).toDouble(),
        referenceNo:  j['reference_no'] as String?,
        remark:       j['remark'] as String?,
        baseUnit:     j['base_unit'] as String?,
      );
}

// ── Provider ───────────────────────────────────────────────────────
final _productHistoryProvider =
    FutureProvider.family<List<_Movement>, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/stock/movements/product/$productId');
  if (res.statusCode == 200) {
    final data = res.data['data'] as List;
    return data.map((j) => _Movement.fromJson(j as Map<String, dynamic>)).toList();
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
    ('ALL',          'ทั้งหมด',   Icons.history,            Colors.blueGrey),
    ('IN',           'รับเข้า',   Icons.add_box_rounded,    Color(0xFF2E7D32)),
    ('OUT',          'เบิกออก',   Icons.remove_circle_rounded, Color(0xFFE65100)),
    ('ADJUST',       'ปรับสต๊อก', Icons.tune_rounded,       Color(0xFF1565C0)),
    ('SALE',         'ขาย',       Icons.shopping_cart_rounded, Color(0xFFC62828)),
  ];

  int _tabIndex   = 0;
  int _currentPage = 1;
  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _tabIndex    = _tabController.index;
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

  @override
  Widget build(BuildContext context) {
    final productId   = widget.stock.productId;
    final historyAsync = ref.watch(_productHistoryProvider(productId));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.white,
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
                color: AppTheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ประวัติสต๊อกสินค้า',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.navyColor)),
                        Text(
                          '${widget.stock.productCode}  ${widget.stock.productName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // สต๊อกคงเหลือ badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'คงเหลือ ${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'ปิด',
                  ),
                ],
              ),
            ),

            // ── TabBar ──────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: const Color(0xFF888888),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: _tabs.map((t) {
                  final (type, label, icon, color) = t;
                  return Tab(
                    child: historyAsync.when(
                      loading: () => Text(label),
                      error: (_, _) => Text(label),
                      data: (all) {
                        final cnt = _filter(all, type).length;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: color),
                            const SizedBox(width: 4),
                            Text(label),
                            if (cnt > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$cnt',
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),

            // ── Content + Pagination (เหมือน product list) ──────
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('เกิดข้อผิดพลาด: $e',
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(_productHistoryProvider(productId)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final (tabType, tabLabel, _, _) = _tabs[_tabIndex];
                  final filtered   = _filter(all, tabType);
                  final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
                  final safePage   = _currentPage.clamp(1, totalPages);

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
                            final tStart = (safePage - 1) * _pageSize;
                            final tEnd   = (tStart + _pageSize).clamp(0, tabFiltered.length);
                            final pageItems = tabFiltered.isEmpty
                                ? <_Movement>[]
                                : tabFiltered.sublist(tStart, tEnd);

                            if (tabFiltered.isEmpty) return _buildEmpty();
                            return ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: pageItems.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (_, i) => _HistoryCard(
                                movement: pageItems[i],
                                baseUnit: widget.stock.baseUnit,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // ── PaginationBar (แบบเดียวกับ product list) ──
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: _pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีรายการประวัติสต๊อก',
                          title: 'ประวัติสต๊อก ${widget.stock.productName}',
                          filename: () => PdfFilename.generate(
                              'stock_history_${widget.stock.productCode}'),
                          hasData: filtered.isNotEmpty,
                          buildPdf: () => StockProductHistoryPdfBuilder.build(
                            productCode: widget.stock.productCode,
                            productName: widget.stock.productName,
                            baseUnit: widget.stock.baseUnit,
                            currentBalance: widget.stock.balance,
                            filterLabel: tabLabel,
                            items: filtered
                                .map((m) => StockHistoryPdfItem(
                                      movementDate: m.movementDate,
                                      movementType: m.movementType,
                                      warehouseName: m.warehouseName,
                                      quantity: m.quantity,
                                      referenceNo: m.referenceNo,
                                      remark: m.remark,
                                    ))
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
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: const Icon(Icons.history, size: 28, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('ไม่มีประวัติในหมวดนี้',
                style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
          ],
        ),
      );
}

// ── HistoryCard ────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _Movement movement;
  final String baseUnit;
  const _HistoryCard({required this.movement, required this.baseUnit});

  @override
  Widget build(BuildContext context) {
    final color      = _typeColor(movement.movementType);
    final icon       = _typeIcon(movement.movementType);
    final isPositive = movement.quantity >= 0;
    final qtyColor   = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
                          color: qtyColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // date + warehouse
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 11, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(movement.movementDate),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.warehouse_outlined, size: 11, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 3),
                    Text(
                      movement.warehouseName,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
                    ),
                  ],
                ),

                // reference / remark
                if (movement.referenceNo != null && movement.referenceNo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.tag, size: 11, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          movement.referenceNo!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
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
                      const Icon(Icons.notes, size: 11, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          movement.remark!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                              fontStyle: FontStyle.italic),
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
