import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_provider.dart';
import 'customer_form_page.dart';

class CustomerListPage extends ConsumerStatefulWidget {  // ✅ เปลี่ยนเป็น StatefulWidget
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
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
      body: Column(
        children: [
          // ✅ เพิ่ม Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาลูกค้า...',
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
          
          // Customer List
          Expanded(
            child: _buildBody(context, ref, customerState),
          ),
        ],
      ),
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
    
    // ✅ กรองลูกค้าตามการค้นหา
    final filteredCustomers = state.customers.where((customer) {
      if (_searchQuery.isEmpty) return true;
      return customer.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             customer.customerCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (customer.phone?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
    
    if (filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'ยังไม่มีลูกค้า' : 'ไม่พบลูกค้า'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = filteredCustomers[index];
        // ... โค้ดเดิม (Card ของลูกค้า)
      },
    );
  }
}