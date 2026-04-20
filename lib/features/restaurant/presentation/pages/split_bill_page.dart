// ignore_for_file: avoid_print

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
  late Map<int, Set<String>> _assignments;
  SplitResult? _itemResult;
  bool _loadingItem = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _resetAssignments();
  }

  void _resetAssignments() {
    _assignments = {for (int i = 0; i < _personCount; i++) i: {}};
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
            onAssign: (itemId, personIdx) => setState(() {
              for (final assigned in _assignments.values) {
                assigned.remove(itemId);
              }
              _assignments[personIdx]?.add(itemId);
              _itemResult = null;
            }),
            onCalculate: _applyItemSplit,
            onPaySplit: _paySplit,
          ),
        ],
      ),
    );
  }

  Future<void> _applyEqualSplit() async {
    setState(() => _loadingEqual = true);
    final result = await ref.read(billProvider.notifier).applySplit(
          widget.tableContext.tableId,
          _buildBalancedSplits(),
        );
    setState(() {
      _equalResult = result;
      _loadingEqual = false;
    });
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถสร้างบิลแยกได้')),
      );
    }
  }

  Future<void> _applyItemSplit() async {
    final allAssigned = widget.bill.items.every(
      (item) => _assignments.values.any((set) => set.contains(item.itemId)),
    );
    if (!allAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากำหนดทุกรายการให้ครบก่อน')),
      );
      return;
    }

    final splits = List.generate(_personCount, (i) {
      final assignedIds = _assignments[i] ?? const <String>{};
      return {
        'label': 'คน ${i + 1}',
        'items': assignedIds
            .map(
              (itemId) => {
                'item_id': itemId,
                'quantity': widget.bill.items
                    .firstWhere((item) => item.itemId == itemId)
                    .quantity,
              },
            )
            .toList(),
      };
    });

    setState(() => _loadingItem = true);
    final result = await ref
        .read(billProvider.notifier)
        .applySplit(widget.tableContext.tableId, splits);
    setState(() {
      _itemResult = result;
      _loadingItem = false;
    });
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถสร้างบิลแยกได้')),
      );
    }
  }

  List<Map<String, dynamic>> _buildBalancedSplits() {
    final buckets = List.generate(
      _splitCount,
      (index) => <String, dynamic>{
        'label': 'คน ${index + 1}',
        'items': <Map<String, dynamic>>[],
        'sum': 0.0,
      },
    );

    final sortedItems = [...widget.bill.items]
      ..sort((a, b) => b.amount.compareTo(a.amount));

    for (final item in sortedItems) {
      buckets.sort(
        (a, b) => ((a['sum'] as double).compareTo(b['sum'] as double)),
      );
      (buckets.first['items'] as List<Map<String, dynamic>>).add({
        'item_id': item.itemId,
        'quantity': item.quantity,
      });
      buckets.first['sum'] = (buckets.first['sum'] as double) + item.amount;
    }

    return buckets
        .map(
          (bucket) => {
            'label': bucket['label'],
            'items': bucket['items'],
          },
        )
        .toList();
  }

  void _paySplit(SplitPortion portion) {
    if (portion.orderIds.isEmpty) return;

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
            modifiers: ((item['modifiers'] as List?) ?? const [])
                .map((modifier) {
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
            customerId: 'WALK_IN',
            customerName: 'ลูกค้าทั่วไป',
          ),
        );
    ref.read(restaurantOrderContextProvider.notifier).state =
        widget.tableContext.copyWith(
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
  final void Function(SplitPortion) onPaySplit;

  const _EqualSplitTab({
    required this.bill,
    required this.count,
    required this.result,
    required this.loading,
    required this.onCountChanged,
    required this.onCalculate,
    required this.onPaySplit,
  });

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
                      onPressed: count > 2 ? () => onCountChanged(count - 1) : null,
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
                      onPressed: count < 20 ? () => onCountChanged(count + 1) : null,
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
          label: const Text('สร้างบิลแยก'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
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
                onPressed:
                    split.orderIds.isEmpty ? null : () => onPaySplit(split),
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
  final Map<int, Set<String>> assignments;
  final SplitResult? result;
  final bool loading;
  final void Function(int) onPersonCountChanged;
  final void Function(String itemId, int personIdx) onAssign;
  final VoidCallback onCalculate;
  final void Function(SplitPortion) onPaySplit;

  const _ItemSplitTab({
    required this.bill,
    required this.personCount,
    required this.assignments,
    required this.result,
    required this.loading,
    required this.onPersonCountChanged,
    required this.onAssign,
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
          'กดที่รายการเพื่อกำหนดว่าใครจ่าย',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...bill.items.map((item) {
          final assignedTo = assignments.entries
              .where((entry) => entry.value.contains(item.itemId))
              .map((entry) => entry.key)
              .firstOrNull;

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'x${item.quantity.toStringAsFixed(item.quantity == item.quantity.truncateToDouble() ? 0 : 1)}  ฿${_fmt.format(item.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: List.generate(personCount, (i) {
                      final selected = assignedTo == i;
                      return GestureDetector(
                        onTap: () => onAssign(item.itemId, i),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: selected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade200,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : Colors.black54,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
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
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
          ...result!.splits.asMap().entries.map((entry) {
            final split = entry.value;
            final children = split.items
                .map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item['product_name'] as String? ?? ''),
                    trailing: Text(
                      '฿${_fmt.format((item['amount'] as num?)?.toDouble() ?? 0)}',
                    ),
                  ),
                )
                .toList()
                .cast<Widget>();
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed:
                      split.orderIds.isEmpty ? null : () => onPaySplit(split),
                  icon: const Icon(Icons.payment),
                  label: Text('ชำระ ${split.label}'),
                ),
              ),
            );

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
