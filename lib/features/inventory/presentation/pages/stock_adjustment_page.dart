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

// ════════════════════════════════════════════════════════════════
// ✅ STEP 1: StockAdjustmentPage — หน้าเมนูหลัก
// ════════════════════════════════════════════════════════════════
class StockAdjustmentPage extends StatelessWidget {
  const StockAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 ปรับปรุงสต๊อก'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepPurple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'เลือกประเภทการปรับปรุงสต๊อกที่ต้องการ\n'
                      'ทุกการเปลี่ยนแปลงจะบันทึกประวัติไว้ในระบบ',
                      style: TextStyle(fontSize: 13, color: Colors.deepPurple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'เลือกประเภทการปรับสต๊อก',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  // 1) ปรับสต๊อก (เพิ่ม/ลด) ✅ Step 2 พร้อมแล้ว
                  _MenuCard(
                    icon: Icons.tune,
                    title: 'ปรับสต๊อก',
                    subtitle: 'เพิ่มหรือลดสต๊อก\nรายการเดียว',
                    color: Colors.blue,
                    badge: '✅ พร้อมใช้',
                    badgeColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdjustStockSubPage(),
                        ),
                      );
                    },
                  ),

                  // 2) ตรวจนับสต๊อก (Stock Take)
                  _MenuCard(
                    icon: Icons.fact_check_outlined,
                    title: 'ตรวจนับสต๊อก',
                    subtitle: 'นับจริงทั้งคลัง\nแล้วเปรียบเทียบ',
                    color: Colors.orange,
                    badge: '✅ พร้อมใช้',
                    badgeColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockTakeSubPage(),
                        ),
                      );
                    },
                  ),

                  // 3) โอนย้ายสต๊อก (Transfer)
                  _MenuCard(
                    icon: Icons.swap_horiz,
                    title: 'โอนย้ายสต๊อก',
                    subtitle: 'โอนระหว่างคลัง\nต้นทาง → ปลายทาง',
                    color: Colors.purple,
                    badge: '✅ พร้อมใช้',
                    badgeColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockTransferSubPage(),
                        ),
                      );
                    },
                  ),

                  // 4) รายงานผลต่าง
                  _MenuCard(
                    icon: Icons.analytics_outlined,
                    title: 'รายงานผลต่าง',
                    subtitle: 'ดูผล Stock Take\nเกิน / ขาด / ตรง',
                    color: Colors.teal,
                    badge: '✅ พร้อมใช้',
                    badgeColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VarianceReportPage(),
                        ),
                      );
                    },
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ปรับสต๊อก (เพิ่ม/ลด)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (stocks) {
          // กรองสินค้าตาม search
          final filtered = _searchQuery.isEmpty
              ? stocks
              : stocks
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
              // ── ซ้าย: เลือกสินค้า ────────────────────────
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ค้นหาสินค้า...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),

                    // รายการสินค้า
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('ไม่พบสินค้า'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final stock = filtered[index];
                                final isSelected =
                                    _selectedStock?.productId ==
                                        stock.productId &&
                                    _selectedStock?.warehouseId ==
                                        stock.warehouseId;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.withValues(
                                    alpha: 0.1,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.blue
                                        : Colors.grey[200],
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    stock.productName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${stock.productCode} • ${stock.warehouseName}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Text(
                                    '${stock.balance.toStringAsFixed(0)} ${stock.baseUnit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: stock.balance > 0
                                          ? Colors.green[700]
                                          : Colors.red,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedStock = stock;
                                      _qtyController.clear();
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              const VerticalDivider(width: 1),

              // ── ขวา: Form ปรับสต๊อก ──────────────────────
              Expanded(
                child: _selectedStock == null
                    ? _buildEmptyState()
                    : _buildAdjustForm(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'เลือกสินค้าที่ต้องการปรับสต๊อก',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
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
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.blue, size: 40),
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
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'รหัส: ${stock.productCode}  •  คลัง: ${stock.warehouseName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // สต๊อกปัจจุบัน
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'สต๊อกปัจจุบัน',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          stock.balance.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          stock.baseUnit,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── ประเภทการปรับ ──────────────────────────────
            const Text(
              'ประเภทการปรับ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _AdjustTypeButton(
                  label: 'เพิ่มสต๊อก',
                  icon: Icons.add_circle,
                  color: Colors.green,
                  isSelected: _adjustType == 'INCREASE',
                  onTap: () => setState(() => _adjustType = 'INCREASE'),
                ),
                const SizedBox(width: 8),
                _AdjustTypeButton(
                  label: 'ลดสต๊อก',
                  icon: Icons.remove_circle,
                  color: Colors.red,
                  isSelected: _adjustType == 'DECREASE',
                  onTap: () => setState(() => _adjustType = 'DECREASE'),
                ),
                const SizedBox(width: 8),
                _AdjustTypeButton(
                  label: 'กำหนดยอด',
                  icon: Icons.edit,
                  color: Colors.orange,
                  isSelected: _adjustType == 'SET',
                  onTap: () => setState(() => _adjustType = 'SET'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── จำนวน ──────────────────────────────────────
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _adjustType == 'SET'
                    ? 'กำหนดสต๊อกใหม่ *'
                    : 'จำนวนที่ต้องการ${_adjustType == 'INCREASE' ? 'เพิ่ม' : 'ลด'} *',
                border: const OutlineInputBorder(),
                suffixText: stock.baseUnit,
                prefixIcon: Icon(
                  _adjustType == 'INCREASE'
                      ? Icons.add
                      : _adjustType == 'DECREASE'
                      ? Icons.remove
                      : Icons.edit,
                  color: _adjustType == 'INCREASE'
                      ? Colors.green
                      : _adjustType == 'DECREASE'
                      ? Colors.red
                      : Colors.orange,
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
                  color: _difference >= 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _difference >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PreviewItem(
                      label: 'ปัจจุบัน',
                      value: stock.balance.toStringAsFixed(0),
                      unit: stock.baseUnit,
                      color: Colors.grey[700]!,
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: _difference >= 0 ? Colors.green : Colors.red,
                    ),
                    _PreviewItem(
                      label: 'หลังปรับ',
                      value: _newBalance.toStringAsFixed(0),
                      unit: stock.baseUnit,
                      color: _difference >= 0 ? Colors.green : Colors.red,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _difference >= 0 ? Colors.green : Colors.red,
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
              decoration: const InputDecoration(
                labelText: 'เลขที่เอกสารอ้างอิง',
                border: OutlineInputBorder(),
                hintText: 'เช่น ADJ-2024-001',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),

            // ── หมายเหตุ ───────────────────────────────────
            TextFormField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'เหตุผล / หมายเหตุ *',
                border: OutlineInputBorder(),
                hintText: 'เช่น สินค้าชำรุด, นับสต๊อกรอบปี, แก้ไขยอดผิด',
                prefixIcon: Icon(Icons.note_alt_outlined),
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
                              _referenceController.clear();
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
                      backgroundColor: Colors.blue,
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
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading ? 'กำลังบันทึก...' : 'บันทึกการปรับสต๊อก',
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
                ? '✅ ปรับสต๊อก ${_selectedStock!.productName} สำเร็จ'
                : '❌ เกิดข้อผิดพลาด กรุณาลองใหม่',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        // Reset form หลังบันทึกสำเร็จ
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจนับสต๊อก (Stock Take)'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // แสดงเฉพาะที่มีผลต่าง
          TextButton.icon(
            onPressed: () =>
                setState(() => _showVarianceOnly = !_showVarianceOnly),
            icon: Icon(
              _showVarianceOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
            label: Text(
              _showVarianceOnly ? 'มีผลต่าง' : 'ทั้งหมด',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'โหลดใหม่',
            onPressed: () {
              _clearItems();
              ref.read(stockBalanceProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (stocks) {
          _initItems(stocks);

          // กรองรายการ
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
              // ── Toolbar ──────────────────────────────────
              _buildToolbar(stocks),

              // ── Summary Bar ──────────────────────────────
              if (_isInitialized) _buildSummaryBar(),

              // ── รายการสินค้า ─────────────────────────────
              Expanded(
                child: _takeItems.isEmpty
                    ? _buildEmptyState()
                    : filtered.isEmpty
                    ? const Center(child: Text('ไม่พบสินค้าที่ตรงกัน'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildItemRow(filtered[index]),
                      ),
              ),

              // ── Bottom: Remark + ปุ่มยืนยัน ─────────────
              if (_takeItems.isNotEmpty) _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  // ── Toolbar: เลือกคลัง + ค้นหา ───────────────────────────────
  Widget _buildToolbar(List<StockBalanceModel> stocks) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Row(
        children: [
          // Dropdown คลัง
          const Text('คลัง:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedWarehouse,
            items: const [
              DropdownMenuItem(value: 'WH001', child: Text('คลังหลัก')),
              DropdownMenuItem(value: 'WH002', child: Text('คลังสยาม')),
            ],
            onChanged: (v) {
              if (v != null) _changeWarehouse(v, stocks);
            },
          ),
          const SizedBox(width: 16),
          // Search
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Text(
            'ทั้งหมด $_totalItems รายการ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _SummaryChip(
            label: 'ตรงกัน',
            count: _matchCount,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'เกิน',
            count: _increaseCount,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _SummaryChip(label: 'ขาด', count: _decreaseCount, color: Colors.red),
        ],
      ),
    );
  }

  // ── แถวสินค้าแต่ละรายการ ──────────────────────────────────────
  Widget _buildItemRow(_StockTakeItem item) {
    final variance = item.variance;
    Color rowColor = Colors.transparent;
    if (variance > 0) rowColor = Colors.blue[50]!;
    if (variance < 0) rowColor = Colors.red[50]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: rowColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.stock.productCode,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  Text(
                    'ในระบบ',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    item.stock.balance.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.stock.baseUnit,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // ช่องกรอกจำนวนที่นับจริง
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    'นับจริง',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: item.countController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixText: item.stock.baseUnit,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ผลต่าง
            SizedBox(
              width: 80,
              child: Column(
                children: [
                  Text(
                    'ผลต่าง',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        variance > 0
                            ? Icons.arrow_upward
                            : variance < 0
                            ? Icons.arrow_downward
                            : Icons.check,
                        size: 14,
                        color: variance > 0
                            ? Colors.blue
                            : variance < 0
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        variance == 0
                            ? 'ตรง'
                            : '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: variance > 0
                              ? Colors.blue
                              : variance < 0
                              ? Colors.red
                              : Colors.green,
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'ไม่มีสินค้าในคลังนี้',
            style: TextStyle(color: Colors.grey[600]),
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
              backgroundColor: hasAnyVariance ? Colors.orange : Colors.green,
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
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Dialog ยืนยัน
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปรับสต๊อก'),
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
              backgroundColor: Colors.orange,
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
          backgroundColor: allOk ? Colors.green : Colors.orange,
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
    {'id': 'WH002', 'name': 'คลังสยาม'},
  ];

  String _fromWarehouseId = 'WH001';
  String _toWarehouseId = 'WH002';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('โอนย้ายสต๊อก (Transfer)'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (stocks) {
          // สินค้าในคลังต้นทาง
          final fromStocks = stocks
              .where((s) => s.warehouseId == _fromWarehouseId && s.balance > 0)
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
                    // Warehouse selector
                    _buildWarehouseSelector(stocks),

                    // Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ค้นหาสินค้า...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),

                    // รายการสินค้า
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    fromStocks.isEmpty
                                        ? 'ไม่มีสินค้าในคลังนี้'
                                        : 'ไม่พบสินค้าที่ค้นหา',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final stock = filtered[index];
                                final isSelected =
                                    _selectedStock?.productId ==
                                    stock.productId;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.purple.withValues(
                                    alpha: 0.1,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.purple
                                        : Colors.grey[200],
                                    child: Icon(
                                      Icons.inventory_2,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  title: Text(
                                    stock.productName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    stock.productCode,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        stock.balance.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      Text(
                                        stock.baseUnit,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedStock = stock;
                                      _qtyController.clear();
                                    });
                                  },
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
    );
  }

  // ── Warehouse Selector ────────────────────────────────────────
  Widget _buildWarehouseSelector(List<StockBalanceModel> stocks) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.purple[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เลือกคลัง',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // ต้นทาง
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ต้นทาง',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _fromWarehouseId,
                      isDense: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: _warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'],
                              child: Text(
                                w['name']!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null && v != _fromWarehouseId) {
                          setState(() {
                            _fromWarehouseId = v;

                            // ถ้า from == to → swap
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
                  ],
                ),
              ),

              // ลูกศร swap
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.purple),
                      tooltip: 'สลับคลัง',
                      onPressed: () {
                        setState(() {
                          final tmp = _fromWarehouseId;
                          _fromWarehouseId = _toWarehouseId;
                          _toWarehouseId = tmp;
                          _selectedStock = null;
                          _qtyController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ปลายทาง
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ปลายทาง',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _toWarehouseId,
                      isDense: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: _warehouses
                          .where((w) => w['id'] != _fromWarehouseId)
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'],
                              child: Text(
                                w['name']!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _toWarehouseId = v;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'เลือกสินค้าที่ต้องการโอนย้าย',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'จาก ${_warehouseName(_fromWarehouseId)} → ${_warehouseName(_toWarehouseId)}',
            style: TextStyle(fontSize: 13, color: Colors.purple[400]),
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
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      color: Colors.purple,
                      size: 40,
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
                            ),
                          ),
                          Text(
                            'รหัส: ${stock.productCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'สต๊อกในคลังต้นทาง',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          stock.balance.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          stock.baseUnit,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    color: Colors.purple,
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
                prefixIcon: const Icon(Icons.swap_horiz, color: Colors.purple),
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
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ผลลัพธ์หลังโอน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
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
                        const Icon(Icons.arrow_forward, color: Colors.purple),
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
                hintText: 'เช่น โอนสต๊อกไปสาขาสยาม',
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
                      backgroundColor: Colors.purple,
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
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการโอนย้าย'),
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
              backgroundColor: Colors.purple,
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
          backgroundColor: success ? Colors.green : Colors.red,
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
// Widget: _MenuCard (ใช้ใน Step 1)
// ════════════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: color),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
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
    {'id': 'WH002', 'name': 'คลังสยาม'},
  ];

  String _warehouseName(String id) => _warehouses.firstWhere(
    (w) => w['id'] == id,
    orElse: () => {'name': id},
  )['name']!;

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementHistoryProvider);
    final stockAsync = ref.watch(stockBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานผลต่าง (Variance Report)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(movementHistoryProvider);
              ref.read(stockBalanceProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: movementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (movements) => stockAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
                    stock?.warehouseName ?? _warehouseName(m.warehouseId),
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
                    d.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
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
    );
  }

  // ── Filter Bar ────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.teal[50],
      child: Row(
        children: [
          // ประเภท
          const Text(
            'ประเภท:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'ทั้งหมด',
            selected: _filterType == 'ALL',
            color: Colors.teal,
            onTap: () => setState(() => _filterType = 'ALL'),
          ),
          const SizedBox(width: 4),
          _FilterChip(
            label: '↑ เกิน',
            selected: _filterType == 'INCREASE',
            color: Colors.blue,
            onTap: () => setState(() => _filterType = 'INCREASE'),
          ),
          const SizedBox(width: 4),
          _FilterChip(
            label: '↓ ขาด',
            selected: _filterType == 'DECREASE',
            color: Colors.red,
            onTap: () => setState(() => _filterType = 'DECREASE'),
          ),
          const SizedBox(width: 16),

          // คลัง
          const Text(
            'คลัง:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _filterWarehouse,
            isDense: true,
            items: _warehouses
                .map(
                  (w) => DropdownMenuItem(
                    value: w['id'],
                    child: Text(
                      w['name']!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _filterWarehouse = v ?? 'ALL'),
          ),
          const SizedBox(width: 16),

          // ช่วงวันที่
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: BorderSide(color: Colors.teal.shade300),
            ),
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _dateRange = null),
              tooltip: 'ล้างวันที่',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _SummaryStatCard(
            label: 'รายการทั้งหมด',
            value: '${items.length}',
            unit: 'รายการ',
            icon: Icons.list_alt,
            color: Colors.teal,
          ),
          const SizedBox(width: 10),
          _SummaryStatCard(
            label: 'สต๊อกเกิน',
            value: '+${totalIncrease.toStringAsFixed(0)}',
            unit: '(${increaseItems.length} รายการ)',
            icon: Icons.arrow_upward,
            color: Colors.blue,
          ),
          const SizedBox(width: 10),
          _SummaryStatCard(
            label: 'สต๊อกขาด',
            value: '-${totalDecrease.toStringAsFixed(0)}',
            unit: '(${decreaseItems.length} รายการ)',
            icon: Icons.arrow_downward,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────
  Widget _buildTable(List<_VarianceItem> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Header
          _buildTableHeader(),
          // Rows
          ...items.map((item) => _buildTableRow(item)),
        ],
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
        color: Colors.teal[700],
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
    final varColor = isIncrease ? Colors.blue[700]! : Colors.red[700]!;
    final rowBg = isIncrease ? Colors.blue[50]! : Colors.red[50]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
                  ),
                ),
                Text(
                  item.productCode,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
              style: const TextStyle(fontSize: 12),
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
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),

          // หมายเหตุ
          Expanded(
            flex: 2,
            child: Text(
              item.remark ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
              style: const TextStyle(fontSize: 11),
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
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            noAdjustAtAll
                ? 'ยังไม่มีการปรับสต๊อก\nกรุณานับสต๊อกผ่านหน้า "ตรวจนับสต๊อก" ก่อน'
                : 'ไม่พบข้อมูลในช่วงที่เลือก',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.6),
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
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal)),
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
          border: Border.all(color: selected ? color : Colors.grey[400]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.grey[700],
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
    return Expanded(
      child: Container(
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
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 🔲 Placeholder สำหรับ Step ที่ยังไม่ได้สร้าง
// ════════════════════════════════════════════════════════════════
class _PlaceholderPage extends StatelessWidget {
  final int step;
  final String title;
  final String description;

  const _PlaceholderPage({
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Step $step: $title')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 80, color: Colors.amber[700]),
              const SizedBox(height: 24),
              Text(
                'Step $step',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🚧 กำลังสร้างในขั้นตอนถัดไป...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
