// customer_dividend_run_list_page.dart
// รายการงวดปันผลลูกค้า + ดูรายละเอียดการจ่ายจริง

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'customer_dividend_run_list_pdf.dart';
import 'customer_dividend_run_pdf.dart';

final _customerDividendRunsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/customer-dividend-runs');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final _customerDividendRunDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, runId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/customer-dividend-runs/$runId');
  if (res.statusCode == 200) {
    return res.data['data'] as Map<String, dynamic>;
  }
  return null;
});

String _runStatusLabel(String status) {
  return switch (status.toUpperCase()) {
    'DRAFT' => 'ร่าง',
    'PARTIAL' => 'จ่ายบางส่วน',
    'PAID' => 'จ่ายครบแล้ว',
    'CANCELLED' => 'ยกเลิก',
    _ => status,
  };
}

class CustomerDividendRunListPage extends ConsumerStatefulWidget {
  const CustomerDividendRunListPage({super.key});

  @override
  ConsumerState<CustomerDividendRunListPage> createState() =>
      _CustomerDividendRunListPageState();
}

class _CustomerDividendRunListPageState
    extends ConsumerState<CustomerDividendRunListPage> {
  final _money = NumberFormat('#,##0.00', 'th_TH');
  final _date = DateFormat('dd/MM/yyyy', 'th_TH');
  static const _pageSize = 10;
  String _search = '';
  String _statusFilter = 'ALL';
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(_customerDividendRunsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      body: EscapePopScope(
        child: Column(
          children: [
            _DividendRunTopBar(
              title: 'งวดปันผลลูกค้า',
              icon: Icons.inventory_2_outlined,
              isDark: isDark,
              onRefresh: () => ref.invalidate(_customerDividendRunsProvider),
            ),
            Container(
              color: isDark ? AppTheme.darkCard : Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเลขงวด / หมายเหตุ...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF23232E)
                          : const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      _search = v.trim().toLowerCase();
                      _currentPage = 1;
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'เกิดข้อผิดพลาด: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (runs) {
                  final totalAmount = runs.fold<double>(
                    0,
                    (sum, run) =>
                        sum +
                        ((run['total_dividend_amount'] as num?)?.toDouble() ??
                            0),
                  );
                  final paidRuns = runs.where(
                    (run) =>
                        (run['status'] as String? ?? '').toUpperCase() == 'PAID',
                  );
                  final partialRuns = runs.where(
                    (run) =>
                        (run['status'] as String? ?? '').toUpperCase() ==
                        'PARTIAL',
                  );
                  final paidAmount = paidRuns.fold<double>(
                    0,
                    (sum, run) =>
                        sum +
                        ((run['actual_paid_total'] as num?)?.toDouble() ??
                            0),
                  );
                  final partialAmount = partialRuns.fold<double>(
                    0,
                    (sum, run) =>
                        sum +
                        ((run['actual_paid_total'] as num?)?.toDouble() ??
                            0),
                  );
                  final outstandingAmount = runs.fold<double>(
                    0,
                    (sum, run) {
                      final status =
                          (run['status'] as String? ?? '').toUpperCase();
                      if (status == 'PAID' || status == 'CANCELLED') {
                        return sum;
                      }
                      final total =
                          (run['total_dividend_amount'] as num?)?.toDouble() ?? 0;
                      final actualPaid =
                          (run['actual_paid_total'] as num?)?.toDouble() ?? 0;
                      return sum + (total - actualPaid).clamp(0.0, total);
                    },
                  );
                  final outstandingRuns = runs.where((run) {
                    final status =
                        (run['status'] as String? ?? '').toUpperCase();
                    return status != 'PAID' && status != 'CANCELLED';
                  });
                  final filtered = runs.where((run) {
                    final status =
                        (run['status'] as String? ?? 'DRAFT').toUpperCase();
                    if (_statusFilter != 'ALL' && status != _statusFilter) {
                      return false;
                    }
                    if (_search.isEmpty) return true;
                    final runNo = (run['run_no'] as String? ?? '').toLowerCase();
                    final remark =
                        (run['remark'] as String? ?? '').toLowerCase();
                    return runNo.contains(_search) || remark.contains(_search);
                  }).toList();
                  final maxPage =
                      filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
                  final safePage = _currentPage.clamp(1, maxPage);
                  final start = (safePage - 1) * _pageSize;
                  final pageItems =
                      filtered.skip(start).take(_pageSize).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'ยังไม่มีงวดปันผล',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _RunMetricCard(
                                    label: 'ยอดปันผลรวม',
                                    amount: totalAmount,
                                    count: runs.length,
                                    color: AppTheme.primaryDark,
                                    icon: Icons.savings_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RunMetricCard(
                                    label: 'จ่ายครบแล้ว',
                                    amount: paidAmount,
                                    count: paidRuns.length,
                                    color: AppTheme.success,
                                    icon: Icons.task_alt_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RunMetricCard(
                                    label: 'จ่ายบางส่วน',
                                    amount: partialAmount,
                                    count: partialRuns.length,
                                    color: AppTheme.warning,
                                    icon: Icons.pending_actions_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RunMetricCard(
                                    label: 'คงเหลือที่ยังไม่จ่าย',
                                    amount: outstandingAmount,
                                    count: outstandingRuns.length,
                                    color: AppTheme.error,
                                    icon: Icons.hourglass_bottom_outlined,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final filters = Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final item in const [
                                      ('ALL', 'ทั้งหมด', AppTheme.navy, -1),
                                      ('DRAFT', 'ร่าง', AppTheme.info, 0),
                                      ('PARTIAL', 'จ่ายบางส่วน', AppTheme.warning, 0),
                                      ('PAID', 'จ่ายครบแล้ว', AppTheme.success, 0),
                                      ('CANCELLED', 'ยกเลิก', AppTheme.error, 0),
                                    ])
                                      _RunFilterChip(
                                        label: item.$2,
                                        count: item.$1 == 'ALL'
                                            ? runs.length
                                            : runs
                                                .where(
                                                  (run) =>
                                                      (run['status'] as String? ??
                                                              '')
                                                          .toUpperCase() ==
                                                      item.$1,
                                                )
                                                .length,
                                        color: item.$3,
                                        selected: _statusFilter == item.$1,
                                        onTap: () {
                                          final count = item.$1 == 'ALL'
                                              ? runs.length
                                              : runs
                                                  .where(
                                                    (run) =>
                                                        (run['status'] as String? ??
                                                                '')
                                                            .toUpperCase() ==
                                                        item.$1,
                                                  )
                                                  .length;
                                          if (count == 0) return;
                                          setState(() {
                                            _statusFilter = item.$1;
                                            _currentPage = 1;
                                          });
                                        },
                                      ),
                                  ],
                                );
                                final stats = Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _RunValueStat(
                                      label: 'กรองแล้ว',
                                      value: '${filtered.length} งวด',
                                      color: AppTheme.primaryDark,
                                    ),
                                    _RunValueStat(
                                      label: 'มูลค่าที่แสดง',
                                      value:
                                          '฿${_money.format(filtered.fold<double>(0, (s, r) => s + ((r['total_dividend_amount'] as num?)?.toDouble() ?? 0)))}',
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                );
                                if (constraints.maxWidth < 900) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      filters,
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: stats,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: filters),
                                    const SizedBox(width: 12),
                                    stats,
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (_, i) {
                            final run = pageItems[i];
                      final status = (run['status'] as String? ?? 'DRAFT').toUpperCase();
                      final paidCount = (run['paid_count'] as num?)?.toInt() ?? 0;
                      final pendingCount =
                          (run['pending_count'] as num?)?.toInt() ?? 0;
                      final skippedCount =
                          (run['skipped_count'] as num?)?.toInt() ?? 0;
                      final period = _periodLabel(
                        run['period_start'] as String?,
                        run['period_end'] as String?,
                      );

                            return Material(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDividendRunDetailPage(
                                      runId: run['run_id'] as String,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  run['run_no'] as String? ?? '-',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  period,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _statusChip(status),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          _infoChip(
                                            'อัตรา',
                                            '${_money.format((run['dividend_percent'] ?? 0) as num)}%',
                                            isDark,
                                          ),
                                          _infoChip(
                                            'ฐานคำนวณ',
                                            '฿${_money.format((run['total_dividend_base'] ?? 0) as num)}',
                                            isDark,
                                          ),
                                          _infoChip(
                                            'ยอดปันผล',
                                            '฿${_money.format((run['total_dividend_amount'] ?? 0) as num)}',
                                            isDark,
                                          ),
                                          _infoChip('จ่ายแล้ว', '$paidCount', isDark),
                                          _infoChip('ค้างจ่าย', '$pendingCount', isDark),
                                          _infoChip('ข้ามจ่าย', '$skippedCount', isDark),
                                        ],
                                      ),
                                      if ((run['remark'] as String?)?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          run['remark'] as String,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemCount: pageItems.length,
                        ),
                      ),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: _pageSize,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลงวดปันผล',
                          title: 'รายการงวดปันผลลูกค้า',
                          filename: () =>
                              PdfFilename.generate('customer_dividend_runs'),
                          buildPdf: () => CustomerDividendRunListPdfBuilder.build(
                            runs: filtered,
                            statusLabel: _statusFilter == 'ALL'
                                ? 'ทั้งหมด'
                                : _runStatusLabel(_statusFilter),
                            search: _search,
                            companyName: settings.companyName,
                          ),
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

  String _periodLabel(String? start, String? end) {
    if (start == null && end == null) return 'ทุกช่วงเวลา';
    final s = start == null ? '?' : _date.format(DateTime.parse(start));
    final e = end == null ? '?' : _date.format(DateTime.parse(end));
    return '$s - $e';
  }

  Widget _statusChip(String status) {
    final (Color bg, Color fg) = switch (status) {
      'PAID' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'PARTIAL' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'CANCELLED' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _runStatusLabel(status),
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12),
      ),
    );
  }

  Widget _infoChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232E) : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey[800],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CustomerDividendRunDetailPage extends ConsumerStatefulWidget {
  final String runId;
  const CustomerDividendRunDetailPage({super.key, required this.runId});

  @override
  ConsumerState<CustomerDividendRunDetailPage> createState() =>
      _CustomerDividendRunDetailPageState();
}

class _CustomerDividendRunDetailPageState
    extends ConsumerState<CustomerDividendRunDetailPage> {
  static const _pageSize = 10;
  String _search = '';
  String _itemStatusFilter = 'ALL';
  int _currentPage = 1;

  Future<bool> _confirmBulkAction({
    required String title,
    required String message,
    required bool isDanger,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? AppTheme.error : null,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runBulkPaymentStatus(String paymentStatus) async {
    final title = switch (paymentStatus) {
      'PAID' => 'ยืนยันจ่ายทั้งหมด',
      'SKIPPED' => 'ยืนยันข้ามทั้งหมด',
      _ => 'ยืนยันรีเซ็ตทั้งหมด',
    };
    final message = switch (paymentStatus) {
      'PAID' =>
        'ระบบจะตั้งสถานะทุกรายการในงวดนี้เป็น "จ่ายแล้ว" และกำหนดยอดจ่ายจริงตามยอดปันผล ต้องการดำเนินการต่อหรือไม่?',
      'SKIPPED' =>
        'ระบบจะตั้งสถานะทุกรายการในงวดนี้เป็น "ข้ามจ่าย" ต้องการดำเนินการต่อหรือไม่?',
      _ =>
        'ระบบจะตั้งสถานะทุกรายการกลับเป็น "ค้างจ่าย" และล้างยอดจ่ายจริงทั้งหมด ต้องการดำเนินการต่อหรือไม่?',
    };
    final confirmed = await _confirmBulkAction(
      title: title,
      message: message,
      isDanger: paymentStatus == 'PENDING',
    );
    if (!confirmed) return;

    final api = ref.read(apiClientProvider);
    await api.put(
      '/api/customer-dividend-runs/${widget.runId}/bulk-payment-status',
      data: {'payment_status': paymentStatus},
    );
    ref.invalidate(_customerDividendRunDetailProvider(widget.runId));
    ref.invalidate(_customerDividendRunsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(_customerDividendRunDetailProvider(widget.runId));
    final money = NumberFormat('#,##0.00', 'th_TH');
    final date = DateFormat('dd/MM/yyyy', 'th_TH');
    final settings = ref.watch(settingsProvider);
    final isAdmin =
        (ref.watch(authProvider).user?.roleId?.toUpperCase() ?? '') == 'ADMIN';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      body: Column(
        children: [
          _DividendRunTopBar(
            title: 'รายละเอียดงวดปันผล',
            icon: Icons.assignment_outlined,
            isDark: isDark,
            onRefresh: () =>
                ref.invalidate(_customerDividendRunDetailProvider(widget.runId)),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data: (data) {
                if (data == null) {
                  return const Center(child: Text('ไม่พบข้อมูล'));
                }
                final allItems =
                    (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
                final filteredItems = allItems.where((item) {
                  final status =
                      (item['payment_status'] as String? ?? 'PENDING')
                          .toUpperCase();
                  if (_itemStatusFilter != 'ALL' && status != _itemStatusFilter) {
                    return false;
                  }
                  if (_search.isEmpty) return true;
                  final customerName =
                      (item['customer_name'] as String? ?? '').toLowerCase();
                  return customerName.contains(_search);
                }).toList();
                final maxPage = filteredItems.isEmpty
                    ? 1
                    : (filteredItems.length / _pageSize).ceil();
                final safePage = _currentPage.clamp(1, maxPage);
                final start = (safePage - 1) * _pageSize;
                final pageItems =
                    filteredItems.skip(start).take(_pageSize).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _headerCard(
                            context,
                            data,
                            allItems,
                            filteredItems,
                            money,
                            date,
                            isDark,
                            ref,
                            settings.companyName,
                            isAdmin,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AppTheme.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'ค้นหาชื่อลูกค้า...',
                                    prefixIcon: const Icon(Icons.search),
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF23232E)
                                        : const Color(0xFFF5F5F5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (v) => setState(() {
                                    _search = v.trim().toLowerCase();
                                    _currentPage = 1;
                                  }),
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final item in const [
                                        ('ALL', 'ทั้งหมด'),
                                        ('PENDING', 'ค้างจ่าย'),
                                        ('PAID', 'จ่ายแล้ว'),
                                        ('SKIPPED', 'ข้ามจ่าย'),
                                      ])
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(
                                              item.$2,
                                              style: TextStyle(
                                                color: _detailChipTextColor(
                                                  selected:
                                                      _itemStatusFilter ==
                                                      item.$1,
                                                  isDark: isDark,
                                                ),
                                                fontWeight:
                                                    _itemStatusFilter == item.$1
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                            selected:
                                                _itemStatusFilter == item.$1,
                                            selectedColor: isDark
                                                ? AppTheme.primary.withValues(
                                                    alpha: 0.22,
                                                  )
                                                : AppTheme.primary.withValues(
                                                    alpha: 0.12,
                                                  ),
                                            backgroundColor: isDark
                                                ? AppTheme.darkElement
                                                : const Color(0xFFF5F5F5),
                                            side: BorderSide(
                                              color:
                                                  _itemStatusFilter == item.$1
                                                  ? AppTheme.primary.withValues(
                                                      alpha: 0.45,
                                                    )
                                                  : (isDark
                                                        ? const Color(
                                                            0xFF4A4A4A,
                                                          )
                                                        : AppTheme.border),
                                            ),
                                            checkmarkColor: AppTheme.primary,
                                            onSelected: (_) => setState(() {
                                              _itemStatusFilter = item.$1;
                                              _currentPage = 1;
                                            }),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (filteredItems.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'ไม่พบรายการลูกค้าตามเงื่อนไข',
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white60 : Colors.grey[700],
                                  ),
                                ),
                              ),
                            )
                          else
                            ...pageItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _itemCard(
                                  context,
                                  item,
                                  money,
                                  isDark,
                                  ref,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          _footerSummary(filteredItems, money, isDark),
                        ],
                      ),
                    ),
                    PaginationBar(
                      currentPage: safePage,
                      totalItems: filteredItems.length,
                      pageSize: _pageSize,
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
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

  Widget _headerCard(
    BuildContext context,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> visibleItems,
    NumberFormat money,
    DateFormat date,
    bool isDark,
    WidgetRef ref,
    String? companyName,
    bool isAdmin,
  ) {
    final periodStart = data['period_start'] as String?;
    final periodEnd = data['period_end'] as String?;
    final periodText = periodStart == null && periodEnd == null
        ? 'ทุกช่วงเวลา'
        : '${periodStart == null ? '?' : date.format(DateTime.parse(periodStart))}'
            ' - ${periodEnd == null ? '?' : date.format(DateTime.parse(periodEnd))}';
    final totalActualPaid = items.fold<double>(
      0,
      (s, i) => s + ((i['paid_amount_actual'] as num?)?.toDouble() ?? 0),
    );
    final totalDividend =
        (data['total_dividend_amount'] as num?)?.toDouble() ?? 0;
    final paidProgress = totalDividend <= 0
        ? 0.0
        : (totalActualPaid / totalDividend).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['run_no'] as String? ?? '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (status) async {
                  final api = ref.read(apiClientProvider);
                  await api.put(
                    '/api/customer-dividend-runs/${widget.runId}/status',
                    data: {'status': status},
                  );
                  ref.invalidate(_customerDividendRunDetailProvider(widget.runId));
                  ref.invalidate(_customerDividendRunsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'DRAFT', child: Text('ตั้งเป็น ร่าง')),
                  PopupMenuItem(
                    value: 'PARTIAL',
                    child: Text('ตั้งเป็น จ่ายบางส่วน'),
                  ),
                  PopupMenuItem(
                    value: 'PAID',
                    child: Text('ตั้งเป็น จ่ายครบแล้ว'),
                  ),
                  PopupMenuItem(
                    value: 'CANCELLED',
                    child: Text('ตั้งเป็น ยกเลิก'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(periodText),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _runBulkPaymentStatus('PAID'),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('จ่ายทั้งหมด'),
              ),
              OutlinedButton.icon(
                onPressed: () => _runBulkPaymentStatus('SKIPPED'),
                icon: const Icon(Icons.skip_next_outlined, size: 18),
                label: const Text('ข้ามทั้งหมด'),
              ),
              OutlinedButton.icon(
                onPressed: isAdmin ? () => _runBulkPaymentStatus('PENDING') : null,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('รีเซ็ตทั้งหมด'),
              ),
              if (!isAdmin)
                Text(
                  'รีเซ็ตทั้งหมดได้เฉพาะผู้ดูแลระบบ',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppTheme.textSub,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallInfo(
                'สถานะ',
                _runStatusLabel(data['status'] as String? ?? '-'),
                isDark,
              ),
              _smallInfo(
                'อัตรา',
                '${money.format((data['dividend_percent'] ?? 0) as num)}%',
                isDark,
              ),
              _smallInfo(
                'ยอดปันผลรวม',
                '฿${money.format((data['total_dividend_amount'] ?? 0) as num)}',
                isDark,
              ),
              _smallInfo(
                'ยอดจ่ายจริงรวม',
                '฿${money.format(totalActualPaid)}',
                isDark,
              ),
              _smallInfo(
                'เทียบยอดปันผล',
                '${money.format(totalDividend == 0 ? 0 : (totalActualPaid / totalDividend * 100))}%',
                isDark,
              ),
              _smallInfo(
                'จ่ายแล้ว',
                '${data['paid_count'] ?? 0}',
                isDark,
              ),
              _smallInfo(
                'ค้างจ่าย',
                '${data['pending_count'] ?? 0}',
                isDark,
              ),
            ],
          ),
          if ((data['remark'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(data['remark'] as String),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: paidProgress,
              minHeight: 10,
              backgroundColor:
                  isDark ? const Color(0xFF23232E) : const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'จ่ายจริงแล้ว ฿${money.format(totalActualPaid)} จาก ฿${money.format(totalDividend)}',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: PdfReportButton(
              emptyMessage: 'ไม่มีข้อมูลตามตัวกรองปัจจุบัน',
              title: 'รายละเอียดงวดปันผลลูกค้า',
              filename: () => PdfFilename.generate('customer_dividend_run'),
              buildPdf: () => CustomerDividendRunPdfBuilder.build(
                run: data,
                items: visibleItems,
                companyName: companyName,
              ),
              hasData: visibleItems.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerSummary(
    List<Map<String, dynamic>> items,
    NumberFormat money,
    bool isDark,
  ) {
    final pendingAmount = items
        .where((i) => (i['payment_status'] as String? ?? 'PENDING').toUpperCase() == 'PENDING')
        .fold<double>(
          0,
          (s, i) => s + ((i['dividend_amount'] as num?)?.toDouble() ?? 0),
        );
    final paidAmount = items
        .where((i) => (i['payment_status'] as String? ?? '').toUpperCase() == 'PAID')
        .fold<double>(
          0,
          (s, i) => s + ((i['paid_amount_actual'] as num?)?.toDouble() ?? 0),
        );
    final skippedAmount = items
        .where((i) => (i['payment_status'] as String? ?? '').toUpperCase() == 'SKIPPED')
        .fold<double>(
          0,
          (s, i) => s + ((i['dividend_amount'] as num?)?.toDouble() ?? 0),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.border,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _smallInfo('ค้างจ่าย', '฿${money.format(pendingAmount)}', isDark),
          _smallInfo('จ่ายแล้ว', '฿${money.format(paidAmount)}', isDark),
          _smallInfo('ข้ามจ่าย', '฿${money.format(skippedAmount)}', isDark),
        ],
      ),
    );
  }

  Widget _itemCard(
    BuildContext context,
    Map<String, dynamic> item,
    NumberFormat money,
    bool isDark,
    WidgetRef ref,
  ) {
    final status = item['payment_status'] as String? ?? 'PENDING';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['customer_name'] as String? ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editItem(context, item, ref),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('แก้ไข'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final api = ref.read(apiClientProvider);
                  final amount = value == 'PAID'
                      ? (item['dividend_amount'] as num?)?.toDouble() ?? 0
                      : 0.0;
                  await api.put(
                    '/api/customer-dividend-runs/${widget.runId}/items/${item['item_id']}/payment-status',
                    data: {
                      'payment_status': value,
                      'paid_amount_actual': amount,
                    },
                  );
                  ref.invalidate(_customerDividendRunDetailProvider(widget.runId));
                  ref.invalidate(_customerDividendRunsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'PENDING', child: Text('ค้างจ่าย')),
                  PopupMenuItem(value: 'PAID', child: Text('จ่ายแล้ว')),
                  PopupMenuItem(value: 'SKIPPED', child: Text('ข้ามจ่าย')),
                ],
                child: _statusPill(status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallInfo(
                'ยอดรับชำระ',
                '฿${money.format((item['paid_amount'] ?? 0) as num)}',
                isDark,
              ),
              _smallInfo(
                'ฐานคำนวณ',
                '฿${money.format((item['dividend_base'] ?? 0) as num)}',
                isDark,
              ),
              _smallInfo(
                'ยอดปันผล',
                '฿${money.format((item['dividend_amount'] ?? 0) as num)}',
                isDark,
              ),
              _smallInfo(
                'จ่ายจริง',
                '฿${money.format((item['paid_amount_actual'] ?? 0) as num)}',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    Map<String, dynamic> item,
    WidgetRef ref,
  ) async {
    final amountCtrl = TextEditingController(
      text: ((item['paid_amount_actual'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: item['note'] as String? ?? '');
    String paymentStatus = (item['payment_status'] as String? ?? 'PENDING').toUpperCase();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('แก้ไข ${item['customer_name'] ?? ''}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: paymentStatus,
                  decoration: const InputDecoration(labelText: 'สถานะการจ่าย'),
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('ค้างจ่าย')),
                    DropdownMenuItem(value: 'PAID', child: Text('จ่ายแล้ว')),
                    DropdownMenuItem(value: 'SKIPPED', child: Text('ข้ามจ่าย')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => paymentStatus = v);
                    if (v == 'PAID' &&
                        (double.tryParse(amountCtrl.text) ?? 0) == 0) {
                      amountCtrl.text =
                          ((item['dividend_amount'] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(2);
                    }
                    if (v != 'PAID') {
                      amountCtrl.text = '0.00';
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ยอดจ่ายจริง',
                    prefixText: '฿ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final api = ref.read(apiClientProvider);
    await api.put(
      '/api/customer-dividend-runs/${widget.runId}/items/${item['item_id']}/payment-status',
      data: {
        'payment_status': paymentStatus,
        'paid_amount_actual': double.tryParse(amountCtrl.text.trim()) ?? 0,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      },
    );
    ref.invalidate(_customerDividendRunDetailProvider(widget.runId));
    ref.invalidate(_customerDividendRunsProvider);
  }

  Widget _smallInfo(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232E) : const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _statusPill(String status) {
    final (String text, Color bg, Color fg) = switch (status.toUpperCase()) {
      'PAID' => ('จ่ายแล้ว', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'SKIPPED' =>
        ('ข้ามจ่าย', const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
      _ => ('ค้างจ่าย', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Color _detailChipTextColor({
    required bool selected,
    required bool isDark,
  }) {
    if (selected) return isDark ? Colors.white : AppTheme.primaryDark;
    return isDark ? Colors.white70 : AppTheme.textSub;
  }
}

class _DividendRunTopBar extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final VoidCallback onRefresh;

  const _DividendRunTopBar({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (canPop) ...[
            context.isMobile
                ? buildMobileHomeCompactButton(context, isDark: isDark)
                : InkWell(
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
                              : AppTheme.border,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 15,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF8A8A8A),
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isDark ? const Color(0xFF333333) : AppTheme.border,
                ),
              ),
              child: Icon(
                Icons.refresh,
                size: 17,
                color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunMetricCard extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _RunMetricCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '฿${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '$count งวด',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RunFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  Color _visible(Color c, bool isDark) {
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
    final isDisabled = count == 0;
    if (!selected) {
      return GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDisabled
                ? (isDark ? const Color(0xFF242424) : const Color(0xFFF3F3F3))
                : (isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDisabled
                  ? (isDark ? const Color(0xFF303030) : const Color(0xFFE6E6E6))
                  : (isDark ? const Color(0xFF4A4A4A) : AppTheme.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDisabled
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark ? Colors.white70 : AppTheme.textSub),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFC8C8C8))
                      : (isDark ? const Color(0xFF5A5A5A) : AppTheme.textSub),
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
      child: Container(
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

class _RunValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RunValueStat({
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
