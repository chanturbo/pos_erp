import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/stock_movement_model.dart';

// Movement History Provider
final movementHistoryProvider = FutureProvider<List<StockMovementModel>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get('/api/stock/movements');
    
    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      return data.map((json) => StockMovementModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

class StockMovementHistoryPage extends ConsumerWidget {
  const StockMovementHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementHistoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการเคลื่อนไหวสต๊อก'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(movementHistoryProvider);
            },
          ),
        ],
      ),
      body: movementsAsync.when(
        data: (movements) => _buildList(context, movements),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text('เกิดข้อผิดพลาด: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(movementHistoryProvider),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildList(BuildContext context, List<StockMovementModel> movements) {
    if (movements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('ยังไม่มีประวัติการเคลื่อนไหว'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getMovementColor(movement.movementType),
              child: Icon(
                _getMovementIcon(movement.movementType),
                color: Colors.white,
              ),
            ),
            title: Text(movement.movementTypeText),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd/MM/yyyy HH:mm').format(movement.movementDate)),
                if (movement.referenceNo != null)
                  Text('อ้างอิง: ${movement.referenceNo}'),
                if (movement.remark != null)
                  Text('หมายเหตุ: ${movement.remark}'),
              ],
            ),
            trailing: Text(
              '${movement.quantity >= 0 ? '+' : ''}${movement.quantity.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: movement.quantity >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Color _getMovementColor(String type) {
    switch (type) {
      case 'IN':
        return Colors.green;
      case 'OUT':
        return Colors.orange;
      case 'TRANSFER_IN':
      case 'TRANSFER_OUT':
        return Colors.purple;
      case 'ADJUST':
        return Colors.blue;
      case 'SALE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getMovementIcon(String type) {
    switch (type) {
      case 'IN':
        return Icons.add_box;
      case 'OUT':
        return Icons.remove_circle;
      case 'TRANSFER_IN':
      case 'TRANSFER_OUT':
        return Icons.swap_horiz;
      case 'ADJUST':
        return Icons.edit;
      case 'SALE':
        return Icons.shopping_cart;
      default:
        return Icons.inventory;
    }
  }
}