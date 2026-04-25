import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../../../shared/services/thermal_print_service.dart';
import '../../../../shared/widgets/thermal_receipt.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../sales/presentation/pages/payment_page.dart';
import '../../../sales/presentation/providers/cart_provider.dart';
import '../../data/models/bill_model.dart';
import '../../data/models/restaurant_order_context.dart';
import '../providers/billing_provider.dart';
import '../providers/table_provider.dart';
import 'split_bill_page.dart';

final _fmt = NumberFormat('#,##0.00');

class BillingPage extends ConsumerStatefulWidget {
  final RestaurantOrderContext tableContext;

  const BillingPage({super.key, required this.tableContext});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  final _scController = TextEditingController(text: '0');
  bool _applyingSC = false;
  bool _checkedDefaultServiceCharge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final defaultRate = ref.read(settingsProvider).defaultServiceChargeRate;
      if (defaultRate > 0) {
        _scController.text = _formatServiceChargeRate(defaultRate);
      }
      ref.read(billingContextProvider.notifier).state = widget.tableContext;
    });
  }

  @override
  void dispose() {
    _scController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billProvider);
    final ctx = widget.tableContext;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ใบแจ้งราคา — ${ctx.displayName}'),
            Text(
              ctx.isTakeaway
                  ? ctx.serviceType
                  : '${ctx.guestCount} คน · ${ctx.serviceType}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(billProvider.notifier).refresh(),
          ),
        ],
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 12),
                const Text(
                  'โหลดบิลไม่สำเร็จ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.read(billProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
        ),
        data: (bill) {
          if (bill == null || bill.isEmpty) {
            return const _EmptyBill();
          }
          _maybeApplyDefaultServiceCharge(bill);
          return _BillBody(
            bill: bill,
            tableContext: ctx,
            scController: _scController,
            applyingSC: _applyingSC,
            onApplySC: () => _applyServiceCharge(bill),
            onDisableSC: () => _disableServiceCharge(bill),
            onEnableSC: () => _enableServiceCharge(bill),
            onSplitBill: () => _openSplitBill(bill),
            onMerge: () => _showMergeDialog(),
            onPrintPreBill: () => _printPreBill(bill),
            onPay: () => _proceedToPayment(bill),
            onFireCourse: _fireCourse,
            onVoidItem: _showVoidDialog,
          );
        },
      ),
    );
  }

  void _maybeApplyDefaultServiceCharge(BillModel bill) {
    if (_checkedDefaultServiceCharge) {
      if (!_applyingSC) {
        _scController.text = _formatServiceChargeRate(bill.serviceChargeRate);
      }
      return;
    }

    _checkedDefaultServiceCharge = true;
    _scController.text = _formatServiceChargeRate(
      bill.serviceChargeRate > 0
          ? bill.serviceChargeRate
          : ref.read(settingsProvider).defaultServiceChargeRate,
    );

    final defaultRate = ref.read(settingsProvider).defaultServiceChargeRate;
    if (!widget.tableContext.hasTable || defaultRate <= 0) return;
    if (bill.serviceChargeRate > 0 || bill.serviceChargeAmount > 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _applyingSC = true);
      final ok = await ref
          .read(billProvider.notifier)
          .setServiceCharge(widget.tableContext.tableId, defaultRate);
      if (!mounted) return;
      setState(() => _applyingSC = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถตั้ง service charge เริ่มต้นได้'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });
  }

  String _formatServiceChargeRate(double rate) {
    if (rate <= 0) return '0';
    return rate.toStringAsFixed(rate == rate.truncateToDouble() ? 0 : 1);
  }

  Future<void> _fireCourse(int courseNo) async {
    if (!widget.tableContext.hasTable) return;
    final ok = await ref
        .read(billProvider.notifier)
        .fireCourse(widget.tableContext.tableId, courseNo);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fire course ไม่สำเร็จ')));
    }
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fire Course $courseNo แล้ว — ส่งครัวเรียบร้อย'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _showVoidDialog(BillItemModel item) async {
    final settings = ref.read(settingsProvider);
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final hasPin = settings.managerPinConfigured;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกรายการ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.productName}  x${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'เหตุผล *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            if (hasPin) ...[
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Manager PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              if (hasPin &&
                  !_matchesManagerPin(
                    pinCtrl.text.trim(),
                    settings.managerPin,
                  )) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('PIN ไม่ถูกต้อง'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    final managerPin = pinCtrl.text.trim();
    final ok = await ref
        .read(billProvider.notifier)
        .voidItem(
          item.itemId,
          reason: reason,
          managerPin: hasPin ? managerPin : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'ยกเลิกรายการ ${item.productName} แล้ว' : 'ยกเลิกไม่สำเร็จ',
        ),
        backgroundColor: ok ? AppTheme.errorColor : Colors.grey,
      ),
    );
  }

  bool _matchesManagerPin(String inputPin, String storedPin) {
    if (storedPin.isEmpty) return inputPin.isEmpty;
    return storedPin == inputPin ||
        CryptoUtils.verifyPassword(inputPin, storedPin);
  }

  Future<void> _applyServiceCharge(BillModel bill) async {
    if (!widget.tableContext.hasTable) return;
    final rate = double.tryParse(_scController.text.trim()) ?? 0;
    if (rate < 0 || rate > 30) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัตรา service charge ต้องอยู่ระหว่าง 0–30%'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _applyingSC = true);
    final ok = await ref
        .read(billProvider.notifier)
        .setServiceCharge(widget.tableContext.tableId, rate);
    _checkedDefaultServiceCharge = true;
    setState(() => _applyingSC = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? rate > 0
                    ? 'ตั้ง service charge ${rate.toStringAsFixed(0)}% แล้ว'
                    : 'ปิด service charge แล้ว'
              : 'ไม่สามารถตั้ง service charge ได้',
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _disableServiceCharge(BillModel bill) async {
    _scController.text = '0';
    await _applyServiceCharge(bill);
  }

  Future<void> _enableServiceCharge(BillModel bill) async {
    final defaultRate = ref.read(settingsProvider).defaultServiceChargeRate;
    _scController.text = _formatServiceChargeRate(defaultRate > 0 ? defaultRate : 10);
    await _applyServiceCharge(bill);
  }

  Future<void> _openSplitBill(BillModel bill) async {
    if (!widget.tableContext.hasTable) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SplitBillPage(bill: bill, tableContext: widget.tableContext),
      ),
    );
    if (!mounted) return;
    // If payment completed (context cleared by PaymentPage), close billing page
    if (ref.read(restaurantOrderContextProvider) == null) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _showMergeDialog() async {
    if (!widget.tableContext.hasTable) return;
    final tableListAsync = ref.read(tableListProvider);
    final tables = tableListAsync.asData?.value ?? [];
    final occupied = tables
        .where(
          (t) =>
              t.status == 'OCCUPIED' &&
              t.tableId != widget.tableContext.tableId,
        )
        .toList();

    if (!mounted) return;

    if (occupied.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่มีโต๊ะอื่นที่เปิดอยู่')));
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _MergeTableDialog(tables: occupied),
    );

    if (selected == null || !mounted) return;

    final ok = await ref
        .read(mergeTablesProvider.notifier)
        .merge(
          sourceTableId: widget.tableContext.tableId,
          targetTableId: selected,
        );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รวมโต๊ะสำเร็จ')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถรวมโต๊ะได้')));
    }
  }

  Future<void> _proceedToPayment(BillModel bill) async {
    final currentCart = ref.read(cartProvider);
    final billingCustomerId = bill.customerId;
    final billingCustomerName = bill.customerName;
    final shouldReuseCartCustomer =
        billingCustomerId == null || billingCustomerId.isEmpty;
    final preservedPriceLevel =
        shouldReuseCartCustomer || billingCustomerId == currentCart.customerId
        ? currentCart.customerPriceLevel
        : 1;
    final items = bill.items
        .map(
          (item) => CartItem(
            productId: item.productId,
            productCode: item.productId,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            amount: item.amount,
            priceLevel1: item.unitPrice,
            note: item.specialInstructions,
            modifiers: item.modifiers
                .map(
                  (modifier) => CartItemModifier(
                    modifierId: modifier['modifier_id'] as String? ?? '',
                    modifierName: modifier['modifier_name'] as String? ?? '',
                    priceAdjustment:
                        (modifier['price_adjustment'] as num?)?.toDouble() ?? 0,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    ref
        .read(cartProvider.notifier)
        .replaceCart(
          CartState(
            items: items,
            customerId:
                billingCustomerId ?? currentCart.customerId ?? 'WALK_IN',
            customerName:
                billingCustomerName ??
                currentCart.customerName ??
                'ลูกค้าทั่วไป',
            customerPriceLevel: preservedPriceLevel,
          ),
        );

    final firstOrderId = bill.orderIds.isNotEmpty ? bill.orderIds.first : null;
    ref.read(restaurantOrderContextProvider.notifier).state = widget
        .tableContext
        .copyWith(
          currentOrderId: firstOrderId,
          currentOrderIds: bill.orderIds,
          subtotalOverride: bill.subtotal,
          discountOverride: bill.discountAmount,
          serviceChargeOverride: bill.serviceChargeAmount,
          totalOverride: bill.grandTotal,
          paymentTitle: 'ชำระบิลรวม',
          splitLabel: null,
        );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );
    if (!mounted) return;
    // If payment completed (context cleared by PaymentPage), close billing page
    if (ref.read(restaurantOrderContextProvider) == null) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _printPreBill(BillModel bill) async {
    final settings = ref.read(settingsProvider);
    final printSettings = ThermalPrintSettings(
      enabled: settings.enableDirectThermalPrint,
      autoPrintOnSale: false,
      host: settings.thermalPrinterHost,
      port: settings.thermalPrinterPort,
      paperWidthMm: settings.thermalPaperWidthMm,
    );

    try {
      await ThermalPrintService.instance.printReceipt(
        settings: printSettings,
        document: ThermalReceiptDocument(
          companyName: settings.companyName,
          address: settings.address,
          phone: settings.phone,
          taxId: settings.taxId,
          orderNo: bill.orderNo ?? 'PRE-${widget.tableContext.displayName}',
          orderDate: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
          customerName: widget.tableContext.isTakeaway
              ? widget.tableContext.displayName
              : '${widget.tableContext.displayName} • ${widget.tableContext.guestCount} คน',
          items: bill.items
              .map(
                (item) => ReceiptItem(
                  name: item.productName,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  amount: item.amount,
                ),
              )
              .toList(),
          subtotal: bill.subtotal,
          discount: bill.discountAmount,
          total: bill.grandTotal,
          paymentLabel: 'ยังไม่ชำระ',
          paymentType: 'PREBILL',
          paidAmount: 0,
          changeAmount: 0,
          title: 'ใบแจ้งราคา / PRE-BILL',
          serviceCharge: bill.serviceChargeAmount,
          footerNote: 'เอกสารนี้ยังไม่ใช่ใบเสร็จรับเงินจริง',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่ง pre-bill ไปที่เครื่องพิมพ์แล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('พิมพ์ pre-bill ไม่สำเร็จ: $e')));
    }
  }
}

// ── Bill body ─────────────────────────────────────────────────────────────────

class _BillBody extends StatelessWidget {
  final BillModel bill;
  final RestaurantOrderContext tableContext;
  final TextEditingController scController;
  final bool applyingSC;
  final VoidCallback onApplySC;
  final VoidCallback onDisableSC;
  final VoidCallback onEnableSC;
  final VoidCallback onSplitBill;
  final VoidCallback onMerge;
  final VoidCallback onPrintPreBill;
  final VoidCallback onPay;
  final void Function(int courseNo) onFireCourse;
  final void Function(BillItemModel item) onVoidItem;

  const _BillBody({
    required this.bill,
    required this.tableContext,
    required this.scController,
    required this.applyingSC,
    required this.onApplySC,
    required this.onDisableSC,
    required this.onEnableSC,
    required this.onSplitBill,
    required this.onMerge,
    required this.onPrintPreBill,
    required this.onPay,
    required this.onFireCourse,
    required this.onVoidItem,
  });

  @override
  Widget build(BuildContext context) {
    final canManageTable = tableContext.hasTable;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Held Courses (fire button) ─────────────────────────
              if (canManageTable)
                () {
                  final heldByCourse = <int, List<BillItemModel>>{};
                  for (final item in bill.items) {
                    if (item.isHeld) {
                      (heldByCourse[item.courseNo] ??= []).add(item);
                    }
                  }
                  if (heldByCourse.isEmpty) return const SizedBox.shrink();
                  final courses = heldByCourse.keys.toList()..sort();
                  return Column(
                    children: [
                      ...courses.map(
                        (courseNo) => _SectionCard(
                          title: 'Course $courseNo — รอ Fire',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...heldByCourse[courseNo]!.map(
                                (item) => _ItemRow(
                                  item: item,
                                  onVoid: () => onVoidItem(item),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => onFireCourse(courseNo),
                                  icon: const Icon(
                                    Icons.local_fire_department,
                                    size: 18,
                                  ),
                                  label: Text('Fire Course $courseNo'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }(),

              // ── Items ──────────────────────────────────────────────────
              _SectionCard(
                title: 'รายการอาหาร',
                child: Column(
                  children: [
                    ...bill.items
                        .where((i) => !i.isHeld)
                        .map(
                          (item) => _ItemRow(
                            item: item,
                            onVoid: () => onVoidItem(item),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Service Charge ─────────────────────────────────────────
              if (canManageTable) ...[
                _SectionCard(
                  title: 'Service Charge',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: bill.hasServiceCharge,
                            onChanged: applyingSC
                                ? null
                                : (val) =>
                                      val ? onEnableSC() : onDisableSC(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bill.hasServiceCharge
                                ? 'เปิดใช้งาน'
                                : 'ปิดใช้งาน',
                            style: TextStyle(
                              color: bill.hasServiceCharge
                                  ? AppTheme.successColor
                                  : AppTheme.subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (applyingSC) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      if (bill.hasServiceCharge) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: scController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  suffixText: '%',
                                  labelText: 'อัตรา',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: applyingSC ? null : onApplySC,
                              child: const Text('ใช้'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Summary ────────────────────────────────────────────────
              _SectionCard(
                title: 'สรุปยอด',
                child: Column(
                  children: [
                    _SummaryRow('ยอดก่อนส่วนลด', bill.subtotal),
                    if (bill.discountAmount > 0)
                      _SummaryRow(
                        'ส่วนลด',
                        -bill.discountAmount,
                        color: AppTheme.errorColor,
                      ),
                    if (bill.hasServiceCharge)
                      _SummaryRow(
                        'Service Charge (${bill.serviceChargeRate.toStringAsFixed(0)}%)',
                        bill.serviceChargeAmount,
                      ),
                    const Divider(),
                    _SummaryRow(
                      'ยอดสุทธิ',
                      bill.grandTotal,
                      bold: true,
                      large: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bottom action bar ───────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canManageTable)
                      OutlinedButton.icon(
                        onPressed: onMerge,
                        icon: const Icon(Icons.merge_type, size: 18),
                        label: const Text('รวมโต๊ะ'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onPrintPreBill,
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Pre-bill'),
                    ),
                    if (canManageTable)
                      OutlinedButton.icon(
                        onPressed: onSplitBill,
                        icon: const Icon(Icons.call_split, size: 18),
                        label: const Text('แยกบิล'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payment),
                    label: Text('ชำระเงิน  ฿${_fmt.format(bill.grandTotal)}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Item row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final BillItemModel item;
  final VoidCallback? onVoid;
  const _ItemRow({required this.item, this.onVoid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // qty badge
          Container(
            width: 36,
            alignment: Alignment.centerRight,
            child: Text(
              'x${_fmtQty(item.quantity)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontSize: 14)),
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty)
                  Text(
                    item.specialInstructions!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ...item.modifiers.map(
                  (modifier) => Text(
                    '+ ${modifier['modifier_name'] ?? ''}'
                    ' (${_fmt.format((modifier['price_adjustment'] as num?)?.toDouble() ?? 0)})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '฿${_fmt.format(item.amount)}',
            style: const TextStyle(fontSize: 14),
          ),
          if (onVoid != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onVoid,
              borderRadius: AppRadius.sm,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool bold;
  final bool large;

  const _SummaryRow(
    this.label,
    this.amount, {
    this.color,
    this.bold = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: large ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('฿${_fmt.format(amount.abs())}', style: style),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBill extends StatelessWidget {
  const _EmptyBill();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
        SizedBox(height: 12),
        Text(
          'ยังไม่มีรายการสั่งอาหาร',
          style: TextStyle(color: Colors.black45),
        ),
      ],
    ),
  );
}

// ── Merge table dialog ────────────────────────────────────────────────────────

class _MergeTableDialog extends StatelessWidget {
  final List tables;
  const _MergeTableDialog({required this.tables});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('รวมบิลไปที่โต๊ะ'),
    content: SizedBox(
      width: 280,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: tables.length,
        itemBuilder: (_, i) {
          final t = tables[i];
          return ListTile(
            leading: const Icon(Icons.table_restaurant),
            title: Text(t.tableName ?? t.tableNo),
            onTap: () => Navigator.pop(context, t.tableId),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
    ],
  );
}
