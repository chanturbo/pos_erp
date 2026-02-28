import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/data/models/product_model.dart';
import '../providers/cart_provider.dart';

class ProductGrid extends ConsumerWidget {
  final List<ProductModel> products;
  
  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('ไม่พบสินค้า'),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, ref, product);
      },
    );
  }
  
  Widget _buildProductCard(BuildContext context, WidgetRef ref, ProductModel product) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // เพิ่มสินค้าลงตะกร้า
          ref.read(cartProvider.notifier).addItem(
            productId: product.productId,
            productCode: product.productCode,
            productName: product.productName,
            unit: product.baseUnit,
            price: product.priceLevel1,
          );
          
          // แสดง Snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เพิ่ม ${product.productName} แล้ว'),
              duration: const Duration(milliseconds: 500),
              behavior: SnackBarBehavior.floating,
              width: 300,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปสินค้า
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            
            // ข้อมูลสินค้า
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productCode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '฿${product.priceLevel1.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}