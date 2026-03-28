// coupon_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';

class CouponListPage extends ConsumerStatefulWidget {
  const CouponListPage({super.key});

  @override
  ConsumerState<CouponListPage> createState() => _CouponListPageState();
}

class _CouponListPageState extends ConsumerState<CouponListPage> {
  final _searchController = TextEditingController();
  String _filter = 'ALL'; // ALL, VALID, USED, EXPIRED
  String _searchQuery = '';
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter ─────────────────────────────────────────────────────
  List<CouponModel> _applyFilter(List<CouponModel> list) {
    return list.where((c) {
      if (_searchQuery.isNotEmpty) {
        if (!c.couponCode.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      switch (_filter) {
        case 'VALID':
          return c.isValid;
        case 'USED':
          return c.isUsed;
        case 'EXPIRED':
          return c.isExpired && !c.isUsed;
        default:
          return true;
      }
    }).toList();
  }

  bool get _hasFilter => _filter != 'ALL' || _searchQuery.isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filter = 'ALL';
    });
  }

  // ── Summary ────────────────────────────────────────────────────
  Map<String, int> _calcSummary(List<CouponModel> list) {
    int valid = 0, used = 0, expired = 0;
    for (final c in list) {
      if (c.isUsed) {
        used++;
      } else if (c.isExpired) {
        expired++;
      } else {
        valid++;
      }
    }
    return {'total': list.length, 'valid': valid, 'used': used, 'expired': expired};
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
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onSearchCleared: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            onRefresh: () => ref.read(couponListProvider.notifier).refresh(),
            onClearFilter: _hasFilter ? _clearFilters : null,
          ),

          // ── Filter Bar ────────────────────────────────────────
          _FilterBar(
            filter: _filter,
            onFilterChanged: (v) => setState(() => _filter = v),
          ),

          // ── Body ──────────────────────────────────────────────
          Expanded(
            child: couponsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => _buildError(e),
              data: (coupons) {
                final filtered = _applyFilter(coupons);
                final summary = _calcSummary(coupons);

                if (filtered.isEmpty) {
                  return _buildEmpty(coupons.isEmpty, promotionsAsync);
                }

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          _SummaryBar(summary: summary),
                          const Divider(height: 1, color: AppTheme.border),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, color: AppTheme.border),
                              itemBuilder: (ctx, i) => _CouponRow(
                                coupon: filtered[i],
                                dateFmt: _dateFmt,
                                onCopy: () {
                                  Clipboard.setData(
                                      ClipboardData(text: filtered[i].couponCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'คัดลอก ${filtered[i].couponCode} แล้ว')),
                                  );
                                },
                                onPrint: () => _showPrintDialog(
                                    context, filtered[i]),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              color: AppTheme.headerBg,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'แสดง ${filtered.length} จาก ${coupons.length} รายการ',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textSub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: FloatingActionButton.extended(
                        onPressed: () => _showGenerateDialog(promotionsAsync),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.add),
                        label: const Text('สร้างคูปอง'),
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

  Widget _buildEmpty(bool noData, AsyncValue<List<PromotionModel>> promotionsAsync) {
    return Stack(
      children: [
        Center(
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
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showGenerateDialog(promotionsAsync),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('สร้างคูปอง'),
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
    final promotions = promotionsAsync.hasValue ? promotionsAsync.value! : <PromotionModel>[];

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

  void _showPrintDialog(BuildContext context, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (_) => _CouponPrintDialog(coupon: coupon, dateFmt: _dateFmt),
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

  const _FilterBar({required this.filter, required this.onFilterChanged});

  static const _items = [
    ('ALL',     'ทั้งหมด',  null),
    ('VALID',   'ใช้ได้',   AppTheme.successColor),
    ('USED',    'ใช้แล้ว',  AppTheme.textSub),
    ('EXPIRED', 'หมดอายุ',  AppTheme.errorColor),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
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

  const _CouponRow({
    required this.coupon,
    required this.dateFmt,
    required this.onCopy,
    required this.onPrint,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Coupon Print / QR Dialog
// ─────────────────────────────────────────────────────────────────
class _CouponPrintDialog extends StatelessWidget {
  final CouponModel coupon;
  final DateFormat dateFmt;

  const _CouponPrintDialog({required this.coupon, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
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
