import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_provider.dart';
import 'customer_form_page.dart';

class CustomerListPage extends ConsumerWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerState = ref.watch(customerListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการลูกค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () {
              ref.read(customerListProvider.notifier).loadCustomers();
            },
          ),
        ],
      ),
      body: _buildBody(context, ref, customerState),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildBody(BuildContext context, WidgetRef ref, CustomerListState state) {
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
                ref.read(customerListProvider.notifier).loadCustomers();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }
    
    if (state.customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('ยังไม่มีลูกค้า'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerFormPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มลูกค้า'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.customers.length,
      itemBuilder: (context, index) {
        final customer = state.customers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple,
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
                if (customer.memberNo != null)
                  Text('สมาชิก: ${customer.memberNo} | คะแนน: ${customer.points}'),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerFormPage(customer: customer),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ยืนยันการลบ'),
                        content: Text('ต้องการลบลูกค้า ${customer.customerName} ใช่หรือไม่?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final success = await ref
                          .read(customerListProvider.notifier)
                          .deleteCustomer(customer.customerId);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'ลบลูกค้าสำเร็จ' : 'ลบลูกค้าไม่สำเร็จ'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}