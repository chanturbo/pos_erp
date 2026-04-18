// ════════════════════════════════════════════════════════════════
// stock_adjustment_page.dart
// Day 33-34: Stock Adjustment — ปรับสต๊อก / นับสต๊อก / โอนย้าย
//
// 🗺️ ROADMAP
//
// ✅ Step 1 — StockAdjustmentPage (หน้าเมนูหลัก)
// ✅ Step 2 — AdjustStockSubPage (ปรับเพิ่ม/ลดทีละรายการ)
// ✅ Step 3 — StockTakeSubPage (ตรวจนับสต๊อก)
// ✅ Step 4 — StockTransferSubPage (โอนย้าย)
// ✅ Step 5 — VarianceReportPage (รายงานผลต่าง)
// ════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventory/data/models/stock_balance_model.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import 'stock_movement_history_page.dart';
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ Phase 5
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';

// ════════════════════════════════════════════════════════════════
// ✅ STEP 1: StockAdjustmentPage — หน้าเมนูหลัก
// ════════════════════════════════════════════════════════════════
class StockAdjustmentPage extends StatelessWidget {
  const StockAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _StockAdjustmentColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: EscapePopScope(
        child: Column(
          children: [
            const _StockAdjustmentTopBar(
              title: 'ปรับปรุงสต๊อก',
              pageTag: 'Stock Adjustment',
              icon: Icons.inventory_2_outlined,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.contentMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: context.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colors.summaryBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _AdjustmentSummaryChip(
                                icon: Icons.tune,
                                label: 'ปรับเพิ่ม/ลด',
                                color: AppTheme.primary,
                              ),
                              _AdjustmentSummaryChip(
                                icon: Icons.fact_check_outlined,
                                label: 'ตรวจนับสต๊อก',
                                color: AppTheme.warning,
                              ),
                              _AdjustmentSummaryChip(
                                icon: Icons.swap_horiz,
                                label: 'โอนย้าย',
                                color: AppTheme.info,
                              ),
                              _AdjustmentSummaryChip(
                                icon: Icons.analytics_outlined,
                                label: 'รายงานผลต่าง',
                                color: AppTheme.success,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _AdjustmentSectionCard(
                          title: 'เลือกประเภทการปรับสต๊อก',
                          icon: Icons.inventory_2_outlined,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: context.isMobile ? 1 : 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: context.isMobile ? 3.2 : 2.8,
                              children: [
                                _MenuCard(
                                  icon: Icons.tune,
                                  label: 'ปรับสต๊อก (เพิ่ม/ลด)',
                                  color: AppTheme.primaryColor,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdjustStockSubPage(),
                                    ),
                                  ),
                                ),
                                _MenuCard(
                                  icon: Icons.fact_check_outlined,
                                  label: 'ตรวจนับสต๊อก',
                                  color: AppTheme.warningColor,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const StockTakeSubPage(),
                                    ),
                                  ),
                                ),
                                _MenuCard(
                                  icon: Icons.swap_horiz,
                                  label: 'โอนย้ายสต๊อก',
                                  color: AppTheme.tealColor,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StockTransferSubPage(),
                                    ),
                                  ),
                                ),
                                _MenuCard(
                                  icon: Icons.analytics_outlined,
                                  label: 'รายงานผลต่าง',
                                  color: AppTheme.purpleColor,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const VarianceReportPage(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ STEP 2: AdjustStockSubPage — ปรับเพิ่ม/ลดทีละรายการ
// ════════════════════════════════════════════════════════════════
class AdjustStockSubPage extends ConsumerStatefulWidget {
  const AdjustStockSubPage({super.key});

  @override
  ConsumerState<AdjustStockSubPage> createState() => _AdjustStockSubPageState();
}

class _AdjustStockSubPageState extends ConsumerState<AdjustStockSubPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarkController = TextEditingController();

  String _searchQuery = '';
  String _adjustType = 'INCREASE'; // INCREASE | DECREASE | SET
  StockBalanceModel? _selectedStock;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _referenceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // คำนวณสต๊อกใหม่ตาม adjustType
  double get _newBalance {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final current = _selectedStock?.balance ?? 0;
    switch (_adjustType) {
      case 'INCREASE':
        return current + qty;
      case 'DECREASE':
        return (current - qty).clamp(0, double.infinity);
      case 'SET':
        return qty;
      default:
        return current;
    }
  }

  double get _difference {
    final current = _selectedStock?.balance ?? 0;
    return _newBalance - current;
  }

  List<StockBalanceModel> _filter(List<StockBalanceModel> src) {
    if (_searchQuery.isEmpty) return src;
    final q = _searchQuery.toLowerCase();
    return src
        .where(
          (s) =>
              s.productName.toLowerCase().contains(q) ||
              s.productCode.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);
    final colors = _StockAdjustmentColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: EscapePopScope(
        child: Column(
          children: [
            _StockAdjustmentTopBar(
              title: 'ปรับสต๊อก (เพิ่ม/ลด)',
              pageTag: 'Adjust Stock',
              icon: Icons.tune,
              trailing: Tooltip(
                message: 'รีเฟรช',
                child: _StockAdjustmentTopBtn(
                  icon: Icons.refresh,
                  onTap: () =>
                      ref.read(stockBalanceProvider.notifier).refresh(),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.contentMaxWidth,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: context.pagePadding,
                        child: _AdjustmentSectionCard(
                          title: 'ค้นหาและเลือกสินค้า',
                          icon: Icons.tune,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 980;
                                final searchField = ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.text,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'ค้นหาชื่อ / รหัสสินค้า...',
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: colors.subtext,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 17,
                                          color: colors.subtext,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 15,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(
                                                    () => _searchQuery = '',
                                                  );
                                                },
                                              )
                                            : ScannerButton(
                                                onScanned: (value) {
                                                  _searchController.text =
                                                      value;
                                                  setState(
                                                    () => _searchQuery = value,
                                                  );
                                                },
                                              ),
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: colors.inputFill,
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _searchQuery = v),
                                    ),
                                  ),
                                );

                                final headerBlock = Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ค้นหาจากชื่อสินค้า รหัสสินค้า หรือสแกนบาร์โค้ด',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'เลือกรายการที่ต้องการปรับ แล้วกรอกจำนวนและเหตุผลก่อนบันทึก',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.subtext,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );

                                final actions = Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [searchField],
                                );

                                if (wide) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: headerBlock),
                                      const SizedBox(width: 16),
                                      actions,
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    headerBlock,
                                    const SizedBox(height: 12),
                                    actions,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: stockAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('เกิดข้อผิดพลาด: $e')),
                          data: (stocks) {
                            final filtered = _filter(stocks);
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1120;
                                final useCardView = context.isMobile;

                                final listPanel = Card(
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  color: colors.cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: colors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: colors.summaryBg,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          10,
                                          12,
                                          10,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _AdjSummaryChip(
                                              'ทั้งหมด',
                                              stocks.length,
                                              AppTheme.info,
                                            ),
                                            _AdjSummaryChip(
                                              'กรองแล้ว',
                                              filtered.length,
                                              AppTheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(height: 1, color: colors.border),
                                      Expanded(
                                        child: filtered.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.search_off_outlined,
                                                      size: 56,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .outline
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      _searchQuery.isEmpty
                                                          ? 'ไม่มีข้อมูลสต๊อก'
                                                          : 'ไม่พบสินค้า "$_searchQuery"',
                                                      style: TextStyle(
                                                        color: colors.subtext,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : useCardView
                                            ? GridView.builder(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount:
                                                          constraints.maxWidth <
                                                              420
                                                          ? 1
                                                          : 2,
                                                      mainAxisSpacing: 8,
                                                      crossAxisSpacing: 8,
                                                      childAspectRatio:
                                                          constraints.maxWidth <
                                                              420
                                                          ? 2.9
                                                          : 1.15,
                                                    ),
                                                itemCount: filtered.length,
                                                itemBuilder: (context, index) {
                                                  final stock = filtered[index];
                                                  final isSelected =
                                                      _selectedStock
                                                              ?.productId ==
                                                          stock.productId &&
                                                      _selectedStock
                                                              ?.warehouseId ==
                                                          stock.warehouseId;
                                                  return _AdjStockItemCard(
                                                    stock: stock,
                                                    isSelected: isSelected,
                                                    compact: true,
                                                    onTap: () => setState(() {
                                                      _selectedStock = stock;
                                                      _qtyController.clear();
                                                    }),
                                                  );
                                                },
                                              )
                                            : ListView.separated(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                itemCount: filtered.length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(height: 6),
                                                itemBuilder: (context, index) {
                                                  final stock = filtered[index];
                                                  final isSelected =
                                                      _selectedStock
                                                              ?.productId ==
                                                          stock.productId &&
                                                      _selectedStock
                                                              ?.warehouseId ==
                                                          stock.warehouseId;
                                                  return _AdjStockItemCard(
                                                    stock: stock,
                                                    isSelected: isSelected,
                                                    onTap: () => setState(() {
                                                      _selectedStock = stock;
                                                      _qtyController.clear();
                                                    }),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                );

                                final formPanel = Card(
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  color: colors.cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: colors.border),
                                  ),
                                  child: _selectedStock == null
                                      ? _buildEmptyState()
                                      : _buildAdjustForm(),
                                );

                                final contentPadding = EdgeInsets.fromLTRB(
                                  context.pagePadding.left,
                                  0,
                                  context.pagePadding.right,
                                  context.pagePadding.bottom,
                                );

                                if (isWide) {
                                  return Padding(
                                    padding: contentPadding,
                                    child: Row(
                                      children: [
                                        SizedBox(width: 340, child: listPanel),
                                        const SizedBox(width: 12),
                                        Expanded(child: formPanel),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: contentPadding,
                                  child: Column(
                                    children: [
                                      SizedBox(height: 320, child: listPanel),
                                      const SizedBox(height: 12),
                                      Expanded(child: formPanel),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────
  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final colors = _StockAdjustmentColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.emptyIconBg,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: const Icon(
                Icons.touch_app,
                size: 42,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'เลือกสินค้าที่ต้องการปรับสต๊อก',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'เลือกรายการจากแผงด้านบนหรือด้านซ้าย',
              style: TextStyle(fontSize: 12, color: colors.subtext),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ปรับสต๊อก ─────────────────────────────────────────
  Widget _buildAdjustForm() {
    final stock = _selectedStock!;
    final qty = double.tryParse(_qtyController.text) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Info Card ──────────────────────────
            _AdjustmentSectionCard(
              title: 'ข้อมูลสินค้า',
              icon: Icons.inventory_2_outlined,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 560;
                    final stockBadge = Column(
                      crossAxisAlignment: stacked
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'สต๊อกปัจจุบัน',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSub,
                          ),
                        ),
                        Text(
                          stock.balance.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          stock.baseUnit,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSub,
                          ),
                        ),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stock.productName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'รหัส: ${stock.productCode}  •  คลัง: ${stock.warehouseName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          stockBadge,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stock.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'รหัส: ${stock.productCode}  •  คลัง: ${stock.warehouseName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        stockBadge,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── ประเภทการปรับ ──────────────────────────────
            _AdjustmentSectionCard(
              title: 'ประเภทการปรับ',
              icon: Icons.category_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AdjustTypeButton(
                    label: 'เพิ่มสต๊อก',
                    icon: Icons.add_circle,
                    color: AppTheme.success,
                    isSelected: _adjustType == 'INCREASE',
                    onTap: () => setState(() => _adjustType = 'INCREASE'),
                  ),
                  _AdjustTypeButton(
                    label: 'ลดสต๊อก',
                    icon: Icons.remove_circle,
                    color: AppTheme.error,
                    isSelected: _adjustType == 'DECREASE',
                    onTap: () => setState(() => _adjustType = 'DECREASE'),
                  ),
                  _AdjustTypeButton(
                    label: 'กำหนดยอด',
                    icon: Icons.edit,
                    color: AppTheme.warning,
                    isSelected: _adjustType == 'SET',
                    onTap: () => setState(() => _adjustType = 'SET'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── จำนวน ──────────────────────────────────────
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _adjustInputDecoration(
                context,
                labelText: _adjustType == 'SET'
                    ? 'กำหนดสต๊อกใหม่ *'
                    : 'จำนวนที่ต้องการ${_adjustType == 'INCREASE' ? 'เพิ่ม' : 'ลด'} *',
                suffixText: stock.baseUnit,
                prefixIcon: Icon(
                  _adjustType == 'INCREASE'
                      ? Icons.add
                      : _adjustType == 'DECREASE'
                      ? Icons.remove
                      : Icons.edit,
                  color: _adjustType == 'INCREASE'
                      ? AppTheme.success
                      : _adjustType == 'DECREASE'
                      ? AppTheme.error
                      : AppTheme.warning,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกจำนวน';
                }
                final q = double.tryParse(value);
                if (q == null || q <= 0) return 'จำนวนต้องมากกว่า 0';
                if (_adjustType == 'DECREASE' && q > stock.balance) {
                  return 'จำนวนเกินสต๊อกปัจจุบัน (${stock.balance.toStringAsFixed(0)})';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── ผลลัพธ์ Preview ────────────────────────────
            if (qty > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _difference >= 0
                      ? AppTheme.successColor.withValues(alpha: 0.06)
                      : AppTheme.errorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _difference >= 0 ? AppTheme.success : AppTheme.error,
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PreviewItem(
                      label: 'ปัจจุบัน',
                      value: stock.balance.toStringAsFixed(0),
                      unit: stock.baseUnit,
                      color: AppTheme.textSub,
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: _difference >= 0
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                    _PreviewItem(
                      label: 'หลังปรับ',
                      value: _newBalance.toStringAsFixed(0),
                      unit: stock.baseUnit,
                      color: _difference >= 0
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _difference >= 0
                            ? AppTheme.success
                            : AppTheme.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_difference >= 0 ? '+' : ''}${_difference.toStringAsFixed(0)} ${stock.baseUnit}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── เลขที่อ้างอิง ──────────────────────────────
            TextFormField(
              controller: _referenceController,
              decoration: _adjustInputDecoration(
                context,
                labelText: 'เลขที่เอกสารอ้างอิง',
                hintText: 'เช่น ADJ-2024-001',
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),

            // ── หมายเหตุ ───────────────────────────────────
            TextFormField(
              controller: _remarkController,
              decoration: _adjustInputDecoration(
                context,
                labelText: 'เหตุผล / หมายเหตุ *',
                hintText: 'เช่น สินค้าชำรุด, นับสต๊อกรอบปี, แก้ไขยอดผิด',
                prefixIcon: const Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกเหตุผล';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // ── ปุ่ม ───────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 560;
                final clearButton = OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _selectedStock = null;
                            _qtyController.clear();
                            _referenceController.clear();
                            _remarkController.clear();
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('ล้างค่า'),
                );
                final saveButton = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading ? 'กำลังบันทึก...' : 'บันทึกการปรับสต๊อก',
                  ),
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      saveButton,
                      const SizedBox(height: 10),
                      clearButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: clearButton),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: saveButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStock == null) return;

    setState(() => _isLoading = true);

    final remark = _remarkController.text.trim();
    final reference = _referenceController.text.trim();

    final success = await ref
        .read(stockBalanceProvider.notifier)
        .adjustStock(
          productId: _selectedStock!.productId,
          warehouseId: _selectedStock!.warehouseId,
          newBalance: _newBalance,
          referenceNo: reference.isEmpty ? null : reference,
          remark: remark,
        );

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'ปรับสต๊อก ${_selectedStock!.productName} สำเร็จ'
                : 'เกิดข้อผิดพลาด กรุณาลองใหม่',
          ),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (success) {
        setState(() {
          _selectedStock = null;
          _qtyController.clear();
          _referenceController.clear();
          _remarkController.clear();
        });
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// _AdjSummaryChip — summary chip สำหรับ AdjustStockSubPage
// ════════════════════════════════════════════════════════════════
class _AdjSummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AdjSummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    final colors = _StockAdjustmentColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockAdjustmentTopBar extends StatelessWidget {
  final String title;
  final String pageTag;
  final IconData icon;
  final Widget? trailing;

  const _StockAdjustmentTopBar({
    required this.title,
    required this.pageTag,
    required this.icon,
    this.trailing,
  });

  static const _kBreak = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final colors = _StockAdjustmentColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.topBarBg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide ? _buildWide(context) : _buildNarrow(context),
    );
  }

  Widget _buildWide(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          const _StockAdjustmentBackBtn(),
          const SizedBox(width: 10),
        ],
        _StockAdjustmentPageIcon(icon: icon),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            pageTag,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          const _StockAdjustmentBackBtn(),
          const SizedBox(width: 8),
        ],
        _StockAdjustmentPageIcon(icon: icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _StockAdjustmentBackBtn extends StatelessWidget {
  const _StockAdjustmentBackBtn();

  @override
  Widget build(BuildContext context) => context.isMobile
      ? buildMobileHomeCompactButton(context)
      : _StockAdjustmentTopBtn(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).pop(),
        );
}

class _StockAdjustmentTopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StockAdjustmentTopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _StockAdjustmentColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.navButtonBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.navButtonBorder),
        ),
        child: Icon(icon, size: 17, color: Colors.white70),
      ),
    );
  }
}

class _StockAdjustmentPageIcon extends StatelessWidget {
  final IconData icon;

  const _StockAdjustmentPageIcon({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
    ),
    child: Icon(icon, color: AppTheme.primaryLight, size: 18),
  );
}

// ════════════════════════════════════════════════════════════════
// _AdjStockItemCard — card item สำหรับ product selection list
// ════════════════════════════════════════════════════════════════
class _AdjStockItemCard extends StatelessWidget {
  final StockBalanceModel stock;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _AdjStockItemCard({
    required this.stock,
    required this.isSelected,
    this.compact = false,
    required this.onTap,
  });

  static final _avatarColors = [
    AppTheme.infoColor,
    AppTheme.successColor,
    AppTheme.warningColor,
    AppTheme.purpleColor,
    AppTheme.tealColor,
    AppTheme.primaryColor,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = AppTheme.borderColorOf(context);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subText = AppTheme.subtextColorOf(context);
    final initial = stock.productName.isNotEmpty
        ? stock.productName.substring(0, 1).toUpperCase()
        : '?';
    final avatarColor =
        _avatarColors[stock.productName.codeUnitAt(0) % _avatarColors.length];

    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isSelected
                        ? AppTheme.primaryColor
                        : avatarColor,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stock.balance.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: stock.balance > 0
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                      Text(
                        stock.baseUnit,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSub,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                stock.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primaryColor : textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stock.productCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subText),
              ),
              const SizedBox(height: 2),
              Text(
                stock.warehouseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subText),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? AppTheme.primaryColor : avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.productName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryColor : textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stock.productCode} • ${stock.warehouseName}',
                    style: TextStyle(fontSize: 11, color: subText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stock.balance.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stock.balance > 0
                        ? AppTheme.success
                        : AppTheme.error,
                  ),
                ),
                Text(
                  stock.baseUnit,
                  style: TextStyle(fontSize: 10, color: subText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: ปุ่มเลือกประเภทการปรับ ────────────────────────────
class _AdjustTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdjustTypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0)),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF444444) : AppTheme.border),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textSub, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSub,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _AdjustmentSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StockAdjustmentColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          if (!colors.isDark)
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          child,
        ],
      ),
    );
  }
}

class _AdjustmentSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AdjustmentSummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StockAdjustmentColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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

InputDecoration _adjustInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? suffixText,
  Widget? prefixIcon,
}) {
  final colors = _StockAdjustmentColors.of(context);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: colors.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class _StockAdjustmentColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color headerBg;
  final Color emptyIconBg;
  final Color navButtonBg;
  final Color navButtonBorder;

  const _StockAdjustmentColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.headerBg,
    required this.emptyIconBg,
    required this.navButtonBg,
    required this.navButtonBorder,
  });

  factory _StockAdjustmentColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StockAdjustmentColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? AppTheme.darkCard : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      headerBg: isDark ? AppTheme.darkElement : AppTheme.headerBg,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
    );
  }
}

// ── Widget: Preview Item ───────────────────────────────────────
class _PreviewItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _PreviewItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final subText = AppTheme.subtextColorOf(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subText)),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(unit, style: TextStyle(fontSize: 11, color: subText)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ STEP 3: StockTakeSubPage — ตรวจนับสต๊อกทั้งคลัง
// ════════════════════════════════════════════════════════════════

// Model เก็บข้อมูลการนับแต่ละรายการ
class _StockTakeItem {
  final StockBalanceModel stock;
  final TextEditingController countController;
  bool _disposed = false;

  _StockTakeItem({required this.stock})
    : countController = TextEditingController(
        text: stock.balance.toStringAsFixed(0),
      );

  double get countedQty =>
      double.tryParse(countController.text) ?? stock.balance;
  double get variance => countedQty - stock.balance;
  bool get hasVariance => variance != 0;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    countController.dispose();
  }
}

class StockTakeSubPage extends ConsumerStatefulWidget {
  const StockTakeSubPage({super.key});

  @override
  ConsumerState<StockTakeSubPage> createState() => _StockTakeSubPageState();
}

class _StockTakeSubPageState extends ConsumerState<StockTakeSubPage> {
  String _selectedWarehouse = 'WH001';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _remarkController = TextEditingController();

  // รายการที่นับ (สร้างเมื่อโหลดข้อมูลแล้ว)
  List<_StockTakeItem> _takeItems = [];
  bool _isInitialized = false;
  bool _isSubmitting = false;

  // filter: แสดงเฉพาะที่มีผลต่าง
  bool _showVarianceOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    _remarkController.dispose();
    for (final item in _takeItems) {
      item.dispose();
    }
    super.dispose();
  }

  // โหลดรายการสินค้าตามคลังที่เลือก
  // เรียกครั้งแรกเท่านั้น (guard ด้วย _isInitialized)
  // ไม่ dispose items เก่าที่นี่ — ให้ _clearItems() จัดการแทน
  void _initItems(List<StockBalanceModel> stocks) {
    if (_isInitialized) return;
    _takeItems = stocks
        .where((s) => s.warehouseId == _selectedWarehouse)
        .map((s) => _StockTakeItem(stock: s))
        .toList();
    _isInitialized = true;
  }

  // Dispose items เก่าแล้วสร้างใหม่ (ใช้เมื่อเปลี่ยนคลัง)
  void _clearItems() {
    for (final item in _takeItems) {
      item.dispose();
    }
    _takeItems = [];
    _isInitialized = false;
  }

  // เปลี่ยนคลัง → reset
  void _changeWarehouse(String wh, List<StockBalanceModel> stocks) {
    _clearItems();
    setState(() {
      _selectedWarehouse = wh;
      _showVarianceOnly = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _initItems(stocks);
  }

  // สรุปผล
  int get _totalItems => _takeItems.length;
  int get _matchCount => _takeItems.where((i) => !i.hasVariance).length;
  int get _increaseCount => _takeItems.where((i) => i.variance > 0).length;
  int get _decreaseCount => _takeItems.where((i) => i.variance < 0).length;

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (canPop) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 15,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.warningContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppTheme.warningColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ตรวจนับสต๊อก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Filter toggle
                  Tooltip(
                    message: _showVarianceOnly
                        ? 'แสดงทั้งหมด'
                        : 'เฉพาะมีผลต่าง',
                    child: InkWell(
                      onTap: () => setState(
                        () => _showVarianceOnly = !_showVarianceOnly,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _showVarianceOnly
                              ? AppTheme.warningColor.withValues(alpha: 0.1)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showVarianceOnly
                                ? AppTheme.warningColor
                                : AppTheme.border,
                          ),
                        ),
                        child: Icon(
                          _showVarianceOnly
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 17,
                          color: _showVarianceOnly
                              ? AppTheme.warningColor
                              : const Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Refresh
                  Tooltip(
                    message: 'โหลดใหม่',
                    child: InkWell(
                      onTap: () {
                        _clearItems();
                        ref.read(stockBalanceProvider.notifier).refresh();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          size: 17,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: stockAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                data: (stocks) {
                  _initItems(stocks);

                  final filtered = _takeItems.where((item) {
                    if (_showVarianceOnly && !item.hasVariance) return false;
                    if (_searchQuery.isEmpty) return true;
                    return item.stock.productName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        item.stock.productCode.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                  }).toList();

                  return Column(
                    children: [
                      // ── Toolbar ────────────────────────────
                      _buildToolbar(stocks),

                      // ── Summary Bar ────────────────────────
                      if (_isInitialized) _buildSummaryBar(),

                      // ── รายการสินค้า ───────────────────────
                      Expanded(
                        child: _takeItems.isEmpty
                            ? _buildEmptyState()
                            : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'ไม่พบสินค้าที่ตรงกัน',
                                  style: TextStyle(color: Color(0xFF8A8A8A)),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _buildItemRow(filtered[index]),
                              ),
                      ),

                      // ── Bottom Bar ─────────────────────────
                      if (_takeItems.isNotEmpty) _buildBottomBar(),
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

  // ── Toolbar: เลือกคลัง + ค้นหา ───────────────────────────────
  Widget _buildToolbar(List<StockBalanceModel> stocks) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          final warehousePicker = Builder(
            builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              final bgColor = cs.surface;
              final txtColor = cs.onSurface;
              final bdColor = cs.outline.withValues(alpha: 0.4);
              return Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bdColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWarehouse,
                    dropdownColor: bgColor,
                    style: TextStyle(fontSize: 13, color: txtColor),
                    iconEnabledColor: txtColor.withValues(alpha: 0.6),
                    items: [
                      DropdownMenuItem(
                        value: 'WH001',
                        child: Text(
                          'คลังหลัก',
                          style: TextStyle(color: txtColor),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _changeWarehouse(v, stocks);
                    },
                  ),
                ),
              );
            },
          );

          final searchField = SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ / รหัสสินค้า...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A8A8A),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 17,
                  color: Color(0xFF8A8A8A),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 15),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : ScannerButton(
                        useSheet: true,
                        onScanned: (value) {
                          _searchController.text = value;
                          setState(() => _searchQuery = value);
                        },
                      ),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'คลัง:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    warehousePicker,
                  ],
                ),
                const SizedBox(height: 10),
                searchField,
              ],
            );
          }

          return Row(
            children: [
              const Text(
                'คลัง:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 8),
              warehousePicker,
              const SizedBox(width: 12),
              Expanded(child: searchField),
            ],
          );
        },
      ),
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────
  Widget _buildSummaryBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'ทั้งหมด $_totalItems รายการ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningColor,
              ),
            ),
          ),
          _SummaryChip(
            label: 'ตรงกัน',
            count: _matchCount,
            color: AppTheme.successColor,
          ),
          _SummaryChip(
            label: 'เกิน',
            count: _increaseCount,
            color: AppTheme.infoColor,
          ),
          _SummaryChip(
            label: 'ขาด',
            count: _decreaseCount,
            color: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }

  // ── แถวสินค้าแต่ละรายการ ──────────────────────────────────────
  Widget _buildItemRow(_StockTakeItem item) {
    final variance = item.variance;
    Color cardColor = Colors.white;
    Color borderColor = AppTheme.border;
    if (variance > 0) {
      cardColor = AppTheme.infoContainer;
      borderColor = AppTheme.infoColor.withValues(alpha: 0.3);
    } else if (variance < 0) {
      cardColor = AppTheme.errorContainer;
      borderColor = AppTheme.errorColor.withValues(alpha: 0.3);
    }

    final varColor = variance > 0
        ? AppTheme.infoColor
        : variance < 0
        ? AppTheme.errorColor
        : AppTheme.successColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ชื่อสินค้า
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.stock.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.stock.productCode,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ),
            ),

            // สต๊อกในระบบ
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'ในระบบ',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8A8A8A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.stock.balance.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    item.stock.baseUnit,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ),
            ),

            // ช่องกรอกจำนวนที่นับจริง
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  const Text(
                    'นับจริง',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8A8A8A)),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 36,
                    child: Builder(
                      builder: (ctx) {
                        final cs = Theme.of(ctx).colorScheme;
                        final bdColor = cs.outline.withValues(alpha: 0.4);
                        return TextField(
                          controller: item.countController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: item.stock.baseUnit,
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: bdColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: bdColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: AppTheme.primary,
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                          ),
                          onChanged: (_) => setState(() {}),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ผลต่าง
            SizedBox(
              width: 72,
              child: Column(
                children: [
                  const Text(
                    'ผลต่าง',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8A8A8A)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        variance > 0
                            ? Icons.arrow_upward
                            : variance < 0
                            ? Icons.arrow_downward
                            : Icons.check,
                        size: 13,
                        color: varColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        variance == 0
                            ? 'ตรง'
                            : '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: varColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warningContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ไม่มีสินค้าในคลังนี้',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ลองเลือกคลังอื่น หรือเพิ่มสินค้าก่อน',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar: Remark + ยืนยัน ──────────────────────────────
  Widget _buildBottomBar() {
    final hasAnyVariance = _takeItems.any((i) => i.hasVariance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Remark
          Expanded(
            child: TextField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ / รอบการนับ',
                hintText: 'เช่น นับสต๊อกประจำเดือน มี.ค. 2567',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ปุ่มยืนยัน
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAnyVariance
                  ? AppTheme.warningColor
                  : AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: _isSubmitting ? null : _handleConfirm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(hasAnyVariance ? Icons.tune : Icons.check_circle),
            label: Text(
              _isSubmitting
                  ? 'กำลังบันทึก...'
                  : hasAnyVariance
                  ? 'ปรับสต๊อกตามที่นับ ($_increaseCount+$_decreaseCount รายการ)'
                  : 'สต๊อกตรงทั้งหมด ✓',
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _handleConfirm() async {
    // รายการที่มีผลต่างเท่านั้น
    final itemsWithVariance = _takeItems.where((i) => i.hasVariance).toList();

    if (itemsWithVariance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ สต๊อกตรงทั้งหมด ไม่มีรายการที่ต้องปรับ'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Dialog ยืนยัน
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ยืนยันการปรับสต๊อก',
          icon: Icons.tune_rounded,
          iconColor: AppTheme.warningColor,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('มีสินค้าที่ต้องปรับ ${itemsWithVariance.length} รายการ'),
            const SizedBox(height: 8),
            Text(
              'เพิ่ม: $_increaseCount รายการ',
              style: const TextStyle(color: Colors.blue),
            ),
            Text(
              'ลด: $_decreaseCount รายการ',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('ต้องการปรับสต๊อกทั้งหมดใช่หรือไม่?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    final remark = _remarkController.text.trim().isEmpty
        ? 'Stock Take ${DateTime.now().toString().substring(0, 10)}'
        : _remarkController.text.trim();

    int successCount = 0;
    final refNo =
        'ST${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    for (final item in itemsWithVariance) {
      final ok = await ref
          .read(stockBalanceProvider.notifier)
          .adjustStock(
            productId: item.stock.productId,
            warehouseId: item.stock.warehouseId,
            newBalance: item.countedQty,
            referenceNo: refNo,
            remark: remark,
          );
      if (ok) successCount++;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      final allOk = successCount == itemsWithVariance.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allOk
                ? '✅ ปรับสต๊อกสำเร็จ $successCount รายการ (อ้างอิง: $refNo)'
                : '⚠️ ปรับสำเร็จ $successCount/${itemsWithVariance.length} รายการ',
          ),
          backgroundColor: allOk
              ? AppTheme.successColor
              : AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      if (allOk) {
        _clearItems();
        Navigator.pop(context);
      }
    }
  }
}

// ── Widget: Summary Chip ───────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ STEP 4: StockTransferSubPage — โอนย้ายระหว่างคลัง
// ════════════════════════════════════════════════════════════════
class StockTransferSubPage extends ConsumerStatefulWidget {
  const StockTransferSubPage({super.key});

  @override
  ConsumerState<StockTransferSubPage> createState() =>
      _StockTransferSubPageState();
}

class _StockTransferSubPageState extends ConsumerState<StockTransferSubPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _remarkController = TextEditingController();

  // คลังที่มีในระบบ
  static const List<Map<String, String>> _warehouses = [
    {'id': 'WH001', 'name': 'คลังหลัก'},
  ];

  String _fromWarehouseId = 'WH001';
  String _toWarehouseId = 'WH001';
  String _searchQuery = '';
  StockBalanceModel? _selectedStock;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  String _warehouseName(String id) => _warehouses.firstWhere(
    (w) => w['id'] == id,
    orElse: () => {'name': id},
  )['name']!;

  double get _transferQty => double.tryParse(_qtyController.text) ?? 0;

  double get _remainingAfter => (_selectedStock?.balance ?? 0) - _transferQty;

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────���─────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (canPop) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 15,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.tealColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: AppTheme.tealColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'โอนย้ายสต๊อก',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  // Search field
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อ / รหัสสินค้า...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8A8A8A),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 17,
                            color: Color(0xFF8A8A8A),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 15),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : ScannerButton(
                                  useSheet: true,
                                  onScanned: (value) {
                                    _searchController.text = value;
                                    setState(() => _searchQuery = value);
                                  },
                                ),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.tealColor,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh
                  Tooltip(
                    message: 'รีเฟรช',
                    child: InkWell(
                      onTap: () =>
                          ref.read(stockBalanceProvider.notifier).refresh(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          size: 17,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: stockAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                data: (stocks) {
                  final fromStocks = stocks
                      .where(
                        (s) =>
                            s.warehouseId == _fromWarehouseId && s.balance > 0,
                      )
                      .toList();

                  final filtered = _searchQuery.isEmpty
                      ? fromStocks
                      : fromStocks
                            .where(
                              (s) =>
                                  s.productName.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ) ||
                                  s.productCode.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ),
                            )
                            .toList();

                  return Row(
                    children: [
                      // ── ซ้าย: เลือกสินค้า ───────────────────────
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            // Warehouse selector (header ขาว)
                            _buildWarehouseSelector(stocks),
                            const Divider(height: 1),

                            // รายการสินค้า
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _searchQuery.isEmpty
                                                ? Icons.inventory_2_outlined
                                                : Icons.search_off_outlined,
                                            size: 56,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _searchQuery.isEmpty
                                                ? 'ไม่มีสินค้าในคลังนี้'
                                                : 'ไม่พบสินค้า "$_searchQuery"',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final stock = filtered[index];
                                        final isSelected =
                                            _selectedStock?.productId ==
                                            stock.productId;
                                        return _TransferItemCard(
                                          stock: stock,
                                          isSelected: isSelected,
                                          onTap: () => setState(() {
                                            _selectedStock = stock;
                                            _qtyController.clear();
                                          }),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const VerticalDivider(width: 1),

                      // ── ขวา: Form โอนย้าย ───────────────────────
                      Expanded(
                        child: _selectedStock == null
                            ? _buildEmptyState()
                            : _buildTransferForm(),
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

  // ── Warehouse Selector ────────────────────────────────────────
  Widget _buildWarehouseSelector(List<StockBalanceModel> stocks) {
    return Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final bgColor = cs.surface;
        final borderColor = cs.outline.withValues(alpha: 0.35);

        Widget warehouseDropdown({
          required String label,
          required String value,
          required List<Map<String, String>> items,
          required ValueChanged<String?> onChanged,
        }) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: bgColor,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      items: items
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'],
                              child: Text(
                                w['name']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: cs.surface,
          child: Row(
            children: [
              warehouseDropdown(
                label: 'ต้นทาง',
                value: _fromWarehouseId,
                items: _warehouses,
                onChanged: (v) {
                  if (v != null && v != _fromWarehouseId) {
                    setState(() {
                      _fromWarehouseId = v;
                      if (_fromWarehouseId == _toWarehouseId) {
                        _toWarehouseId = _warehouses.firstWhere(
                          (w) => w['id'] != _fromWarehouseId,
                        )['id']!;
                      }
                      _selectedStock = null;
                      _qtyController.clear();
                    });
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 6, right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      final tmp = _fromWarehouseId;
                      _fromWarehouseId = _toWarehouseId;
                      _toWarehouseId = tmp;
                      _selectedStock = null;
                      _qtyController.clear();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.swap_horiz,
                      size: 20,
                      color: AppTheme.tealColor,
                    ),
                  ),
                ),
              ),
              warehouseDropdown(
                label: 'ปลายทาง',
                value: _toWarehouseId,
                items: _warehouses
                    .where((w) => w['id'] != _fromWarehouseId)
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _toWarehouseId = v);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Empty State ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.tealColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.swap_horiz,
              size: 48,
              color: AppTheme.tealColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'เลือกสินค้าที่ต้องการโอนย้าย',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'จาก ${_warehouseName(_fromWarehouseId)} → ${_warehouseName(_toWarehouseId)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.tealColor),
          ),
        ],
      ),
    );
  }

  // ── Form โอนย้าย ─────────────────────────────────────────────
  Widget _buildTransferForm() {
    final stock = _selectedStock!;
    final qty = _transferQty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Info Card ──────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.tealColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.tealColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.tealColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: AppTheme.tealColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'รหัส: ${stock.productCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A8A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'สต๊อกต้นทาง',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                      Text(
                        stock.balance.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.tealColor,
                        ),
                      ),
                      Text(
                        stock.baseUnit,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Route: ต้นทาง → ปลายทาง ───────────────────
            Row(
              children: [
                Expanded(
                  child: _RouteCard(
                    label: 'ต้นทาง',
                    warehouseName: _warehouseName(_fromWarehouseId),
                    icon: Icons.output,
                    color: Colors.red,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppTheme.tealColor,
                    size: 32,
                  ),
                ),
                Expanded(
                  child: _RouteCard(
                    label: 'ปลายทาง',
                    warehouseName: _warehouseName(_toWarehouseId),
                    icon: Icons.input,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── จำนวนที่โอน ────────────────────────────────
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'จำนวนที่ต้องการโอน *',
                border: const OutlineInputBorder(),
                suffixText: stock.baseUnit,
                prefixIcon: const Icon(
                  Icons.swap_horiz,
                  color: AppTheme.tealColor,
                ),
                helperText:
                    'โอนได้สูงสุด ${stock.balance.toStringAsFixed(0)} ${stock.baseUnit}',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกจำนวน';
                }
                final q = double.tryParse(value);
                if (q == null || q <= 0) return 'จำนวนต้องมากกว่า 0';
                if (q > stock.balance) {
                  return 'เกินสต๊อกคงเหลือ (${stock.balance.toStringAsFixed(0)} ${stock.baseUnit})';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── Preview หลังโอน ────────────────────────────
            if (qty > 0 && qty <= stock.balance) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.tealColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.tealColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ผลลัพธ์หลังโอน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.tealColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PreviewTransferItem(
                          label:
                              '${_warehouseName(_fromWarehouseId)}\n(ต้นทาง)',
                          before: stock.balance,
                          after: _remainingAfter,
                          unit: stock.baseUnit,
                          color: Colors.red,
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          color: AppTheme.tealColor,
                        ),
                        _PreviewTransferItem(
                          label: '${_warehouseName(_toWarehouseId)}\n(ปลายทาง)',
                          before: null,
                          after: qty,
                          unit: stock.baseUnit,
                          color: Colors.green,
                          showPlus: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── หมายเหตุ ───────────────────────────────────
            TextFormField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                border: OutlineInputBorder(),
                hintText: 'เช่น โอนสต๊อกไปคลังหลัก',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // ── ปุ่ม ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedStock = null;
                              _qtyController.clear();
                              _remarkController.clear();
                            });
                          },
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้างค่า'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _handleSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.swap_horiz),
                    label: Text(
                      _isLoading ? 'กำลังโอน...' : 'ยืนยันการโอนย้าย',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStock == null) return;

    // Dialog ยืนยัน
    final qty = _transferQty;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ยืนยันการโอนย้าย',
          icon: Icons.swap_horiz,
          iconColor: AppTheme.tealColor,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สินค้า: ${_selectedStock!.productName}'),
            const SizedBox(height: 4),
            Text(
              'จำนวน: ${qty.toStringAsFixed(0)} ${_selectedStock!.baseUnit}',
            ),
            const SizedBox(height: 4),
            Text('จาก: ${_warehouseName(_fromWarehouseId)}'),
            Text('ไปยัง: ${_warehouseName(_toWarehouseId)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final remark = _remarkController.text.trim();

    final success = await ref
        .read(stockBalanceProvider.notifier)
        .transferStock(
          productId: _selectedStock!.productId,
          fromWarehouseId: _fromWarehouseId,
          toWarehouseId: _toWarehouseId,
          quantity: qty,
          remark: remark.isEmpty ? null : remark,
        );

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ โอนย้าย ${_selectedStock!.productName} ${qty.toStringAsFixed(0)} ${_selectedStock!.baseUnit} สำเร็จ'
                : '❌ เกิดข้อผิดพลาด กรุณาลองใหม่',
          ),
          backgroundColor: success
              ? AppTheme.successColor
              : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (success) {
        setState(() {
          _selectedStock = null;
          _qtyController.clear();
          _remarkController.clear();
        });
      }
    }
  }
}

// ── Widget: Transfer Item Card ─────────────────────────────────
class _TransferItemCard extends StatelessWidget {
  final StockBalanceModel stock;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransferItemCard({
    required this.stock,
    required this.isSelected,
    required this.onTap,
  });

  static final _avatarColors = [
    AppTheme.tealColor,
    AppTheme.successColor,
    AppTheme.infoColor,
    AppTheme.warningColor,
    AppTheme.purpleColor,
    AppTheme.primaryColor,
  ];

  @override
  Widget build(BuildContext context) {
    final initial = stock.productName.isNotEmpty
        ? stock.productName.substring(0, 1).toUpperCase()
        : '?';
    final avatarColor =
        _avatarColors[stock.productName.codeUnitAt(0) % _avatarColors.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.tealColor.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.tealColor : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? AppTheme.tealColor : avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.productName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.tealColor
                          : const Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stock.productCode} • ${stock.warehouseName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stock.balance.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stock.balance > 0
                        ? AppTheme.success
                        : AppTheme.error,
                  ),
                ),
                Text(
                  stock.baseUnit,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSub),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: Route Card ─────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final String label;
  final String warehouseName;
  final IconData icon;
  final Color color;

  const _RouteCard({
    required this.label,
    required this.warehouseName,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            warehouseName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Widget: Preview Transfer Item ──────────────────────────────
class _PreviewTransferItem extends StatelessWidget {
  final String label;
  final double? before;
  final double after;
  final String unit;
  final Color color;
  final bool showPlus;

  const _PreviewTransferItem({
    required this.label,
    required this.before,
    required this.after,
    required this.unit,
    required this.color,
    this.showPlus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (before != null) ...[
          Text(
            before!.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
          const Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
        ],
        Text(
          '${showPlus ? '+' : ''}${after.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(unit, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Widget: _MenuCard — Dashboard quick-menu style (ใช้ใน Step 1)
// ════════════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ STEP 5: VarianceReportPage — รายงานผลต่างจาก Stock Take
// ════════════════════════════════════════════════════════════════

// Model สำหรับ 1 รายการใน Variance Report
class _VarianceItem {
  final String productId;
  final String productCode;
  final String productName;
  final String warehouseId;
  final String warehouseName;
  final String baseUnit;
  final double before; // ยอดก่อนปรับ (quantity ของ movement)
  final double after; // ยอดหลังปรับ  (คำนวณจาก balance ปัจจุบัน)
  final double variance; // ผลต่าง
  final DateTime date;
  final String? referenceNo;
  final String? remark;

  _VarianceItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.warehouseId,
    required this.warehouseName,
    required this.baseUnit,
    required this.before,
    required this.after,
    required this.variance,
    required this.date,
    this.referenceNo,
    this.remark,
  });
}

class VarianceReportPage extends ConsumerStatefulWidget {
  const VarianceReportPage({super.key});

  @override
  ConsumerState<VarianceReportPage> createState() => _VarianceReportPageState();
}

class _VarianceReportPageState extends ConsumerState<VarianceReportPage> {
  // Filter
  String _filterType = 'ALL'; // ALL | INCREASE | DECREASE
  String _filterWarehouse = 'ALL';
  DateTimeRange? _dateRange;

  static const List<Map<String, String>> _warehouses = [
    {'id': 'ALL', 'name': 'ทุกคลัง'},
    {'id': 'WH001', 'name': 'คลังหลัก'},
  ];

  String _warehouseName(String id) => _warehouses.firstWhere(
    (w) => w['id'] == id,
    orElse: () => {'name': id},
  )['name']!;

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementHistoryProvider);
    final stockAsync = ref.watch(stockBalanceProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (canPop) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 15,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.purpleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.purpleColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'รายงานผลต่าง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(
                    message: 'รีเฟรช',
                    child: InkWell(
                      onTap: () {
                        ref.invalidate(movementHistoryProvider);
                        ref.read(stockBalanceProvider.notifier).refresh();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          size: 17,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: movementsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                data: (movements) => stockAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                  data: (stocks) {
                    // สร้าง lookup map: productId → stock info
                    final stockMap = <String, StockBalanceModel>{};
                    for (final s in stocks) {
                      stockMap['${s.productId}_${s.warehouseId}'] = s;
                    }

                    // กรองเฉพาะ ADJUST movements
                    final adjustMovements = movements
                        .where((m) => m.movementType == 'ADJUST')
                        .toList();

                    // สร้าง VarianceItems
                    final items = adjustMovements.map((m) {
                      final key = '${m.productId}_${m.warehouseId}';
                      final stock = stockMap[key];
                      return _VarianceItem(
                        productId: m.productId,
                        productCode: stock?.productCode ?? m.productId,
                        productName: stock?.productName ?? 'ไม่ทราบชื่อสินค้า',
                        warehouseId: m.warehouseId,
                        warehouseName:
                            stock?.warehouseName ??
                            _warehouseName(m.warehouseId),
                        baseUnit: stock?.baseUnit ?? '',
                        before: m.quantity < 0
                            ? (stock?.balance ?? 0) - m.quantity
                            : (stock?.balance ?? 0) - m.quantity,
                        after: stock?.balance ?? 0,
                        variance: m.quantity,
                        date: m.movementDate,
                        referenceNo: m.referenceNo,
                        remark: m.remark,
                      );
                    }).toList();

                    // Apply filters
                    final filtered = items.where((item) {
                      // warehouse filter
                      if (_filterWarehouse != 'ALL' &&
                          item.warehouseId != _filterWarehouse) {
                        return false;
                      }

                      // type filter
                      if (_filterType == 'INCREASE' && item.variance <= 0) {
                        return false;
                      }

                      if (_filterType == 'DECREASE' && item.variance >= 0) {
                        return false;
                      }

                      // date filter
                      if (_dateRange != null) {
                        final d = item.date;

                        if (d.isBefore(_dateRange!.start) ||
                            d.isAfter(
                              _dateRange!.end.add(const Duration(days: 1)),
                            )) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    // Sort by date desc
                    filtered.sort((a, b) => b.date.compareTo(a.date));

                    return Column(
                      children: [
                        // ── Filter Bar ────────────────────────────
                        _buildFilterBar(),

                        // ── Summary Cards ─────────────────────────
                        _buildSummaryCards(filtered),

                        // ── Table ─────────────────────────────────
                        Expanded(
                          child: filtered.isEmpty
                              ? _buildEmptyState(adjustMovements.isEmpty)
                              : _buildTable(filtered),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Bar ────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'ประเภท:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              _FilterChip(
                label: 'ทั้งหมด',
                selected: _filterType == 'ALL',
                color: AppTheme.purpleColor,
                onTap: () => setState(() => _filterType = 'ALL'),
              ),
              _FilterChip(
                label: '↑ เกิน',
                selected: _filterType == 'INCREASE',
                color: AppTheme.infoColor,
                onTap: () => setState(() => _filterType = 'INCREASE'),
              ),
              _FilterChip(
                label: '↓ ขาด',
                selected: _filterType == 'DECREASE',
                color: AppTheme.errorColor,
                onTap: () => setState(() => _filterType = 'DECREASE'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'คลัง:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Builder(
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterWarehouse,
                        isDense: true,
                        dropdownColor: cs.surface,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                        iconEnabledColor: cs.onSurface.withValues(alpha: 0.6),
                        items: _warehouses
                            .map(
                              (w) => DropdownMenuItem(
                                value: w['id'],
                                child: Text(
                                  w['name']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _filterWarehouse = v ?? 'ALL'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _dateRange == null
                      ? 'ทุกวัน'
                      : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  side: BorderSide(
                    color: AppTheme.purpleColor.withValues(alpha: 0.5),
                  ),
                  foregroundColor: AppTheme.purpleColor,
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _dateRange = null),
                  tooltip: 'ล้างวันที่',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────
  Widget _buildSummaryCards(List<_VarianceItem> items) {
    final increaseItems = items.where((i) => i.variance > 0).toList();
    final decreaseItems = items.where((i) => i.variance < 0).toList();
    final totalIncrease = increaseItems.fold(0.0, (sum, i) => sum + i.variance);
    final totalDecrease = decreaseItems.fold(
      0.0,
      (sum, i) => sum + i.variance.abs(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        const spacing = 10.0;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: cardWidth,
                child: _SummaryStatCard(
                  label: 'รายการทั้งหมด',
                  value: '${items.length}',
                  unit: 'รายการ',
                  icon: Icons.list_alt,
                  color: Colors.teal,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryStatCard(
                  label: 'สต๊อกเกิน',
                  value: '+${totalIncrease.toStringAsFixed(0)}',
                  unit: '(${increaseItems.length} รายการ)',
                  icon: Icons.arrow_upward,
                  color: Colors.blue,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryStatCard(
                  label: 'สต๊อกขาด',
                  value: '-${totalDecrease.toStringAsFixed(0)}',
                  unit: '(${decreaseItems.length} รายการ)',
                  icon: Icons.arrow_downward,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Table ──────────────────────────────────────────────────────
  Widget _buildTable(List<_VarianceItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactCards = constraints.maxWidth < 1080;

        if (useCompactCards) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) => _buildVarianceCard(items[index]),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              _buildTableHeader(),
              ...items.map((item) => _buildTableRow(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVarianceCard(_VarianceItem item) {
    final isIncrease = item.variance > 0;
    final varColor = isIncrease ? AppTheme.infoColor : AppTheme.errorColor;
    final rowBg = isIncrease ? AppTheme.infoContainer : AppTheme.errorContainer;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: rowBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: varColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.productCode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      color: varColor,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isIncrease ? '+' : ''}${item.variance.toStringAsFixed(0)} ${item.baseUnit}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: varColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildVarianceMeta('คลัง', item.warehouseName),
                _buildVarianceMeta('เลขที่อ้างอิง', item.referenceNo ?? '-'),
                _buildVarianceMeta('วันที่', _formatDateTime(item.date)),
              ],
            ),
            if ((item.remark ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.remark!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.purpleColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('สินค้า', style: style)),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('คลัง', style: style)),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text('ผลต่าง', style: style, textAlign: TextAlign.right),
          ),
          SizedBox(width: 8),
          SizedBox(width: 100, child: Text('เลขที่อ้างอิง', style: style)),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('หมายเหตุ', style: style)),
          SizedBox(width: 8),
          SizedBox(width: 100, child: Text('วันที่', style: style)),
        ],
      ),
    );
  }

  Widget _buildTableRow(_VarianceItem item) {
    final isIncrease = item.variance > 0;
    final varColor = isIncrease ? AppTheme.infoColor : AppTheme.errorColor;
    final rowBg = isIncrease ? AppTheme.infoContainer : AppTheme.errorContainer;
    final borderColor = isIncrease
        ? AppTheme.infoColor.withValues(alpha: 0.2)
        : AppTheme.errorColor.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // สินค้า
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  item.productCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // คลัง
          Expanded(
            flex: 2,
            child: Text(
              item.warehouseName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 8),

          // ผลต่าง
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  color: varColor,
                  size: 14,
                ),
                const SizedBox(width: 2),
                Text(
                  '${isIncrease ? '+' : ''}${item.variance.toStringAsFixed(0)} ${item.baseUnit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: varColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // เลขที่อ้างอิง
          SizedBox(
            width: 100,
            child: Text(
              item.referenceNo ?? '-',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 8),

          // หมายเหตุ
          Expanded(
            flex: 2,
            child: Text(
              item.remark ?? '-',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // วันที่
          SizedBox(
            width: 100,
            child: Text(
              _formatDateTime(item.date),
              style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────
  Widget _buildEmptyState(bool noAdjustAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.purpleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 48,
              color: AppTheme.purpleColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noAdjustAtAll
                ? 'ยังไม่มีการปรับสต๊อก'
                : 'ไม่พบข้อมูลในช่วงที่เลือก',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (noAdjustAtAll) ...[
            const SizedBox(height: 6),
            const Text(
              'กรุณานับสต๊อกผ่านหน้า "ตรวจนับสต๊อก" ก่อน',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVarianceMeta(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.purpleColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatDateTime(DateTime d) =>
      '${d.day}/${d.month}/${d.year}\n${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Widget: Filter Chip ────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Colors.white
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Widget: Summary Stat Card ──────────────────────────────────
class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
