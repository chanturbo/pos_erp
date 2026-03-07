import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/goods_receipt_provider.dart';
import '../../data/models/goods_receipt_model.dart';
import 'goods_receipt_form_page.dart';

class GoodsReceiptListPage extends ConsumerStatefulWidget {
  const GoodsReceiptListPage({super.key});

  @override
  ConsumerState<GoodsReceiptListPage> createState() => _GoodsReceiptListPageState();
}

class _GoodsReceiptListPageState extends ConsumerState<GoodsReceiptListPage> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(goodsReceiptListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบรับสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(goodsReceiptListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          _buildSearchAndFilter(),

          // List
          Expanded(
            child: receiptsAsync.when(
              data: (receipts) => _buildReceiptList(receipts),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewReceipt,
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบรับสินค้า'),
      ),
    );
  }

  // Search & Filter Bar
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาเลขที่ใบรับสินค้า, PO, ซัพพลายเออร์...',
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
          
          // Status Filter
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
              DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
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

  // Receipt List
  Widget _buildReceiptList(List<GoodsReceiptModel> receipts) {
    // Filter
    var filteredReceipts = receipts.where((receipt) {
      final matchesSearch = receipt.grNo.toLowerCase().contains(_searchQuery) ||
          (receipt.poNo?.toLowerCase().contains(_searchQuery) ?? false) ||
          receipt.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus = _statusFilter == 'ALL' || receipt.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    if (filteredReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีใบรับสินค้า',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewReceipt,
              icon: const Icon(Icons.add),
              label: const Text('สร้างใบรับสินค้าใหม่'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReceipts.length,
      itemBuilder: (context, index) {
        final receipt = filteredReceipts[index];
        return _buildReceiptCard(receipt);
      },
    );
  }

  // Receipt Card
  Widget _buildReceiptCard(GoodsReceiptModel receipt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewReceiptDetails(receipt),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.grNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (receipt.poNo != null)
                          Row(
                            children: [
                              Icon(Icons.link, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'PO: ${receipt.poNo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(receipt.status),
                ],
              ),
              
              const Divider(height: 24),
              
              // Info Rows
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(receipt.grDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.business,
                      receipt.supplierName,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.warehouse,
                      receipt.warehouseName,
                    ),
                  ),
                  if (receipt.remark != null)
                    Expanded(
                      child: _buildInfoRow(
                        Icons.note,
                        receipt.remark!,
                      ),
                    ),
                ],
              ),
              
              // Actions (เฉพาะ DRAFT)
              if (receipt.status == 'DRAFT') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteReceipt(receipt),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('ลบ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmReceipt(receipt),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('ยืนยันรับสินค้า'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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

  // Status Chip
  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'DRAFT':
        color = Colors.orange;
        label = 'ร่าง';
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
      labelStyle: TextStyle(color: HSLColor.fromColor(color).withLightness(0.3).toColor(),),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  // Info Row
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

  // Error Widget
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
              ref.read(goodsReceiptListProvider.notifier).refresh();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // Create New Receipt
  Future<void> _createNewReceipt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GoodsReceiptFormPage(),
      ),
    );
  }

  // View Receipt Details
  Future<void> _viewReceiptDetails(GoodsReceiptModel receipt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoodsReceiptFormPage(receipt: receipt),
      ),
    );
  }

  // Confirm Receipt
  Future<void> _confirmReceipt(GoodsReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการรับสินค้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการยืนยันการรับสินค้า ${receipt.grNo} ใช่หรือไม่?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การยืนยันจะทำให้สินค้าเข้าสต๊อกและไม่สามารถแก้ไขได้',
                      style: TextStyle(fontSize: 12),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(goodsReceiptListProvider.notifier)
          .confirmGoodsReceipt(receipt.grId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'ยืนยันรับสินค้าสำเร็จ - สินค้าเข้าสต๊อกแล้ว' 
                  : 'ยืนยันรับสินค้าไม่สำเร็จ'
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Delete Receipt
  Future<void> _deleteReceipt(GoodsReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบใบรับสินค้า ${receipt.grNo} ใช่หรือไม่?'),
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
      final success = await ref
          .read(goodsReceiptListProvider.notifier)
          .deleteGoodsReceipt(receipt.grId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ลบใบรับสินค้าสำเร็จ' : 'ลบใบรับสินค้าไม่สำเร็จ'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}