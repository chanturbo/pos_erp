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
    final customerState = ref.watch(customerListProvider);
    
    // กรองลูกค้าตามการค้นหา
    final filteredCustomers = customerState.customers.where((customer) {
      if (_searchQuery.isEmpty) return true;
      return customer.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             customer.customerCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (customer.phone?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
    
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
              child: customerState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCustomers.isEmpty
                      ? const Center(child: Text('ไม่พบลูกค้า'))
                      : ListView.builder(
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            final isSelected = widget.currentCustomer?.customerId == customer.customerId;
                            
                            return Card(
                              color: isSelected ? Colors.blue[50] : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? Colors.blue : Colors.purple,
                                  child: Text(
                                    customer.customerName.substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(customer.customerName),
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
                                    : null,
                                onTap: () {
                                  Navigator.pop(context, customer);
                                },
                              ),
                            );
                          },
                        ),
            ),
            
            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, null); // Clear customer
                    },
                    child: const Text('ล้างลูกค้า'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('ยกเลิก'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}