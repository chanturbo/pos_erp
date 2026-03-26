import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_in_dialog.dart';
import '../widgets/stock_out_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';
import '../widgets/stock_transfer_dialog.dart';
import 'stock_movement_history_page.dart';
import '../../data/models/stock_balance_model.dart';

// ── Color aliases → AppTheme ──────────────────────────────────────
const _navy    = AppTheme.navyColor;
const _orange  = AppTheme.primaryColor;
const _border  = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _error   = AppTheme.errorColor;
const _warning = AppTheme.warningColor;

class StockBalancePage extends ConsumerStatefulWidget {
  const StockBalancePage({super.key});

  @override
  ConsumerState<StockBalancePage> createState() => _StockBalancePageState();
}

class _StockBalancePageState extends ConsumerState<StockBalancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery       = '';
  String _selectedWarehouse = 'WH001'; // ✅ เหมือนไฟล์เดิม
  bool   _isTableView       = true;    // ← default: Table View
  bool   _showLowStockOnly  = false;
  String _sortColumn        = 'productCode';
  bool   _sortAsc           = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Filter + Sort (รักษา logic รวมยอด "ทุกคลัง" จากไฟล์เดิม)
  // ─────────────────────────────────────────────────────────────
  List<StockBalanceModel> _applyFilters(
    List<StockBalanceModel> stocks,
    int lowThreshold,
    bool alertOn,
  ) {
    // 1. กรองคลัง — เหมือน logic เดิม
    var result = stocks.where((s) {
      if (_selectedWarehouse != 'ALL' &&
          s.warehouseId != _selectedWarehouse) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.productName.toLowerCase().contains(q) &&
            !s.productCode.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_showLowStockOnly && !(alertOn && s.balance < lowThreshold)) {
        return false;
      }
      return true;
    }).toList();

    // 2. รวมยอด "ทุกคลัง" — เหมือน logic เดิม ✅
    if (_selectedWarehouse == 'ALL') {
      final Map<String, StockBalanceModel> combined = {};
      for (var s in result) {
        if (combined.containsKey(s.productId)) {
          final ex = combined[s.productId]!;
          combined[s.productId] = StockBalanceModel(
            productId: ex.productId,
            productCode: ex.productCode,
            productName: ex.productName,
            baseUnit: ex.baseUnit,
            warehouseId: 'ALL',
            warehouseName: 'ทุกคลัง',
            balance: ex.balance + s.balance,
          );
        } else {
          combined[s.productId] = s;
        }
      }
      result = combined.values.toList();
    }

    // 3. Sort
    result.sort((a, b) {
      int c;
      switch (_sortColumn) {
        case 'productCode': c = a.productCode.compareTo(b.productCode); break;
        case 'productName': c = a.productName.compareTo(b.productName); break;
        case 'balance':     c = a.balance.compareTo(b.balance); break;
        default: c = 0;
      }
      return _sortAsc ? c : -c;
    });
    return result;
  }

  void _onSort(String col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = true;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);
    final settings   = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สต๊อกคงเหลือ'),
        actions: [
          // Filter: สต๊อกต่ำ
          Tooltip(
            message: _showLowStockOnly ? 'แสดงทั้งหมด' : 'เฉพาะสต๊อกต่ำ',
            child: IconButton(
              icon: Icon(Icons.warning_amber_rounded,
                  color: _showLowStockOnly
                      ? AppTheme.primaryLight
                      : null),
              onPressed: () =>
                  setState(() => _showLowStockOnly = !_showLowStockOnly),
            ),
          ),
          // Toggle view
          Tooltip(
            message: _isTableView ? 'Card View' : 'Table View',
            child: IconButton(
              icon: Icon(_isTableView
                  ? Icons.view_agenda_outlined
                  : Icons.table_rows_outlined),
              onPressed: () => setState(() => _isTableView = !_isTableView),
            ),
          ),
          // ✅ History — เหมือนไฟล์เดิม
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ประวัติการเคลื่อนไหว',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const StockMovementHistoryPage()),
            ),
          ),
          // ✅ Refresh — เหมือนไฟล์เดิม
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(stockBalanceProvider.notifier).refresh(),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Toolbar ─────────────────────────────────────────
          _buildToolbar(stockAsync, settings),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: stockAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('กำลังโหลดสต๊อก...'),
                  ],
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: _error),
                    const SizedBox(height: 16),
                    Text('เกิดข้อผิดพลาด: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(stockBalanceProvider.notifier).refresh(),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
              data: (stocks) {
                final filtered = _applyFilters(
                  stocks,
                  settings.lowStockThreshold,
                  settings.enableLowStockAlert,
                );
                if (filtered.isEmpty) return _buildEmpty();
                return _isTableView
                    ? _buildTableView(filtered, settings)
                    : _buildCardView(filtered, settings);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Toolbar: Search + Warehouse dropdown + Summary
  // ─────────────────────────────────────────────────────────────
  Widget _buildToolbar(AsyncValue stockAsync, settings) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // Search — เหมือนไฟล์เดิม
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสินค้า...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ✅ Warehouse dropdown — เหมือนไฟล์เดิม
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWarehouse,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'ALL', child: Text('ทุกคลัง')),
                      DropdownMenuItem(
                          value: 'WH001', child: Text('คลังหลัก')),
                      DropdownMenuItem(
                          value: 'WH002', child: Text('คลังสยาม')),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedWarehouse = v!),
                  ),
                ),
              ),
            ],
          ),

          // Summary chips
          stockAsync.whenOrNull(
                data: (stocks) {
                  final filtered = _applyFilters(
                    stocks,
                    settings.lowStockThreshold,
                    settings.enableLowStockAlert,
                  );
                  final lowCount = filtered
                      .where((s) =>
                          settings.enableLowStockAlert &&
                          s.balance < settings.lowStockThreshold)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        _SummaryChip('รายการ', filtered.length, _navy),
                        if (lowCount > 0) ...[
                          const SizedBox(width: 8),
                          _SummaryChip('สต๊อกต่ำ', lowCount, _error),
                        ],
                      ],
                    ),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildTableView(List<StockBalanceModel> stocks, settings) {
    final int threshold = settings.lowStockThreshold;
    final bool alertOn  = settings.enableLowStockAlert;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            color: _navy,
            child: Row(
              children: [
                const _HeaderCell('#', width: 48, center: true),
                _SortableHeader('รหัสสินค้า', 'productCode',
                    _sortColumn, _sortAsc, _onSort, flex: 2),
                _SortableHeader('ชื่อสินค้า', 'productName',
                    _sortColumn, _sortAsc, _onSort, flex: 4),
                const _HeaderCell('คลัง', flex: 2),
                _SortableHeader('คงเหลือ', 'balance',
                    _sortColumn, _sortAsc, _onSort,
                    flex: 2, rightAlign: true),
                const _HeaderCell('หน่วย', flex: 1, center: true),
                const _HeaderCell('สถานะ', flex: 2, center: true),
                const _HeaderCell('', width: 120),
              ],
            ),
          ),

          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stocks.length,
            itemBuilder: (_, i) {
              final s     = stocks[i];
              final isLow = alertOn && s.balance < threshold;
              return _StockTableRow(
                stock: s,
                no: i + 1,
                isEven: i.isEven,
                isLow: isLow,
                onTap: () => _showStockActions(context, s),
                onStockIn: () => showDialog(
                    context: context,
                    builder: (_) => StockInDialog(stock: s)),
                onStockOut: () => showDialog(
                    context: context,
                    builder: (_) => StockOutDialog(stock: s)),
                onTransfer: () => showDialog(
                    context: context,
                    builder: (_) => StockTransferDialog(stock: s)),
                onAdjust: () => showDialog(
                    context: context,
                    builder: (_) => StockAdjustDialog(stock: s)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARD VIEW — รักษา ListTile pattern จากไฟล์เดิม + ปรับ style
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardView(List<StockBalanceModel> stocks, settings) {
    final int threshold  = settings.lowStockThreshold;
    final bool alertOn   = settings.enableLowStockAlert;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: stocks.length,
      itemBuilder: (_, i) {
        final s     = stocks[i];
        final isLow = alertOn && s.balance < threshold;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isLow ? _warning : _border,
              width: isLow ? 1.5 : 1,
            ),
          ),
          color: isLow ? const Color(0xFFFFFDE7) : Colors.white,
          // ✅ ListTile เหมือนโครงสร้างเดิม
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isLow ? _error : _success,
              child: Icon(
                isLow ? Icons.warning : Icons.inventory,
                color: Colors.white,
              ),
            ),
            title: Text(s.productName,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A))), // ✅
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รหัส: ${s.productCode}',
                    style: const TextStyle(color: Color(0xFF555555))),
                Text('คลัง: ${s.warehouseName}',
                    style: const TextStyle(color: Color(0xFF555555))),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${s.balance.toStringAsFixed(0)} ${s.baseUnit}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLow ? _error : _success,
                  ),
                ),
                if (isLow)
                  const Text('สต๊อกต่ำ!',
                      style: TextStyle(fontSize: 12, color: _error)),
              ],
            ),
            onTap: () => _showStockActions(context, s),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stock Actions Bottom Sheet — ✅ เหมือนไฟล์เดิม
  // ─────────────────────────────────────────────────────────────
  void _showStockActions(BuildContext context, StockBalanceModel stock) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 18, color: _navy),
                  const SizedBox(width: 8),
                  Text(stock.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  Text(
                    '${stock.balance.toStringAsFixed(0)} ${stock.baseUnit}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _success),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_box, color: _success),
              title: const Text('รับสินค้าเข้า'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => StockInDialog(stock: stock));
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: _orange),
              title: const Text('เบิกสินค้าออก'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => StockOutDialog(stock: stock));
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Color(0xFF6A1B9A)),
              title: const Text('โอนย้ายสินค้า'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => StockTransferDialog(stock: stock));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF1565C0)),
              title: const Text('ปรับสต๊อก'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => StockAdjustDialog(stock: stock));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _showLowStockOnly
                  ? 'ไม่มีสินค้าที่สต๊อกต่ำ'
                  : 'ไม่พบข้อมูลสต๊อก',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// _StockTableRow
// ════════════════════════════════════════════════════════════════
class _StockTableRow extends StatelessWidget {
  final StockBalanceModel stock;
  final int no;
  final bool isEven;
  final bool isLow;
  final VoidCallback onTap;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;

  const _StockTableRow({
    required this.stock,
    required this.no,
    required this.isEven,
    required this.isLow,
    required this.onTap,
    required this.onStockIn,
    required this.onStockOut,
    required this.onTransfer,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    // ── สีคงที่ ไม่ขึ้นกับ dark mode ──────────────────────────
    const nameColor  = Color(0xFF1A1A1A);
    const codeColor  = Color(0xFF555555);
    const whColor    = Color(0xFF666666);
    const unitColor  = Color(0xFF1A1A1A);
    const noColor    = Color(0xFFBBBBBB);

    return InkWell(
      onTap: onTap,
      hoverColor: _orange.withValues(alpha: 0.05),
      child: Container(
        decoration: BoxDecoration(
          color: isLow
              ? const Color(0xFFFFF8E1)
              : (isEven ? Colors.white : const Color(0xFFF9F9F7)),
          border: isLow
              ? const Border(
                  left: BorderSide(color: _warning, width: 3))
              : null,
        ),
        child: Row(
          children: [
            // No.
            SizedBox(
              width: 48,
              child: Center(
                child: Text('$no',
                    style: const TextStyle(
                        fontSize: 12, color: noColor)),
              ),
            ),
            // รหัส
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 11, horizontal: 8),
                child: Text(stock.productCode,
                    style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        color: codeColor)), // ✅
              ),
            ),
            // ชื่อ
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 11, horizontal: 8),
                child: Text(stock.productName,
                    style: const TextStyle(
                        fontSize: 13,
                        color: nameColor), // ✅
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            // คลัง
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(stock.warehouseName,
                    style: const TextStyle(
                        fontSize: 12,
                        color: whColor)), // ✅
              ),
            ),
            // คงเหลือ
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    stock.balance.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isLow ? _error : _success,
                    ),
                  ),
                ),
              ),
            ),
            // หน่วย
            Expanded(
              flex: 1,
              child: Center(
                  child: Text(stock.baseUnit,
                      style: const TextStyle(
                          fontSize: 12,
                          color: unitColor))),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: isLow
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCDD2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 12, color: _error),
                            SizedBox(width: 3),
                            Text('สต๊อกต่ำ',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _error)),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB9F6CA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('ปกติ',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B5E20))),
                      ),
              ),
            ),
            // Actions
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StockActionBtn(
                      icon: Icons.add_box_outlined,
                      color: _success,
                      tooltip: 'รับเข้า',
                      onTap: onStockIn),
                  _StockActionBtn(
                      icon: Icons.remove_circle_outline,
                      color: _orange,
                      tooltip: 'เบิกออก',
                      onTap: onStockOut),
                  _StockActionBtn(
                      icon: Icons.swap_horiz,
                      color: const Color(0xFF6A1B9A),
                      tooltip: 'โอนย้าย',
                      onTap: onTransfer),
                  _StockActionBtn(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF1565C0),
                      tooltip: 'ปรับสต๊อก',
                      onTap: onAdjust),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared Sub-widgets
// ─────────────────────────────────────────────────────────────────

class _StockActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _StockActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final double? width;
  final bool center;
  const _HeaderCell(this.label,
      {this.flex = 1, this.width, this.center = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(label,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4));
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: center ? Center(child: text) : text,
    );
    if (width != null) return SizedBox(width: width, child: content);
    return Expanded(flex: flex, child: content);
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String column;
  final String current;
  final bool ascending;
  final void Function(String) onSort;
  final int flex;
  final bool rightAlign;
  const _SortableHeader(
      this.label, this.column, this.current, this.ascending, this.onSort,
      {this.flex = 1, this.rightAlign = false});

  @override
  Widget build(BuildContext context) {
    final isActive = current == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(column),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: rightAlign
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: isActive
                          ? AppTheme.primaryLight
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(width: 4),
              Icon(
                isActive
                    ? (ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 13,
                color: isActive
                    ? AppTheme.primaryLight
                    : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}