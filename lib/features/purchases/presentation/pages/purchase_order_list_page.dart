import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/purchase_provider.dart';
import '../../data/models/purchase_order_model.dart';
import 'purchase_order_form_page.dart';

class PurchaseOrderListPage extends ConsumerStatefulWidget {
  const PurchaseOrderListPage({super.key});

  @override
  ConsumerState<PurchaseOrderListPage> createState() => _PurchaseOrderListPageState();
}

class _PurchaseOrderListPageState extends ConsumerState<PurchaseOrderListPage> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final purchaseOrdersAsync = ref.watch(purchaseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบสั่งซื้อ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(purchaseListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเลขที่ PO, ซัพพลายเออร์...',
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
                    DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
                    DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')),
                    DropdownMenuItem(value: 'PARTIAL', child: Text('รับบางส่วน')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('เสร็จสมบูรณ์')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                    });
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: purchaseOrdersAsync.when(
              data: (orders) {
                // Filter
                var filteredOrders = orders.where((order) {
                  final matchesSearch = order.poNo.toLowerCase().contains(_searchQuery) ||
                      (order.supplierName?.toLowerCase().contains(_searchQuery) ?? false);
                  final matchesStatus = _statusFilter == 'ALL' || order.status == _statusFilter;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'ไม่มีใบสั่งซื้อ',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildPurchaseOrderCard(order);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('เกิดข้อผิดพลาด: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(purchaseListProvider.notifier).refresh();
                      },
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PurchaseOrderFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบสั่งซื้อ'),
      ),
    );
  }

  Widget _buildPurchaseOrderCard(PurchaseOrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseOrderFormPage(order: order),
            ),
          );
        },
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
                          order.poNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.supplierName ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusChip(order.status),
                      const SizedBox(height: 4),
                      _buildPaymentStatusChip(order.paymentStatus),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(order.poDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.warehouse,
                      order.warehouseName ?? '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ยอดรวม',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '฿${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              if (order.status == 'DRAFT') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deletePurchaseOrder(order),
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
                        onPressed: () => _approvePurchaseOrder(order),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('อนุมัติ'),
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
        color = Colors.grey;
        label = 'ร่าง';
        break;
      case 'APPROVED':
        color = Colors.blue;
        label = 'อนุมัติแล้ว';
        break;
      case 'PARTIAL':
        color = Colors.orange;
        label = 'รับบางส่วน';
        break;
      case 'COMPLETED':
        color = Colors.green;
        label = 'เสร็จสมบูรณ์';
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

  Widget _buildPaymentStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'UNPAID':
        color = Colors.red;
        label = 'ยังไม่จ่าย';
        break;
      case 'PARTIAL':
        color = Colors.orange;
        label = 'จ่ายบางส่วน';
        break;
      case 'PAID':
        color = Colors.green;
        label = 'จ่ายแล้ว';
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

  Future<void> _deletePurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบใบสั่งซื้อ ${order.poNo} ใช่หรือไม่?'),
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
          .read(purchaseListProvider.notifier)
          .deletePurchaseOrder(order.poId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ลบใบสั่งซื้อสำเร็จ' : 'ลบใบสั่งซื้อไม่สำเร็จ'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePurchaseOrder(PurchaseOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการอนุมัติ'),
        content: Text('คุณต้องการอนุมัติใบสั่งซื้อ ${order.poNo} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(purchaseListProvider.notifier)
          .approvePurchaseOrder(order.poId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'อนุมัติใบสั่งซื้อสำเร็จ' : 'อนุมัติใบสั่งซื้อไม่สำเร็จ'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}