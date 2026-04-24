
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../sales/presentation/pages/payment_page.dart';
import '../../../sales/presentation/providers/cart_provider.dart';
import '../../data/models/bill_model.dart';
import '../../data/models/restaurant_order_context.dart';
import '../providers/billing_provider.dart';

final _fmt = NumberFormat('#,##0.00');

class SplitBillPage extends ConsumerStatefulWidget {
  final BillModel bill;
  final RestaurantOrderContext tableContext;

  const SplitBillPage({
    super.key,
    required this.bill,
    required this.tableContext,
  });

  @override
  ConsumerState<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends ConsumerState<SplitBillPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _splitCount = 2;
  SplitResult? _equalResult;
  bool _loadingEqual = false;

  int _personCount = 2;
  late Map<String, List<double>> _assignments;
  SplitResult? _itemResult;
  bool _loadingItem = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _resetAssignments();
  }

  void _resetAssignments() {
    _assignments = {
      for (final item in widget.bill.items)
        item.itemId: List.filled(_personCount, 0),
    };
  }

  void _changeAssignmentQuantity(
    BillItemModel item,
    int personIdx,
    double delta,
  ) {
    final current = List<double>.from(
      _assignments[item.itemId] ?? List.filled(_personCount, 0),
    );
    final allocatedElsewhere = current.asMap().entries.fold<double>(
      0,
      (sum, entry) => entry.key == personIdx ? sum : sum + entry.value,
    );
    final maxAllowed = (item.quantity - allocatedElsewhere).clamp(
      0.0,
      double.infinity,
    );
    final nextValue = (current[personIdx] + delta).clamp(0.0, maxAllowed);
    if ((nextValue - current[personIdx]).abs() < 0.0001) return;

    setState(() {
      current[personIdx] = nextValue;
      _assignments[item.itemId] = current;
      _itemResult = null;
    });
  }

  void _assignRemainingQuantity(BillItemModel item, int personIdx) {
    final current = List<double>.from(
      _assignments[item.itemId] ?? List.filled(_personCount, 0),
    );
    final allocatedElsewhere = current.asMap().entries.fold<double>(
      0,
      (sum, entry) => entry.key == personIdx ? sum : sum + entry.value,
    );
    final remaining = (item.quantity - allocatedElsewhere).clamp(
      0.0,
      double.infinity,
    );

    setState(() {
      current[personIdx] = remaining;
      _assignments[item.itemId] = current;
      _itemResult = null;
    });
  }

  double _quantityStepFor(BillItemModel item) {
    final quantity = item.quantity;
    if ((quantity - quantity.truncateToDouble()).abs() > 0.0001) {
      return 0.5;
    }
    return quantity <= 1 ? 0.5 : 1;
  }

  String _formatQuantity(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แยกบิล — ${widget.tableContext.tableName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'แบ่งเท่ากัน'),
            Tab(icon: Icon(Icons.list_alt), text: 'แยกรายการ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EqualSplitTab(
            bill: widget.bill,
            count: _splitCount,
            result: _equalResult,
            loading: _loadingEqual,
            onCountChanged: (v) => setState(() {
              _splitCount = v;
              _equalResult = null;
            }),
            onCalculate: _applyEqualSplit,
            onConfirm: _confirmEqualSplit,
            onPaySplit: _paySplit,
          ),
          _ItemSplitTab(
            bill: widget.bill,
            personCount: _personCount,
            assignments: _assignments,
            result: _itemResult,
            loading: _loadingItem,
            onPersonCountChanged: (v) => setState(() {
              _personCount = v;
              _resetAssignments();
              _itemResult = null;
            }),
            onDecreaseQuantity: (item, personIdx) => _changeAssignmentQuantity(
              item,
              personIdx,
              -_quantityStepFor(item),
            ),
            onIncreaseQuantity: (item, personIdx) => _changeAssignmentQuantity(
              item,
              personIdx,
              _quantityStepFor(item),
            ),
            onAssignRemaining: _assignRemainingQuantity,
            formatQuantity: _formatQuantity,
            onCalculate: _applyItemSplit,
            onPaySplit: _paySplit,
          ),
        ],
      ),
    );
  }

  Future<void> _applyEqualSplit() async {
    setState(() => _loadingEqual = true);
    final result = await ref
        .read(billProvider.notifier)
        .splitEqual(widget.tableContext.tableId, _splitCount);
    setState(() {
      _equalResult = result;
      _loadingEqual = false;
    });
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถดูตัวอย่างการแยกบิลได้')),
      );
    }
  }

  Future<void> _confirmEqualSplit() async {
    final preview = _equalResult;
    if (preview == null) return;

    setState(() => _loadingEqual = true);
    final result = await ref
        .read(billProvider.notifier)
        .applySplit(
          widget.tableContext.tableId,
          _buildSplitsFromPreview(preview),
          previewToken: preview.previewToken ?? widget.bill.previewToken,
        );
    setState(() {
      _equalResult = result;
      _loadingEqual = false;
    });
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถสร้างบิลแยกได้ หรือรายการเปลี่ยนแปลงระหว่างที่ใช้งาน',
          ),
        ),
      );
    }
  }

  Future<void> _applyItemSplit() async {
    final allAssigned = widget.bill.items.every((item) {
      final assigned = _assignments[item.itemId] ?? const <double>[];
      final totalAssigned = assigned.fold<double>(
        0,
        (sum, value) => sum + value,
      );
      return (totalAssigned - item.quantity).abs() < 0.0001;
    });
    if (!allAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาแจกแจงจำนวนของทุกรายการให้ครบก่อน')),
      );
      return;
    }

    final splits = List.generate(_personCount, (i) {
      final assignedItems = widget.bill.items
          .map((item) {
            final quantity = (_assignments[item.itemId] ?? const <double>[])[i];
            if (quantity <= 0) return null;
            return {'item_id': item.itemId, 'quantity': quantity};
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      return {'label': 'คน ${i + 1}', 'items': assignedItems};
    });

    setState(() => _loadingItem = true);
    final result = await ref
        .read(billProvider.notifier)
        .applySplit(
          widget.tableContext.tableId,
          splits,
          previewToken: widget.bill.previewToken,
        );
    setState(() {
      _itemResult = result;
      _loadingItem = false;
    });
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถสร้างบิลแยกได้ หรือรายการเปลี่ยนแปลงระหว่างที่ใช้งาน',
          ),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _buildSplitsFromPreview(SplitResult preview) {
    return preview.splits
        .map(
          (split) => {
            'label': split.label,
            'items': split.items
                .map(
                  (item) => {
                    'item_id': item['item_id'],
                    'quantity': item['quantity'],
                  },
                )
                .toList(),
          },
        )
        .toList();
  }

  void _paySplit(SplitPortion portion) {
    if (portion.orderIds.isEmpty) return;
    final currentCart = ref.read(cartProvider);

    final items = portion.items
        .map(
          (item) => CartItem(
            productId: item['product_id'] as String? ?? '',
            productCode: item['product_code'] as String? ?? '',
            productName: item['product_name'] as String? ?? '',
            unit: item['unit'] as String? ?? '',
            quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
            unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
            amount: (item['amount'] as num?)?.toDouble() ?? 0,
            priceLevel1: (item['unit_price'] as num?)?.toDouble() ?? 0,
            note: item['special_instructions'] as String?,
            modifiers: ((item['modifiers'] as List?) ?? const []).map((
              modifier,
            ) {
              final data = Map<String, dynamic>.from(modifier as Map);
              return CartItemModifier(
                modifierId: data['modifier_id'] as String? ?? '',
                modifierName: data['modifier_name'] as String? ?? '',
                priceAdjustment:
                    (data['price_adjustment'] as num?)?.toDouble() ?? 0,
              );
            }).toList(),
          ),
        )
        .toList();

    ref.read(cartProvider.notifier).replaceCart(
      CartState(
        items: items,
        customerId: currentCart.customerId,
        customerName: currentCart.customerName,
        customerPriceLevel: currentCart.customerPriceLevel,
      ),
    );
    ref.read(restaurantOrderContextProvider.notifier).state = widget
        .tableContext
        .copyWith(
          currentOrderId: portion.orderIds.first,
          currentOrderIds: portion.orderIds,
          subtotalOverride: portion.subtotal,
          discountOverride: portion.discountAmount,
          serviceChargeOverride: portion.serviceCharge,
          totalOverride: portion.total,
          paymentTitle: 'ชำระบิลแยก',
          splitLabel: portion.label,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );
  }
}

class _EqualSplitTab extends StatelessWidget {
  final BillModel bill;
  final int count;
  final SplitResult? result;
  final bool loading;
  final void Function(int) onCountChanged;
  final VoidCallback onCalculate;
  final VoidCallback onConfirm;
  final void Function(SplitPortion) onPaySplit;

  const _EqualSplitTab({
    required this.bill,
    required this.count,
    required this.result,
    required this.loading,
    required this.onCountChanged,
    required this.onCalculate,
    required this.onConfirm,
    required this.onPaySplit,
  });

  bool get _isPreviewOnly =>
      result != null && result!.splits.every((split) => split.orderIds.isEmpty);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'แบ่งจ่ายกี่คน',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: count > 2
                          ? () => onCountChanged(count - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$count คน',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: count < 20
                          ? () => onCountChanged(count + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ยอดรวม ฿${_fmt.format(bill.grandTotal)}\nระบบจะกระจายตามรายการเพื่อให้จ่ายได้จริง',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : onCalculate,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.call_split),
          label: const Text('ดูตัวอย่างบิลแยก'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_isPreviewOnly) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loading ? null : onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ยืนยันสร้างบิลแยก'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 16),
          if (_isPreviewOnly)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'นี่คือการแบ่งแบบตัวอย่าง ระบบจะสร้าง order จริงเมื่อกดยืนยัน',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ...result!.splits.asMap().entries.map((entry) {
            final split = entry.value;
            return Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(split.label),
                subtitle: Text(
                  split.orderIds.isNotEmpty
                      ? 'Order: ${split.orderIds.join(", ")}'
                      : 'ยังไม่ได้สร้าง order',
                ),
                trailing: Text(
                  '฿${_fmt.format(split.total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          ...result!.splits.map(
            (split) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: split.orderIds.isEmpty
                    ? null
                    : () => onPaySplit(split),
                icon: const Icon(Icons.payment),
                label: Text('ชำระ ${split.label}'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemSplitTab extends StatelessWidget {
  final BillModel bill;
  final int personCount;
  final Map<String, List<double>> assignments;
  final SplitResult? result;
  final bool loading;
  final void Function(int) onPersonCountChanged;
  final void Function(BillItemModel item, int personIdx) onDecreaseQuantity;
  final void Function(BillItemModel item, int personIdx) onIncreaseQuantity;
  final void Function(BillItemModel item, int personIdx) onAssignRemaining;
  final String Function(double quantity) formatQuantity;
  final VoidCallback onCalculate;
  final void Function(SplitPortion) onPaySplit;

  const _ItemSplitTab({
    required this.bill,
    required this.personCount,
    required this.assignments,
    required this.result,
    required this.loading,
    required this.onPersonCountChanged,
    required this.onDecreaseQuantity,
    required this.onIncreaseQuantity,
    required this.onAssignRemaining,
    required this.formatQuantity,
    required this.onCalculate,
    required this.onPaySplit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text(
              'จำนวนคน:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: personCount > 2
                  ? () => onPersonCountChanged(personCount - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$personCount',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: personCount < 10
                  ? () => onPersonCountChanged(personCount + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'ระบุจำนวนต่อคนในแต่ละรายการให้รวมครบตามจำนวนเดิม',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...bill.items.map((item) {
          final assignedQuantities =
              assignments[item.itemId] ?? List.filled(personCount, 0);
          final allocated = assignedQuantities.fold<double>(
            0,
            (sum, value) => sum + value,
          );
          final remaining = (item.quantity - allocated).clamp(
            0.0,
            double.infinity,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'จำนวนเดิม ${formatQuantity(item.quantity)} ${item.unit}  •  ฿${_fmt.format(item.amount)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining > 0.0001
                        ? 'เหลืออีก ${formatQuantity(remaining)} ${item.unit}'
                        : 'แจกแจงครบแล้ว',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining > 0.0001
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(personCount, (i) {
                    final quantity = assignedQuantities[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 54,
                            child: Text(
                              'คน ${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ลด ${item.productName} คน ${i + 1}',
                            onPressed: () => onDecreaseQuantity(item, i),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 52),
                            alignment: Alignment.center,
                            child: Text(
                              formatQuantity(quantity),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'เพิ่ม ${item.productName} คน ${i + 1}',
                            onPressed: () => onIncreaseQuantity(item, i),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const SizedBox(width: 8),
                          if (remaining > 0.0001)
                            OutlinedButton(
                              onPressed: () => onAssignRemaining(item, i),
                              child: const Text('รับที่เหลือ'),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : onCalculate,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.call_split),
          label: const Text('สร้างบิลแยก'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
          ...result!.splits.asMap().entries.map((entry) {
            final split = entry.value;
            final children = <Widget>[
              ...split.items.map(
                (item) => ListTile(
                  dense: true,
                  title: Text(item['product_name'] as String? ?? ''),
                  trailing: Text(
                    '฿${_fmt.format((item['amount'] as num?)?.toDouble() ?? 0)}',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: split.orderIds.isEmpty
                      ? null
                      : () => onPaySplit(split),
                  icon: const Icon(Icons.payment),
                  label: Text('ชำระ ${split.label}'),
                ),
              ),
            ];

            return Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(split.label),
                subtitle: Text(
                  split.orderIds.isNotEmpty
                      ? 'Order: ${split.orderIds.join(", ")}'
                      : 'ยังไม่ได้สร้าง order',
                ),
                trailing: Text(
                  '฿${_fmt.format(split.total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                children: children,
              ),
            );
          }),
        ],
      ],
    );
  }
}
