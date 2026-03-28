import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/models/stock_movement_model.dart';

// ── Color aliases ─────────────────────────────────────────────────
const _navy    = AppTheme.navyColor;
const _success = AppTheme.successColor;
const _error   = AppTheme.errorColor;

// ── Top-level helpers ─────────────────────────────────────────────
Color _movTypeColor(String type) {
  switch (type) {
    case 'IN':           return const Color(0xFF2E7D32);
    case 'OUT':          return const Color(0xFFE65100);
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
    case 'TRANSFER':     return const Color(0xFF6A1B9A);
    case 'ADJUST':       return const Color(0xFF1565C0);
    case 'SALE':         return const Color(0xFFC62828);
    default:             return Colors.grey;
  }
}

IconData _movTypeIcon(String type) {
  switch (type) {
    case 'IN':           return Icons.add_box_rounded;
    case 'OUT':          return Icons.remove_circle_rounded;
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
    case 'TRANSFER':     return Icons.swap_horiz_rounded;
    case 'ADJUST':       return Icons.tune_rounded;
    case 'SALE':         return Icons.shopping_cart_rounded;
    default:             return Icons.inventory_2_rounded;
  }
}

String _movTypeLabel(String type) {
  switch (type) {
    case 'IN':           return 'รับเข้า';
    case 'OUT':          return 'เบิกออก';
    case 'TRANSFER_IN':  return 'รับโอน';
    case 'TRANSFER_OUT': return 'โอนออก';
    case 'TRANSFER':     return 'โอนย้าย';
    case 'ADJUST':       return 'ปรับสต๊อก';
    case 'SALE':         return 'ขาย';
    default:             return type;
  }
}

// ── Provider ──────────────────────────────────────────────────────
final movementHistoryProvider =
    FutureProvider<List<StockMovementModel>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  try {
    final response = await apiClient.get('/api/stock/movements');
    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      return data
          .map((json) => StockMovementModel.fromJson(json))
          .toList();
    }
    return [];
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────
class StockMovementHistoryPage extends ConsumerStatefulWidget {
  const StockMovementHistoryPage({super.key});

  @override
  ConsumerState<StockMovementHistoryPage> createState() =>
      _StockMovementHistoryPageState();
}

class _StockMovementHistoryPageState
    extends ConsumerState<StockMovementHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery  = '';
  String _filterType   = 'ALL';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StockMovementModel> _applyFilters(List<StockMovementModel> all) {
    return all.where((m) {
      final matchType = _filterType == 'ALL' || m.movementType == _filterType;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          m.productId.toLowerCase().contains(q) ||
          (m.referenceNo?.toLowerCase().contains(q) ?? false) ||
          (m.remark?.toLowerCase().contains(q) ?? false) ||
          _movTypeLabel(m.movementType).contains(q);
      return matchType && matchSearch;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ประวัติการเคลื่อนไหวสต๊อก'),
        actions: [
          // Toggle view
          Tooltip(
            message: _isTableView ? 'Card View' : 'List View',
            waitDuration: const Duration(milliseconds: 600),
            child: IconButton(
              icon: Icon(_isTableView
                  ? Icons.view_agenda_outlined
                  : Icons.table_rows_outlined),
              onPressed: () => setState(() => _isTableView = !_isTableView),
            ),
          ),
          // Refresh
          Tooltip(
            message: 'รีเฟรช',
            waitDuration: const Duration(milliseconds: 600),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(movementHistoryProvider),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Toolbar ─────────────────────────────────────────────
          _buildToolbar(),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: movementsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('เกิดข้อผิดพลาด: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(movementHistoryProvider),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
              data: (movements) {
                final filtered = _applyFilters(movements);
                if (movements.isEmpty) return _buildEmpty();
                if (filtered.isEmpty) return _buildEmptyFiltered();
                return Column(
                  children: [
                    // Summary chips
                    _buildSummary(movements, filtered),
                    // List / Card
                    Expanded(
                      child: _isTableView
                          ? _buildListView(filtered)
                          : _buildCardView(filtered),
                    ),
                    // Footer
                    _buildFooter(filtered.length, movements.length),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Toolbar
  // ─────────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'ค้นหา รหัสสินค้า / อ้างอิง...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF8A8A8A)),
                  prefixIcon: const Icon(Icons.search,
                      size: 17, color: Color(0xFF8A8A8A)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 15, color: Color(0xFF8A8A8A)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Type filter dropdown
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterType,
                isDense: true,
                dropdownColor: Colors.white,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1A1A1A)),
                items: const [
                  DropdownMenuItem(value: 'ALL',          child: Text('ทุกประเภท')),
                  DropdownMenuItem(value: 'IN',           child: Text('รับเข้า')),
                  DropdownMenuItem(value: 'OUT',          child: Text('เบิกออก')),
                  DropdownMenuItem(value: 'ADJUST',       child: Text('ปรับสต๊อก')),
                  DropdownMenuItem(value: 'TRANSFER',     child: Text('โอนย้าย')),
                  DropdownMenuItem(value: 'TRANSFER_IN',  child: Text('รับโอน')),
                  DropdownMenuItem(value: 'TRANSFER_OUT', child: Text('โอนออก')),
                  DropdownMenuItem(value: 'SALE',         child: Text('ขาย')),
                ],
                onChanged: (v) => setState(() => _filterType = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Summary chips
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSummary(List<StockMovementModel> all,
      List<StockMovementModel> filtered) {
    int countOf(String t) =>
        filtered.where((m) => m.movementType == t ||
            (t == 'TRANSFER' && (m.movementType == 'TRANSFER_IN' || m.movementType == 'TRANSFER_OUT'))).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip('ทั้งหมด', filtered.length, _navy),
            const SizedBox(width: 6),
            _SummaryChip('รับเข้า',   countOf('IN'),      const Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            _SummaryChip('เบิกออก',   countOf('OUT'),     const Color(0xFFE65100)),
            const SizedBox(width: 6),
            _SummaryChip('โอนย้าย',   countOf('TRANSFER'), const Color(0xFF6A1B9A)),
            const SizedBox(width: 6),
            _SummaryChip('ปรับสต๊อก', countOf('ADJUST'),  const Color(0xFF1565C0)),
            const SizedBox(width: 6),
            _SummaryChip('ขาย',       countOf('SALE'),    const Color(0xFFC62828)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LIST VIEW (table style)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildListView(List<StockMovementModel> movements) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            color: _navy,
            child: const Row(
              children: [
                _HeaderCell('#',         width: 48, center: true),
                _HeaderCell('วันที่/เวลา', flex: 3),
                _HeaderCell('ประเภท',    flex: 2, center: true),
                _HeaderCell('รหัสสินค้า', flex: 3),
                _HeaderCell('คลัง',       flex: 2),
                _HeaderCell('จำนวน',     flex: 2, rightAlign: true),
                _HeaderCell('เลขอ้างอิง', flex: 3),
              ],
            ),
          ),

          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: movements.length,
            itemBuilder: (_, i) => _MovementListRow(
              movement: movements[i],
              no: i + 1,
              isEven: i.isEven,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // CARD VIEW
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCardView(List<StockMovementModel> movements) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: movements.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MovementCard(movement: movements[i]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Footer
  // ─────────────────────────────────────────────────────────────────
  Widget _buildFooter(int shown, int total) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            'แสดง $shown จาก $total รายการ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }

  // ── Empty states ─────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: const Icon(Icons.history,
                  size: 38, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('ยังไม่มีประวัติการเคลื่อนไหว',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text('ประวัติจะแสดงเมื่อมีการรับ/เบิก/โอนสต๊อก',
                style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A))),
          ],
        ),
      );

  Widget _buildEmptyFiltered() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('ไม่พบรายการที่ค้นหา',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _filterType  = 'ALL';
                });
              },
              child: const Text('ล้างตัวกรอง'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
// _MovementListRow — table row
// ─────────────────────────────────────────────────────────────────
class _MovementListRow extends StatelessWidget {
  final StockMovementModel movement;
  final int  no;
  final bool isEven;

  const _MovementListRow({
    required this.movement,
    required this.no,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isEven ? Colors.white : const Color(0xFFF9F9F7);
    final isPositive = movement.quantity >= 0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
            bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // #
          SizedBox(
            width: 48,
            child: Center(
              child: Text('$no',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFBBBBBB))),
            ),
          ),
          // วันที่
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 11, horizontal: 8),
              child: Text(
                DateFormat('dd/MM/yy HH:mm')
                    .format(movement.movementDate),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF555555)),
              ),
            ),
          ),
          // ประเภท
          Expanded(
            flex: 2,
            child: Center(
              child: _TypeBadge(type: movement.movementType),
            ),
          ),
          // รหัสสินค้า
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                movement.productId,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF555555)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // คลัง
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                movement.warehouseId,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF666666)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // จำนวน
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? _success : _error,
                  ),
                ),
              ),
            ),
          ),
          // เลขอ้างอิง
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                movement.referenceNo ?? '—',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF8A8A8A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _MovementCard — card view item
// ─────────────────────────────────────────────────────────────────
class _MovementCard extends StatelessWidget {
  final StockMovementModel movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final color      = _movTypeColor(movement.movementType);
    final icon       = _movTypeIcon(movement.movementType);
    final isPositive = movement.quantity >= 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type + quantity row
                  Row(
                    children: [
                      _TypeBadge(type: movement.movementType),
                      const Spacer(),
                      Text(
                        '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isPositive ? _success : _error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Product + warehouse
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 13, color: Color(0xFF8A8A8A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          movement.productId,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Color(0xFF555555)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.warehouse_outlined,
                          size: 13, color: Color(0xFF8A8A8A)),
                      const SizedBox(width: 4),
                      Text(
                        movement.warehouseId,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Date
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Color(0xFF8A8A8A)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(movement.movementDate),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8A8A8A)),
                      ),
                    ],
                  ),

                  // Reference + remark
                  if (movement.referenceNo != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.tag,
                            size: 12, color: Color(0xFF8A8A8A)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            movement.referenceNo!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF555555)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (movement.remark != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.notes,
                            size: 12, color: Color(0xFF8A8A8A)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            movement.remark!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A8A8A),
                                fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────
// _TypeBadge
// ─────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _movTypeColor(type);
    final label = _movTypeLabel(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _SummaryChip
// ─────────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
// _HeaderCell — table header column
// ─────────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  final int?    flex;
  final bool    center;
  final bool    rightAlign;

  const _HeaderCell(
    this.label, {
    this.width,
    this.flex,
    this.center     = false,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget text = Text(
      label,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white),
    );
    if (center) text = Center(child: text);
    if (rightAlign) text = Align(alignment: Alignment.centerRight, child: text);

    final inner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: text,
    );

    if (width != null) return SizedBox(width: width, child: inner);
    return Expanded(flex: flex ?? 1, child: inner);
  }
}
