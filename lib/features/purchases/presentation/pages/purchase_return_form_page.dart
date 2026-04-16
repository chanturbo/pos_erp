import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../data/models/purchase_return_model.dart';
import '../../data/models/purchase_return_item_model.dart';
import '../providers/purchase_return_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PurchaseReturnFormPage extends ConsumerStatefulWidget {
  final PurchaseReturnModel? returnDoc;
  const PurchaseReturnFormPage({super.key, this.returnDoc});

  @override
  ConsumerState<PurchaseReturnFormPage> createState() =>
      _PurchaseReturnFormPageState();
}

class _PurchaseReturnFormPageState
    extends ConsumerState<PurchaseReturnFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _returnNoController;
  late TextEditingController _reasonController;
  late TextEditingController _remarkController;

  DateTime _returnDate = DateTime.now();
  String? _supplierId;
  String? _supplierName;

  final List<PurchaseReturnItemModel> _items = [];
  bool _isLoading = false;
  bool _isViewMode = false;
  bool _isCardView = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (widget.returnDoc != null) {
      final d = widget.returnDoc!;
      _returnNoController = TextEditingController(text: d.returnNo);
      _reasonController = TextEditingController(text: d.reason ?? '');
      _remarkController = TextEditingController(text: d.remark ?? '');
      _returnDate = d.returnDate;
      _supplierId = d.supplierId;
      _supplierName = d.supplierName;
      _isViewMode = d.isConfirmed;
      if (d.items != null) _items.addAll(d.items!);
    } else {
      final ts = DateTime.now().millisecondsSinceEpoch;
      _returnNoController = TextEditingController(
        text: 'PRET${ts.toString().substring(8)}',
      );
      _reasonController = TextEditingController();
      _remarkController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _returnNoController.dispose();
    _reasonController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Preload data so dialogs open immediately on first tap
    ref.watch(productListProvider);
    ref.watch(supplierListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Title Bar ────────────────────────────────────────
            _PRFormTitleBar(
              isEdit: widget.returnDoc != null,
              isViewMode: _isViewMode,
            ),

            // ── Form Body ────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── ข้อมูลทั่วไป ──────────────────────────
                      _SectionCard(
                        icon: Icons.info_outline,
                        title: 'ข้อมูลทั่วไป',
                        color: AppTheme.error,
                        child: _buildGeneralSection(isDark),
                      ),
                      const SizedBox(height: 14),

                      // ── รายการสินค้า ──────────────────────────
                      _SectionCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'รายการสินค้าที่คืน',
                        color: AppTheme.info,
                        trailing: _isViewMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Toggle view
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _isCardView = !_isCardView,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.info.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppTheme.info.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        _isCardView
                                            ? Icons.view_list
                                            : Icons.grid_view,
                                        size: 16,
                                        color: AppTheme.info,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Add button
                                  if (_supplierId != null)
                                    GestureDetector(
                                      onTap: _addItem,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'เพิ่ม',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                        child: _buildItemsSection(isDark),
                      ),
                      const SizedBox(height: 14),

                      // ── สรุปยอด ───────────────────────────────
                      if (_items.isNotEmpty) ...[
                        _SectionCard(
                          icon: Icons.summarize_outlined,
                          title: 'สรุปยอด',
                          color: AppTheme.error,
                          child: _buildSummarySection(isDark),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── เหตุผล / หมายเหตุ ─────────────────────
                      _SectionCard(
                        icon: Icons.note_alt_outlined,
                        title: 'เหตุผล / หมายเหตุ',
                        color: AppTheme.warning,
                        child: _buildRemarkSection(isDark),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Actions ────────────────────────────────────
            if (!_isViewMode) _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Section builders
  // ─────────────────────────────────────────────────────────────
  Widget _buildGeneralSection(bool isDark) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // เลขที่ใบคืน (read-only)
        _PRFieldLabel('เลขที่ใบคืนสินค้า'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.receipt_outlined,
                size: 16,
                color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
              ),
              const SizedBox(width: 8),
              Text(
                _returnNoController.text,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // วันที่คืน
        _PRFieldLabel('วันที่คืนสินค้า'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isViewMode ? null : _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.error),
                const SizedBox(width: 8),
                Text(
                  dateFmt.format(_returnDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (!_isViewMode)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ซัพพลายเออร์
        _PRFieldLabel('ซัพพลายเออร์'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isViewMode ? null : _selectSupplier,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _supplierId == null
                    ? AppTheme.error.withValues(alpha: 0.5)
                    : isDark
                    ? const Color(0xFF3A3A3A)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 16,
                  color: _supplierId != null
                      ? AppTheme.error
                      : AppTheme.textSub,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _supplierName ?? 'แตะเพื่อเลือกซัพพลายเออร์',
                    style: TextStyle(
                      fontSize: 13,
                      color: _supplierName != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : AppTheme.textSub,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isViewMode)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(bool isDark) {
    if (_supplierId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.business_outlined,
                size: 40,
                color: isDark ? const Color(0xFF555555) : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณาเลือกซัพพลายเออร์ก่อน',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: isDark ? const Color(0xFF555555) : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                'ยังไม่มีรายการสินค้า',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                ),
              ),
              if (!_isViewMode) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('เพิ่มสินค้า'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _isCardView
        ? Column(
            children: _items.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ItemCard(
                  item: e.value,
                  index: e.key,
                  isViewMode: _isViewMode,
                  onDelete: () => setState(() => _items.removeAt(e.key)),
                  isDark: isDark,
                ),
              );
            }).toList(),
          )
        : Column(
            children: [
              // List header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'สินค้า',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        'จำนวน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        'รวม',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFAAAAAA)
                              : AppTheme.textSub,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (!_isViewMode) const SizedBox(width: 28),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ..._items.asMap().entries.map((e) {
                final item = e.value;
                final i = e.key;
                final isEven = i.isEven;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
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
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF888888)
                                : AppTheme.textSub,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.productCode,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF888888)
                                    : AppTheme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${NumberFormat('#,##0.##').format(item.quantity)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          '฿${NumberFormat('#,##0.00').format(item.amount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFEF9A9A)
                                : AppTheme.error,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      if (!_isViewMode)
                        SizedBox(
                          width: 28,
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 15,
                              color: isDark
                                  ? const Color(0xFF888888)
                                  : AppTheme.textSub,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          );
  }

  Widget _buildSummarySection(bool isDark) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final total = _items.fold<double>(0, (s, item) => s + item.amount);

    return Column(
      children: [
        _SummaryRow(
          label: 'จำนวนรายการ',
          value: '${_items.length} รายการ',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Divider(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
          height: 1,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ยอดรวมที่คืน',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '฿${fmt.format(total)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFEF9A9A) : AppTheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemarkSection(bool isDark) {
    if (_isViewMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PRFieldLabel('เหตุผลการคืน'),
          const SizedBox(height: 4),
          _ViewField(
            text: _reasonController.text.isEmpty ? '-' : _reasonController.text,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _PRFieldLabel('หมายเหตุ'),
          const SizedBox(height: 4),
          _ViewField(
            text: _remarkController.text.isEmpty ? '-' : _remarkController.text,
            isDark: isDark,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PRFieldLabel('เหตุผลการคืน'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'สินค้าชำรุด, ส่งผิด, ฯลฯ',
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.warning_amber_outlined, size: 18),
            filled: true,
            fillColor: isDark ? AppTheme.darkElement : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PRFieldLabel('หมายเหตุ'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _remarkController,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'หมายเหตุเพิ่มเติม...',
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
            filled: true,
            fillColor: isDark ? AppTheme.darkElement : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Bottom Bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
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
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
                ),
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
              ),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'บันทึกใบคืนสินค้า',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _returnDate = date);
  }

  Future<void> _selectSupplier() async {
    final suppliers = ref.read(supplierListProvider).value;
    if (suppliers == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) =>
          _SupplierSelectionDialog(suppliers: suppliers, isDark: isDark),
    );
    if (selected != null && mounted) {
      setState(() {
        _supplierId = selected['id'];
        _supplierName = selected['name'];
      });
    }
  }

  Future<void> _addItem() async {
    final products = ref.read(productListProvider).value;
    if (products == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำลังโหลดข้อมูลสินค้า...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<PurchaseReturnItemModel>(
      context: context,
      builder: (ctx) => _ItemDialog(
        products: products,
        lineNo: _items.length + 1,
        isDark: isDark,
      ),
    );
    if (result != null) setState(() => _items.add(result));
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกซัพพลายเออร์'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authState = ref.read(authProvider);
    final total = _items.fold<double>(0, (s, item) => s + item.amount);

    final doc = PurchaseReturnModel(
      returnId: widget.returnDoc?.returnId ?? '',
      returnNo: _returnNoController.text.trim(),
      returnDate: _returnDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: total,
      status: 'DRAFT',
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      userId: authState.user!.userId,
      createdAt: widget.returnDoc?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      items: _items,
    );

    final success = await ref
        .read(purchaseReturnListProvider.notifier)
        .createReturn(doc);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกใบคืนสินค้าสำเร็จ'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TITLE BAR
// ═══════════════════════════════════════════════════════════════
class _PRFormTitleBar extends StatelessWidget {
  final bool isEdit;
  final bool isViewMode;
  const _PRFormTitleBar({required this.isEdit, required this.isViewMode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkTopBar : AppTheme.navy;
    final safeTop = MediaQuery.of(context).padding.top;

    final String title;
    if (isViewMode) {
      title = 'รายละเอียดใบคืนสินค้า';
    } else if (isEdit) {
      title = 'แก้ไขใบคืนสินค้า';
    } else {
      title = 'สร้างใบคืนสินค้า';
    }

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(4, safeTop + 6, 12, 10),
      child: Row(
        children: [
          context.isMobile
              ? buildMobileHomeCompactButton(context, isDark: true)
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_return,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (isViewMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'ยืนยันแล้ว',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.success,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.10 : 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Body
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ITEM CARD (card view)
// ═══════════════════════════════════════════════════════════════
class _ItemCard extends StatelessWidget {
  final PurchaseReturnItemModel item;
  final int index;
  final bool isViewMode;
  final VoidCallback onDelete;
  final bool isDark;

  const _ItemCard({
    required this.item,
    required this.index,
    required this.isViewMode,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.productCode,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF888888)
                            : AppTheme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isViewMode)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppTheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                label: 'จำนวน',
                value:
                    '${NumberFormat('#,##0.##').format(item.quantity)} ${item.unit}',
                color: AppTheme.info,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'ราคา/หน่วย',
                value: '฿${fmt.format(item.unitPrice)}',
                color: AppTheme.warning,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'รวม',
                value: '฿${fmt.format(item.amount)}',
                color: AppTheme.error,
                isDark: isDark,
              ),
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 13,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'เหตุผล: ${item.reason}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUPPLIER SELECTION DIALOG
// ═══════════════════════════════════════════════════════════════
class _SupplierSelectionDialog extends StatefulWidget {
  final List suppliers;
  final bool isDark;
  const _SupplierSelectionDialog({
    required this.suppliers,
    required this.isDark,
  });

  @override
  State<_SupplierSelectionDialog> createState() =>
      _SupplierSelectionDialogState();
}

class _SupplierSelectionDialogState extends State<_SupplierSelectionDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = widget.suppliers
        .where(
          (s) =>
              s.supplierName.toLowerCase().contains(_search) ||
              s.supplierCode.toLowerCase().contains(_search),
        )
        .toList();

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เลือกซัพพลายเออร์',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white54 : AppTheme.textSub,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'ค้นหาซัพพลายเออร์...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkElement
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(ctx, <String, String>{
                      'id': s.supplierId,
                      'name': s.supplierName,
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white12 : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.error.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              s.supplierName.isNotEmpty
                                  ? s.supplierName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.supplierName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  s.supplierCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF888888)
                                        : AppTheme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppTheme.textSub,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ITEM DIALOG
// ═══════════════════════════════════════════════════════════════
class _ItemDialog extends StatefulWidget {
  final List products;
  final int lineNo;
  final bool isDark;

  const _ItemDialog({
    required this.products,
    required this.lineNo,
    required this.isDark,
  });

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  String? _selectedProductId;
  String _search = '';
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();
  ProductUnitOption? _selectedUnit;

  ProductModel? get _product {
    if (_selectedProductId == null) return null;
    for (final p in widget.products) {
      if (p.productId == _selectedProductId) return p;
    }
    return null;
  }

  double get _baseQty {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    return qty * (_selectedUnit?.factor ?? 1);
  }

  double get _baseCost {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final factor = _selectedUnit?.factor ?? 1;
    return factor == 0 ? price : price / factor;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = widget.products
        .where(
          (p) =>
              p.productName.toLowerCase().contains(_search) ||
              p.productCode.toLowerCase().contains(_search),
        )
        .toList();

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_shopping_cart,
                    size: 18,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เพิ่มรายการสินค้า',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.info,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white54 : AppTheme.textSub,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search + Product selector
                    _DialogFieldLabel('สินค้า', isDark: isDark),
                    const SizedBox(height: 4),
                    TextField(
                      onChanged: (v) =>
                          setState(() => _search = v.toLowerCase()),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาสินค้า...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3A3A)
                              : AppTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final p = filtered[i];
                          final isSelected = _selectedProductId == p.productId;
                          return InkWell(
                            onTap: () => setState(() {
                              _selectedProductId = p.productId;
                              _selectedUnit = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: isSelected
                                  ? AppTheme.info.withValues(alpha: 0.12)
                                  : null,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppTheme.info,
                                    )
                                  else
                                    const SizedBox(width: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${p.productCode} - ${p.productName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Unit dropdown
                    if (_product != null) ...[
                      _DialogFieldLabel('หน่วย', isDark: isDark),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUnit?.unit,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkElement
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3A3A3A)
                                  : AppTheme.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3A3A3A)
                                  : AppTheme.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.error,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: _product!.allUnits
                            .map<DropdownMenuItem<String>>(
                              (u) => DropdownMenuItem(
                                value: u.unit,
                                child: Text(
                                  u.factor == 1
                                      ? u.unit
                                      : '${u.unit}  (1 ${u.unit} = ${u.factor.toStringAsFixed(0)} ${_product!.baseUnit})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedUnit = _product!.allUnits.firstWhere(
                            (u) => u.unit == v,
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Qty + Price
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DialogFieldLabel('จำนวน', isDark: isDark),
                              const SizedBox(height: 4),
                              _DialogTextField(
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DialogFieldLabel('ราคา/หน่วย', isDark: isDark),
                              const SizedBox(height: 4),
                              _DialogTextField(
                                controller: _priceCtrl,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Conversion preview card
                    if (_product != null &&
                        _selectedUnit != null &&
                        _selectedUnit!.factor != 1) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.swap_horiz,
                              size: 14,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'คืนจริง ${_baseQty.toStringAsFixed(0)} ${_product!.baseUnit}'
                                '  •  ต้นทุน/ฐาน ${_baseCost.toStringAsFixed(2)} บาท',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Reason
                    _DialogFieldLabel('เหตุผลการคืน', isDark: isDark),
                    const SizedBox(height: 4),
                    _DialogTextField(
                      controller: _reasonCtrl,
                      hintText: 'สินค้าชำรุด, ส่งผิด, ฯลฯ',
                      maxLines: 2,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('เพิ่ม'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสินค้า'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final baseQty = _baseQty;
    final baseCost = _baseCost;
    if (baseQty <= 0 || baseCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนและราคาที่ถูกต้อง'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final product = widget.products.firstWhere(
      (p) => p.productId == _selectedProductId,
    );
    Navigator.pop(
      context,
      PurchaseReturnItemModel(
        itemId: '',
        returnId: '',
        lineNo: widget.lineNo,
        productId: product.productId,
        productCode: product.productCode,
        productName: product.productName,
        unit: product.baseUnit,
        warehouseId: 'WH001',
        warehouseName: 'คลังหลัก',
        quantity: baseQty,
        unitPrice: baseCost,
        amount: baseCost * baseQty,
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════
class _PRFieldLabel extends StatelessWidget {
  final String text;
  const _PRFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSub,
      ),
    );
  }
}

class _DialogFieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _DialogFieldLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
    ),
  );
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final TextInputType keyboardType;
  final int maxLines;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _DialogTextField({
    required this.controller,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    onChanged: onChanged,
    style: TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    ),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: isDark ? AppTheme.darkElement : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _ViewField extends StatelessWidget {
  final String text;
  final bool isDark;
  const _ViewField({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white70 : AppTheme.textSub,
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppTheme.textSub,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    ],
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
