import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/pdf/pdf_export_service.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../providers/purchase_provider.dart';
import '../../data/models/purchase_order_model.dart';
import 'purchase_order_form_page.dart';
import 'purchase_order_pdf_report.dart';

class PurchaseOrderListPage extends ConsumerStatefulWidget {
  const PurchaseOrderListPage({super.key});

  @override
  ConsumerState<PurchaseOrderListPage> createState() =>
      _PurchaseOrderListPageState();
}

class _PurchaseOrderListPageState extends ConsumerState<PurchaseOrderListPage> {
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

  List<PurchaseOrderModel> _filter(List<PurchaseOrderModel> src) {
    return src.where((order) {
      final matchesSearch =
          order.poNo.toLowerCase().contains(_searchQuery) ||
          (order.supplierName?.toLowerCase().contains(_searchQuery) ?? false);
      final matchesStatus =
          _statusFilter == 'ALL' || order.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final purchaseOrdersAsync = ref.watch(purchaseListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────
            _POListTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              isCardView: _isCardView,
              onSearchChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
              onSearchCleared: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              onToggleView: () => setState(() => _isCardView = !_isCardView),
              onRefresh: () =>
                  ref.read(purchaseListProvider.notifier).refresh(),
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PurchaseOrderFormPage(),
                ),
              ),
            ),

            // ── Summary + Status Filter Bar ──────────────────────
            _buildSummaryBar(purchaseOrdersAsync),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: purchaseOrdersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (orders) {
                  final filtered = _filter(orders);
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
                          emptyMessage: 'ไม่มีข้อมูลใบสั่งซื้อ',
                          title: 'รายงานใบสั่งซื้อ',
                          filename: () =>
                              PdfFilename.generate('purchase_order_report'),
                          buildPdf: () =>
                              PurchaseOrderPdfBuilder.build(filtered),
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
  Widget _buildSummaryBar(
    AsyncValue<List<PurchaseOrderModel>> purchaseOrdersAsync,
  ) {
    return purchaseOrdersAsync.maybeWhen(
      data: (all) {
        final filtered = _filter(all);
        final total = filtered.fold<double>(0, (s, o) => s + o.totalAmount);
        final fmt = NumberFormat('#,##0.00', 'th_TH');

        int countByStatus(String status) =>
            all.where((o) => o.status == status).length;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          color: isDark ? AppTheme.darkCard : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // แถว 1 — Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _POFilterChip(
                      label: 'ทั้งหมด',
                      count: all.length,
                      color: AppTheme.navy,
                      selected: _statusFilter == 'ALL',
                      onTap: () => setState(() => _statusFilter = 'ALL'),
                    ),
                    const SizedBox(width: 6),
                    _POFilterChip(
                      label: 'ร่าง',
                      count: countByStatus('DRAFT'),
                      color: AppTheme.textSub,
                      selected: _statusFilter == 'DRAFT',
                      onTap: () => setState(() => _statusFilter = 'DRAFT'),
                    ),
                    const SizedBox(width: 6),
                    _POFilterChip(
                      label: 'อนุมัติแล้ว',
                      count: countByStatus('APPROVED'),
                      color: AppTheme.info,
                      selected: _statusFilter == 'APPROVED',
                      onTap: () => setState(() => _statusFilter = 'APPROVED'),
                    ),
                    const SizedBox(width: 6),
                    _POFilterChip(
                      label: 'รับบางส่วน',
                      count: countByStatus('PARTIAL'),
                      color: AppTheme.warning,
                      selected: _statusFilter == 'PARTIAL',
                      onTap: () => setState(() => _statusFilter = 'PARTIAL'),
                    ),
                    const SizedBox(width: 6),
                    _POFilterChip(
                      label: 'เสร็จสิ้น',
                      count: countByStatus('COMPLETED'),
                      color: AppTheme.success,
                      selected: _statusFilter == 'COMPLETED',
                      onTap: () => setState(() => _statusFilter = 'COMPLETED'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // แถว 2 — Financial summary
              Row(
                children: [
                  _POValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} ใบ',
                    color: AppTheme.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  _POValueStat(
                    label: 'ยอดรวม',
                    value: '฿${fmt.format(total)}',
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
  Widget _buildCardView(List<PurchaseOrderModel> orders) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _POCard(
        order: orders[i],
        onTap: () => _openPurchaseOrderForm(orders[i]),
        onDelete: () => _deletePurchaseOrder(orders[i]),
        onApprove: () => _approvePurchaseOrder(orders[i]),
        onPrintPdf: () => _openPurchaseOrderPdf(orders[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIST VIEW (compact)
  // ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<PurchaseOrderModel> orders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
          child: Row(
            children: [
              const SizedBox(width: 14), // status bar
              Expanded(
                flex: 3,
                child: Text(
                  'เลขที่ PO / ซัพพลายเออร์',
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
                width: 76,
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
                width: 90,
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
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              final isEven = i.isEven;
              final isDraft = order.status == 'DRAFT';
              return InkWell(
                onTap: () => _openPurchaseOrderForm(order),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── แถว 1: ข้อมูลหลัก ────────────────────
                      Row(
                        children: [
                          // Status color bar
                          Container(
                            width: 4,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // PO No + Supplier
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.poNo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  order.supplierName ?? '-',
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
                          // Date
                          SizedBox(
                            width: 72,
                            child: Text(
                              DateFormat('dd/MM/yy').format(order.poDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFAAAAAA)
                                    : AppTheme.textSub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Status chip
                          SizedBox(
                            width: 76,
                            child: Center(
                              child: _buildStatusBadge(order.status),
                            ),
                          ),
                          // Amount
                          SizedBox(
                            width: 90,
                            child: Text(
                              '฿${NumberFormat('#,##0.00', 'th_TH').format(order.totalAmount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.info,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // ── แถว 2: ปุ่ม DRAFT ────────────────────
                      if (isDraft) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 52,
                              height: 34,
                              child: OutlinedButton(
                                onPressed: () => _openPurchaseOrderPdf(order),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.info,
                                  side: const BorderSide(color: AppTheme.info),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 52,
                              height: 34,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _deletePurchaseOrder(orders[i]),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  side: const BorderSide(color: AppTheme.error),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 88,
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _approvePurchaseOrder(orders[i]),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text(
                                  'อนุมัติ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 52,
                              height: 34,
                              child: OutlinedButton(
                                onPressed: () => _openPurchaseOrderPdf(order),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.info,
                                  side: const BorderSide(color: AppTheme.info),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
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

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return AppTheme.textSub;
      case 'APPROVED':
        return AppTheme.info;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'COMPLETED':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    String label;
    switch (status) {
      case 'DRAFT':
        label = 'ร่าง';
        break;
      case 'APPROVED':
        label = 'อนุมัติ';
        break;
      case 'PARTIAL':
        label = 'บางส่วน';
        break;
      case 'COMPLETED':
        label = 'เสร็จสิ้น';
        break;
      default:
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
                ? Icons.receipt_long_outlined
                : Icons.search_off_outlined,
            size: 72,
            color: isDark ? const Color(0xFF444444) : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'ยังไม่มีใบสั่งซื้อ'
                : 'ไม่พบใบสั่งซื้อ "$_searchQuery"',
            style: TextStyle(
              color: isDark ? const Color(0xFF888888) : Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'กดปุ่ม + เพื่อสร้างใบสั่งซื้อใหม่',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF666666) : Colors.grey[400],
              ),
            ),
          ],
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
          onPressed: () => ref.read(purchaseListProvider.notifier).refresh(),
          child: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  Future<void> _deletePurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ยืนยันการลบ',
          icon: Icons.delete_outline,
          iconColor: AppTheme.error,
        ),
        content: Text('ต้องการลบใบสั่งซื้อ ${order.poNo} ออกจากระบบ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('ลบ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(purchaseListProvider.notifier)
        .deletePurchaseOrder(order.poId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ลบใบสั่งซื้อสำเร็จ' : 'ลบใบสั่งซื้อไม่สำเร็จ'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _approvePurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ยืนยันการอนุมัติ',
          icon: Icons.check_circle_outline,
          iconColor: AppTheme.success,
        ),
        content: Text('อนุมัติใบสั่งซื้อ ${order.poNo} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('อนุมัติ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(purchaseListProvider.notifier)
        .approvePurchaseOrder(order.poId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'อนุมัติใบสั่งซื้อสำเร็จ' : 'อนุมัติใบสั่งซื้อไม่สำเร็จ',
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPurchaseOrderPdf(PurchaseOrderModel order) async {
    final fullOrder =
        await ref.read(purchaseListProvider.notifier).getPurchaseOrderDetails(
          order.poId,
        );
    final pdfOrder = fullOrder ?? order;
    if (!mounted) return;
    await PdfExportService.showPreview(
      context,
      title: 'ใบสั่งซื้อ ${pdfOrder.poNo}',
      filename: PdfFilename.generate('purchase_order_${pdfOrder.poNo}'),
      buildPdf: () => PurchaseOrderPdfBuilder.build([pdfOrder]),
    );
  }

  Future<void> _openPurchaseOrderForm(PurchaseOrderModel order) async {
    final fullOrder =
        await ref.read(purchaseListProvider.notifier).getPurchaseOrderDetails(
          order.poId,
        );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderFormPage(order: fullOrder ?? order),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _POCard — Card view item
// ════════════════════════════════════════════════════════════════
class _POCard extends StatelessWidget {
  final PurchaseOrderModel order;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onPrintPdf;

  const _POCard({
    required this.order,
    required this.onTap,
    required this.onDelete,
    required this.onApprove,
    required this.onPrintPdf,
  });

  Color get _statusColor {
    switch (order.status) {
      case 'DRAFT':
        return AppTheme.textSub;
      case 'APPROVED':
        return AppTheme.info;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'COMPLETED':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  String get _statusLabel {
    switch (order.status) {
      case 'DRAFT':
        return 'ร่าง';
      case 'APPROVED':
        return 'อนุมัติแล้ว';
      case 'PARTIAL':
        return 'รับบางส่วน';
      case 'COMPLETED':
        return 'เสร็จสิ้น';
      default:
        return order.status;
    }
  }

  String get _paymentLabel {
    switch (order.paymentStatus) {
      case 'UNPAID':
        return 'ยังไม่จ่าย';
      case 'PARTIAL':
        return 'จ่ายบางส่วน';
      case 'PAID':
        return 'จ่ายแล้ว';
      default:
        return order.paymentStatus;
    }
  }

  Color get _paymentColor {
    switch (order.paymentStatus) {
      case 'UNPAID':
        return AppTheme.error;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'PAID':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    // Avatar color from supplier name
    final colors = [
      AppTheme.primary,
      AppTheme.info,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.purpleColor,
      AppTheme.tealColor,
    ];
    final supplierName = order.supplierName ?? 'S';
    final avatarColor = colors[supplierName.codeUnitAt(0) % colors.length];
    final initial = supplierName.isNotEmpty
        ? supplierName[0].toUpperCase()
        : 'S';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : AppTheme.border,
        ),
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
              // ── Row 1: Avatar + Info + Badges ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
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
                  const SizedBox(width: 12),

                  // PO No + Supplier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.poNo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.supplierName ?? '-',
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

                  // Status + Payment badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(label: _statusLabel, color: _statusColor),
                      const SizedBox(height: 4),
                      _StatusBadge(label: _paymentLabel, color: _paymentColor),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
              ),
              const SizedBox(height: 10),

              // ── Row 2: Meta info ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat('dd/MM/yyyy').format(order.poDate),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.warehouse_outlined,
                      text: order.warehouseName ?? '-',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 3: Total ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ยอดรวม',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFAAAAAA)
                          : AppTheme.textSub,
                    ),
                  ),
                  Text(
                    '฿${fmt.format(order.totalAmount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),

              // ── Row 4: Action buttons (DRAFT only) ─────────────
              if (order.status == 'DRAFT') ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: onPrintPdf,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.info,
                          side: const BorderSide(color: AppTheme.info),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text(
                          'อนุมัติ',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 34,
                      child: OutlinedButton(
                        onPressed: onPrintPdf,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.info,
                          side: const BorderSide(color: AppTheme.info),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
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
// _POListTopBar — responsive top bar
// ════════════════════════════════════════════════════════════════
class _POListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _POListTopBar({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop, isDark)
          : _buildDoubleRow(context, canPop, isDark),
    );
  }

  Widget _buildSingleRow(BuildContext context, bool canPop, bool isDark) {
    return Row(
      children: [
        if (canPop) ...[_POBackBtn(isDark: isDark), const SizedBox(width: 10)],
        _POPageIcon(),
        const SizedBox(width: 10),
        Text(
          'ใบสั่งซื้อ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: _POSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        _POToggleBtn(
          icon: isCardView
              ? Icons.view_list_outlined
              : Icons.grid_view_outlined,
          tooltip: isCardView ? 'List View' : 'Card View',
          isDark: isDark,
          onTap: onToggleView,
        ),
        const SizedBox(width: 6),
        _PORefreshBtn(isDark: isDark, onTap: onRefresh),
        const SizedBox(width: 6),
        _POAddBtn(onTap: onAdd),
      ],
    );
  }

  Widget _buildDoubleRow(BuildContext context, bool canPop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _POBackBtn(isDark: isDark),
              const SizedBox(width: 8),
            ],
            _POPageIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ใบสั่งซื้อ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _POToggleBtn(
              icon: isCardView
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              tooltip: isCardView ? 'List View' : 'Card View',
              isDark: isDark,
              onTap: onToggleView,
            ),
            const SizedBox(width: 4),
            _PORefreshBtn(isDark: isDark, onTap: onRefresh),
            const SizedBox(width: 4),
            _POAddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        _POSearchField(
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

class _POBackBtn extends StatelessWidget {
  final bool isDark;
  const _POBackBtn({required this.isDark});
  @override
  Widget build(BuildContext context) => context.isMobile
      ? buildMobileHomeCompactButton(context, isDark: isDark)
      : InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : AppTheme.border,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 15,
              color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
            ),
          ),
        );
}

class _POPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.receipt_long_outlined,
      color: AppTheme.primaryDark,
      size: 18,
    ),
  );
}

class _POSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool isDark;

  const _POSearchField({
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
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: 'ค้นหาเลขที่ PO, ซัพพลายเออร์...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF666666) : const Color(0xFF8A8A8A),
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: isDark ? const Color(0xFF666666) : const Color(0xFF8A8A8A),
        ),
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
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkElement : Colors.white,
      ),
      onChanged: onChanged,
    ),
  );
}

class _POToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _POToggleBtn({
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
          color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
        ),
      ),
    ),
  );
}

class _PORefreshBtn extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _PORefreshBtn({required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'รีเฟรช',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : AppTheme.border,
          ),
        ),
        child: Icon(
          Icons.refresh,
          size: 17,
          color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
        ),
      ),
    ),
  );
}

class _POAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _POAddBtn({required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'สร้างใบสั่งซื้อ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: 13,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// Shared small widgets
// ════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
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
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 13,
        color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _POFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _POFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  /// ในโหมดมืด สีเข้ม (navy / dark green ฯลฯ) จะมองไม่เห็น
  /// → lighten ให้ lightness ≥ 0.65 เพื่อให้ contrast กับพื้นหลังมืด
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
    final vc = _visible(color, isDark); // visible color for dark mode

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

class _POValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _POValueStat({
    required this.label,
    required this.value,
    required this.color,
  });

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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
            ),
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
