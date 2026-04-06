import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import '../providers/goods_receipt_provider.dart';
import '../../data/models/goods_receipt_model.dart';
import 'goods_receipt_form_page.dart';
import 'goods_receipt_pdf_report.dart';

class GoodsReceiptListPage extends ConsumerStatefulWidget {
  const GoodsReceiptListPage({super.key});

  @override
  ConsumerState<GoodsReceiptListPage> createState() =>
      _GoodsReceiptListPageState();
}

class _GoodsReceiptListPageState
    extends ConsumerState<GoodsReceiptListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _isCardView = false;
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GoodsReceiptModel> _filter(List<GoodsReceiptModel> src) {
    return src.where((r) {
      final matchesSearch =
          r.grNo.toLowerCase().contains(_searchQuery) ||
              (r.poNo?.toLowerCase().contains(_searchQuery) ?? false) ||
              r.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'ALL' || r.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(goodsReceiptListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────
          _GRListTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            isCardView: _isCardView,
            onSearchChanged: (v) =>
                setState(() { _searchQuery = v.toLowerCase(); _currentPage = 1; }),
            onSearchCleared: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _currentPage = 1; });
            },
            onToggleView: () =>
                setState(() => _isCardView = !_isCardView),
            onRefresh: () =>
                ref.read(goodsReceiptListProvider.notifier).refresh(),
            onAdd: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GoodsReceiptFormPage()),
            ),
          ),

          // ── Summary + Status Filter Bar ──────────────────────
          _buildSummaryBar(receiptsAsync),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: receiptsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (receipts) {
                final filtered = _filter(receipts);
                if (filtered.isEmpty) return _buildEmpty();
                final totalPages =
                    (filtered.length / _pageSize).ceil().clamp(1, 9999);
                final safePage = _currentPage.clamp(1, totalPages);
                final start = (safePage - 1) * _pageSize;
                final end = (start + _pageSize).clamp(0, filtered.length);
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
                      pageSize: _pageSize,
                      onPageChanged: (p) =>
                          setState(() => _currentPage = p),
                      trailing: PdfReportButton(
                        emptyMessage: 'ไม่มีข้อมูลการรับสินค้า',
                        title: 'รายงานการรับสินค้า',
                        filename: () =>
                            PdfFilename.generate('goods_receipt_report'),
                        buildPdf: () =>
                            GoodsReceiptPdfBuilder.build(filtered),
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Summary Bar + Status Filter
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(
      AsyncValue<List<GoodsReceiptModel>> receiptsAsync) {
    return receiptsAsync.maybeWhen(
      data: (all) {
        final filtered = _filter(all);
        final isDark =
            Theme.of(context).brightness == Brightness.dark;

        int countByStatus(String s) =>
            all.where((r) => r.status == s).length;

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
                    _GRFilterChip(
                      label: 'ทั้งหมด',
                      count: all.length,
                      color: AppTheme.navy,
                      selected: _statusFilter == 'ALL',
                      onTap: () =>
                          setState(() { _statusFilter = 'ALL'; _currentPage = 1; }),
                    ),
                    const SizedBox(width: 6),
                    _GRFilterChip(
                      label: 'ร่าง',
                      count: countByStatus('DRAFT'),
                      color: AppTheme.warning,
                      selected: _statusFilter == 'DRAFT',
                      onTap: () =>
                          setState(() { _statusFilter = 'DRAFT'; _currentPage = 1; }),
                    ),
                    const SizedBox(width: 6),
                    _GRFilterChip(
                      label: 'ยืนยันแล้ว',
                      count: countByStatus('CONFIRMED'),
                      color: AppTheme.success,
                      selected: _statusFilter == 'CONFIRMED',
                      onTap: () =>
                          setState(() { _statusFilter = 'CONFIRMED'; _currentPage = 1; }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Summary stats
              Row(
                children: [
                  _GRValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} ใบ',
                    color: AppTheme.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  _GRValueStat(
                    label: 'รายการสินค้า',
                    value:
                        '${filtered.fold(0, (s, r) => s + r.itemCount)} รายการ',
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
  Widget _buildCardView(List<GoodsReceiptModel> receipts) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: receipts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _GRCard(
        receipt: receipts[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  GoodsReceiptFormPage(receipt: receipts[i])),
        ),
        onDelete: () => _deleteReceipt(receipts[i]),
        onConfirm: () => _confirmReceipt(receipts[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIST VIEW (compact)
  // ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<GoodsReceiptModel> receipts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text('เลขที่ GR / PO',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub)),
              ),
              SizedBox(
                width: 72,
                child: Text('วันที่',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub),
                    textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 80,
                child: Text('สถานะ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub),
                    textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 50,
                child: Text('รายการ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, i) {
              final r = receipts[i];
              final isEven = i.isEven;
              final statusColor = r.status == 'CONFIRMED'
                  ? AppTheme.success
                  : AppTheme.warning;
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GoodsReceiptFormPage(receipt: r)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── แถว 1: ข้อมูลหลัก ────────────────────
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 34,
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
                                Text(r.grNo,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A))),
                                Text(
                                  r.poNo != null
                                      ? 'PO: ${r.poNo}'
                                      : r.supplierName,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFFAAAAAA)
                                          : AppTheme.textSub),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            child: Text(
                              DateFormat('dd/MM/yy').format(r.grDate),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFFAAAAAA)
                                      : AppTheme.textSub),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Center(
                              child: _GRStatusBadge(status: r.status),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${r.itemCount}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.info),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      // ── แถว 2: ปุ่ม DRAFT ────────────────────
                      if (r.status == 'DRAFT') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 52,
                              height: 34,
                              child: OutlinedButton(
                                onPressed: () => _deleteReceipt(receipts[i]),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  side: const BorderSide(
                                      color: AppTheme.error),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                child: const Icon(
                                    Icons.delete_outline, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _confirmReceipt(receipts[i]),
                                icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 14),
                                label: const Text('ยืนยันรับ',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.local_shipping_outlined
                : Icons.search_off_outlined,
            size: 72,
            color: isDark ? const Color(0xFF444444) : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'ยังไม่มีใบรับสินค้า'
                : 'ไม่พบใบรับสินค้า "$_searchQuery"',
            style: TextStyle(
                color: isDark
                    ? const Color(0xFF888888)
                    : Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 72, color: AppTheme.error),
            const SizedBox(height: 12),
            Text('เกิดข้อผิดพลาด: $e'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(goodsReceiptListProvider.notifier).refresh(),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmReceipt(GoodsReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark =
            Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline,
                    size: 18, color: AppTheme.success),
              ),
              const SizedBox(width: 10),
              Text('ยืนยันการรับสินค้า',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ยืนยันรับสินค้า ${receipt.grNo} ใช่หรือไม่?',
                  style: TextStyle(
                      color:
                          isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppTheme.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'การยืนยันจะทำให้สินค้าเข้าสต๊อกและไม่สามารถแก้ไขได้',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87),
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
              child: Text('ยกเลิก',
                  style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : AppTheme.textSub)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('ยืนยัน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(goodsReceiptListProvider.notifier)
        .confirmGoodsReceipt(receipt.grId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'ยืนยันรับสินค้าสำเร็จ — สินค้าเข้าสต๊อกแล้ว'
          : 'ยืนยันรับสินค้าไม่สำเร็จ'),
      backgroundColor: success ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _deleteReceipt(GoodsReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark =
            Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.error),
              ),
              const SizedBox(width: 10),
              Text('ยืนยันการลบ',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A))),
            ],
          ),
          content: Text(
              'ต้องการลบใบรับสินค้า ${receipt.grNo} ออกจากระบบ?',
              style: TextStyle(
                  color:
                      isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ยกเลิก',
                  style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : AppTheme.textSub)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('ลบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(goodsReceiptListProvider.notifier)
        .deleteGoodsReceipt(receipt.grId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'ลบใบรับสินค้าสำเร็จ'
          : 'ลบใบรับสินค้าไม่สำเร็จ'),
      backgroundColor: success ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ════════════════════════════════════════════════════════════════
// _GRCard — Card view item
// ════════════════════════════════════════════════════════════════
class _GRCard extends StatelessWidget {
  final GoodsReceiptModel receipt;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;

  const _GRCard({
    required this.receipt,
    required this.onTap,
    required this.onDelete,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Avatar color from supplier name
    final colors = [
      AppTheme.primary, AppTheme.info, AppTheme.success,
      AppTheme.warning, AppTheme.purpleColor, AppTheme.tealColor,
    ];
    final name = receipt.supplierName;
    final avatarColor =
        colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isDark ? const Color(0xFF333333) : AppTheme.border),
      ),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Avatar + Info + Status ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor,
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receipt.grNo,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A))),
                        const SizedBox(height: 2),
                        Text(receipt.supplierName,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFAAAAAA)
                                    : AppTheme.textSub),
                            overflow: TextOverflow.ellipsis),
                        if (receipt.poNo != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.link,
                                  size: 11,
                                  color: isDark
                                      ? const Color(0xFF888888)
                                      : AppTheme.textSub),
                              const SizedBox(width: 3),
                              Text('PO: ${receipt.poNo}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF888888)
                                          : AppTheme.textSub)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _GRStatusBadge(status: receipt.status),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF2C2C2C)
                      : AppTheme.border),
              const SizedBox(height: 10),

              // ── Row 2: Meta info ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _GRInfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat('dd/MM/yyyy')
                          .format(receipt.grDate),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _GRInfoChip(
                      icon: Icons.warehouse_outlined,
                      text: receipt.warehouseName,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Row 3: Item count ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('รายการสินค้า',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub)),
                  Text(
                    '${receipt.itemCount} รายการ',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.info),
                  ),
                ],
              ),

              // ── Row 4: Action buttons (DRAFT only) ─────────────
              if (receipt.status == 'DRAFT') ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 14),
                        label: const Text('ยืนยันรับ',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _GRListTopBar
// ════════════════════════════════════════════════════════════════
class _GRListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _GRListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.isCardView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  static const _kBreak = 640.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop, isDark)
          : _buildDoubleRow(context, canPop, isDark),
    );
  }

  Widget _buildSingleRow(
      BuildContext context, bool canPop, bool isDark) {
    return Row(
      children: [
        if (canPop) ...[
          _GRBackBtn(isDark: isDark),
          const SizedBox(width: 10),
        ],
        _GRPageIcon(),
        const SizedBox(width: 10),
        Text('ใบรับสินค้า',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color:
                    isDark ? Colors.white : const Color(0xFF1A1A1A))),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _GRSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        _GRIconBtn(
          icon: isCardView
              ? Icons.view_list_outlined
              : Icons.grid_view_outlined,
          tooltip: isCardView ? 'List View' : 'Card View',
          isDark: isDark,
          onTap: onToggleView,
        ),
        const SizedBox(width: 6),
        _GRIconBtn(
          icon: Icons.refresh,
          tooltip: 'รีเฟรช',
          isDark: isDark,
          onTap: onRefresh,
        ),
        const SizedBox(width: 6),
        _GRAddBtn(onTap: onAdd),
      ],
    );
  }

  Widget _buildDoubleRow(
      BuildContext context, bool canPop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _GRBackBtn(isDark: isDark),
              const SizedBox(width: 8),
            ],
            _GRPageIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text('ใบรับสินค้า',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis),
            ),
            _GRIconBtn(
              icon: isCardView
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              tooltip: isCardView ? 'List View' : 'Card View',
              isDark: isDark,
              onTap: onToggleView,
            ),
            const SizedBox(width: 4),
            _GRIconBtn(
              icon: Icons.refresh,
              tooltip: 'รีเฟรช',
              isDark: isDark,
              onTap: onRefresh,
            ),
            const SizedBox(width: 4),
            _GRAddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        _GRSearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ── TopBar sub-widgets ─────────────────────────────────────────

class _GRBackBtn extends StatelessWidget {
  final bool isDark;
  const _GRBackBtn({required this.isDark});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkElement
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark
                    ? const Color(0xFF333333)
                    : AppTheme.border),
          ),
          child: Icon(Icons.arrow_back_ios_new,
              size: 15,
              color: isDark
                  ? const Color(0xFFAAAAAA)
                  : const Color(0xFF8A8A8A)),
        ),
      );
}

class _GRPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.successContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.local_shipping_outlined,
            color: AppTheme.success, size: 18),
      );
}

class _GRSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool isDark;

  const _GRSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'ค้นหาเลขที่ GR, PO, ซัพพลายเออร์...',
            hintStyle: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF666666)
                    : const Color(0xFF8A8A8A)),
            prefixIcon: Icon(Icons.search,
                size: 17,
                color: isDark
                    ? const Color(0xFF666666)
                    : const Color(0xFF8A8A8A)),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: onCleared,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppTheme.primary, width: 1.5)),
            filled: true,
            fillColor:
                isDark ? AppTheme.darkElement : Colors.white,
          ),
          onChanged: onChanged,
        ),
      );
}

class _GRIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _GRIconBtn({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkElement
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF333333)
                      : AppTheme.border),
            ),
            child: Icon(icon,
                size: 17,
                color: isDark
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFF8A8A8A)),
          ),
        ),
      );
}

class _GRAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _GRAddBtn({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: compact
            ? const SizedBox.shrink()
            : const Text('สร้างใบรับสินค้า',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16, vertical: 13),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
}

// ── Shared small widgets ───────────────────────────────────────

class _GRStatusBadge extends StatelessWidget {
  final String status;
  const _GRStatusBadge({required this.status});

  Color get _color =>
      status == 'CONFIRMED' ? AppTheme.success : AppTheme.warning;
  String get _label =>
      status == 'CONFIRMED' ? 'ยืนยันแล้ว' : 'ร่าง';

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                    color: _color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(_label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _color)),
          ],
        ),
      );
}

class _GRInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _GRInfoChip(
      {required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon,
              size: 13,
              color: isDark
                  ? const Color(0xFF888888)
                  : AppTheme.textSub),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : AppTheme.textSub),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

class _GRFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _GRFilterChip({
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

    // ── ไม่ได้เลือก ──────────────────────────────────────────────
    if (!selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isDark ? const Color(0xFF4A4A4A) : AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppTheme.textSub)),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF5A5A5A) : AppTheme.textSub,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // ── ถูกเลือก ──────────────────────────────────────────────
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
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: vc)),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: vc, borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GRValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _GRValueStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFFAAAAAA)
                      : AppTheme.textSub)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
