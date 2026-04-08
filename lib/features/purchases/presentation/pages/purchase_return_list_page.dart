import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../providers/purchase_return_provider.dart';
import '../../data/models/purchase_return_model.dart';
import 'purchase_return_form_page.dart';
import 'purchase_return_pdf_report.dart';

class PurchaseReturnListPage extends ConsumerStatefulWidget {
  const PurchaseReturnListPage({super.key});

  @override
  ConsumerState<PurchaseReturnListPage> createState() =>
      _PurchaseReturnListPageState();
}

class _PurchaseReturnListPageState
    extends ConsumerState<PurchaseReturnListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _isCardView = false;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PurchaseReturnModel> _filter(List<PurchaseReturnModel> src) {
    return src.where((r) {
      final matchesSearch =
          r.returnNo.toLowerCase().contains(_searchQuery) ||
          r.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus = _statusFilter == 'ALL' || r.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList()..sort((a, b) => b.returnDate.compareTo(a.returnDate));
  }

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(purchaseReturnListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────
            _PRListTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              isCardView: _isCardView,
              onSearchChanged: (v) => setState(() {
                _searchQuery = v.toLowerCase();
                _currentPage = 1;
              }),
              onSearchCleared: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
              },
              onToggleView: () => setState(() => _isCardView = !_isCardView),
              onRefresh: () =>
                  ref.read(purchaseReturnListProvider.notifier).refresh(),
              onAdd: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseReturnFormPage(),
                    ),
                  ).then(
                    (_) =>
                        ref.read(purchaseReturnListProvider.notifier).refresh(),
                  ),
            ),

            // ── Summary + Status Filter Bar ──────────────────────
            _buildSummaryBar(returnsAsync),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: returnsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (returns) {
                  final filtered = _filter(returns);
                  if (filtered.isEmpty) return _buildEmpty();
                  final totalPages = (filtered.length / pageSize).ceil().clamp(
                    1,
                    9999,
                  );
                  final safePage = _currentPage.clamp(1, totalPages);
                  final start = (safePage - 1) * pageSize;
                  final end = (start + pageSize).clamp(0, filtered.length);
                  final pageItems = filtered.sublist(start, end);
                  return Column(
                    children: [
                      Expanded(
                        child: _isCardView
                            ? _buildCardView(pageItems)
                            : _buildListView(pageItems),
                      ),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลการคืนสินค้า',
                          title: 'รายงานการคืนสินค้า',
                          filename: () =>
                              PdfFilename.generate('purchase_return_report'),
                          buildPdf: () =>
                              PurchaseReturnPdfBuilder.build(filtered),
                          hasData: filtered.isNotEmpty,
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

  // ─────────────────────────────────────────────────────────────
  // Summary Bar + Status Filter
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(AsyncValue<List<PurchaseReturnModel>> returnsAsync) {
    return returnsAsync.maybeWhen(
      data: (all) {
        final filtered = _filter(all);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fmt = NumberFormat('#,##0.00', 'th_TH');
        final totalAmt = filtered.fold<double>(0, (s, r) => s + r.totalAmount);

        int countByStatus(String s) => all.where((r) => r.status == s).length;

        return Container(
          color: isDark ? AppTheme.darkCard : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PRFilterChip(
                      label: 'ทั้งหมด',
                      count: all.length,
                      color: AppTheme.navy,
                      selected: _statusFilter == 'ALL',
                      onTap: () => setState(() {
                        _statusFilter = 'ALL';
                        _currentPage = 1;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _PRFilterChip(
                      label: 'ร่าง',
                      count: countByStatus('DRAFT'),
                      color: AppTheme.warning,
                      selected: _statusFilter == 'DRAFT',
                      onTap: () => setState(() {
                        _statusFilter = 'DRAFT';
                        _currentPage = 1;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _PRFilterChip(
                      label: 'ยืนยันแล้ว',
                      count: countByStatus('CONFIRMED'),
                      color: AppTheme.success,
                      selected: _statusFilter == 'CONFIRMED',
                      onTap: () => setState(() {
                        _statusFilter = 'CONFIRMED';
                        _currentPage = 1;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Summary stats
              Row(
                children: [
                  _PRValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} ใบ',
                    color: AppTheme.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  _PRValueStat(
                    label: 'ยอดรวม',
                    value: '฿${fmt.format(totalAmt)}',
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  _PRValueStat(
                    label: 'รายการสินค้า',
                    value:
                        '${filtered.fold(0, (s, r) => s + (r.items?.length ?? 0))} รายการ',
                    color: AppTheme.info,
                  ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARD VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardView(List<PurchaseReturnModel> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PRCard(
        returnDoc: items[i],
        onTap: () => _openForm(items[i]),
        onConfirm: () => _confirmReturn(items[i]),
        onDelete: () => _deleteReturn(items[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIST VIEW (compact)
  // ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<PurchaseReturnModel> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  'เลขที่ / ซัพพลายเออร์',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  'วันที่',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'สถานะ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 86,
                child: Text(
                  'ยอดรวม',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              final isEven = i.isEven;
              final statusColor = r.isConfirmed
                  ? AppTheme.success
                  : AppTheme.warning;
              return InkWell(
                onTap: () => _openForm(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isEven
                        ? (isDark ? AppTheme.darkCard : Colors.white)
                        : (isDark
                              ? AppTheme.darkElement
                              : const Color(0xFFF9F9F9)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : AppTheme.border,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.returnNo,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              r.supplierName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFAAAAAA)
                                    : AppTheme.textSub,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          DateFormat('dd/MM/yy').format(r.returnDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : AppTheme.textSub,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Center(child: _PRStatusBadge(status: r.status)),
                      ),
                      SizedBox(
                        width: 86,
                        child: Text(
                          '฿${NumberFormat('#,##0.00', 'th_TH').format(r.totalAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFEF9A9A)
                                : AppTheme.error,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Empty / Error
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_return_outlined,
            size: 64,
            color: isDark ? const Color(0xFF555555) : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่มีรายการคืนสินค้า',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseReturnFormPage(),
                  ),
                ).then(
                  (_) =>
                      ref.read(purchaseReturnListProvider.notifier).refresh(),
                ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('สร้างใบคืนสินค้า'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(
            'เกิดข้อผิดพลาด: $error',
            style: const TextStyle(color: AppTheme.textSub),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                ref.read(purchaseReturnListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  void _openForm(PurchaseReturnModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PurchaseReturnFormPage(returnDoc: r)),
    ).then((_) => ref.read(purchaseReturnListProvider.notifier).refresh());
  }

  Future<void> _confirmReturn(PurchaseReturnModel r) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'ยืนยันการคืนสินค้า',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ยืนยันใบคืนสินค้า ${r.returnNo}?',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppTheme.textSub,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ระบบจะลดสต๊อกสินค้าตามจำนวนที่คืน',
                      style: TextStyle(fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final success = await ref
          .read(purchaseReturnListProvider.notifier)
          .confirmReturn(r.returnId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ยืนยันสำเร็จ' : 'ยืนยันไม่สำเร็จ'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteReturn(PurchaseReturnModel r) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'ลบใบคืนสินค้า',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'ต้องการลบใบคืนสินค้า ${r.returnNo} ใช่หรือไม่?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : AppTheme.textSub,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final success = await ref
          .read(purchaseReturnListProvider.notifier)
          .deleteReturn(r.returnId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ลบสำเร็จ' : 'ลบไม่สำเร็จ'),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════
class _PRListTopBar extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _PRListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.isCardView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  State<_PRListTopBar> createState() => _PRListTopBarState();
}

class _PRListTopBarState extends State<_PRListTopBar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkTopBar : AppTheme.navy;
    final safeTop = MediaQuery.of(context).padding.top;

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(12, safeTop + 8, 12, 10),
      child: LayoutBuilder(
        builder: (_, c) {
          final isWide = c.maxWidth >= 640;
          if (isWide) {
            return Row(
              children: [
                _PRPageIcon(),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'คืนสินค้า',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                _PRSearchField(
                  controller: widget.searchController,
                  onChanged: widget.onSearchChanged,
                  onCleared: widget.onSearchCleared,
                ),
                const SizedBox(width: 6),
                _PRIconBtn(
                  icon: widget.isCardView ? Icons.view_list : Icons.grid_view,
                  tooltip: widget.isCardView ? 'ListView' : 'CardView',
                  onTap: widget.onToggleView,
                ),
                const SizedBox(width: 4),
                _PRIconBtn(
                  icon: Icons.refresh,
                  tooltip: 'รีเฟรช',
                  onTap: widget.onRefresh,
                ),
                const SizedBox(width: 6),
                _PRAddBtn(onTap: widget.onAdd),
              ],
            );
          }
          // Narrow — 2 rows
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PRPageIcon(),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'คืนสินค้า',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _PRIconBtn(
                    icon: widget.isCardView ? Icons.view_list : Icons.grid_view,
                    tooltip: widget.isCardView ? 'ListView' : 'CardView',
                    onTap: widget.onToggleView,
                  ),
                  const SizedBox(width: 4),
                  _PRIconBtn(
                    icon: Icons.refresh,
                    tooltip: 'รีเฟรช',
                    onTap: widget.onRefresh,
                  ),
                  const SizedBox(width: 6),
                  _PRAddBtn(onTap: widget.onAdd),
                ],
              ),
              const SizedBox(height: 8),
              _PRSearchField(
                controller: widget.searchController,
                onChanged: widget.onSearchChanged,
                onCleared: widget.onSearchCleared,
                fullWidth: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD
// ═══════════════════════════════════════════════════════════════
class _PRCard extends StatelessWidget {
  final PurchaseReturnModel returnDoc;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const _PRCard({
    required this.returnDoc,
    required this.onTap,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = returnDoc.isConfirmed
        ? AppTheme.success
        : AppTheme.warning;
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final dateFmt = DateFormat('dd/MM/yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_return,
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          returnDoc.returnNo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          returnDoc.supplierName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : AppTheme.textSub,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _PRStatusBadge(status: returnDoc.status),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _PRInfoChip(
                        icon: Icons.calendar_today,
                        label: dateFmt.format(returnDoc.returnDate),
                      ),
                      const SizedBox(width: 8),
                      _PRInfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: '${returnDoc.items?.length ?? 0} รายการ',
                      ),
                      if (returnDoc.reason != null &&
                          returnDoc.reason!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PRInfoChip(
                            icon: Icons.warning_amber_outlined,
                            label: returnDoc.reason!,
                            color: AppTheme.warning,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ยอดรวมที่คืน',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub,
                        ),
                      ),
                      Text(
                        '฿${fmt.format(returnDoc.totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFEF9A9A)
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  // Draft actions
                  if (returnDoc.isDraft) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onConfirm,
                            icon: const Icon(Icons.check, size: 15),
                            label: const Text(
                              'ยืนยัน',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.success,
                              side: const BorderSide(
                                color: AppTheme.success,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline, size: 15),
                            label: const Text(
                              'ลบ',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(
                                color: AppTheme.error,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════
class _PRFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PRFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  static Color _visible(Color c, bool isDark) {
    if (!isDark) return c;
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness < 0.50) {
      return hsl
          .withLightness(0.68)
          .withSaturation((hsl.saturation * 0.75).clamp(0.0, 1.0))
          .toColor();
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vc = _visible(color, isDark);

    if (!selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF4A4A4A) : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppTheme.textSub,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF5A5A5A) : AppTheme.textSub,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: vc.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: vc, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: vc,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: vc,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PRValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PRValueStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSub),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PRStatusBadge extends StatelessWidget {
  final String status;
  const _PRStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case 'CONFIRMED':
        color = AppTheme.success;
        label = 'ยืนยันแล้ว';
        break;
      default:
        color = AppTheme.warning;
        label = 'ร่าง';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
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
}

class _PRInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final int maxLines;

  const _PRInfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: c),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PRPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.assignment_return, size: 18, color: Colors.white),
    );
  }
}

class _PRSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool fullWidth;

  const _PRSearchField({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      width: fullWidth ? double.infinity : 200,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'ค้นหาเลขที่, ซัพพลายเออร์...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onCleared,
                  child: const Icon(
                    Icons.clear,
                    size: 16,
                    color: Colors.white54,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white38, width: 1),
          ),
        ),
      ),
    );
    return fullWidth ? field : field;
  }
}

class _PRIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PRIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _PRAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PRAddBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'คืนสินค้า',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
