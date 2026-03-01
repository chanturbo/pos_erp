import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import 'product_form_page.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productListProvider);  // ✅ นี่คือ ProductListState
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () {
              ref.read(productListProvider.notifier).loadProducts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
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
          
          // Product List
          Expanded(
            child: _buildBody(context, ref, productState),  // ✅ สร้าง method แยก
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // ✅ สร้าง method สำหรับแสดง body
  Widget _buildBody(BuildContext context, WidgetRef ref, ProductListState state) {
    // Loading
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Error
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(productListProvider.notifier).loadProducts();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }
    
    // กรองสินค้าตามการค้นหา
    final filteredProducts = state.products.where((product) {
      if (_searchQuery.isEmpty) return true;
      return product.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             product.productCode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    // Empty state
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'ยังไม่มีสินค้า' : 'ไม่พบสินค้า'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มสินค้า'),
            ),
          ],
        ),
      );
    }
    
    // Product List
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(product.productCode.substring(0, 2)),
            ),
            title: Text(product.productName),
            subtitle: Text(
              'รหัส: ${product.productCode} | ราคา: ฿${product.priceLevel1.toStringAsFixed(2)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormPage(product: product),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ยืนยันการลบ'),
                        content: Text('ต้องการลบสินค้า ${product.productName} ใช่หรือไม่?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final success = await ref
                          .read(productListProvider.notifier)
                          .deleteProduct(product.productId);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'ลบสินค้าสำเร็จ' : 'ลบสินค้าไม่สำเร็จ'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}