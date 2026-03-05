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
    final productAsync = ref.watch(productListProvider);
    final cartState = ref.watch(cartProvider);
    final holdOrdersState = ref.watch(holdOrdersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('จุดขาย'),
            const SizedBox(width: 16),
            
            // ✅ แสดงลูกค้าทั่วไปหรือลูกค้าที่เลือก
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cartState.customerId != null && cartState.customerId != 'WALK_IN'
                      ? Colors.blue[100]  // ลูกค้าที่เลือก
                      : Colors.grey[200], // ลูกค้าทั่วไป
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cartState.customerId != null && cartState.customerId != 'WALK_IN'
                        ? Colors.blue 
                        : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: cartState.customerId != null && cartState.customerId != 'WALK_IN'
                          ? Colors.blue 
                          : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        cartState.customerName ?? 'ลูกค้าทั่วไป', // ✅ แสดง "ลูกค้าทั่วไป" ถ้าไม่มี
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cartState.customerId != null && cartState.customerId != 'WALK_IN'
                              ? Colors.blue 
                              : Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ✅ แสดงปุ่ม X เฉพาะเมื่อเลือกลูกค้า (ไม่ใช่ลูกค้าทั่วไป)
                    if (cartState.customerId != null && cartState.customerId != 'WALK_IN') ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          // ✅ กลับไปเป็นลูกค้าทั่วไป
                          ref.read(cartProvider.notifier).setCustomer('WALK_IN', 'ลูกค้าทั่วไป');
                        },
                        child: const Icon(Icons.close, size: 16, color: Colors.blue),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // จำนวนสินค้าในตะกร้า
            if (cartState.itemCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          ],
        ),
        actions: [
          // Customer Button
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'เลือกลูกค้า',
            onPressed: () async {
              final result = await showDialog<CustomerModel?>(
                context: context,
                builder: (context) => const CustomerSelectorDialog(),
              );
              
              if (result != null) {
                // เลือกลูกค้า
                ref.read(cartProvider.notifier).setCustomer(
                  result.customerId,
                  result.customerName,
                );
              }
            },
          ),
          
          // Discount Button
          IconButton(
            icon: const Icon(Icons.discount),
            tooltip: 'ส่วนลด',
            onPressed: () async {
              final result = await showDialog<Map<String, double>>(
                context: context,
                builder: (context) => const DiscountDialog(),
              );
              
              if (result != null) {
                ref.read(cartProvider.notifier).setDiscount(
                  percent: result['percent'],
                  amount: result['amount'],
                );
              }
            },
          ),
          
          // Hold Orders Button
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
              if (holdOrdersState.orders.isNotEmpty)
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
                      '${holdOrdersState.orders.length}',
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
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Hold Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสินค้า...',
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
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: cartState.items.isEmpty
                      ? null
                      : () async {
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => _HoldOrderNameDialog(),
                          );
                          
                          if (result != null && result.isNotEmpty) {
                            ref.read(cartProvider.notifier).hold(result);
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('พักบิล: $result')),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text('พักบิล'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Row(
              children: [
                // Product Grid (60%)
                Expanded(
                  flex: 60,
                  child: productAsync.when(
                    data: (products) {
                      // กรองสินค้า
                      final filteredProducts = products.where((product) {
                        if (_searchQuery.isEmpty) return true;
                        return product.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                               product.productCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                               (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                      }).toList();
                      
                      if (filteredProducts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(_searchQuery.isEmpty ? 'ไม่มีสินค้า' : 'ไม่พบสินค้า'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(productListProvider.notifier).refresh();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('รีเฟรช'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ProductGrid(products: filteredProducts);
                    },
                    loading: () => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('กำลังโหลดสินค้า...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 80, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('เกิดข้อผิดพลาด: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(productListProvider.notifier).refresh();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Cart Panel (40%)
                const Expanded(
                  flex: 40,
                  child: CartPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Hold Order Name Dialog
class _HoldOrderNameDialog extends StatefulWidget {
  @override
  State<_HoldOrderNameDialog> createState() => _HoldOrderNameDialogState();
}

class _HoldOrderNameDialogState extends State<_HoldOrderNameDialog> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultName = 'บิล ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _controller = TextEditingController(text: defaultName);
  }
  
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