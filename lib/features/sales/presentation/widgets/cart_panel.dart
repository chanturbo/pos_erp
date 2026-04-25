import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../providers/cart_provider.dart';
import '../pages/payment_page.dart';
import '../widgets/discount_dialog.dart';
import '../../../products/presentation/providers/product_provider.dart'; // ✅ scan เพิ่มสินค้า
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../restaurant/presentation/providers/table_provider.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/services/mobile_scanner_service.dart'; // ✅ MobileScannerService
import '../../../../shared/services/thermal_print_service.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/cart_toast.dart';

// ── OAG Tokens ────────────────────────────────────────────────────
const _navy = AppTheme.navyColor;
const _orange = AppTheme.primaryColor;
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
  final bool showCheckoutButton;
  final bool showHoldButton;
  final VoidCallback? onHold;

  const CartPanel({
    super.key,
    this.showScanRow = true,
    this.autofocusScan = true,
    this.showCheckoutButton = true,
    this.showHoldButton = false,
    this.onHold,
  });

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final _scrollController = ScrollController();
  int _prevItemCount = 0;
  int _scanRowSession = 0;
  bool _isSendingRestaurantOrder = false;

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

  Future<void> _sendRestaurantOrder() async {
    if (_isSendingRestaurantOrder) return;

    final restaurantContext = ref.read(restaurantOrderContextProvider);
    final cartState = ref.read(cartProvider);
    final authState = ref.read(authProvider);
    final selectedBranch = ref.read(selectedBranchProvider);
    final selectedWarehouse = ref.read(selectedWarehouseProvider);
    final apiClient = ref.read(apiClientProvider);

    if (restaurantContext == null) return;
    if (cartState.items.isEmpty) return;

    // Only send items that haven't been sent yet (second wave support)
    final unsentItems = cartState.items
        .where((i) => !cartState.kitchenSentLineIds.contains(i.lineId))
        .toList();
    if (unsentItems.isEmpty) return;
    if (selectedBranch == null || selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสาขาและคลังของเครื่องนี้ก่อนส่งออเดอร์'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSendingRestaurantOrder = true);

    final products = ref.read(productListProvider).value ?? const [];
    final productById = {
      for (final product in products) product.productId: product,
    };

    final unsentSubtotal = unsentItems.fold<double>(0, (s, i) => s + i.amount);
    final orderData = {
      'status': 'OPEN',
      'customer_id': cartState.customerId,
      'customer_name': cartState.customerName,
      'user_id': authState.user?.userId ?? 'USR001',
      'branch_id': selectedBranch.branchId,
      'warehouse_id': selectedWarehouse.warehouseId,
      'table_id': restaurantContext.hasTable ? restaurantContext.tableId : null,
      'session_id': restaurantContext.hasSession
          ? restaurantContext.sessionId
          : null,
      'service_type': restaurantContext.serviceType,
      'party_size': restaurantContext.guestCount,
      'subtotal': unsentSubtotal,
      'discount_amount': 0.0,
      'coupon_discount': 0.0,
      'points_used': 0,
      'amount_before_vat': unsentSubtotal,
      'vat_amount': 0.0,
      'total_amount': unsentSubtotal,
      'payment_type': 'PENDING',
      'paid_amount': 0.0,
      'change_amount': 0.0,
      if (restaurantContext.currentOrderId?.isNotEmpty == true)
        'parent_order_id': restaurantContext.currentOrderId,
      'items': unsentItems
          .map(
            (item) => {
              'product_id': item.productId,
              'product_code': item.productCode,
              'product_name': item.productName,
              'unit': item.unit,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'discount_percent': 0.0,
              'discount_amount': 0.0,
              'amount': item.amount,
              'special_instructions': item.note,
              'course_no': item.courseNo,
              if (item.modifiers.isNotEmpty)
                'modifiers': item.modifiers
                    .map(
                      (modifier) => {
                        'modifier_id': modifier.modifierId,
                        'modifier_name': modifier.modifierName,
                        'price_adjustment': modifier.priceAdjustment,
                      },
                    )
                    .toList(),
            },
          )
          .toList(),
    };

    try {
      final response = await apiClient.post('/api/sales', data: orderData);
      if (response.statusCode != 200) {
        throw Exception('ไม่สามารถส่งออเดอร์เข้าครัวได้');
      }

      final responseData = response.data is Map ? response.data as Map : {};
      final dataMap = responseData['data'] is Map
          ? responseData['data'] as Map
          : {};
      final orderId = dataMap['order_id'] as String? ?? '';
      final orderNo = dataMap['order_no'] as String?;

      if (orderId.isEmpty) {
        throw Exception('สร้างออเดอร์ไม่สำเร็จ');
      }

      // Mark these items as sent (keep first orderId as the primary)
      final sentLineIds = unsentItems.map((i) => i.lineId).toSet();
      ref.read(cartProvider.notifier).markKitchenSent(sentLineIds);

      if (restaurantContext.currentOrderId?.isEmpty ?? true) {
        ref
            .read(restaurantOrderContextProvider.notifier)
            .state = restaurantContext.copyWith(
          currentOrderId: orderId,
          currentOrderNo: orderNo,
        );
      }
      ref.invalidate(tableListProvider);

      // Auto-print kitchen ticket if enabled
      final settings = ref.read(settingsProvider);
      if (settings.autoPrintKitchenTicket &&
          settings.enableDirectThermalPrint) {
        final printSettings = ThermalPrintSettings(
          enabled: settings.enableDirectThermalPrint,
          autoPrintOnSale: settings.autoPrintReceipt,
          host: settings.thermalPrinterHost,
          port: settings.thermalPrinterPort,
          paperWidthMm: settings.thermalPaperWidthMm,
        );
        final ticket = KitchenTicketDocument(
          tableName: restaurantContext.displayName,
          orderNo: orderNo ?? orderId,
          orderTime: DateFormat('HH:mm').format(DateTime.now()),
          items: unsentItems.map((item) {
            final product = productById[item.productId];
            return KitchenTicketItem(
              courseNo: item.courseNo,
              quantity: item.quantity.toDouble(),
              unit: item.unit,
              name: item.productName,
              specialInstructions: item.note,
              station: product?.prepStation ?? 'kitchen',
            );
          }).toList(),
        );
        ThermalPrintService.instance.printKitchenTicket(
          settings: printSettings,
          document: ticket,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderNo == null || orderNo.isEmpty
                ? 'ส่งออเดอร์เข้าครัวแล้ว'
                : 'ส่งออเดอร์ $orderNo เข้าครัวแล้ว',
          ),
          backgroundColor: _success,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = e.response?.data is Map
          ? (e.response!.data['message'] as String?)
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverMsg ?? 'ไม่สามารถส่งออเดอร์เข้าครัวได้'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingRestaurantOrder = false);
      }
    }
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
        final density = _CartPanelDensity.fromConstraints(constraints);

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            border: Border(left: BorderSide(color: AppTheme.borderColorOf(context))),
            borderRadius: AppRadius.topMd,
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
                  key: ValueKey(_scanRowSession),
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
                            final rowItem = cartState.items[i];
                            return _CartRow(
                              item: rowItem,
                              isEven: i.isEven,
                              density: density,
                              kitchenSent: cartState.kitchenSentLineIds
                                  .contains(rowItem.lineId),
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
              _CartSummary(
                cartState: cartState,
                density: density,
                showCheckoutButton: widget.showCheckoutButton,
                showHoldButton: widget.showHoldButton,
                onHold: widget.onHold,
                isRestaurantFlow:
                    ref.watch(restaurantOrderContextProvider) != null,
                isKitchenSent:
                    (ref
                        .watch(restaurantOrderContextProvider)
                        ?.currentOrderId
                        ?.isNotEmpty ??
                    false),
                hasUnsentItems: cartState.hasUnsentItems,
                skipKitchen:
                    ref
                        .watch(restaurantOrderContextProvider)
                        ?.skipKitchen ??
                    false,
                isSendingRestaurantOrder: _isSendingRestaurantOrder,
                onSendToKitchen: _sendRestaurantOrder,
                onOpenNewBill: () => setState(() => _scanRowSession++),
              ),
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

  /// true เมื่อ CartPanel ถูก constrain ด้านความสูง < 300px
  /// → ย่อ summary padding + ซ่อน item count strip
  final bool compactHeight;

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
    this.compactHeight = false,
  });

  factory _CartPanelDensity.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final compactHeight = height.isFinite && height < 300;

    if (width < 340) {
      return _CartPanelDensity(
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
        compactHeight: compactHeight,
      );
    }

    if (width < 420) {
      return _CartPanelDensity(
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
        compactHeight: compactHeight,
      );
    }

    return _CartPanelDensity(
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
      compactHeight: compactHeight,
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
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: AppRadius.topMd,
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
                borderRadius: AppRadius.md,
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
              borderRadius: AppRadius.sm,
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
    super.key,
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
      onScannedInSheet: (sheetContext, result) {
        if (result.value.isEmpty) return;
        _addByBarcode(context, result.value).catchError((_) {
          if (sheetContext.mounted) {
            _notFound(sheetContext, result.value, useSnackBar: true);
          }
        });
      },
    );
  }

  // ── กรณีไม่พบสินค้า ──────────────────────────────────────────
  void _notFound(
    BuildContext context,
    String barcode, {
    bool useSnackBar = false,
  }) {
    if (!context.mounted) return;
    if (useSnackBar) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('ไม่พบสินค้า: $barcode'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            ),
          );
        return;
      }
    }

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
            borderRadius: AppRadius.sm,
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
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
        borderRadius: AppRadius.sm,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: AppRadius.sm,
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
  final bool kitchenSent;

  const _CartRow({
    required this.item,
    required this.isEven,
    required this.density,
    this.kitchenSent = false,
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
    ref.read(cartProvider.notifier).setQuantity(widget.item.lineId, safe);
    setState(() => _editingQty = false);
  }

  Future<void> _showNoteSheet(CartItem item) async {
    final presets = [
      'ไม่ผงชูรส',
      'ไม่หวาน',
      'ไม่เค็ม',
      'รสจืด',
      'ไม่เผ็ด',
      'เพิ่มเผ็ด',
      'ไม่ใส่ผัก',
      'ไม่ใส่หอม',
      'ไม่ใส่กระเทียม',
      'เพิ่มพริก',
    ];

    final ctrl = TextEditingController(text: item.note ?? '');
    final selected = <String>{};
    // pre-tick any preset that already appears in the existing note
    for (final p in presets) {
      if (ctrl.text.contains(p)) selected.add(p);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            void togglePreset(String preset) {
              setSheet(() {
                if (selected.contains(preset)) {
                  selected.remove(preset);
                  ctrl.text =
                      ctrl.text.replaceAll(preset, '').replaceAll(RegExp(r', *,'), ',').replaceAll(RegExp(r'^,\s*|,\s*$'), '').trim();
                } else {
                  selected.add(preset);
                  final base = ctrl.text.trim();
                  ctrl.text = base.isEmpty ? preset : '$base, $preset';
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(ctx),
                  borderRadius: AppRadius.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note, color: _orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'หมายเหตุ: ${item.productName}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColorOf(ctx),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Icon(Icons.close, size: 20, color: AppTheme.subtextColorOf(ctx)),
                          ),
                        ],
                      ),
                    ),
                    // preset chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'เลือกได้เลย',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtextColorOf(ctx),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: presets.map((p) {
                          final active = selected.contains(p);
                          return GestureDetector(
                            onTap: () => togglePreset(p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: active ? _orange : AppTheme.surface3Of(ctx),
                                borderRadius: AppRadius.sm,
                                border: Border.all(
                                  color: active ? _orange : AppTheme.borderColorOf(ctx),
                                ),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: active ? Colors.white : AppTheme.textColorOf(ctx),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // free text
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'หรือพิมพ์เพิ่มเติม',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColorOf(ctx)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: ctrl,
                        autofocus: false,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: AppTheme.textColorOf(ctx)),
                        decoration: InputDecoration(
                          hintText: 'เช่น ไม่เผ็ด, เพิ่มน้ำมัน...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.mutedTextOf(ctx)),
                          filled: true,
                          fillColor: AppTheme.surface3Of(ctx),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.sm,
                            borderSide: BorderSide(color: AppTheme.borderColorOf(ctx)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.sm,
                            borderSide: BorderSide(color: AppTheme.borderColorOf(ctx)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.sm,
                            borderSide: const BorderSide(color: _orange, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    // action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ref.read(cartProvider.notifier).setNote(item.lineId, null);
                                Navigator.pop(ctx);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppTheme.borderColorOf(ctx)),
                                foregroundColor: AppTheme.subtextColorOf(ctx),
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                              ),
                              child: const Text('ล้าง'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                final note = ctrl.text.trim();
                                ref.read(cartProvider.notifier).setNote(item.lineId, note.isEmpty ? null : note);
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                              ),
                              child: const Text('บันทึก'),
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
        );
      },
    );
    ctrl.dispose();
  }

  Future<void> _showCourseDialog(CartItem item) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(
          'กำหนดคอร์สสำหรับ\n${item.productName}',
          style: const TextStyle(fontSize: 15),
        ),
        children: List.generate(4, (i) {
          final n = i + 1;
          final label = n == 1 ? 'คอร์ส 1 (เสิร์ฟทันที)' : 'คอร์ส $n';
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, n),
            child: Row(
              children: [
                Icon(
                  n == item.courseNo
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: n == item.courseNo ? _orange : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
          );
        }),
      ),
    );
    if (selected != null) {
      ref.read(cartProvider.notifier).setCourseNo(item.lineId, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final density = widget.density;
    final kitchenSent = widget.kitchenSent;
    final isRestaurant = ref.watch(restaurantOrderContextProvider) != null;
    final productInfo = Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: density.rowFontSize,
                      fontWeight: FontWeight.w500,
                      color: kitchenSent
                          ? AppTheme.subtextColorOf(context)
                          : AppTheme.textColorOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: density.compact ? 2 : 1,
                  ),
                ),
                if (kitchenSent)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _success.withValues(alpha: 0.12),
                      borderRadius: AppRadius.xs,
                      border: Border.all(
                        color: _success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 10,
                          color: _success,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'ส่งแล้ว',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (item.modifiers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: item.modifiers.map((m) {
                    final adj = m.priceAdjustment;
                    final adjText = adj == 0
                        ? ''
                        : adj > 0
                            ? ' +฿${adj.toStringAsFixed(0)}'
                            : ' -฿${adj.abs().toStringAsFixed(0)}';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.07),
                        borderRadius: AppRadius.xs,
                        border: Border.all(
                            color: _navy.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '${m.modifierName}$adjText',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textColorOf(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (item.note?.isNotEmpty == true)
              GestureDetector(
                onTap: () => _showNoteSheet(item),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 1),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 13, color: _orange.withValues(alpha: 0.85)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.note!,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: _orange.withValues(alpha: 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '฿${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                    style: TextStyle(
                      fontSize: density.metaFontSize,
                      color: AppTheme.subtextColorOf(context),
                    ),
                  ),
                ),
                if (isRestaurant) ...[
                  GestureDetector(
                    onTap: () => _showNoteSheet(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: item.note?.isNotEmpty == true
                            ? _orange.withValues(alpha: 0.12)
                            : AppTheme.surface3Of(context),
                        borderRadius: AppRadius.xs,
                        border: Border.all(
                          color: item.note?.isNotEmpty == true
                              ? _orange.withValues(alpha: 0.5)
                              : AppTheme.borderColorOf(context),
                        ),
                      ),
                      child: Icon(
                        item.note?.isNotEmpty == true ? Icons.edit_note : Icons.add_comment_outlined,
                        size: 13,
                        color: item.note?.isNotEmpty == true
                            ? _orange
                            : AppTheme.subtextColorOf(context),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCourseDialog(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.courseNo > 1
                            ? (AppTheme.isDark(context)
                                ? const Color(0xFF1A2A3A)
                                : Colors.blue.shade50)
                            : AppTheme.surface3Of(context),
                        borderRadius: AppRadius.xs,
                        border: Border.all(
                          color: item.courseNo > 1
                              ? (AppTheme.isDark(context)
                                  ? AppTheme.infoColor
                                  : Colors.blue.shade300)
                              : AppTheme.borderColorOf(context),
                        ),
                      ),
                      child: Text(
                        'C${item.courseNo}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.courseNo > 1
                              ? (AppTheme.isDark(context)
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700)
                              : AppTheme.subtextColorOf(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
                .decreaseQuantity(item.lineId),
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
                color: AppTheme.cardColor(context),
                borderRadius: AppRadius.xs,
                border: Border.all(
                  color: _editingQty ? _orange : AppTheme.borderColorOf(context),
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
                        color: AppTheme.textColorOf(context),
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
                        color: AppTheme.textColorOf(context),
                      ),
                    ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add,
            compact: density.compact,
            onTap: () => ref
                .read(cartProvider.notifier)
                .increaseQuantity(item.lineId),
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
      color: kitchenSent
          ? _success.withValues(alpha: 0.06)
          : (widget.isEven ? AppTheme.rowEvenOf(context) : AppTheme.rowOddOf(context)),
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
                              .removeItem(item.lineId),
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
                        .removeItem(item.lineId),
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
      borderRadius: AppRadius.xs,
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
                              color: AppTheme.textColorOf(context),
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
                          color: AppTheme.textColorOf(context),
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
        borderRadius: AppRadius.xs,
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
  final bool showCheckoutButton;
  final bool showHoldButton;
  final bool isRestaurantFlow;
  final bool isKitchenSent;
  final bool hasUnsentItems;
  final bool skipKitchen;
  final bool isSendingRestaurantOrder;
  final VoidCallback? onHold;
  final Future<void> Function()? onSendToKitchen;
  final VoidCallback? onOpenNewBill;

  const _CartSummary({
    required this.cartState,
    required this.density,
    required this.showCheckoutButton,
    required this.showHoldButton,
    required this.isRestaurantFlow,
    required this.isKitchenSent,
    required this.hasUnsentItems,
    required this.skipKitchen,
    required this.isSendingRestaurantOrder,
    required this.onHold,
    this.onSendToKitchen,
    this.onOpenNewBill,
  });

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
    final canCheckout =
        cartState.items.isNotEmpty &&
        (!isRestaurantFlow || isKitchenSent || skipKitchen);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              density.compactHeight ? 6 : 10,
              12,
              0,
            ),
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
                  padding: EdgeInsets.symmetric(
                    vertical: density.compactHeight ? 4 : 6,
                  ),
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

          // Item count strip — ซ่อนเมื่อพื้นที่จำกัด
          if (cartState.itemCount > 0 && !density.compactHeight)
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
                  borderRadius: AppRadius.sm,
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

          if (showCheckoutButton || showHoldButton || isRestaurantFlow)
            Padding(
              padding: EdgeInsets.all(density.compactHeight ? 6 : 10),
              child: Row(
                children: [
                  if (isRestaurantFlow && hasUnsentItems && !skipKitchen) ...[
                    Expanded(
                      flex: showCheckoutButton || showHoldButton ? 6 : 1,
                      child: SizedBox(
                        height: density.compactHeight
                            ? 38
                            : (context.isMobile ? 44 : 48),
                        child: ElevatedButton(
                          onPressed:
                              cartState.items.isEmpty ||
                                  isSendingRestaurantOrder
                              ? null
                              : onSendToKitchen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _info,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: disabledColor,
                            disabledForegroundColor: isDark
                                ? Colors.white30
                                : Colors.grey[500],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSendingRestaurantOrder)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(Icons.kitchen_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isSendingRestaurantOrder
                                      ? 'กำลังส่ง...'
                                      : 'ส่งเข้าครัว',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
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
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showHoldButton) ...[
                    Expanded(
                      flex: 5,
                      child: OutlinedButton(
                        onPressed: cartState.items.isEmpty ? null : onHold,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(
                            0,
                            density.compactHeight
                                ? 38
                                : (context.isMobile ? 44 : 48),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause_circle_outline_rounded,
                                size: 17,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'พักบิล',
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showCheckoutButton)
                    Expanded(
                      flex: showHoldButton ? 11 : 1,
                      child: SizedBox(
                        height: density.compactHeight
                            ? 38
                            : (context.isMobile ? 44 : 48),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canCheckout
                                ? _success
                                : disabledColor,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: isDark
                                ? Colors.white30
                                : Colors.grey[500],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md,
                            ),
                          ),
                          onPressed: !canCheckout
                              ? null
                              : () async {
                                  final result =
                                      await Navigator.push<ReceiptExitAction>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PaymentPage(),
                                        ),
                                      );
                                  if (result == ReceiptExitAction.openNewBill) {
                                    onOpenNewBill?.call();
                                  }
                                },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  !canCheckout &&
                                          isRestaurantFlow &&
                                          !isKitchenSent &&
                                          !skipKitchen
                                      ? Icons.lock_outline_rounded
                                      : Icons.payment,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  !canCheckout
                                      ? (isRestaurantFlow &&
                                                !isKitchenSent &&
                                                !skipKitchen
                                            ? 'กรุณาส่งเข้าครัวก่อน'
                                            : 'ชำระเงิน')
                                      : (isRestaurantFlow
                                            ? 'ปิดบิล  ฿${cartState.total.toStringAsFixed(2)}'
                                            : 'ชำระเงิน  ฿${cartState.total.toStringAsFixed(2)}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
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
                    ),
                ],
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
        borderRadius: AppRadius.sm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hasDiscount
                ? _orange.withValues(alpha: 0.12)
                : (isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5)),
            borderRadius: AppRadius.sm,
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
