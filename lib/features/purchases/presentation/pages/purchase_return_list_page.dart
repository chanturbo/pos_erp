import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/purchase_return_provider.dart';
import '../../data/models/purchase_return_model.dart';
import 'purchase_return_form_page.dart';

class PurchaseReturnListPage extends ConsumerStatefulWidget {
  const PurchaseReturnListPage({super.key});

  @override
  ConsumerState<PurchaseReturnListPage> createState() => _PurchaseReturnListPageState();
}

class _PurchaseReturnListPageState extends ConsumerState<PurchaseReturnListPage> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(purchaseReturnListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('คืนสินค้า (Purchase Return)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(purchaseReturnListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: returnsAsync.when(
              data: (returns) => _buildReturnList(returns),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewReturn,
        icon: const Icon(Icons.add),
        label: const Text('คืนสินค้า'),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาเลขที่ใบคืนสินค้า, ซัพพลายเออร์...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
              DropdownMenuItem(value: 'DRAFT', child: Text('แบบร่าง')),
              DropdownMenuItem(value: 'CONFIRMED', child: Text('ยืนยันแล้ว')),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReturnList(List<PurchaseReturnModel> returns) {
    var filteredReturns = returns.where((returnDoc) {
      final matchesSearch = returnDoc.returnNo.toLowerCase().contains(_searchQuery) ||
          returnDoc.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus = _statusFilter == 'ALL' || returnDoc.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    // เรียงจากใหม่ไปเก่า
    filteredReturns.sort((a, b) => b.returnDate.compareTo(a.returnDate));

    if (filteredReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีรายการคืนสินค้า',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewReturn,
              icon: const Icon(Icons.add),
              label: const Text('คืนสินค้าใหม่'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReturns.length,
      itemBuilder: (context, index) {
        final returnDoc = filteredReturns[index];
        return _buildReturnCard(returnDoc);
      },
    );
  }

  Widget _buildReturnCard(PurchaseReturnModel returnDoc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewReturnDetails(returnDoc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          returnDoc.returnNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          returnDoc.supplierName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(returnDoc.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(returnDoc.returnDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.access_time,
                      DateFormat('HH:mm').format(returnDoc.createdAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยอดรวม',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '฿${returnDoc.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              if (returnDoc.reason != null && returnDoc.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'เหตุผล: ${returnDoc.reason}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (returnDoc.isDraft) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmReturn(returnDoc),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('ยืนยัน'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteReturn(returnDoc),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('ลบ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'DRAFT':
        color = Colors.orange;
        label = 'แบบร่าง';
        break;
      case 'CONFIRMED':
        color = Colors.green;
        label = 'ยืนยันแล้ว';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: HSLColor.fromColor(color).withLightness(0.3).toColor(),
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('เกิดข้อผิดพลาด: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(purchaseReturnListProvider.notifier).refresh();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewReturn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PurchaseReturnFormPage(),
      ),
    );
    ref.read(purchaseReturnListProvider.notifier).refresh();
  }

  Future<void> _viewReturnDetails(PurchaseReturnModel returnDoc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseReturnFormPage(returnDoc: returnDoc),
      ),
    );
    ref.read(purchaseReturnListProvider.notifier).refresh();
  }

  Future<void> _confirmReturn(PurchaseReturnModel returnDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการคืนสินค้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ต้องการยืนยันใบคืนสินค้า ${returnDoc.returnNo} ใช่หรือไม่?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ระบบจะลดสต๊อกสินค้าตามจำนวนที่คืน',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(purchaseReturnListProvider.notifier).confirmReturn(returnDoc.returnId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ยืนยันสำเร็จ' : 'ยืนยันไม่สำเร็จ'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReturn(PurchaseReturnModel returnDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบใบคืนสินค้า ${returnDoc.returnNo} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(purchaseReturnListProvider.notifier).deleteReturn(returnDoc.returnId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ลบสำเร็จ' : 'ลบไม่สำเร็จ'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}