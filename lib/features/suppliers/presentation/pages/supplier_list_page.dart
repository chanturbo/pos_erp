import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supplier_provider.dart';
import '../widgets/supplier_form_dialog.dart';
import '../../data/models/supplier_model.dart';

class SupplierListPage extends ConsumerStatefulWidget {
  const SupplierListPage({super.key});

  @override
  ConsumerState<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends ConsumerState<SupplierListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ซัพพลายเออร์'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(supplierListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาซัพพลายเออร์...',
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
                  onPressed: () {
                    _showSupplierForm(context, null);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มซัพพลายเออร์'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Supplier List
          Expanded(
            child: supplierAsync.when(
              data: (suppliers) {
                // กรองตามการค้นหา
                final filteredSuppliers = suppliers.where((supplier) {
                  if (_searchQuery.isEmpty) return true;
                  return supplier.supplierName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      supplier.supplierCode
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (supplier.phone
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false);
                }).toList();

                if (filteredSuppliers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('ไม่พบข้อมูลซัพพลายเออร์'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSuppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = filteredSuppliers[index];
                    return _buildSupplierCard(supplier);
                  },
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('กำลังโหลดซัพพลายเออร์...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('เกิดข้อผิดพลาด: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(supplierListProvider.notifier).refresh();
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
    );
  }

  Widget _buildSupplierCard(SupplierModel supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: supplier.isActive ? Colors.blue : Colors.grey,
          child: Text(
            supplier.supplierName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          supplier.supplierName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รหัส: ${supplier.supplierCode}'),
            if (supplier.contactPerson != null)
              Text('ติดต่อ: ${supplier.contactPerson}'),
            if (supplier.phone != null) Text('โทร: ${supplier.phone}'),
            if (supplier.lineId != null) Text('Line: ${supplier.lineId}'),
            Row(
              children: [
                Text('เครดิต: ${supplier.creditTerm} วัน'),
                const SizedBox(width: 16),
                Text(
                    'วงเงิน: ฿${supplier.creditLimit.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active/Inactive Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: supplier.isActive ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                supplier.isActive ? 'ใช้งาน' : 'ระงับ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('แก้ไข'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ลบ', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showSupplierForm(context, supplier);
                } else if (value == 'delete') {
                  _confirmDelete(supplier);
                }
              },
            ),
          ],
        ),
        onTap: () {
          _showSupplierDetails(supplier);
        },
      ),
    );
  }

  void _showSupplierForm(BuildContext context, SupplierModel? supplier) {
    showDialog(
      context: context,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    );
  }

  void _showSupplierDetails(SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier.supplierName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('รหัส', supplier.supplierCode),
              _buildDetailRow('ผู้ติดต่อ', supplier.contactPerson ?? '-'),
              _buildDetailRow('โทรศัพท์', supplier.phone ?? '-'),
              _buildDetailRow('อีเมล', supplier.email ?? '-'),
              _buildDetailRow('Line ID', supplier.lineId ?? '-'),
              _buildDetailRow('ที่อยู่', supplier.address ?? '-'),
              _buildDetailRow('เลขผู้เสียภาษี', supplier.taxId ?? '-'),
              _buildDetailRow('เครดิต', '${supplier.creditTerm} วัน'),
              _buildDetailRow(
                  'วงเงินเครดิต', '฿${supplier.creditLimit.toStringAsFixed(0)}'),
              _buildDetailRow(
                  'สถานะ', supplier.isActive ? 'ใช้งาน' : 'ระงับ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSupplierForm(context, supplier);
            },
            child: const Text('แก้ไข'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ ${supplier.supplierName} ใช่หรือไม่?'),
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
          .read(supplierListProvider.notifier)
          .deleteSupplier(supplier.supplierId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'ลบซัพพลายเออร์สำเร็จ' : 'เกิดข้อผิดพลาด'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}