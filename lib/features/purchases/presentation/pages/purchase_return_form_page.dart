import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../data/models/goods_receipt_item_model.dart';
import '../../data/models/goods_receipt_model.dart';
import '../../data/models/purchase_return_model.dart';
import '../../data/models/purchase_return_item_model.dart';
import '../providers/goods_receipt_provider.dart';
import '../providers/purchase_return_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
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
  String? _referenceType;
  String? _referenceId;
  GoodsReceiptModel? _sourceReceipt;
  Map<String, double> _confirmedReturnedQtyByProduct = {};

  final List<PurchaseReturnItemModel> _items = [];
  bool _isLoading = false;
  bool _isViewMode = false;
  bool _isCardView = false;
  bool _isLoadingReference = false;

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
      _referenceType = d.referenceType;
      _referenceId = d.referenceId;
      _isViewMode = d.isConfirmed;
      if (d.items != null) _items.addAll(d.items!);
      if (_referenceType == 'GOODS_RECEIPT' && _referenceId != null) {
        _isLoadingReference = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadSourceReceipt(_referenceId!);
        });
      }
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
    ref.watch(supplierListProvider);
    ref.watch(goodsReceiptListProvider);

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
                                  if (_sourceReceipt != null)
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
        const SizedBox(height: 12),

        _PRFieldLabel('ใบรับสินค้าอ้างอิง'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isViewMode ? null : _selectReferenceReceipt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _referenceId == null
                    ? AppTheme.warning.withValues(alpha: 0.5)
                    : isDark
                    ? const Color(0xFF3A3A3A)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_outlined,
                  size: 16,
                  color: _referenceId != null
                      ? AppTheme.info
                      : AppTheme.textSub,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sourceReceipt != null
                        ? '${_sourceReceipt!.grNo} • ${_sourceReceipt!.warehouseName}'
                        : _referenceId != null
                        ? 'อ้างอิง ${_referenceId!}'
                        : _supplierId == null
                        ? 'เลือกซัพพลายเออร์ก่อน'
                        : _isLoadingReference
                        ? 'กำลังโหลดใบรับสินค้า...'
                        : 'แตะเพื่อเลือกใบรับสินค้าอ้างอิง',
                    style: TextStyle(
                      fontSize: 13,
                      color: _sourceReceipt != null
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
        if (_sourceReceipt != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.info.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'คืนสินค้าได้เฉพาะรายการจาก ${_sourceReceipt!.grNo}'
              ' เข้าคลัง ${_sourceReceipt!.warehouseName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

    if (_sourceReceipt == null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inventory_outlined,
                size: 40,
                color: isDark ? const Color(0xFF555555) : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณาเลือกใบรับสินค้าอ้างอิงก่อน',
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: isDark ? Colors.white24 : AppTheme.border,
              ),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: isDark ? Colors.white60 : AppTheme.textSub,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'บันทึกใบคืนสินค้า',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
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
      final supplierChanged = _supplierId != null && _supplierId != selected['id'];
      setState(() {
        _supplierId = selected['id'];
        _supplierName = selected['name'];
        if (supplierChanged) {
          _referenceType = null;
          _referenceId = null;
          _sourceReceipt = null;
          _confirmedReturnedQtyByProduct = {};
          _items.clear();
        }
      });
    }
  }

  Future<void> _selectReferenceReceipt() async {
    if (_supplierId == null) {
      _showSnack('กรุณาเลือกซัพพลายเออร์ก่อน');
      return;
    }

    final receiptsAsync = ref.read(goodsReceiptListProvider);
    final receipts = receiptsAsync.value;
    if (receipts == null) {
      _showSnack('กำลังโหลดใบรับสินค้า...');
      return;
    }

    final candidateReceipts = receipts
        .where(
          (receipt) =>
              receipt.supplierId == _supplierId && receipt.status == 'CONFIRMED',
        )
        .toList()
      ..sort((a, b) => b.grDate.compareTo(a.grDate));

    if (candidateReceipts.isEmpty) {
      _showSnack('ไม่พบใบรับสินค้าที่ยืนยันแล้วของซัพพลายเออร์นี้');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showDialog<GoodsReceiptModel>(
      context: context,
      builder: (ctx) => _ReceiptSelectionDialog(
        receipts: candidateReceipts,
        isDark: isDark,
      ),
    );

    if (selected == null || !mounted) return;
    await _loadSourceReceipt(selected.grId, clearItems: true);
  }

  Future<void> _loadSourceReceipt(
    String grId, {
    bool clearItems = false,
  }) async {
    setState(() => _isLoadingReference = true);

    final receipt = await ref
        .read(goodsReceiptListProvider.notifier)
        .getGoodsReceiptDetails(grId);
    final confirmedReturnedQtyByProduct = receipt == null
        ? <String, double>{}
        : await _loadConfirmedReturnedQtyByProduct(grId);

    if (!mounted) return;

    setState(() {
      _isLoadingReference = false;
      _referenceType = receipt == null ? null : 'GOODS_RECEIPT';
      _referenceId = receipt?.grId;
      _sourceReceipt = receipt;
      _confirmedReturnedQtyByProduct = confirmedReturnedQtyByProduct;
      if (clearItems) _items.clear();
    });

    if (receipt == null) {
      _showSnack('โหลดรายละเอียดใบรับสินค้าไม่สำเร็จ');
    }
  }

  Future<void> _addItem() async {
    if (_sourceReceipt == null) {
      _showSnack('กรุณาเลือกใบรับสินค้าอ้างอิงก่อน');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<PurchaseReturnItemModel>(
      context: context,
      builder: (ctx) => _ItemDialog(
        receipt: _sourceReceipt!,
        confirmedReturnedQtyByProduct: _confirmedReturnedQtyByProduct,
        existingItems: _items,
        lineNo: _items.length + 1,
        isDark: isDark,
      ),
    );
    if (result != null) setState(() => _items.add(result));
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      _showSnack('กรุณาเลือกซัพพลายเออร์');
      return;
    }
    if (_referenceId == null || _referenceType != 'GOODS_RECEIPT') {
      _showSnack('กรุณาเลือกใบรับสินค้าอ้างอิง');
      return;
    }
    if (_items.isEmpty) {
      _showSnack('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ');
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
      referenceType: _referenceType,
      referenceId: _referenceId,
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

    final success = widget.returnDoc == null
        ? await ref.read(purchaseReturnListProvider.notifier).createReturn(doc)
        : await ref.read(purchaseReturnListProvider.notifier).updateReturn(doc);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.returnDoc == null
                  ? 'บันทึกใบคืนสินค้าสำเร็จ'
                  : 'แก้ไขใบคืนสินค้าสำเร็จ',
            ),
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

  void _showSnack(String message, {Color backgroundColor = AppTheme.error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, double>> _loadConfirmedReturnedQtyByProduct(
    String grId,
  ) async {
    final returns = ref.read(purchaseReturnListProvider).value ?? const <PurchaseReturnModel>[];
    final confirmedReturns = returns
        .where(
          (doc) =>
              doc.status == 'CONFIRMED' &&
              doc.referenceType == 'GOODS_RECEIPT' &&
              doc.referenceId == grId,
        )
        .toList();

    final qtyByProduct = <String, double>{};

    for (final doc in confirmedReturns) {
      final fullDoc = await ref
          .read(purchaseReturnListProvider.notifier)
          .getReturnDetails(doc.returnId);
      for (final item in fullDoc?.items ?? const <PurchaseReturnItemModel>[]) {
        qtyByProduct[item.productId] =
            (qtyByProduct[item.productId] ?? 0) + item.quantity;
      }
    }

    return qtyByProduct;
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
// RECEIPT SELECTION DIALOG
// ═══════════════════════════════════════════════════════════════
class _ReceiptSelectionDialog extends StatefulWidget {
  final List<GoodsReceiptModel> receipts;
  final bool isDark;

  const _ReceiptSelectionDialog({
    required this.receipts,
    required this.isDark,
  });

  @override
  State<_ReceiptSelectionDialog> createState() => _ReceiptSelectionDialogState();
}

class _ReceiptSelectionDialogState extends State<_ReceiptSelectionDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.receipts
        .where(
          (receipt) =>
              receipt.grNo.toLowerCase().contains(_search) ||
              receipt.warehouseName.toLowerCase().contains(_search),
        )
        .toList();
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Dialog(
      backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(
                  alpha: widget.isDark ? 0.10 : 0.06,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เลือกใบรับสินค้าอ้างอิง',
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
                      color: widget.isDark ? Colors.white54 : AppTheme.textSub,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'ค้นหาเลขที่ใบรับสินค้า หรือคลัง...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: widget.isDark
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
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final receipt = filtered[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(ctx, receipt),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.white12
                              : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.grNo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'วันที่ ${dateFmt.format(receipt.grDate)} • ${receipt.warehouseName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? const Color(0xFFAAAAAA)
                                  : AppTheme.textSub,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${receipt.itemCount} รายการ',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.info,
                              fontWeight: FontWeight.w600,
                            ),
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
  final GoodsReceiptModel receipt;
  final Map<String, double> confirmedReturnedQtyByProduct;
  final List<PurchaseReturnItemModel> existingItems;
  final int lineNo;
  final bool isDark;

  const _ItemDialog({
    required this.receipt,
    required this.confirmedReturnedQtyByProduct,
    required this.existingItems,
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
  final _reasonCtrl = TextEditingController();

  List<_ReturnableReceiptItemOption> get _options {
    final source = <String, _ReturnableReceiptItemOption>{};
    for (final item in widget.receipt.items ?? <GoodsReceiptItemModel>[]) {
      final current = source[item.productId];
      source[item.productId] = current == null
          ? _ReturnableReceiptItemOption.fromReceiptItem(item)
          : current.accumulate(item);
    }

    widget.confirmedReturnedQtyByProduct.forEach((productId, qty) {
      final current = source[productId];
      if (current != null) {
        source[productId] = current.take(qty);
      }
    });

    for (final existing in widget.existingItems) {
      final current = source[existing.productId];
      if (current != null) {
        source[existing.productId] = current.take(existing.quantity);
      }
    }

    return source.values
        .where((item) => item.remainingQty > 0)
        .where(
          (item) =>
              item.productName.toLowerCase().contains(_search) ||
              item.productCode.toLowerCase().contains(_search),
        )
        .toList()
      ..sort((a, b) => a.productCode.compareTo(b.productCode));
  }

  _ReturnableReceiptItemOption? get _selectedOption {
    if (_selectedProductId == null) return null;
    for (final option in _options) {
      if (option.productId == _selectedProductId) return option;
    }
    return null;
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final selected = _selectedOption;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Column(
          children: [
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
                  Expanded(
                    child: Text(
                      'เพิ่มจาก ${widget.receipt.grNo}',
                      style: const TextStyle(
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
                    _DialogFieldLabel('สินค้าในใบรับสินค้า', isDark: isDark),
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
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3A3A)
                              : AppTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _options.isEmpty
                          ? Center(
                              child: Text(
                                'ไม่มีรายการที่คืนได้เพิ่มเติม',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFAAAAAA)
                                      : AppTheme.textSub,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _options.length,
                              itemBuilder: (ctx, i) {
                                final option = _options[i];
                                final isSelected =
                                    _selectedProductId == option.productId;
                                return InkWell(
                                  onTap: () => setState(() {
                                    _selectedProductId = option.productId;
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${option.productCode} - ${option.productName}',
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
                                              Text(
                                                'คงเหลือให้คืน ${NumberFormat('#,##0.##').format(option.remainingQty)} ${option.unit}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.info,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ReadOnlyInfoField(
                              label: 'คลังต้นทาง',
                              value: widget.receipt.warehouseName,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ReadOnlyInfoField(
                              label: 'ราคา/หน่วย',
                              value:
                                  '฿${NumberFormat('#,##0.00').format(selected.unitPrice)}',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DialogFieldLabel('จำนวนคืน', isDark: isDark),
                      const SizedBox(height: 4),
                      _DialogTextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        isDark: isDark,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'คืนได้สูงสุด ${NumberFormat('#,##0.##').format(selected.remainingQty)} ${selected.unit}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'รวมเป็นเงิน ฿${NumberFormat('#,##0.00').format((_qty > 0 ? _qty : 0) * selected.unitPrice)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DialogFieldLabel('เหตุผลการคืน', isDark: isDark),
                      const SizedBox(height: 4),
                      _DialogTextField(
                        controller: _reasonCtrl,
                        hintText: 'สินค้าชำรุด, ส่งผิด, ฯลฯ',
                        maxLines: 2,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
    final selected = _selectedOption;
    if (selected == null) {
      _snack('กรุณาเลือกรายการสินค้า');
      return;
    }

    final quantity = _qty;
    if (quantity <= 0) {
      _snack('กรุณาระบุจำนวนคืนที่ถูกต้อง');
      return;
    }
    if (quantity > selected.remainingQty) {
      _snack(
        'จำนวนคืนเกินยอดคงเหลือ (${selected.remainingQty.toStringAsFixed(2)} ${selected.unit})',
      );
      return;
    }

    Navigator.pop(
      context,
      PurchaseReturnItemModel(
        itemId: '',
        returnId: '',
        lineNo: widget.lineNo,
        productId: selected.productId,
        productCode: selected.productCode,
        productName: selected.productName,
        unit: selected.unit,
        warehouseId: widget.receipt.warehouseId,
        warehouseName: widget.receipt.warehouseName,
        quantity: quantity,
        unitPrice: selected.unitPrice,
        amount: quantity * selected.unitPrice,
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ReturnableReceiptItemOption {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double remainingQty;
  final double unitPrice;

  const _ReturnableReceiptItemOption({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.remainingQty,
    required this.unitPrice,
  });

  factory _ReturnableReceiptItemOption.fromReceiptItem(GoodsReceiptItemModel item) {
    final receivedQty = item.receivedQuantity;
    final unitPrice = receivedQty <= 0 ? item.unitPrice : item.amount / receivedQty;
    return _ReturnableReceiptItemOption(
      productId: item.productId,
      productCode: item.productCode,
      productName: item.productName,
      unit: item.unit,
      remainingQty: receivedQty,
      unitPrice: unitPrice,
    );
  }

  _ReturnableReceiptItemOption accumulate(GoodsReceiptItemModel item) {
    final nextQty = remainingQty + item.receivedQuantity;
    final nextAmount = (remainingQty * unitPrice) + item.amount;
    return _ReturnableReceiptItemOption(
      productId: productId,
      productCode: productCode,
      productName: productName,
      unit: unit,
      remainingQty: nextQty,
      unitPrice: nextQty <= 0 ? unitPrice : nextAmount / nextQty,
    );
  }

  _ReturnableReceiptItemOption take(double usedQty) {
    return _ReturnableReceiptItemOption(
      productId: productId,
      productCode: productCode,
      productName: productName,
      unit: unit,
      remainingQty:
          (remainingQty - usedQty).clamp(0, double.infinity).toDouble(),
      unitPrice: unitPrice,
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

class _ReadOnlyInfoField extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ReadOnlyInfoField({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DialogFieldLabel(label, isDark: isDark),
      const SizedBox(height: 4),
      Container(
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
          value,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    ],
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
