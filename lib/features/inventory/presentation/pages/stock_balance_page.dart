import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_in_dialog.dart';
import '../widgets/stock_out_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';
import '../widgets/stock_transfer_dialog.dart'; // ✅ เพิ่ม
import 'stock_movement_history_page.dart'; // ✅ เพิ่ม

class StockBalancePage extends ConsumerStatefulWidget {
  const StockBalancePage({super.key});

  @override
  ConsumerState<StockBalancePage> createState() => _StockBalancePageState();
}

class _StockBalancePageState extends ConsumerState<StockBalancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สต๊อกคงเหลือ'),
        actions: [
          // ✅ เพิ่มปุ่มดูประวัติ
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ประวัติการเคลื่อนไหว',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StockMovementHistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(stockBalanceProvider.notifier).loadStockBalance();
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

          // Stock List
          Expanded(child: _buildBody(context, ref, stockState)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    StockBalanceState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                ref.read(stockBalanceProvider.notifier).loadStockBalance();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    // กรองสต๊อกตามการค้นหา
    final filteredStocks = state.stocks.where((stock) {
      if (_searchQuery.isEmpty) return true;
      return stock.productName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          stock.productCode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredStocks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('ไม่พบข้อมูลสต๊อก'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredStocks.length,
      itemBuilder: (context, index) {
        final stock = filteredStocks[index];
        final isLowStock = stock.balance < 10; // ✅ Low stock alert

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLowStock ? Colors.red : Colors.green,
              child: Icon(
                isLowStock ? Icons.warning : Icons.inventory,
                color: Colors.white,
              ),
            ),
            title: Text(stock.productName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รหัส: ${stock.productCode}'),
                Text('คลัง: ${stock.warehouseName}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stock.balance.toStringAsFixed(0)} ${stock.baseUnit}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLowStock ? Colors.red : Colors.green,
                  ),
                ),
                if (isLowStock)
                  const Text(
                    'สต๊อกต่ำ!',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
              ],
            ),
            onTap: () {
              _showStockActions(context, stock);
            },
          ),
        );
      },
    );
  }

  void _showStockActions(BuildContext context, stock) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_box, color: Colors.green),
            title: const Text('รับสินค้าเข้า'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => StockInDialog(stock: stock),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle, color: Colors.orange),
            title: const Text('เบิกสินค้าออก'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => StockOutDialog(stock: stock),
              );
            },
          ),
          // ✅ เพิ่มปุ่มโอนย้าย
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.purple),
            title: const Text('โอนย้ายสินค้า'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => StockTransferDialog(stock: stock),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('ปรับสต๊อก'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => StockAdjustDialog(stock: stock),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
