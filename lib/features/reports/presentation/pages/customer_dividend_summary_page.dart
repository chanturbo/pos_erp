// ignore_for_file: avoid_print
// customer_dividend_summary_page.dart
// รายงานสรุปยอดปันผลคืนลูกค้า — คิดจากยอดรับชำระแล้วตาม % ที่กำหนด

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
import 'customer_dividend_summary_pdf.dart';
import 'customer_dividend_run_list_page.dart';

const _kPageSize = 20;

class CustomerDividendSummaryRow {
  final String customerId;
  final String customerName;
  final int orderCount;
  final double totalAmount;
  final double paidAmount;
  final double creditAmount;
  final double dividendPercent;
  final double dividendBase;
  final double dividendAmount;
  final String? savedRunId;
  final String? savedRunNo;
  final DateTime? lastOrderDate;

  const CustomerDividendSummaryRow({
    required this.customerId,
    required this.customerName,
    required this.orderCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.creditAmount,
    required this.dividendPercent,
    required this.dividendBase,
    required this.dividendAmount,
    this.savedRunId,
    this.savedRunNo,
    this.lastOrderDate,
  });

  factory CustomerDividendSummaryRow.fromJson(Map<String, dynamic> j) =>
      CustomerDividendSummaryRow(
        customerId: j['customer_id'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '-',
        orderCount: (j['order_count'] as num?)?.toInt() ?? 0,
        totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        creditAmount: (j['credit_amount'] as num?)?.toDouble() ?? 0,
        dividendPercent: (j['dividend_percent'] as num?)?.toDouble() ?? 0,
        dividendBase: (j['dividend_base'] as num?)?.toDouble() ?? 0,
        dividendAmount: (j['dividend_amount'] as num?)?.toDouble() ?? 0,
        savedRunId: j['saved_run_id'] as String?,
        savedRunNo: j['saved_run_no'] as String?,
        lastOrderDate: j['last_order_date'] != null
            ? DateTime.tryParse(j['last_order_date'] as String)
            : null,
      );

  bool get isSaved => (savedRunNo ?? '').isNotEmpty;
}

final _customerDividendProvider = FutureProvider.autoDispose
    .family<List<CustomerDividendSummaryRow>, _DividendQuery>((ref, query) async {
  final api = ref.read(apiClientProvider);
  final params = <String, dynamic>{
    'dividend_percent': query.dividendPercent.toStringAsFixed(2),
  };
  if (query.start != null) {
    params['start_date'] = DateFormat('yyyy-MM-dd').format(query.start!);
  }
  if (query.end != null) {
    params['end_date'] = DateFormat('yyyy-MM-dd').format(query.end!);
  }
  final res = await api.get(
    '/api/reports/customer-dividend-summary',
    queryParameters: params,
  );
  if (res.statusCode == 200) {
    final list = res.data['data'] as List? ?? [];
    return list
        .map((j) =>
            CustomerDividendSummaryRow.fromJson(j as Map<String, dynamic>))
        .toList();
  }
  return [];
});

class _DividendQuery {
  final DateTime? start;
  final DateTime? end;
  final double dividendPercent;

  const _DividendQuery({
    this.start,
    this.end,
    required this.dividendPercent,
  });

  @override
  bool operator ==(Object other) =>
      other is _DividendQuery &&
      other.start == start &&
      other.end == end &&
      other.dividendPercent == dividendPercent;

  @override
  int get hashCode => Object.hash(start, end, dividendPercent);
}

class CustomerDividendSummaryPage extends ConsumerStatefulWidget {
  const CustomerDividendSummaryPage({super.key});

  @override
  ConsumerState<CustomerDividendSummaryPage> createState() =>
      _CustomerDividendSummaryPageState();
}

class _CustomerDividendSummaryPageState
    extends ConsumerState<CustomerDividendSummaryPage> {
  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _fmtInt = NumberFormat('#,##0', 'th_TH');
  final _fmtDate = DateFormat('dd/MM/yyyy', 'th_TH');

  String _preset = 'THIS_MONTH';
  DateTime? _customStart;
  DateTime? _customEnd;

  String _search = '';
  final _searchCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '3.00');
  double _dividendPercent = 3.0;
  String _saveStatusFilter = 'UNSAVED';
  final Set<String> _selectedCustomerIds = <String>{};

  int _sortColumn = 4;
  bool _sortAsc = false;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  _DividendQuery get _query {
    if (_preset == 'CUSTOM') {
      return _DividendQuery(
        start: _customStart,
        end: _customEnd,
        dividendPercent: _dividendPercent,
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case 'TODAY':
        return _DividendQuery(
          start: today,
          end: today,
          dividendPercent: _dividendPercent,
        );
      case 'THIS_WEEK':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return _DividendQuery(
          start: monday,
          end: today,
          dividendPercent: _dividendPercent,
        );
      case 'THIS_MONTH':
        return _DividendQuery(
          start: DateTime(now.year, now.month, 1),
          end: today,
          dividendPercent: _dividendPercent,
        );
      case 'THIS_YEAR':
        return _DividendQuery(
          start: DateTime(now.year, 1, 1),
          end: today,
          dividendPercent: _dividendPercent,
        );
      default:
        return _DividendQuery(dividendPercent: _dividendPercent);
    }
  }

  String get _presetLabel {
    switch (_preset) {
      case 'TODAY':
        return 'วันนี้';
      case 'THIS_WEEK':
        return 'สัปดาห์นี้';
      case 'THIS_MONTH':
        return 'เดือนนี้';
      case 'THIS_YEAR':
        return 'ปีนี้';
      case 'ALL':
        return 'ทั้งหมด';
      case 'CUSTOM':
        final s = _customStart != null ? _fmtDate.format(_customStart!) : '?';
        final e = _customEnd != null ? _fmtDate.format(_customEnd!) : '?';
        return '$s – $e';
      default:
        return 'ทั้งหมด';
    }
  }

  List<CustomerDividendSummaryRow> _apply(List<CustomerDividendSummaryRow> rows) {
    final filtered = rows.where((r) {
      final matchSearch =
          _search.isEmpty ||
          r.customerName.toLowerCase().contains(_search.toLowerCase());
      final matchSaved = switch (_saveStatusFilter) {
        'SAVED' => r.isSaved,
        'UNSAVED' => !r.isSaved,
        _ => true,
      };
      return matchSearch && matchSaved;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.customerName.compareTo(b.customerName);
        case 1:
          cmp = a.orderCount.compareTo(b.orderCount);
        case 2:
          cmp = a.paidAmount.compareTo(b.paidAmount);
        case 3:
          cmp = a.dividendPercent.compareTo(b.dividendPercent);
        case 4:
          cmp = a.dividendAmount.compareTo(b.dividendAmount);
        case 5:
          cmp = a.creditAmount.compareTo(b.creditAmount);
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      locale: const Locale('th', 'TH'),
    );
    if (result != null) {
      setState(() {
        _preset = 'CUSTOM';
        _customStart =
            DateTime(result.start.year, result.start.month, result.start.day);
        _customEnd =
            DateTime(result.end.year, result.end.month, result.end.day);
        _currentPage = 1;
        _selectedCustomerIds.clear();
      });
    }
  }

  void _onSort(int col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = col == 0 || col == 3;
      }
      _currentPage = 1;
    });
  }

  void _applyDividendPercent() {
    final parsed = double.tryParse(_percentCtrl.text.trim());
    setState(() {
      _dividendPercent = parsed == null || parsed < 0 ? 0 : parsed;
      _percentCtrl.text = _dividendPercent.toStringAsFixed(2);
      _currentPage = 1;
      _selectedCustomerIds.clear();
    });
  }

  Future<void> _saveDividendRun(List<CustomerDividendSummaryRow> rows) async {
    final savableRows = rows
        .where((r) => !r.isSaved && _selectedCustomerIds.contains(r.customerId))
        .toList();
    if (savableRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรายการที่ยังไม่ถูกบันทึกงวด')),
      );
      return;
    }
    final remarkCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('บันทึกงวดปันผล'),
        content: TextField(
          controller: remarkCtrl,
          decoration: const InputDecoration(
            labelText: 'หมายเหตุ (ถ้ามี)',
            hintText: 'เช่น งวดประจำเดือนนี้',
          ),
          maxLines: 2,
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
    );
    if (ok != true || !mounted) return;

    final api = ref.read(apiClientProvider);
    final userId = ref.read(authProvider).user?.userId;
    final query = _query;
    final payload = {
      'period_start': query.start?.toIso8601String(),
      'period_end': query.end?.toIso8601String(),
      'dividend_percent': _dividendPercent,
      'remark': remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
      'created_by': userId,
      'items': savableRows
          .map(
            (r) => {
              'customer_id': r.customerId,
              'customer_name': r.customerName,
              'order_count': r.orderCount,
              'paid_amount': r.paidAmount,
              'credit_amount': r.creditAmount,
              'dividend_base': r.dividendBase,
              'dividend_percent': r.dividendPercent,
              'dividend_amount': r.dividendAmount,
            },
          )
          .toList(),
    };

    final res = await api.post('/api/customer-dividend-runs', data: payload);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final runNo = (res.data['data'] as Map?)?['run_no'] as String? ?? '-';
      final savedIds = savableRows.map((row) => row.customerId).toSet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกงวดปันผลสำเร็จ: $runNo')),
      );
      setState(() => _selectedCustomerIds.removeAll(savedIds));
      ref.invalidate(_customerDividendProvider(query));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerDividendRunListPage()),
      );
    } else {
      final message = res.data is Map
          ? (res.data['message'] as String? ?? 'ไม่สามารถบันทึกงวดปันผลได้')
          : 'ไม่สามารถบันทึกงวดปันผลได้';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final query = _query;
    final async = ref.watch(_customerDividendProvider(query));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF0F2F5),
      body: EscapePopScope(
        child: Column(
          children: [
            _DividendPageTopBar(
              title: 'สรุปยอดปันผลคืนลูกค้า',
              icon: Icons.savings_outlined,
              isDark: isDark,
              onRefresh: () => ref.invalidate(_customerDividendProvider(query)),
              action: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerDividendRunListPage(),
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('งวดปันผล'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  side: const BorderSide(color: AppTheme.primaryDark),
                ),
              ),
            ),
            _FilterBar(
              preset: _preset,
              label: _presetLabel,
              searchCtrl: _searchCtrl,
              percentCtrl: _percentCtrl,
              saveStatusFilter: _saveStatusFilter,
              isDark: isDark,
              onPresetChanged: (p) {
                if (p == 'CUSTOM') {
                  _pickCustomRange();
                } else {
                  setState(() {
                    _preset = p;
                    _currentPage = 1;
                    _selectedCustomerIds.clear();
                  });
                }
              },
              onSearchChanged: (v) => setState(() {
                _search = v;
                _currentPage = 1;
              }),
              onSaveStatusChanged: (v) => setState(() {
                _saveStatusFilter = v;
                _currentPage = 1;
              }),
              onPickCustom: _pickCustomRange,
              onApplyPercent: _applyDividendPercent,
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
                data: (rows) {
                  final filtered = _apply(rows);
                  _selectedCustomerIds.removeWhere(
                    (id) => !rows.any(
                      (row) => row.customerId == id && !row.isSaved,
                    ),
                  );
                  final maxPage =
                      filtered.isEmpty ? 1 : (filtered.length / _kPageSize).ceil();
                  final safePage = _currentPage.clamp(1, maxPage);
                  final start = (safePage - 1) * _kPageSize;
                  final pageRows =
                      filtered.skip(start).take(_kPageSize).toList();

                  return _buildContent(
                    context,
                    pageRows: pageRows,
                    allFiltered: filtered,
                    settings: settings,
                    query: query,
                    safePage: safePage,
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<CustomerDividendSummaryRow> pageRows,
    required List<CustomerDividendSummaryRow> allFiltered,
    required dynamic settings,
    required _DividendQuery query,
    required int safePage,
    required bool isDark,
  }) {
    final totalPaid = allFiltered.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalDividendBase =
        allFiltered.fold<double>(0, (s, r) => s + r.dividendBase);
    final totalDividend =
        allFiltered.fold<double>(0, (s, r) => s + r.dividendAmount);
    final totalOrders = allFiltered.fold<int>(0, (s, r) => s + r.orderCount);
    final savedCount = allFiltered.where((r) => r.isSaved).length;
    final unsavedRows = allFiltered.where((r) => !r.isSaved).toList();
    final selectedUnsavedCount = unsavedRows
        .where((r) => _selectedCustomerIds.contains(r.customerId))
        .length;
    final allUnsavedSelected = unsavedRows.isNotEmpty &&
        unsavedRows.every((r) => _selectedCustomerIds.contains(r.customerId));

    return Column(
      children: [
        _SummaryStrip(
          customerCount: allFiltered.length,
          totalOrders: totalOrders,
          totalPaid: totalPaid,
          totalDividendBase: totalDividendBase,
          totalDividend: totalDividend,
          dividendPercent: _dividendPercent,
          savedCount: savedCount,
          selectedCount: selectedUnsavedCount,
          fmt: _fmt,
          fmtInt: _fmtInt,
          isDark: isDark,
        ),
        Expanded(
          child: allFiltered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        size: 56,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty
                            ? 'ไม่พบลูกค้าที่ค้นหา'
                            : 'ไม่มีข้อมูลในช่วงเวลานี้',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  primary: true,
                  padding: const EdgeInsets.all(16),
                  child: _DataTable(
                    rows: pageRows,
                    startNo: (safePage - 1) * _kPageSize + 1,
                    fmt: _fmt,
                    fmtDate: _fmtDate,
                    isDark: isDark,
                    sortColumn: _sortColumn,
                    sortAsc: _sortAsc,
                    onSort: _onSort,
                    selectedIds: _selectedCustomerIds,
                    onToggleRow: (row, selected) {
                      if (row.isSaved) return;
                      setState(() {
                        if (selected) {
                          _selectedCustomerIds.add(row.customerId);
                        } else {
                          _selectedCustomerIds.remove(row.customerId);
                        }
                      });
                    },
                  ),
                ),
        ),
        PaginationBar(
          currentPage: safePage,
          totalItems: allFiltered.length,
          pageSize: _kPageSize,
          onPageChanged: (p) => setState(() => _currentPage = p),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: unsavedRows.isEmpty
                    ? null
                    : () => setState(() {
                        if (allUnsavedSelected) {
                          for (final row in unsavedRows) {
                            _selectedCustomerIds.remove(row.customerId);
                          }
                        } else {
                          for (final row in unsavedRows) {
                            _selectedCustomerIds.add(row.customerId);
                          }
                        }
                      }),
                icon: Icon(
                  allUnsavedSelected
                      ? Icons.check_box_outline_blank
                      : Icons.select_all,
                  size: 18,
                ),
                label: Text(allUnsavedSelected ? 'ล้างการเลือก' : 'เลือกที่ยังไม่บันทึก'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: selectedUnsavedCount == 0
                    ? null
                    : () => _saveDividendRun(allFiltered),
                icon: const Icon(Icons.save_alt_outlined, size: 18),
                label: Text('บันทึกงวด ($selectedUnsavedCount)'),
              ),
              const SizedBox(width: 8),
              PdfReportButton(
                emptyMessage: 'ไม่มีข้อมูลลูกค้า',
                title: 'รายงานสรุปยอดปันผลคืนลูกค้า',
                filename: () => PdfFilename.generate('customer_dividend_summary'),
                buildPdf: () => CustomerDividendSummaryPdfBuilder.build(
                  rows: allFiltered,
                  periodLabel: _presetLabel,
                  dividendPercent: _dividendPercent,
                  companyName: settings.companyName,
                  dateFrom: query.start,
                  dateTo: query.end,
                ),
                hasData: allFiltered.isNotEmpty,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String preset;
  final String label;
  final TextEditingController searchCtrl;
  final TextEditingController percentCtrl;
  final String saveStatusFilter;
  final bool isDark;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSaveStatusChanged;
  final VoidCallback onPickCustom;
  final VoidCallback onApplyPercent;

  const _FilterBar({
    required this.preset,
    required this.label,
    required this.searchCtrl,
    required this.percentCtrl,
    required this.saveStatusFilter,
    required this.isDark,
    required this.onPresetChanged,
    required this.onSearchChanged,
    required this.onSaveStatusChanged,
    required this.onPickCustom,
    required this.onApplyPercent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in [
                  ('TODAY', 'วันนี้'),
                  ('THIS_WEEK', 'สัปดาห์นี้'),
                  ('THIS_MONTH', 'เดือนนี้'),
                  ('THIS_YEAR', 'ปีนี้'),
                  ('ALL', 'ทั้งหมด'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 12,
                          color: _chipTextColor(
                            selected: preset == item.$1,
                            isDark: isDark,
                          ),
                          fontWeight: preset == item.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selected: preset == item.$1,
                      selectedColor: isDark
                          ? AppTheme.primary.withValues(alpha: 0.22)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      backgroundColor:
                          isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
                      side: BorderSide(
                        color: preset == item.$1
                            ? AppTheme.primary.withValues(alpha: 0.45)
                            : (isDark
                                ? const Color(0xFF4A4A4A)
                                : AppTheme.border),
                      ),
                      checkmarkColor: AppTheme.primary,
                      onSelected: (_) => onPresetChanged(item.$1),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          preset == 'CUSTOM' ? label : 'กำหนดเอง',
                          style: TextStyle(
                            fontSize: 12,
                            color: _chipTextColor(
                              selected: preset == 'CUSTOM',
                              isDark: isDark,
                            ),
                            fontWeight: preset == 'CUSTOM'
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    selected: preset == 'CUSTOM',
                    selectedColor: isDark
                        ? AppTheme.primary.withValues(alpha: 0.22)
                        : AppTheme.primary.withValues(alpha: 0.12),
                    backgroundColor:
                        isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
                    side: BorderSide(
                      color: preset == 'CUSTOM'
                          ? AppTheme.primary.withValues(alpha: 0.45)
                          : (isDark
                              ? const Color(0xFF4A4A4A)
                              : AppTheme.border),
                    ),
                    checkmarkColor: AppTheme.primary,
                    onSelected: (_) => onPickCustom(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อลูกค้า...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: saveStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'สถานะบันทึก',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
                    DropdownMenuItem(
                      value: 'UNSAVED',
                      child: Text('ยังไม่บันทึก'),
                    ),
                    DropdownMenuItem(
                      value: 'SAVED',
                      child: Text('บันทึกแล้ว'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onSaveStatusChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: percentCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '% ปันผล',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                  ),
                  onSubmitted: (_) => onApplyPercent(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onApplyPercent,
                child: const Text('คำนวณ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _chipTextColor({required bool selected, required bool isDark}) {
    if (selected) return isDark ? Colors.white : AppTheme.primaryDark;
    return isDark ? Colors.white70 : AppTheme.textSub;
  }
}

class _SummaryStrip extends StatelessWidget {
  final int customerCount;
  final int totalOrders;
  final double totalPaid;
  final double totalDividendBase;
  final double totalDividend;
  final double dividendPercent;
  final int savedCount;
  final int selectedCount;
  final NumberFormat fmt;
  final NumberFormat fmtInt;
  final bool isDark;

  const _SummaryStrip({
    required this.customerCount,
    required this.totalOrders,
    required this.totalPaid,
    required this.totalDividendBase,
    required this.totalDividend,
    required this.dividendPercent,
    required this.savedCount,
    required this.selectedCount,
    required this.fmt,
    required this.fmtInt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final chips = [
      _StatChip(
        label: 'ลูกค้า',
        value: '$customerCount ราย',
        icon: Icons.people_outline,
        iconColor: Colors.purple,
        isDark: isDark,
      ),
      _StatChip(
        label: 'ออเดอร์รวม',
        value: fmtInt.format(totalOrders),
        icon: Icons.receipt_long_outlined,
        iconColor: Colors.blue,
        isDark: isDark,
      ),
      _StatChip(
        label: 'ยอดรับชำระรวม',
        value: '฿${fmt.format(totalPaid)}',
        icon: Icons.payments_outlined,
        iconColor: Colors.green,
        isDark: isDark,
      ),
      _StatChip(
        label: 'ฐานคำนวณปันผล',
        value: '฿${fmt.format(totalDividendBase)}',
        icon: Icons.calculate_outlined,
        iconColor: Colors.teal,
        isDark: isDark,
      ),
      _StatChip(
        label: 'อัตราปันผล',
        value: '${fmt.format(dividendPercent)}%',
        icon: Icons.percent,
        iconColor: Colors.indigo,
        isDark: isDark,
      ),
      _StatChip(
        label: 'ยอดปันผลรวม',
        value: '฿${fmt.format(totalDividend)}',
        icon: Icons.savings_outlined,
        iconColor: Colors.orange,
        isDark: isDark,
      ),
      _StatChip(
        label: 'บันทึกงวดแล้ว',
        value: '$savedCount ราย',
        icon: Icons.inventory_2_outlined,
        iconColor: Colors.brown,
        isDark: isDark,
      ),
      _StatChip(
        label: 'เลือกรอบนี้',
        value: '$selectedCount ราย',
        icon: Icons.checklist_rtl_outlined,
        iconColor: Colors.teal,
        isDark: isDark,
      ),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          const minChipWidth = 140.0;
          final available = constraints.maxWidth;
          int perRow = available >= 1260 ? 8 : available >= 980 ? 4 : available >= 640 ? 3 : 2;
          double chipW = (available - gap * (perRow - 1)) / perRow;
          if (chipW < minChipWidth) {
            perRow = 2;
            chipW = (available - gap * (perRow - 1)) / perRow;
          }

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: chips.map((c) => SizedBox(width: chipW, child: c)).toList(),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE3E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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

class _DividendPageTopBar extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final VoidCallback onRefresh;
  final Widget? action;

  const _DividendPageTopBar({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.onRefresh,
    this.action,
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
          if (action != null) ...[
            action!,
            const SizedBox(width: 6),
          ],
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

class _DataTable extends StatelessWidget {
  final List<CustomerDividendSummaryRow> rows;
  final int startNo;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final bool isDark;
  final int sortColumn;
  final bool sortAsc;
  final ValueChanged<int> onSort;
  final Set<String> selectedIds;
  final void Function(CustomerDividendSummaryRow row, bool selected) onToggleRow;

  const _DataTable({
    required this.rows,
    required this.startNo,
    required this.fmt,
    required this.fmtDate,
    required this.isDark,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
    required this.selectedIds,
    required this.onToggleRow,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final hdrBg = isDark ? const Color(0xFF12343B) : const Color(0xFF00897B);
    final altBg = isDark ? const Color(0xFF1A1A2A) : const Color(0xFFF4FBFA);
    final borderColor =
        isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE3E8F0);

    final headerRow = TableRow(
      decoration: BoxDecoration(color: hdrBg),
      children: [
        _hdrCell('เลือก', -1, sortColumn, sortAsc, onSort),
        _hdrCell('#', -1, sortColumn, sortAsc, onSort),
        _hdrCell('ลูกค้า', 0, sortColumn, sortAsc, onSort),
        _hdrCell('ออเดอร์', 1, sortColumn, sortAsc, onSort),
        _hdrCell('รับชำระแล้ว', 2, sortColumn, sortAsc, onSort),
        _hdrCell('% ปันผล', 3, sortColumn, sortAsc, onSort),
        _hdrCell('ยอดปันผล', 4, sortColumn, sortAsc, onSort),
        _hdrCell('คงค้างเครดิต', 5, sortColumn, sortAsc, onSort),
        _hdrCell('สถานะบันทึก', -1, sortColumn, sortAsc, onSort),
        _hdrCell('ซื้อล่าสุด', -1, sortColumn, sortAsc, onSort),
      ],
    );

    final dataRows = rows.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final rowBg = i.isOdd ? altBg : bg;
      final isSelected = selectedIds.contains(r.customerId);

      return TableRow(
        decoration: BoxDecoration(
          color: r.isSaved ? rowBg.withValues(alpha: 0.78) : rowBg,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        children: [
          Center(
            child: Checkbox(
              value: r.isSaved ? false : isSelected,
              onChanged: r.isSaved
                  ? null
                  : (v) => onToggleRow(r, v ?? false),
            ),
          ),
          _cell(
            '${startNo + i}',
            align: TextAlign.center,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
          _cell(
            r.customerName,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A237E),
          ),
          _cell(
            '${r.orderCount}',
            align: TextAlign.center,
            color: isDark ? Colors.white70 : Colors.blueGrey[700],
          ),
          _cell(
            '฿${fmt.format(r.dividendBase)}',
            align: TextAlign.right,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
          ),
          _cell(
            '${fmt.format(r.dividendPercent)}%',
            align: TextAlign.center,
            color: isDark ? Colors.white70 : Colors.indigo[700],
          ),
          _cell(
            '฿${fmt.format(r.dividendAmount)}',
            align: TextAlign.right,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
          ),
          _cell(
            r.creditAmount > 0 ? '฿${fmt.format(r.creditAmount)}' : '-',
            align: TextAlign.right,
            color: r.creditAmount > 0
                ? (isDark ? const Color(0xFFFFCC80) : const Color(0xFF8D6E63))
                : (isDark ? Colors.white38 : Colors.grey[400]),
          ),
          _statusCell(r),
          _cell(
            r.lastOrderDate != null ? fmtDate.format(r.lastOrderDate!) : '-',
            align: TextAlign.center,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ],
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                  child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {
                    2: IntrinsicColumnWidth(flex: 1.0),
                  },
                  children: [headerRow, ...dataRows],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hdrCell(
    String text,
    int col,
    int sortColumn,
    bool sortAsc,
    ValueChanged<int> onSort,
  ) {
    final active = col >= 0 && sortColumn == col;
    return InkWell(
      onTap: col >= 0 ? () => onSort(col) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (col >= 0) ...[
              const SizedBox(width: 4),
              Icon(
                active
                    ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 14,
                color: active ? Colors.white : Colors.white70,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(
    String text, {
    TextAlign align = TextAlign.left,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }

  Widget _statusCell(CustomerDividendSummaryRow row) {
    if (!row.isSaved) {
      return _cell(
        'ยังไม่บันทึก',
        align: TextAlign.center,
        color: isDark ? Colors.white54 : Colors.grey[600],
      );
    }

    final label = row.savedRunNo == null
        ? 'บันทึกแล้ว'
        : 'บันทึกแล้ว (${row.savedRunNo})';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF3A2E1F)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? const Color(0xFFFFCC80)
                  : const Color(0xFFE65100),
            ),
          ),
        ),
      ),
    );
  }
}
