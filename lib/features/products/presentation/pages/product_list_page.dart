import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import 'product_form_page.dart';
import '../../../../shared/widgets/async_state_widgets.dart'; // ✅ Phase 4
import '../../../../shared/utils/app_transitions.dart';       // ✅ Phase 4

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
    final productAsync = ref.watch(productListProvider); // ✅ เปลี่ยน

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () {
              ref.read(productListProvider.notifier).refresh(); // ✅ เปลี่ยน
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

          // Product List ✅ ใช้ .buildUI() แทน .when() boilerplate
          Expanded(
            child: productAsync.buildUI(
              onRetry: () => ref.read(productListProvider.notifier).refresh(),
              data: (products) {
                // กรองสินค้า
                final filteredProducts = products.where((product) {
                  if (_searchQuery.isEmpty) return true;
                  return product.productName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      product.productCode
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                }).toList();

                // ✅ Empty state
                if (filteredProducts.isEmpty) {
                  return EmptyStateWidget(
                    icon: _searchQuery.isEmpty
                        ? Icons.inventory_2_outlined
                        : Icons.search_off_outlined,
                    title: _searchQuery.isEmpty
                        ? 'ยังไม่มีสินค้า'
                        : 'ไม่พบสินค้า "$_searchQuery"',
                    subtitle: _searchQuery.isEmpty
                        ? 'กดปุ่ม + เพื่อเพิ่มสินค้าใหม่'
                        : 'ลองค้นหาด้วยคำอื่น',
                    actionLabel: _searchQuery.isEmpty ? 'เพิ่มสินค้า' : null,
                    onAction: _searchQuery.isEmpty
                        ? () => context.pushSlide(const ProductFormPage())
                        : null,
                  );
                }

                // ✅ List พร้อม FadeSlideIn stagger
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: index * 30),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              product.productCode.length >= 2
                                  ? product.productCode.substring(0, 2)
                                  : product.productCode,
                            ),
                          ),
                          title: Text(product.productName),
                          subtitle: Text(
                            'รหัส: ${product.productCode} | ราคา: ฿${product.priceLevel1.toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductFormPage(product: product),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () => _confirmDelete(product),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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

  // ✅ แยก delete logic ออกมาเป็น method + ใช้ helper ใหม่
  Future<void> _confirmDelete(dynamic product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบสินค้า ${product.productName} ใช่หรือไม่?',
      confirmLabel: 'ลบ',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    final success = await ref
        .read(productListProvider.notifier)
        .deleteProduct(product.productId);

    if (!mounted) return;

    // ✅ ใช้ SnackBar extension
    if (success) {
      context.showSuccess('ลบสินค้าสำเร็จ');
    } else {
      context.showError('ลบสินค้าไม่สำเร็จ');
    }
  }
}