// coupon_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pdf/widgets.dart' as pw;
import 'coupon_pdf_report.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/pdf/pdf_export_service.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';

class CouponListPage extends ConsumerStatefulWidget {
  const CouponListPage({super.key});

  @override
  ConsumerState<CouponListPage> createState() => _CouponListPageState();
}

class _CouponListPageState extends ConsumerState<CouponListPage> {
  final _searchController = TextEditingController();
  String    _filter = 'ALL'; // ALL, VALID, USED, EXPIRED
  String    _searchQuery = '';
  bool      _groupByPromotion = false;
  DateTime? _expiresFrom;
  DateTime? _expiresTo;
  Timer? _debounce;
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  // ── Multi-select ───────────────────────────────────────────────
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final Set<String> _collapsedGroups = {};
  CouponPaperSize _batchPaperSize = CouponPaperSize.a6;

  void _enterSelectionMode() =>
      setState(() { _selectionMode = true; _selectedIds.clear(); });

  void _exitSelectionMode() =>
      setState(() { _selectionMode = false; _selectedIds.clear(); });

  void _toggleSelect(String id) => setState(() {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
  });

  void _selectAll(List<CouponModel> list) =>
      setState(() => _selectedIds.addAll(list.map((c) => c.couponCode)));

  List<CouponModel> _getSelected(List<CouponModel> all) =>
      all.where((c) => _selectedIds.contains(c.couponCode)).toList();

  Future<void> _printSelected(List<CouponModel> all) async {
    final selected = _getSelected(all);
    if (selected.isEmpty) return;
    try {
      await PdfExportService.showPreview(
        context,
        title: 'คูปองส่วนลด (${selected.length} ใบ)',
        filename: PdfFilename.generate('coupons_batch'),
        buildPdf: () => CouponCardPdfBuilder.buildMultiple(
          selected,
          paperSize: _batchPaperSize,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  Future<void> _shareSelected(List<CouponModel> all) async {
    final selected = _getSelected(all);
    if (selected.isEmpty) return;
    try {
      await PdfExportService.shareFile(
        title: 'คูปองส่วนลด (${selected.length} ใบ)',
        filename: PdfFilename.generate('coupons_batch'),
        buildPdf: () => CouponCardPdfBuilder.buildMultiple(
          selected,
          paperSize: _batchPaperSize,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Filter ─────────────────────────────────────────────────────
  bool get _hasFilter =>
      _filter != 'ALL' ||
      _searchQuery.isNotEmpty ||
      _expiresFrom != null ||
      _expiresTo != null;

  void _applyAllFilters() {
    ref.read(couponListProvider.notifier).applyFilter(
          status: _filter,
          search: _searchQuery,
          expiresFrom: _expiresFrom?.toIso8601String() ?? '',
          expiresTo:   _expiresTo?.toIso8601String()   ?? '',
        );
  }

  void _onSearchChanged(String v) {
    setState(() {
      _searchQuery = v;
      _selectedIds.clear();
    });
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      _applyAllFilters,
    );
  }

  void _onFilterChanged(String v) {
    setState(() {
      _filter = v;
      _selectedIds.clear();
    });
    _applyAllFilters();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery  = '';
      _filter       = 'ALL';
      _expiresFrom  = null;
      _expiresTo    = null;
      _selectedIds.clear();
    });
    ref.read(couponListProvider.notifier).applyFilter(status: 'ALL', search: '');
  }

  Future<void> _pickExpiresFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'หมดอายุตั้งแต่',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiresFrom = picked;
      if (_expiresTo != null && _expiresTo!.isBefore(picked)) {
        _expiresTo = null;
      }
      _selectedIds.clear();
    });
    _applyAllFilters();
  }

  Future<void> _pickExpiresTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresTo ?? _expiresFrom ?? DateTime.now(),
      firstDate: _expiresFrom ?? DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'หมดอายุถึง',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiresTo = picked;
      _selectedIds.clear();
    });
    _applyAllFilters();
  }

  void _toggleGroupMode() {
    final next = !_groupByPromotion;
    setState(() {
      _groupByPromotion = next;
      _selectionMode    = false;
      _selectedIds.clear();
    });
    if (next) {
      ref.read(couponListProvider.notifier).enableGroupMode();
    } else {
      ref.read(couponListProvider.notifier).disableGroupMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(couponListProvider);
    final promotionsAsync = ref.watch(promotionListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ───────────────────────────────────────────
          _TopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            hasFilter: _hasFilter,
            onSearchChanged: _onSearchChanged,
            onSearchCleared: () {
              _searchController.clear();
              _onSearchChanged('');
            },
            onRefresh: () => ref.read(couponListProvider.notifier).refresh(),
            onClearFilter: _hasFilter ? _clearFilters : null,
          ),

          // ── Filter Bar ────────────────────────────────────────
          _FilterBar(
            filter: _filter,
            onFilterChanged: _onFilterChanged,
            groupByPromotion: _groupByPromotion,
            onGroupToggle: _toggleGroupMode,
            expiresFrom: _expiresFrom,
            expiresTo: _expiresTo,
            onPickExpiresFrom: _pickExpiresFrom,
            onPickExpiresTo: _pickExpiresTo,
            onClearExpiryDates: (_expiresFrom != null || _expiresTo != null)
                ? () {
                    setState(() {
                      _expiresFrom = null;
                      _expiresTo   = null;
                      _selectedIds.clear();
                    });
                    _applyAllFilters();
                  }
                : null,
          ),

          // ── Body ──────────────────────────────────────────────
          Expanded(
            child: couponsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => _buildError(e),
              data: (pageState) {
                if (pageState.items.isEmpty) {
                  return _buildEmpty(pageState.total == 0, promotionsAsync);
                }

                final items = pageState.items;

                if (_groupByPromotion) {
                  return _buildGroupedView(items, pageState.summary, promotionsAsync);
                }

                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            _SummaryBar(summary: pageState.summary),
                            const Divider(height: 1, color: AppTheme.border),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1, color: AppTheme.border),
                                itemBuilder: (ctx, i) => _CouponRow(
                                  coupon: items[i],
                                  dateFmt: _dateFmt,
                                  selectionMode: _selectionMode,
                                  isSelected: _selectedIds.contains(items[i].couponCode),
                                  onTap: _selectionMode
                                      ? () => _toggleSelect(items[i].couponCode)
                                      : () => _showDetailDialog(context, items[i]),
                                  onCopy: () {
                                    Clipboard.setData(
                                        ClipboardData(text: items[i].couponCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'คัดลอก ${items[i].couponCode} แล้ว')),
                                    );
                                  },
                                  onPrint: () => _showPrintDialog(context, items[i]),
                                ),
                              ),
                            ),
                            // ── Footer: pagination + action buttons ──
                            if (!_selectionMode)
                              PaginationBar(
                                currentPage: pageState.page,
                                totalItems: pageState.total,
                                pageSize: pageState.limit,
                                onPageChanged: (p) => ref
                                    .read(couponListProvider.notifier)
                                    .goToPage(p),
                                trailing: _buildActionButtons(items, promotionsAsync),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // ── Selection bar (แสดงเมื่อ selection mode) ──
                    if (_selectionMode)
                      _SelectionBar(
                        selectedCount: _selectedIds.length,
                        totalCount: items.length,
                        allSelected: _selectedIds.length == items.length,
                        paperSize: _batchPaperSize,
                        onPaperSizeChanged: (s) =>
                            setState(() => _batchPaperSize = s),
                        onSelectAll: () => _selectAll(items),
                        onDeselectAll: () =>
                            setState(() => _selectedIds.clear()),
                        onPrint: _selectedIds.isEmpty
                            ? null
                            : () => _printSelected(items),
                        onShare: _selectedIds.isEmpty
                            ? null
                            : () => _shareSelected(items),
                        onCancel: _exitSelectionMode,
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

  // ── Grouped view ────────────────────────────────────────────────
  Widget _buildGroupedView(
    List<CouponModel> items,
    Map<String, int> summary,
    AsyncValue<List<PromotionModel>> promotionsAsync,
  ) {
    // Group by promotionId — preserve order (first-seen)
    final groupOrder  = <String>[];
    final groupMap    = <String, List<CouponModel>>{};
    final groupNames  = <String, String>{};
    for (final c in items) {
      if (!groupMap.containsKey(c.promotionId)) {
        groupOrder.add(c.promotionId);
        groupMap[c.promotionId]   = [];
        groupNames[c.promotionId] = c.promotionName ?? c.promotionId;
      }
      groupMap[c.promotionId]!.add(c);
    }

    // Build flat list: [header, row, row, …, header, row, …]
    final slivers = <Widget>[];
    for (final promoId in groupOrder) {
      final coupons   = groupMap[promoId]!;
      final promoName = groupNames[promoId]!;
      final valid   = coupons.where((c) => !c.isUsed && !c.isExpired).length;
      final used    = coupons.where((c) => c.isUsed).length;
      final expired = coupons.where((c) => !c.isUsed && c.isExpired).length;

      final isCollapsed = _collapsedGroups.contains(promoId);

      // Section header
      slivers.add(SliverToBoxAdapter(
        child: InkWell(
          onTap: () => setState(() {
            if (isCollapsed) {
              _collapsedGroups.remove(promoId);
            } else {
              _collapsedGroups.add(promoId);
            }
          }),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: isCollapsed ? const Radius.circular(10) : Radius.zero,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: isCollapsed ? const Radius.circular(10) : Radius.zero,
              ),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.local_offer,
                      size: 15, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(promoName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                ),
                // Mini stats
                _MiniStat(count: coupons.length, label: 'ทั้งหมด',
                    color: AppTheme.textSub),
                const SizedBox(width: 8),
                if (valid > 0)
                  _MiniStat(count: valid, label: 'ใช้ได้',
                      color: AppTheme.successColor),
                if (used > 0) ...[
                  const SizedBox(width: 8),
                  _MiniStat(count: used, label: 'ใช้แล้ว',
                      color: AppTheme.textSub),
                ],
                if (expired > 0) ...[
                  const SizedBox(width: 8),
                  _MiniStat(count: expired, label: 'หมดอายุ',
                      color: AppTheme.errorColor),
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isCollapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      size: 18, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
        ),
      ));

      // Coupon rows (hidden when collapsed)
      if (!isCollapsed) {
        slivers.add(SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(
                left:   BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
                right:  BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
                bottom: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: coupons.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (ctx, i) => _CouponRow(
                coupon: coupons[i],
                dateFmt: _dateFmt,
                onTap: () => _showDetailDialog(context, coupons[i]),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: coupons[i].couponCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('คัดลอก ${coupons[i].couponCode} แล้ว')));
                },
                onPrint: () => _showPrintDialog(context, coupons[i]),
              ),
            ),
          ),
        ));
      }
    }

    // Footer with create button
    slivers.add(SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.headerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            _Chip(
                icon: Icons.confirmation_number,
                label: '${summary['total'] ?? 0} ทั้งหมด',
                color: AppTheme.info),
            const SizedBox(width: 12),
            _Chip(
                icon: Icons.check_circle_outline,
                label: '${summary['valid'] ?? 0} ใช้ได้',
                color: AppTheme.successColor),
            const Spacer(),
            _CompactBtn(
              icon: Icons.add,
              label: 'สร้างคูปอง',
              color: Colors.white,
              bgColor: AppTheme.primaryColor,
              onTap: () => _showGenerateDialog(promotionsAsync),
            ),
          ],
        ),
      ),
    ));

    return CustomScrollView(slivers: slivers);
  }

  Widget _buildEmpty(bool noData, AsyncValue<List<PromotionModel>> promotionsAsync) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined,
                    size: 80, color: Colors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  noData ? 'ยังไม่มีคูปอง' : 'ไม่พบคูปองที่ตรงกับเงื่อนไข',
                  style: const TextStyle(fontSize: 15, color: AppTheme.textSub),
                ),
                if (_hasFilter) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('ล้างตัวกรอง'),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Footer bar เหมือน PaginationBar — มีปุ่ม +สร้างคูปอง
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.headerBg,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              _CompactBtn(
                icon: Icons.add,
                label: 'สร้างคูปอง',
                color: Colors.white,
                bgColor: AppTheme.primaryColor,
                onTap: () => _showGenerateDialog(promotionsAsync),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('เกิดข้อผิดพลาด: $e'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(couponListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // ── Generate Dialog ────────────────────────────────────────────
  void _showGenerateDialog(AsyncValue<List<PromotionModel>> promotionsAsync) async {
    final promotions = (promotionsAsync.hasValue ? promotionsAsync.value! : <PromotionModel>[])
        .where((p) => p.isActive && !p.isExpired)
        .toList();

    if (promotions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาสร้างโปรโมชั่นก่อน')));
      return;
    }

    String? selectedPromoId = promotions.first.promotionId;
    final countCtrl = TextEditingController(text: '1');
    final customCodeCtrl = TextEditingController();
    DateTime? expiresAt;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.infoContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.confirmation_number,
                    color: AppTheme.infoColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('สร้างคูปอง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('โปรโมชั่น *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPromoId,
                    decoration: _dialogInputDeco(),
                    items: promotions
                        .map((p) => DropdownMenuItem(
                              value: p.promotionId,
                              child: Text(p.promotionName,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedPromoId = v),
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('จำนวนคูปอง'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dialogInputDeco(suffix: 'ใบ'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10, 20, 50]
                        .map((n) => ActionChip(
                              label: Text('$n',
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () => setStateDialog(
                                  () => countCtrl.text = n.toString()),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('โค้ดกำหนดเอง (ถ้าต้องการ)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customCodeCtrl,
                    decoration: _dialogInputDeco(hint: 'เว้นว่าง = สุ่มอัตโนมัติ'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('วันหมดอายุ (ถ้าต้องการ)'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setStateDialog(() => expiresAt = picked);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: _dialogInputDeco(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              expiresAt != null
                                  ? DateFormat('dd/MM/yyyy').format(expiresAt!)
                                  : 'ไม่จำกัด',
                              style: TextStyle(
                                  color: expiresAt != null
                                      ? null
                                      : AppTheme.textSub),
                            ),
                          ),
                          const Icon(Icons.calendar_today,
                              size: 16, color: AppTheme.textSub),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (selectedPromoId == null) return;
                final count = int.tryParse(countCtrl.text) ?? 1;
                final success = await ref
                    .read(couponListProvider.notifier)
                    .createCoupons(
                      promotionId: selectedPromoId!,
                      count: count,
                      expiresAt: expiresAt,
                      customCode: customCodeCtrl.text.isNotEmpty
                          ? customCodeCtrl.text.toUpperCase()
                          : null,
                    );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('สร้างคูปอง $count ใบแล้ว')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('สร้างคูปอง'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (_) => _CouponDetailDialog(coupon: coupon, dateFmt: _dateFmt),
    );
  }

  void _showPrintDialog(BuildContext context, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (_) => _CouponPrintDialog(coupon: coupon, dateFmt: _dateFmt),
    );
  }

  // ── Action buttons ใน PaginationBar trailing ─────────────────
  Widget _buildActionButtons(
    List<CouponModel> items,
    AsyncValue<List<PromotionModel>> promotionsAsync,
  ) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactBtn(
            icon: Icons.checklist,
            label: 'เลือก',
            color: Colors.white,
            bgColor: AppTheme.infoColor,
            onTap: _enterSelectionMode,
          ),
          const SizedBox(width: 6),
          PdfReportButton(
            emptyMessage: 'ไม่มีข้อมูลคูปอง',
            title: 'รายงานคูปอง',
            filename: () => PdfFilename.generate('coupon_report'),
            buildPdf: () => CouponPdfBuilder.build(items),
            hasData: items.isNotEmpty,
          ),
          const SizedBox(width: 6),
          _CompactBtn(
            icon: Icons.add,
            label: 'สร้างคูปอง',
            color: Colors.white,
            bgColor: AppTheme.primaryColor,
            onTap: () => _showGenerateDialog(promotionsAsync),
          ),
        ],
      ),
    );
  }

  Widget _dialogLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSub));

  InputDecoration _dialogInputDeco({String? hint, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSub),
        suffixText: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// ─────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool hasFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onRefresh;
  final VoidCallback? onClearFilter;

  const _TopBar({
    required this.searchController,
    required this.searchQuery,
    required this.hasFilter,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onRefresh,
    this.onClearFilter,
  });

  static const _kBreak = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide ? _buildWide(context, canPop) : _buildNarrow(context, canPop),
    );
  }

  Widget _buildWide(BuildContext context, bool canPop) {
    return Row(
      children: [
        if (canPop) ...[
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
        ],
        _PageIcon(),
        const SizedBox(width: 10),
        const Text('จัดการคูปอง',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A))),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: _SearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ),
        const SizedBox(width: 8),
        if (hasFilter && onClearFilter != null)
          _ClearFilterBtn(onTap: onClearFilter!),
        const SizedBox(width: 6),
        _RefreshBtn(onTap: onRefresh),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context, bool canPop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _BackBtn(onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
            ],
            _PageIcon(),
            const SizedBox(width: 8),
            const Text('จัดการคูปอง',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const Spacer(),
            if (hasFilter && onClearFilter != null)
              _ClearFilterBtn(onTap: onClearFilter!),
            const SizedBox(width: 6),
            _RefreshBtn(onTap: onRefresh),
          ],
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final bool groupByPromotion;
  final VoidCallback onGroupToggle;
  final DateTime? expiresFrom;
  final DateTime? expiresTo;
  final VoidCallback onPickExpiresFrom;
  final VoidCallback onPickExpiresTo;
  final VoidCallback? onClearExpiryDates;

  const _FilterBar({
    required this.filter,
    required this.onFilterChanged,
    required this.groupByPromotion,
    required this.onGroupToggle,
    required this.expiresFrom,
    required this.expiresTo,
    required this.onPickExpiresFrom,
    required this.onPickExpiresTo,
    this.onClearExpiryDates,
  });

  static const _items = [
    ('ALL',     'ทั้งหมด',  null),
    ('VALID',   'ใช้ได้',   AppTheme.successColor),
    ('USED',    'ใช้แล้ว',  AppTheme.textSub),
    ('EXPIRED', 'หมดอายุ',  AppTheme.errorColor),
  ];

  static final _dateFmt = DateFormat('dd/MM/yy', 'th_TH');

  @override
  Widget build(BuildContext context) {
    final hasExpiry = expiresFrom != null || expiresTo != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Status chips + Group toggle ──────────────────
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _items.map((item) {
                      final value = item.$1;
                      final label = item.$2;
                      final color = item.$3 ?? AppTheme.primaryColor;
                      final selected = filter == value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? color : AppTheme.textSub,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                          selected: selected,
                          selectedColor: color.withValues(alpha: 0.12),
                          checkmarkColor: color,
                          side: BorderSide(
                              color: selected ? color : AppTheme.border),
                          backgroundColor: const Color(0xFFF5F5F5),
                          onSelected: (_) => onFilterChanged(value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: groupByPromotion
                    ? 'ยกเลิกการจัดกลุ่ม'
                    : 'จัดกลุ่มตามโปรโมชั่น',
                child: InkWell(
                  onTap: onGroupToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: groupByPromotion
                          ? AppTheme.primaryColor
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: groupByPromotion
                            ? AppTheme.primaryColor
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_copy_outlined,
                            size: 14,
                            color: groupByPromotion
                                ? Colors.white
                                : AppTheme.textSub),
                        const SizedBox(width: 5),
                        Text('จัดกลุ่ม',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: groupByPromotion
                                  ? Colors.white
                                  : AppTheme.textSub,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ── Row 2: Expiry date range filter ─────────────────────
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_outlined,
                  size: 14,
                  color: hasExpiry
                      ? AppTheme.primaryColor
                      : AppTheme.textSub),
              const SizedBox(width: 6),
              Text('หมดอายุ:',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasExpiry
                        ? AppTheme.primaryColor
                        : AppTheme.textSub,
                    fontWeight: hasExpiry
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
              const SizedBox(width: 8),
              _DatePickerButton(
                label: expiresFrom != null
                    ? _dateFmt.format(expiresFrom!)
                    : 'ตั้งแต่',
                active: expiresFrom != null,
                onTap: onPickExpiresFrom,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('→',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSub)),
              ),
              _DatePickerButton(
                label: expiresTo != null
                    ? _dateFmt.format(expiresTo!)
                    : 'ถึง',
                active: expiresTo != null,
                onTap: onPickExpiresTo,
              ),
              if (hasExpiry) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onClearExpiryDates,
                  borderRadius: BorderRadius.circular(4),
                  child: const Icon(Icons.close,
                      size: 16, color: AppTheme.textSub),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.10)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? AppTheme.primaryColor : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? AppTheme.primaryColor : AppTheme.textSub,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary Bar
// ─────────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final Map<String, int> summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF8F5),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _Chip(icon: Icons.confirmation_number,
              label: '${summary['total']} ทั้งหมด', color: AppTheme.info),
          _Chip(icon: Icons.check_circle_outline,
              label: '${summary['valid']} ใช้ได้', color: AppTheme.successColor),
          if ((summary['used'] ?? 0) > 0)
            _Chip(icon: Icons.block, label: '${summary['used']} ใช้แล้ว',
                color: AppTheme.textSub),
          if ((summary['expired'] ?? 0) > 0)
            _Chip(icon: Icons.cancel_outlined,
                label: '${summary['expired']} หมดอายุ', color: AppTheme.errorColor),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Compact action button — ใช้ใน PaginationBar trailing
// ─────────────────────────────────────────────────────────────────
class _CompactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;
  final VoidCallback onTap;

  const _CompactBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────
// Coupon Row
// ─────────────────────────────────────────────────────────────────
class _CouponRow extends StatelessWidget {
  final CouponModel coupon;
  final DateFormat dateFmt;
  final VoidCallback onCopy;
  final VoidCallback onPrint;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelected;

  const _CouponRow({
    required this.coupon,
    required this.dateFmt,
    required this.onCopy,
    required this.onPrint,
    this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
  });

  static ({Color color, String label, IconData icon}) _status(CouponModel c) {
    if (c.isUsed) {
      return (color: AppTheme.textSub, label: 'ใช้แล้ว', icon: Icons.check_circle);
    } else if (c.isExpired) {
      return (color: AppTheme.errorColor, label: 'หมดอายุ', icon: Icons.cancel);
    } else {
      return (color: AppTheme.successColor, label: 'ใช้ได้', icon: Icons.confirmation_number);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _status(coupon);

    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon / Checkbox
          if (selectionMode)
            SizedBox(
              width: 42,
              height: 42,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap?.call(),
                activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: st.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(st.icon, color: st.color, size: 20),
            ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      coupon.couponCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                        decoration: coupon.isUsed ? TextDecoration.lineThrough : null,
                        color: coupon.isUsed
                            ? AppTheme.textSub
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (!selectionMode) ...[
                      if (!coupon.isUsed && !coupon.isExpired) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onCopy,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.copy, size: 14, color: AppTheme.textSub),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onPrint,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.qr_code, size: 14, color: AppTheme.infoColor),
                        ),
                      ),
                    ],
                  ],
                ),
                if (coupon.promotionName != null) ...[
                  const SizedBox(height: 2),
                  Text(coupon.promotionName!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSub)),
                ],
                if (coupon.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text('หมดอายุ: ${dateFmt.format(coupon.expiresAt!)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSub)),
                ],
                if (coupon.isUsed && coupon.usedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('ใช้เมื่อ: ${dateFmt.format(coupon.usedAt!)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSub)),
                ],
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: st.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(st.icon, size: 12, color: st.color),
                const SizedBox(width: 4),
                Text(st.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: st.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
// Coupon Detail Dialog
// ─────────────────────────────────────────────────────────────────
class _CouponDetailDialog extends StatelessWidget {
  final CouponModel coupon;
  final DateFormat dateFmt;

  const _CouponDetailDialog({required this.coupon, required this.dateFmt});

  static ({Color color, IconData icon, String label}) _status(CouponModel c) {
    if (c.isUsed) return (color: AppTheme.textSub, icon: Icons.check_circle, label: 'ใช้แล้ว');
    if (c.isExpired) return (color: AppTheme.errorColor, icon: Icons.cancel, label: 'หมดอายุ');
    return (color: AppTheme.successColor, icon: Icons.confirmation_number, label: 'ใช้ได้');
  }

  @override
  Widget build(BuildContext context) {
    final st = _status(coupon);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usedByLabel = coupon.usedBy == null || coupon.usedBy!.isEmpty
        ? '-'
        : coupon.usedBy == 'WALK_IN'
            ? 'ลูกค้าทั่วไป'
            : coupon.usedBy!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.confirmation_number,
                        color: AppTheme.infoColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('รายละเอียดคูปอง',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Code + Status ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? const Color(0xFF444444) : AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        coupon.couponCode,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: st.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: st.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(st.icon, size: 12, color: st.color),
                          const SizedBox(width: 4),
                          Text(st.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: st.color,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Info rows ────────────────────────────────────
              if (coupon.promotionName != null)
                _DetailRow(
                  icon: Icons.local_offer_outlined,
                  label: 'โปรโมชั่น',
                  value: coupon.promotionName!,
                ),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'สร้างเมื่อ',
                value: dateFmt.format(coupon.createdAt),
              ),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'หมดอายุ',
                value: coupon.expiresAt != null
                    ? dateFmt.format(coupon.expiresAt!)
                    : 'ไม่จำกัด',
                valueColor: coupon.isExpired ? AppTheme.errorColor : null,
              ),

              // ── Used section ─────────────────────────────────
              if (coupon.isUsed) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark ? const Color(0xFF444444) : AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: AppTheme.textSub),
                          SizedBox(width: 6),
                          Text('ข้อมูลการใช้งาน',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSub)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.person,
                        label: 'ผู้ใช้',
                        value: usedByLabel,
                      ),
                      if (coupon.usedAt != null)
                        _DetailRow(
                          icon: Icons.access_time,
                          label: 'ใช้เมื่อ',
                          value: dateFmt.format(coupon.usedAt!),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSub),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? textColor)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Coupon Print / QR Dialog
// ─────────────────────────────────────────────────────────────────
class _CouponPrintDialog extends StatefulWidget {
  final CouponModel coupon;
  final DateFormat dateFmt;

  const _CouponPrintDialog({required this.coupon, required this.dateFmt});

  @override
  State<_CouponPrintDialog> createState() => _CouponPrintDialogState();
}

class _CouponPrintDialogState extends State<_CouponPrintDialog> {
  bool _printing = false;
  bool _sharing = false;
  CouponPaperSize _paperSize = CouponPaperSize.a6;

  Future<pw.Document> _buildPdf() => CouponCardPdfBuilder.build(
        widget.coupon,
        paperSize: _paperSize,
      );

  String get _filename =>
      PdfFilename.generate('coupon_${widget.coupon.couponCode}');

  Future<void> _previewCard() async {
    setState(() => _printing = true);
    try {
      await PdfExportService.showPreview(
        context,
        title: 'คูปองส่วนลด ${widget.coupon.couponCode}',
        filename: _filename,
        buildPdf: _buildPdf,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      await PdfExportService.shareFile(
        title: 'คูปองส่วนลด ${widget.coupon.couponCode}',
        filename: _filename,
        buildPdf: _buildPdf,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final dateFmt = widget.dateFmt;
    final st = coupon.isUsed
        ? (color: AppTheme.textSub, label: 'ใช้แล้ว')
        : coupon.isExpired
            ? (color: AppTheme.errorColor, label: 'หมดอายุ')
            : (color: AppTheme.successColor, label: 'ใช้ได้');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.confirmation_number,
                        color: AppTheme.infoColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('คูปองส่วนลด',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── QR Code ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: QrImageView(
                  data: coupon.couponCode,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // ── Code ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      coupon.couponCode,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: coupon.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('คัดลอก ${coupon.couponCode} แล้ว')),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy,
                            size: 16, color: AppTheme.infoColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Info ─────────────────────────────────────────
              if (coupon.promotionName != null)
                _InfoRow(
                    icon: Icons.local_offer,
                    text: coupon.promotionName!,
                    color: AppTheme.primaryColor),
              if (coupon.expiresAt != null) ...[
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.event,
                  text: 'หมดอายุ: ${dateFmt.format(coupon.expiresAt!)}',
                  color: coupon.isExpired
                      ? AppTheme.errorColor
                      : AppTheme.textSub,
                ),
              ],
              const SizedBox(height: 12),

              // ── Paper size selector ───────────────────────────
              Row(
                children: [
                  const Text('ขนาดกระดาษ',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
                  const Spacer(),
                  SegmentedButton<CouponPaperSize>(
                    segments: const [
                      ButtonSegment(
                        value: CouponPaperSize.a6,
                        label: Text('A6'),
                        icon: Icon(Icons.crop_landscape_outlined, size: 14),
                      ),
                      ButtonSegment(
                        value: CouponPaperSize.a4,
                        label: Text('A4'),
                        icon: Icon(Icons.crop_portrait_outlined, size: 14),
                      ),
                    ],
                    selected: {_paperSize},
                    onSelectionChanged: (s) =>
                        setState(() => _paperSize = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Status badge ──────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: st.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: st.color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  st.label,
                  style: TextStyle(
                      color: st.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),

              // ── Action buttons ────────────────────────────────
              const SizedBox(height: 4),
              Row(
                children: [
                  // แสดง / พิมพ์ PDF
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_printing || _sharing) ? null : _previewCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _printing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                      label: Text(_printing ? 'กำลังเตรียม...' : 'แสดง PDF',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // แชร์ PDF
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_printing || _sharing) ? null : _shareCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _sharing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_outlined, size: 17),
                      label: Text(_sharing ? 'กำลังแชร์...' : 'แชร์ PDF',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Selection Action Bar
// ─────────────────────────────────────────────────────────────────
class _SelectionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final CouponPaperSize paperSize;
  final ValueChanged<CouponPaperSize> onPaperSizeChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;
  final VoidCallback onCancel;

  const _SelectionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.paperSize,
    required this.onPaperSizeChanged,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onPrint,
    required this.onShare,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Count
          Text(
            'เลือก $selectedCount / $totalCount',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          // Select all / deselect all toggle
          TextButton.icon(
            onPressed: allSelected ? onDeselectAll : onSelectAll,
            icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              size: 16,
            ),
            label: Text(allSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
          const Spacer(),
          // Paper size toggle
          SegmentedButton<CouponPaperSize>(
            segments: const [
              ButtonSegment(
                value: CouponPaperSize.a6,
                label: Text('A6'),
                icon: Icon(Icons.crop_landscape_outlined, size: 14),
              ),
              ButtonSegment(
                value: CouponPaperSize.a4,
                label: Text('A4'),
                icon: Icon(Icons.crop_portrait_outlined, size: 14),
              ),
            ],
            selected: {paperSize},
            onSelectionChanged: (s) => onPaperSizeChanged(s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          // Cancel
          TextButton(
            onPressed: onCancel,
            child: const Text('ยกเลิก',
                style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
          ),
          const SizedBox(width: 8),
          // Preview/Print button
          ElevatedButton.icon(
            onPressed: onPrint,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: Text(
              selectedCount == 0 ? 'แสดง PDF' : 'แสดง $selectedCount ใบ',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          // Share button
          ElevatedButton.icon(
            onPressed: onShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: Text(
              selectedCount == 0 ? 'แชร์ PDF' : 'แชร์ $selectedCount ใบ',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoRow(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color),
                textAlign: TextAlign.center),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────
class _PageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.infoContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.confirmation_number_outlined,
            color: AppTheme.infoColor, size: 18),
      );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'ค้นหาโค้ดคูปอง...',
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSub),
            prefixIcon: const Icon(Icons.search, size: 17, color: AppTheme.textSub),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: onCleared,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: onChanged,
        ),
      );
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'รีเฟรช',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.refresh, size: 17, color: AppTheme.textSub),
          ),
        ),
      );
}

class _ClearFilterBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearFilterBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'ล้างตัวกรองทั้งหมด',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_off, size: 15, color: AppTheme.error),
                const SizedBox(width: 5),
                const Text('ล้างตัวกรอง',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _MiniStat({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count $label',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.arrow_back,
              size: 17, color: AppTheme.textSub),
        ),
      );
}
