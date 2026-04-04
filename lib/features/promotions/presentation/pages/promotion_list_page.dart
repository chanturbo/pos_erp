import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';
import 'promotion_form_page.dart';
import 'coupon_list_page.dart';
import 'promotion_usage_report_page.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';

class PromotionListPage extends ConsumerStatefulWidget {
  const PromotionListPage({super.key});

  @override
  ConsumerState<PromotionListPage> createState() => _PromotionListPageState();
}

class _PromotionListPageState extends ConsumerState<PromotionListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'ALL'; // ALL, ACTIVE, UPCOMING, EXPIRED, INACTIVE
  int _currentPage = 1;

  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _dateFmt = DateFormat('dd/MM/yyyy', 'th_TH');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter Logic ───────────────────────────────────────────────
  List<PromotionModel> _applyFilter(List<PromotionModel> list) {
    final now = DateTime.now();
    return list.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.promotionName.toLowerCase().contains(q) &&
            !p.promotionCode.toLowerCase().contains(q)) {
          return false;
        }
      }
      switch (_filter) {
        case 'ACTIVE':
          return p.isActive && now.isAfter(p.startDate) && now.isBefore(p.endDate);
        case 'UPCOMING':
          return p.isActive && now.isBefore(p.startDate);
        case 'EXPIRED':
          return now.isAfter(p.endDate);
        case 'INACTIVE':
          return !p.isActive;
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
      _currentPage = 1;
    });
  }

  // ── Summary ────────────────────────────────────────────────────
  Map<String, int> _calcSummary(List<PromotionModel> list) {
    final now = DateTime.now();
    int active = 0, upcoming = 0, expired = 0, inactive = 0;
    for (final p in list) {
      if (!p.isActive) {
        inactive++;
      } else if (now.isAfter(p.startDate) && now.isBefore(p.endDate)) {
        active++;
      } else if (now.isBefore(p.startDate)) {
        upcoming++;
      } else {
        expired++;
      }
    }
    return {
      'total': list.length,
      'active': active,
      'upcoming': upcoming,
      'expired': expired,
      'inactive': inactive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final promotionsAsync = ref.watch(promotionListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;

    void openCoupon() => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CouponListPage()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ─────────────────────────────────────────
          _TopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            hasFilter: _hasFilter,
            onSearchChanged: (v) => setState(() {
              _searchQuery = v;
              _currentPage = 1;
            }),
            onSearchCleared: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _currentPage = 1;
              });
            },
            onRefresh: () =>
                ref.read(promotionListProvider.notifier).refresh(),
            onClearFilter: _hasFilter ? _clearFilters : null,
            onReport: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PromotionUsageReportPage()),
            ),
          ),

          // ── Filter Bar ──────────────────────────────────────
          _FilterBar(
            filter: _filter,
            onFilterChanged: (v) => setState(() {
              _filter = v;
              _currentPage = 1;
            }),
          ),

          // ── Body ────────────────────────────────────────────
          Expanded(
            child: promotionsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => _buildError(e),
              data: (promotions) {
                final filtered = _applyFilter(promotions);
                final summary = _calcSummary(promotions);

                final totalFiltered = filtered.length;
                final totalPages =
                    totalFiltered == 0 ? 1 : (totalFiltered / pageSize).ceil();
                final page = _currentPage.clamp(1, totalPages);
                final pageStart = (page - 1) * pageSize;
                final pageEnd = (pageStart + pageSize).clamp(0, totalFiltered);
                final pageItems = totalFiltered == 0
                    ? <PromotionModel>[]
                    : filtered.sublist(pageStart, pageEnd);

                if (filtered.isEmpty) return _buildEmpty(promotions.isEmpty, openCoupon);

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      // ── Summary Bar ──────────────────
                      _SummaryBar(summary: summary),
                      const Divider(height: 1, color: AppTheme.border),

                      // ── List ─────────────────────────
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: pageItems.length,
                          separatorBuilder: (_, _) => const Divider(
                              height: 1, color: AppTheme.border),
                          itemBuilder: (ctx, i) => _PromotionRow(
                            promotion: pageItems[i],
                            fmt: _fmt,
                            dateFmt: _dateFmt,
                            onEdit: () => _openForm(pageItems[i]),
                            onToggle: () => _toggleActive(pageItems[i]),
                            onDelete: () => _confirmDelete(pageItems[i]),
                          ),
                        ),
                      ),

                      // ── Footer / Pagination ──────────
                      PaginationBar(
                        currentPage: page,
                        totalItems: totalFiltered,
                        pageSize: pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: _buildFooterBtns(openCoupon),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noData, VoidCallback openCoupon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 80, color: Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    noData ? 'ยังไม่มีโปรโมชั่น' : 'ไม่พบโปรโมชั่นที่ตรงกับเงื่อนไข',
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
          PaginationBar(
            currentPage: 1,
            totalItems: 0,
            pageSize: ref.read(settingsProvider).listPageSize,
            onPageChanged: (_) {},
            trailing: _buildFooterBtns(openCoupon),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBtns(VoidCallback openCoupon) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PromoFooterBtn(
            icon: Icons.confirmation_number_outlined,
            label: 'จัดการคูปอง',
            color: AppTheme.infoColor,
            filled: true,
            onTap: openCoupon,
          ),
          const SizedBox(width: 6),
          _PromoFooterBtn(
            icon: Icons.add,
            label: 'สร้างโปรโมชั่น',
            color: AppTheme.primaryColor,
            filled: true,
            onTap: () => _openForm(null),
          ),
        ],
      ),
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
            onPressed: () => ref.read(promotionListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────
  void _openForm(PromotionModel? promo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PromotionFormPage(promotion: promo)),
    );
    ref.read(promotionListProvider.notifier).refresh();
  }

  void _toggleActive(PromotionModel p) async {
    final updated = p.copyWith(isActive: !p.isActive);
    await ref.read(promotionListProvider.notifier).updatePromotion(updated);
  }

  void _confirmDelete(PromotionModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบโปรโมชั่น "${p.promotionName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performDelete(p);
            },
            child: const Text('ลบ',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(PromotionModel p,
      {bool forceDeleteCoupons = false}) async {
    if (!mounted) return;

    final result = await ref
        .read(promotionListProvider.notifier)
        .deletePromotion(p.promotionId,
            forceDeleteCoupons: forceDeleteCoupons);

    if (!mounted) return;
    final code = result['code'] as String?;

    if (result['success'] == true) {
      final cancelled = (result['coupons_cancelled'] as int?) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cancelled > 0
            ? 'ลบโปรโมชั่นแล้ว (ยกเลิกคูปอง $cancelled ใบ)'
            : 'ลบโปรโมชั่นแล้ว'),
      ));
      return;
    }

    if (code == 'HAS_ORDERS') {
      final orderCount = (result['order_count'] as int?) ?? 0;
      final usedCoupons = (result['used_coupon_count'] as int?) ?? 0;
      _showBlockedDialog(p, orderCount, usedCoupons);
      return;
    }

    if (code == 'HAS_UNUSED_COUPONS') {
      final couponCount = (result['coupon_count'] as int?) ?? 0;
      _showUnusedCouponsDialog(p, couponCount);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('เกิดข้อผิดพลาด: ${result['message'] ?? 'ไม่ทราบสาเหตุ'}'),
    ));
  }

  void _showBlockedDialog(
      PromotionModel p, int orderCount, int usedCouponCount) {
    final detail = [
      if (orderCount > 0) 'ออเดอร์ $orderCount รายการ',
      if (usedCouponCount > 0) 'คูปองที่ใช้แล้ว $usedCouponCount ใบ',
    ].join(' และ ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.block, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          const Text('ไม่สามารถลบได้'),
        ]),
        content: Text(
          'โปรโมชั่น "${p.promotionName}" ถูกใช้งานแล้วใน $detail\n\n'
          'ต้องการปิดการใช้งานแทนหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.pause_circle_outline, size: 16),
            label: const Text('ปิดการใช้งาน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (p.isActive) {
                await ref
                    .read(promotionListProvider.notifier)
                    .updatePromotion(p.copyWith(isActive: false));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ปิดการใช้งานโปรโมชั่นแล้ว')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showUnusedCouponsDialog(PromotionModel p, int couponCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.confirmation_number_outlined,
              color: AppTheme.warningColor, size: 20),
          const SizedBox(width: 8),
          const Text('มีคูปองที่ยังไม่ได้ใช้'),
        ]),
        content: Text(
          'โปรโมชั่น "${p.promotionName}" มีคูปองที่ยังไม่ถูกใช้อีก $couponCount ใบ\n\n'
          'ต้องการยกเลิกคูปองทั้งหมดและลบโปรโมชั่นนี้ด้วยหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_outlined, size: 16),
            label: Text('ยกเลิกคูปอง $couponCount ใบ และลบ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performDelete(p, forceDeleteCoupons: true);
            },
          ),
        ],
      ),
    );
  }
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
  final VoidCallback onReport;

  const _TopBar({
    required this.searchController,
    required this.searchQuery,
    required this.hasFilter,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onRefresh,
    required this.onReport,
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
      child: isWide
          ? _buildWide(context, canPop)
          : _buildNarrow(context, canPop),
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
        const Text(
          'โปรโมชั่น',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A)),
        ),
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
        const SizedBox(width: 6),
        Tooltip(
          message: 'รายงานการใช้งานโปรโมชั่น',
          child: IconButton(
            icon: const Icon(Icons.bar_chart, size: 20),
            onPressed: onReport,
          ),
        ),
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
            const Text(
              'โปรโมชั่น',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
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
    ('ALL',      'ทั้งหมด',         null),
    ('ACTIVE',   'กำลังใช้งาน',    AppTheme.successColor),
    ('UPCOMING', 'เร็วๆ นี้',       AppTheme.infoColor),
    ('EXPIRED',  'หมดอายุ',         AppTheme.errorColor),
    ('INACTIVE', 'ปิดการใช้งาน',   AppTheme.textSub),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
                selected: selected,
                selectedColor: color.withValues(alpha: 0.12),
                checkmarkColor: color,
                side: BorderSide(
                  color: selected ? color : AppTheme.border,
                ),
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
          _SummaryChip(
            icon: Icons.local_offer,
            label: '${summary['total']} รายการ',
            color: AppTheme.info,
          ),
          _SummaryChip(
            icon: Icons.play_circle_outline,
            label: '${summary['active']} ใช้งาน',
            color: AppTheme.successColor,
          ),
          if ((summary['upcoming'] ?? 0) > 0)
            _SummaryChip(
              icon: Icons.schedule,
              label: '${summary['upcoming']} เร็วๆ นี้',
              color: AppTheme.infoColor,
            ),
          if ((summary['expired'] ?? 0) > 0)
            _SummaryChip(
              icon: Icons.cancel_outlined,
              label: '${summary['expired']} หมดอายุ',
              color: AppTheme.errorColor,
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Promotion Row
// ─────────────────────────────────────────────────────────────────
class _PromotionRow extends StatelessWidget {
  final PromotionModel promotion;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PromotionRow({
    required this.promotion,
    required this.fmt,
    required this.dateFmt,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  static _PromotionStatus _status(PromotionModel p) {
    final now = DateTime.now();
    if (!p.isActive) {
      return _PromotionStatus(
          label: 'ปิด', color: AppTheme.textSub, icon: Icons.block);
    } else if (now.isAfter(p.startDate) && now.isBefore(p.endDate)) {
      return _PromotionStatus(
          label: 'ใช้งานอยู่', color: AppTheme.successColor, icon: Icons.play_circle);
    } else if (now.isBefore(p.startDate)) {
      return _PromotionStatus(
          label: 'เร็วๆ นี้', color: AppTheme.infoColor, icon: Icons.schedule);
    } else {
      return _PromotionStatus(
          label: 'หมดอายุ', color: AppTheme.errorColor, icon: Icons.cancel);
    }
  }

  static String _discountLabel(PromotionModel p, NumberFormat fmt) {
    switch (p.promotionType) {
      case 'DISCOUNT_PERCENT':
        final cap = p.maxDiscountAmount != null
            ? ' (สูงสุด ฿${fmt.format(p.maxDiscountAmount!)})'
            : '';
        return 'ลด ${p.discountValue.toStringAsFixed(0)}%$cap';
      case 'DISCOUNT_AMOUNT':
        return 'ลด ฿${fmt.format(p.discountValue)}';
      case 'BUY_X_GET_Y':
        return 'ซื้อ ${p.buyQty} แถม ${p.getQty}';
      case 'FREE_ITEM':
        return 'ของแถมฟรี';
      default:
        return p.promotionType;
    }
  }

  static Widget _typeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'DISCOUNT_PERCENT':
        icon = Icons.percent;
        color = const Color(0xFF9C27B0);
        break;
      case 'DISCOUNT_AMOUNT':
        icon = Icons.money;
        color = AppTheme.successColor;
        break;
      case 'BUY_X_GET_Y':
        icon = Icons.card_giftcard;
        color = AppTheme.errorColor;
        break;
      case 'FREE_ITEM':
        icon = Icons.free_breakfast;
        color = const Color(0xFF009688);
        break;
      default:
        icon = Icons.local_offer;
        color = AppTheme.primaryColor;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = promotion;
    final st = _status(p);
    final isExpired = st.label == 'หมดอายุ';
    final isRunningOrUpcoming =
        st.label == 'ใช้งานอยู่' || st.label == 'เร็วๆ นี้';

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────
            Row(
              children: [
                _typeIcon(p.promotionType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.promotionName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 2),
                      Text(p.promotionCode,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSub)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: st.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, size: 13, color: st.color),
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
            const SizedBox(height: 10),

            // ── Discount info ────────────────────────────────────
            Row(
              children: [
                Icon(Icons.local_offer,
                    size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  _discountLabel(p, fmt),
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                if (p.minAmount > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.shopping_cart,
                      size: 13, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(
                    'ขั้นต่ำ ฿${fmt.format(p.minAmount)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSub),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // ── Period ───────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.date_range,
                    size: 13, color: AppTheme.textSub),
                const SizedBox(width: 4),
                Text(
                  '${dateFmt.format(p.startDate)} – ${dateFmt.format(p.endDate)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSub),
                ),
                if (p.maxUses != null) ...[
                  const Spacer(),
                  const Icon(Icons.people, size: 13, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(
                    '${p.currentUses}/${p.maxUses} ครั้ง',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSub),
                  ),
                ],
              ],
            ),

            // ── Progress ─────────────────────────────────────────
            if (p.maxUses != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p.maxUses! > 0
                      ? (p.currentUses / p.maxUses!).clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: AppTheme.border,
                  color: p.currentUses >= p.maxUses!
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
                  minHeight: 5,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // ── Actions ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isRunningOrUpcoming)
                  _ActionBtn(
                    icon: Icons.pause_circle_outline,
                    label: 'หยุดชั่วคราว',
                    color: AppTheme.warningColor,
                    onTap: onToggle,
                  ),
                if (!p.isActive && !isExpired)
                  _ActionBtn(
                    icon: Icons.play_circle_outline,
                    label: 'เปิดใช้งาน',
                    color: AppTheme.successColor,
                    onTap: onToggle,
                  ),
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'แก้ไข',
                  color: AppTheme.infoColor,
                  onTap: onEdit,
                ),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  label: 'ลบ',
                  color: AppTheme.errorColor,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Footer Button (จัดการคูปอง / สร้างโปรโมชั่น)
// ─────────────────────────────────────────────────────────────────
class _PromoFooterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _PromoFooterBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? color : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionStatus {
  final String label;
  final Color color;
  final IconData icon;
  const _PromotionStatus(
      {required this.label, required this.color, required this.icon});
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
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
        child: const Icon(Icons.local_offer,
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
            hintText: 'ค้นหาชื่อ, รหัสโปรโมชั่น...',
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
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_off,
                    size: 15, color: AppTheme.error),
                const SizedBox(width: 5),
                const Text(
                  'ล้างตัวกรอง',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500),
                ),
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
          child: const Icon(Icons.arrow_back, size: 17, color: AppTheme.textSub),
        ),
      );
}
