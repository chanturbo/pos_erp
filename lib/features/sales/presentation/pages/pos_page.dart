import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';

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
    
    // กรองสินค้าตามการค้นหา
    final filteredProducts = productState.products.where((product) {
      if (_searchQuery.isEmpty) return true;
      return product.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             product.productCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS - จุดขาย'),
        actions: [
          // จำนวนสินค้าในตะกร้า
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
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
          Expanded(
            flex: 40,
            child: CartPanel(),
          ),
        ],
      ),
    );
  }
}