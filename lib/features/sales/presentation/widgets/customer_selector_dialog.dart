import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../customers/data/models/customer_model.dart';

class CustomerSelectorDialog extends ConsumerStatefulWidget {
  final CustomerModel? currentCustomer;
  
  const CustomerSelectorDialog({super.key, this.currentCustomer});

  @override
  ConsumerState<CustomerSelectorDialog> createState() => _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends ConsumerState<CustomerSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerListProvider);
    
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เลือกลูกค้า',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            // ✅ ปุ่มลูกค้าทั่วไป
            Card(
              color: Colors.blue[50],
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: const Text(
                  'ลูกค้าทั่วไป',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('ขายแบบไม่ระบุลูกค้า'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // ✅ ส่งค่า Walk-in customer
                  Navigator.pop(context, CustomerModel(
                    customerId: 'WALK_IN',
                    customerCode: 'WALK-IN',
                    customerName: 'ลูกค้าทั่วไป',
                  ));
                },
              ),
            ),
            const Divider(),
            
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาลูกค้า (ชื่อ, รหัส, เบอร์โทร)',
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
            const SizedBox(height: 16),
            
            // Customer List
            Expanded(
              child: customerAsync.when(
                data: (customers) {
                  // ✅ กรอง WALK_IN ออก (แสดงแยกด้านบนแล้ว)
                  final filteredCustomers = customers.where((customer) {
                    if (customer.customerId == 'WALK_IN') return false; // Skip
                    if (_searchQuery.isEmpty) return true;
                    return customer.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           customer.customerCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           (customer.phone?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                  }).toList();
                  
                  if (filteredCustomers.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('ไม่พบลูกค้า'),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final isSelected = widget.currentCustomer?.customerId == customer.customerId;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? Colors.blue[50] : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? Colors.blue : Colors.purple,
                            child: Text(
                              customer.customerName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            customer.customerName,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('รหัส: ${customer.customerCode}'),
                              if (customer.phone != null)
                                Text('โทร: ${customer.phone}'),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context, customer);
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('กำลังโหลดลูกค้า...'),
                    ],
                  ),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('เกิดข้อผิดพลาด: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(customerListProvider.notifier).refresh();
                        },
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    );
  }
}