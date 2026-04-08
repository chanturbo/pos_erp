import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../pages/payment_page.dart';
import '../widgets/discount_dialog.dart';
import '../../../products/presentation/providers/product_provider.dart'; // ✅ scan เพิ่มสินค้า
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ MobileScannerService
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/cart_toast.dart';

// ── OAG Tokens ────────────────────────────────────────────────────
const _navy = AppTheme.navyColor;
const _orange = AppTheme.primaryColor;
const _surface = AppTheme.surfaceColor;
const _border = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _error = AppTheme.errorColor;
const _info = AppTheme.infoColor;

// ─────────────────────────────────────────────────────────────────
// CartPanel
// ─────────────────────────────────────────────────────────────────
class CartPanel extends ConsumerStatefulWidget {
  final bool showScanRow;
  final bool autofocusScan;

  const CartPanel({
    super.key,
    this.showScanRow = true,
    this.autofocusScan = true,
  });

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final _scrollController = ScrollController();
  int _prevItemCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── เลื่อน scroll ไปที่รายการล่าสุด ──────────────────────────
  void _scrollToBottom() {
    // ถ้า scroll ไม่ได้ (content ยังไม่เกิน viewport) → ไม่ต้องทำ
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _scrollController.animateTo(
      maxScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    // ดักจับเมื่อจำนวน item เพิ่มขึ้น → scroll ลงล่าง
    // ใช้ addPostFrameCallback เพื่อรอให้ ListView render ก่อน
    if (cartState.items.length > _prevItemCount) {
      _prevItemCount = cartState.items.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      _prevItemCount = cartState.items.length;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final density = _CartPanelDensity.fromWidth(constraints.maxWidth);

        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            border: Border(left: BorderSide(color: _border)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              _CartHeader(
                itemCount: cartState.itemCount,
                onClear: cartState.items.isEmpty
                    ? null
                    : () => ref.read(cartProvider.notifier).clear(),
              ),

              // ── Scan Row ─────────────────────────────────────────
              if (widget.showScanRow)
                _ScanRow(
                  ref: ref,
                  autofocus: widget.autofocusScan,
                  compact: density.compact,
                ),

              // ── Column labels ────────────────────────────────────
              if (cartState.items.isNotEmpty && !density.stackedRows)
                _ColHeader(density: density),

              // ── Cart Items ───────────────────────────────────────
              Expanded(
                child: cartState.items.isEmpty && cartState.freeItems.isEmpty
                    ? const _EmptyCart()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount:
                            cartState.items.length +
                            (cartState.hasFreeItems
                                ? 1 + cartState.freeItems.length
                                : 0),
                        itemBuilder: (_, i) {
                          // regular items
                          if (i < cartState.items.length) {
                            return _CartRow(
                              item: cartState.items[i],
                              isEven: i.isEven,
                              density: density,
                            );
                          }
                          // free items header
                          if (i == cartState.items.length) {
                            return _FreeItemsHeader(
                              count: cartState.freeItems.length,
                            );
                          }
                          // free item rows
                          final fi = cartState
                              .freeItems[i - cartState.items.length - 1];
                          return _FreeItemRow(item: fi, density: density);
                        },
                      ),
              ),

              // ── Summary ──────────────────────────────────────────
              _CartSummary(cartState: cartState, density: density),
            ],
          ),
        );
      },
    );
  }
}

class _CartPanelDensity {
  final bool compact;
  final bool stackedRows;
  final double controlWidth;
  final double amountWidth;
  final double leadingWidth;
  final double horizontalPadding;
  final double qtyBoxWidth;
  final double qtyBoxHeight;
  final double rowFontSize;
  final double metaFontSize;
  final double amountFontSize;

  const _CartPanelDensity({
    required this.compact,
    required this.stackedRows,
    required this.controlWidth,
    required this.amountWidth,
    required this.leadingWidth,
    required this.horizontalPadding,
    required this.qtyBoxWidth,
    required this.qtyBoxHeight,
    required this.rowFontSize,
    required this.metaFontSize,
    required this.amountFontSize,
  });

  factory _CartPanelDensity.fromWidth(double width) {
    if (width < 340) {
      return const _CartPanelDensity(
        compact: true,
        stackedRows: true,
        controlWidth: 120,
        amountWidth: 88,
        leadingWidth: 28,
        horizontalPadding: 8,
        qtyBoxWidth: 34,
        qtyBoxHeight: 26,
        rowFontSize: 11,
        metaFontSize: 10,
        amountFontSize: 12,
      );
    }

    if (width < 420) {
      return const _CartPanelDensity(
        compact: true,
        stackedRows: false,
        controlWidth: 80,
        amountWidth: 60,
        leadingWidth: 24,
        horizontalPadding: 6,
        qtyBoxWidth: 30,
        qtyBoxHeight: 24,
        rowFontSize: 11,
        metaFontSize: 9,
        amountFontSize: 11,
      );
    }

    return const _CartPanelDensity(
      compact: false,
      stackedRows: false,
      controlWidth: 92,
      amountWidth: 68,
      leadingWidth: 28,
      horizontalPadding: 8,
      qtyBoxWidth: 36,
      qtyBoxHeight: 26,
      rowFontSize: 12,
      metaFontSize: 10,
      amountFontSize: 12,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Header — Navy bar + item count badge
// ─────────────────────────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  final int itemCount;
  final VoidCallback? onClear;

  const _CartHeader({required this.itemCount, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppTheme.navyBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          const Text(
            'รายการสินค้า',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Color(0xFFEF9A9A),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'ล้าง',
                      style: TextStyle(fontSize: 11, color: Color(0xFFEF9A9A)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Scan Row — Search field + Scan button
// row แยกระหว่าง Header และรายการสินค้า
// พิมพ์ barcode แล้ว Enter หรือกดปุ่มสแกน → เพิ่มสินค้าทันที
// ─────────────────────────────────────────────────────────────────
class _ScanRow extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final bool autofocus;
  final bool compact;

  const _ScanRow({
    required this.ref,
    this.autofocus = true,
    this.compact = false,
  });

  @override
  ConsumerState<_ScanRow> createState() => _ScanRowState();
}

class _ScanRowState extends ConsumerState<_ScanRow> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── ค้นหาสินค้าจาก barcode / productCode แล้วเพิ่มทันที ──────
  Future<void> _addByBarcode(BuildContext context, String raw) async {
    final b = raw.trim().toLowerCase();
    if (b.isEmpty) return;

    final productsAsync = ref.read(productListProvider);
    if (!productsAsync.hasValue) return;

    final match = productsAsync.value!.firstWhere(
      (p) =>
          (p.barcode?.toLowerCase() == b) || p.productCode.toLowerCase() == b,
      orElse: () => throw _NotFoundError(),
    );

    ref
        .read(cartProvider.notifier)
        .addItem(
          productId: match.productId,
          productCode: match.productCode,
          productName: match.productName,
          unit: match.baseUnit,
          unitPrice: match.priceLevel1,
          groupId: match.groupId,
        );

    // ล้าง field + focus กลับทันที (พร้อมสแกนชิ้นถัดไป)
    _ctrl.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();

    if (context.mounted) {
      ref
          .read(cartToastProvider.notifier)
          .show(
            'เพิ่ม ${match.productName} แล้ว',
            duration: const Duration(milliseconds: 1200),
          );
    }
  }

  // ── เปิดกล้องแบบต่อเนื่อง — สแกนซ้ำได้ ไม่ปิดกล้อง ─────────
  Future<void> _onScanTap(BuildContext context) async {
    await MobileScannerService.openContinuous(
      context,
      onScanned: (result) {
        if (result.value.isEmpty) return;
        _addByBarcode(context, result.value).catchError((_) {
          if (context.mounted) _notFound(context, result.value);
        });
      },
    );
  }

  // ── กรณีไม่พบสินค้า ──────────────────────────────────────────
  void _notFound(BuildContext context, String barcode) {
    if (!context.mounted) return;
    ref
        .read(cartToastProvider.notifier)
        .show(
          'ไม่พบสินค้า: $barcode',
          backgroundColor: AppTheme.errorColor,
          icon: Icons.search_off,
          duration: const Duration(seconds: 2),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark
        ? AppTheme.darkElement.withValues(alpha: 0.6)
        : AppTheme.subtextColor;
    final bgColor = isDark ? AppTheme.darkCard : Colors.white;
    final iconColor = isDark ? Colors.white70 : AppTheme.subtextColor;
    final borderColor = isDark ? const Color(0xFF333333) : _border;

    final inputField = SizedBox(
      height: 34,
      child: TextField(
        controller: _ctrl,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          hintText: 'บาร์โค้ด / รหัสสินค้า...',
          hintStyle: TextStyle(fontSize: 12, color: hintColor),
          prefixIcon: Icon(Icons.search, size: 16, color: iconColor),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 14, color: iconColor),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _ctrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isDark ? AppTheme.darkElement : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
        style: TextStyle(fontSize: 12, color: textColor),
        onChanged: (v) => setState(() => _query = v),
        onSubmitted: (v) async {
          try {
            await _addByBarcode(context, v);
          } on _NotFoundError {
            if (context.mounted) _notFound(context, v);
          }
        },
      ),
    );

    final scanButton = Tooltip(
      message: 'สแกน QR / Barcode เพิ่มสินค้า',
      child: InkWell(
        onTap: () async {
          try {
            await _onScanTap(context);
          } on _NotFoundError catch (_) {
            // handled inside _addByBarcode → _notFound
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 15, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'สแกน',
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackedControls = widget.compact && constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: stackedControls
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    inputField,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: scanButton),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: inputField),
                    const SizedBox(width: 8),
                    scanButton,
                  ],
                ),
        );
      },
    );
  }
}

class _NotFoundError implements Exception {}

// ─────────────────────────────────────────────────────────────────
// Column labels
// ─────────────────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final _CartPanelDensity density;

  const _ColHeader({required this.density});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEEEEE),
      padding: EdgeInsets.symmetric(
        horizontal: density.horizontalPadding,
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(width: density.leadingWidth - density.horizontalPadding),
          const Expanded(
            flex: 5,
            child: Text(
              'สินค้า',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(
            width: density.controlWidth,
            child: const Center(
              child: Text(
                'จำนวน',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(
            width: density.amountWidth,
            child: const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'รวม',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(width: density.horizontalPadding - 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Cart Row — compact single-line + inline qty edit
// แทนที่ Card ขนาดใหญ่ (~110px) ด้วย row (~42px)
// ─────────────────────────────────────────────────────────────────
class _CartRow extends ConsumerStatefulWidget {
  final CartItem item;
  final bool isEven;
  final _CartPanelDensity density;

  const _CartRow({
    required this.item,
    required this.isEven,
    required this.density,
  });

  @override
  ConsumerState<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends ConsumerState<_CartRow> {
  bool _editingQty = false;
  late TextEditingController _qtyCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editingQty) _commitQty();
    });
  }

  @override
  void didUpdateWidget(_CartRow old) {
    super.didUpdateWidget(old);
    // sync ตัวเลขเมื่อ quantity เปลี่ยนจากภายนอก
    if (!_editingQty && old.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = widget.item.quantity.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitQty() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final safe = qty < 0.001 ? 1.0 : qty;
    ref.read(cartProvider.notifier).setQuantity(widget.item.productId, safe);
    setState(() => _editingQty = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final density = widget.density;
    final productInfo = Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.productName,
              style: TextStyle(
                fontSize: density.rowFontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: density.compact ? 2 : 1,
            ),
            Text(
              '฿${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
              style: TextStyle(
                fontSize: density.metaFontSize,
                color: AppTheme.subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
    final qtyControl = SizedBox(
      width: density.controlWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _QtyBtn(
            icon: Icons.remove,
            compact: density.compact,
            onTap: () => ref
                .read(cartProvider.notifier)
                .decreaseQuantity(item.productId),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _editingQty = true;
                _qtyCtrl.text = item.quantity.toStringAsFixed(0);
                _qtyCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _qtyCtrl.text.length,
                );
              });
              Future.microtask(() => _focusNode.requestFocus());
            },
            child: Container(
              width: density.qtyBoxWidth,
              height: density.qtyBoxHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _editingQty ? _orange : _border,
                  width: _editingQty ? 1.5 : 1,
                ),
              ),
              child: _editingQty
                  ? TextField(
                      controller: _qtyCtrl,
                      focusNode: _focusNode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: density.rowFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _commitQty(),
                    )
                  : Text(
                      item.quantity.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: density.rowFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add,
            compact: density.compact,
            onTap: () => ref
                .read(cartProvider.notifier)
                .increaseQuantity(item.productId),
          ),
        ],
      ),
    );
    final amountText = Text(
      '฿${item.amount.toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: density.amountFontSize,
        fontWeight: FontWeight.bold,
        color: _info,
      ),
    );

    return Container(
      color: widget.isEven ? Colors.white : const Color(0xFFF9F9F7),
      padding: EdgeInsets.symmetric(horizontal: density.horizontalPadding),
      child: density.stackedRows
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: density.leadingWidth,
                        child: InkWell(
                          onTap: () => ref
                              .read(cartProvider.notifier)
                              .removeItem(item.productId),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, size: 13, color: _error),
                          ),
                        ),
                      ),
                      productInfo,
                      const SizedBox(width: 8),
                      amountText,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [qtyControl],
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: density.leadingWidth,
                  child: InkWell(
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .removeItem(item.productId),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 13, color: _error),
                    ),
                  ),
                ),
                productInfo,
                qtyControl,
                SizedBox(
                  width: density.amountWidth,
                  child: Padding(
                    padding: EdgeInsets.only(right: density.compact ? 2 : 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: amountText,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Qty +/- button
// ─────────────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _QtyBtn({
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.all(compact ? 2 : 3),
        child: Icon(icon, size: compact ? 13 : 14, color: _navy),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Free Items Header
// ─────────────────────────────────────────────────────────────────
class _FreeItemsHeader extends StatelessWidget {
  final int count;
  const _FreeItemsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border(
          top: BorderSide(color: Colors.green.shade200),
          bottom: BorderSide(color: Colors.green.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            'ของแถมฟรี ($count รายการ)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Free Item Row — แสดงของแถม (ไม่มี qty control, ไม่มีลบ)
// ─────────────────────────────────────────────────────────────────
class _FreeItemRow extends StatelessWidget {
  final CartItem item;
  final _CartPanelDensity density;

  const _FreeItemRow({required this.item, required this.density});

  @override
  Widget build(BuildContext context) {
    final amountText = Text(
      '฿0.00',
      style: TextStyle(
        fontSize: density.amountFontSize,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );

    return Container(
      color: const Color(0xFFF1FFF3),
      padding: EdgeInsets.symmetric(
        horizontal: density.horizontalPadding,
        vertical: 7,
      ),
      child: density.stackedRows
          ? Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: density.leadingWidth,
                      child: const Icon(
                        Icons.card_giftcard,
                        size: 15,
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: density.rowFontSize,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1A1A1A),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          Text(
                            'ของแถมฟรี',
                            style: TextStyle(
                              fontSize: density.metaFontSize,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    amountText,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_FreeQtyChip(item: item, density: density)],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: density.leadingWidth,
                  child: const Icon(
                    Icons.card_giftcard,
                    size: 15,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: density.rowFontSize,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: density.compact ? 2 : 1,
                      ),
                      Text(
                        'ของแถมฟรี',
                        style: TextStyle(
                          fontSize: density.metaFontSize,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: density.controlWidth,
                  child: Center(
                    child: _FreeQtyChip(item: item, density: density),
                  ),
                ),
                SizedBox(
                  width: density.amountWidth,
                  child: Padding(
                    padding: EdgeInsets.only(right: density.compact ? 2 : 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: amountText,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FreeQtyChip extends StatelessWidget {
  final CartItem item;
  final _CartPanelDensity density;

  const _FreeQtyChip({required this.item, required this.density});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.compact ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        'x${item.quantity.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: density.rowFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty Cart
// ─────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 52, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'ตะกร้าว่าง',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'กดสินค้าเพื่อเพิ่มลงตะกร้า',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary + Pay button
// รักษา subtotal / totalDiscount / total จากไฟล์เดิม
// ─────────────────────────────────────────────────────────────────
class _CartSummary extends StatelessWidget {
  final CartState cartState;
  final _CartPanelDensity density;

  const _CartSummary({required this.cartState, required this.density});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalFontSize = density.compact
        ? 18.0
        : (context.isMobile ? 18.0 : 20.0);
    final bgColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subTextColor = isDark
        ? AppTheme.darkElement.withValues(alpha: 0.8)
        : Colors.grey;
    final dividerColor = isDark ? const Color(0xFF333333) : _border;
    final disabledColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey[300];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'รวม',
                  value: '฿${cartState.subtotal.toStringAsFixed(2)}',
                  valueColor: textColor,
                ),

                if (cartState.totalDiscount > 0) ...[
                  const SizedBox(height: 3),
                  _SummaryRow(
                    label: 'ส่วนลด',
                    value: '-฿${cartState.totalDiscount.toStringAsFixed(2)}',
                    valueColor: _error,
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: dividerColor),
                ),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactSummary =
                        density.compact || constraints.maxWidth < 360;

                    if (compactSummary) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ยอดชำระ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '฿${cartState.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: totalFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: _success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _DiscountButton(cartState: cartState, isDark: isDark),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ยอดชำระ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        _DiscountButton(cartState: cartState, isDark: isDark),
                        const SizedBox(width: 12),
                        Text(
                          '฿${cartState.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: totalFontSize,
                            fontWeight: FontWeight.bold,
                            color: _success,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Item count strip
          if (cartState.itemCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkElement.withValues(alpha: 0.5)
                      : _navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cartState.itemCount} รายการ',
                      style: TextStyle(fontSize: 10, color: subTextColor),
                    ),
                    Text(
                      'รวม ${cartState.items.fold<double>(0, (s, i) => s + i.quantity).toStringAsFixed(0)} ชิ้น',
                      style: TextStyle(fontSize: 10, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ),

          // ปุ่มชำระเงิน
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              height: context.isMobile ? 44 : 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cartState.items.isEmpty
                      ? disabledColor
                      : _success,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: isDark
                      ? Colors.white30
                      : Colors.grey[500],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: cartState.items.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentPage()),
                      ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cartState.items.isEmpty
                          ? 'ชำระเงิน'
                          : 'ชำระเงิน  ฿${cartState.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.subtextColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _DiscountButton — ปุ่มส่วนลดในแถวยอดชำระ
// • ตะกร้าว่าง           → ซ่อน
// • ยังไม่มีส่วนลด       → ปุ่ม outline สีเทา "🏷 ส่วนลด"
// • มีส่วนลดแล้ว         → badge สีส้ม แสดงค่า กดเพื่อแก้ไข/ลบ
// ─────────────────────────────────────────────────────────────────
class _DiscountButton extends ConsumerWidget {
  final CartState cartState;
  final bool isDark;

  const _DiscountButton({required this.cartState, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ตะกร้าว่าง → ซ่อนปุ่ม
    if (cartState.items.isEmpty) return const SizedBox.shrink();

    final hasDiscount = cartState.totalDiscount > 0;

    // label แสดงค่าส่วนลดปัจจุบัน
    String label;
    if (!hasDiscount) {
      label = 'ส่วนลด';
    } else if (cartState.discountPercent > 0) {
      label = '${cartState.discountPercent.toStringAsFixed(0)}%';
    } else {
      label = '-฿${cartState.totalDiscount.toStringAsFixed(0)}';
    }

    return Tooltip(
      message: hasDiscount ? 'แก้ไข / ลบส่วนลด' : 'ตั้งส่วนลด',
      child: InkWell(
        onTap: () async {
          final result = await showDialog<Map<String, double>>(
            context: context,
            builder: (_) => DiscountDialog(
              currentPercent: cartState.discountPercent,
              currentAmount: cartState.discountAmount,
            ),
          );
          if (result != null) {
            ref
                .read(cartProvider.notifier)
                .setDiscount(
                  percent: result['percent'],
                  amount: result['amount'],
                );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hasDiscount
                ? _orange.withValues(alpha: 0.12)
                : (isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasDiscount
                  ? _orange.withValues(alpha: 0.6)
                  : (isDark ? const Color(0xFF444444) : AppTheme.borderColor),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasDiscount ? Icons.local_offer : Icons.local_offer_outlined,
                size: 13,
                color: hasDiscount
                    ? _orange
                    : (isDark ? Colors.white54 : AppTheme.subtextColor),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasDiscount ? FontWeight.w700 : FontWeight.w500,
                  color: hasDiscount
                      ? _orange
                      : (isDark ? Colors.white54 : AppTheme.subtextColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
