import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../customers/data/models/customer_model.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/hold_orders_dialog.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productListProvider);
    final cartState = ref.watch(cartProvider);    
    final holdOrdersState = ref.watch(holdOrdersProvider); // ✅ แก้ไข
    final orders = holdOrdersState.orders; // ✅ แก้ไข
    // กรองสินค้าตามการค้นหา
    final filteredProducts = productState.products.where((product) {
      if (_searchQuery.isEmpty) return true;
      return product.productName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          product.productCode.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (product.barcode?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS - จุดขาย'),
        actions: [
          // ✅ Customer Button
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'เลือกลูกค้า',
            onPressed: () async {
              final customer = await showDialog<CustomerModel?>(
                context: context,
                builder: (context) => CustomerSelectorDialog(
                  currentCustomer: cartState.customerId != null
                      ? CustomerModel(
                          customerId: cartState.customerId!,
                          customerCode: '',
                          customerName: cartState.customerName!,
                        )
                      : null,
                ),
              );

              if (customer != null) {
                ref
                    .read(cartProvider.notifier)
                    .setCustomer(customer.customerId, customer.customerName);
              } else if (customer == null && context.mounted) {
                // Clear customer
                ref.read(cartProvider.notifier).setCustomer(null, null);
              }
            },
          ),

          // ✅ Discount Button
          IconButton(
            icon: const Icon(Icons.discount),
            tooltip: 'ส่วนลด',
            onPressed: () async {
              final result = await showDialog<Map<String, double>>(
                context: context,
                builder: (context) => DiscountDialog(
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
          ),

          // ✅ Hold Orders Button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.folder),
                tooltip: 'บิลที่พัก',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const HoldOrdersDialog(),
                  );
                },
              ),
              if (orders.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${orders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // จำนวนสินค้าในตะกร้า
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cartState.itemCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ซ้าย: Product Grid (60%)
          Expanded(
            flex: 60,
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ค้นหาสินค้า (ชื่อ, รหัส, บาร์โค้ด)',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),

                      // ✅ Hold Button
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: cartState.items.isEmpty
                            ? null
                            : () async {
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (context) => _HoldOrderNameDialog(),
                                );

                                if (name != null && name.isNotEmpty) {
                                  ref.read(cartProvider.notifier).hold(name);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('พักบิล: $name')),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.pause_circle),
                        label: const Text('พักบิล'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Customer Info Banner
                if (cartState.customerName != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ลูกค้า: ${cartState.customerName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ref
                                .read(cartProvider.notifier)
                                .setCustomer(null, null);
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('ลบ'),
                        ),
                      ],
                    ),
                  ),

                // Product Grid
                Expanded(
                  child: productState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ProductGrid(products: filteredProducts),
                ),
              ],
            ),
          ),

          // ขวา: Cart Panel (40%)
          const Expanded(flex: 40, child: CartPanel()),
        ],
      ),
    );
  }
}

// ✅ Dialog สำหรับตั้งชื่อบิลที่พัก
class _HoldOrderNameDialog extends StatefulWidget {
  @override
  State<_HoldOrderNameDialog> createState() => _HoldOrderNameDialogState();
}

class _HoldOrderNameDialogState extends State<_HoldOrderNameDialog> {
  final _controller = TextEditingController(
    text:
        'บิล ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('พักบิล'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'ชื่อบิล',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
