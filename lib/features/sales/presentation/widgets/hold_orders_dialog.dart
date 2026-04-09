import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../providers/cart_provider.dart';

class HoldOrdersDialog extends ConsumerStatefulWidget {
  const HoldOrdersDialog({super.key});

  @override
  ConsumerState<HoldOrdersDialog> createState() => _HoldOrdersDialogState();
}

class _HoldOrdersDialogState extends ConsumerState<HoldOrdersDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _renameOrder(int index, HoldOrder order) async {
    final controller = TextEditingController(text: order.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'แก้ชื่อบิลที่พัก',
          icon: Icons.edit_note_rounded,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อบิล',
            hintText: 'เช่น โต๊ะ 5 / ลูกค้ารับกลับ',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    ref.read(holdOrdersProvider.notifier).renameOrder(index, result.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เปลี่ยนชื่อบิลเป็น "$result" แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holdOrdersState = ref.watch(holdOrdersProvider);
    final filteredEntries = holdOrdersState.orders.asMap().entries.where((
      entry,
    ) {
      final order = entry.value;
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();
      return order.name.toLowerCase().contains(query) ||
          (order.cartState.customerName?.toLowerCase().contains(query) ??
              false);
    }).toList();
    final orders = filteredEntries.map((entry) => entry.value).toList();

    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'บิลที่พัก (${orders.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                buildMobileCloseCompactButton(context),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อบิล, โต๊ะ, หรือลูกค้า',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),

            // Hold Orders List
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('ไม่มีบิลที่พัก'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final originalIndex = entry.key;
                        final order = entry.value;
                        final cart = order.cartState; // ✅ ดึง cartState

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              order.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${cart.items.length} รายการ'),
                                if (cart.customerName != null)
                                  Text('ลูกค้า: ${cart.customerName}'),
                                Text(
                                  'เวลา: ${DateFormat('HH:mm').format(order.timestamp)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '฿${cart.total.toStringAsFixed(2)}', // ✅ ใช้ cart.total
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'แก้ชื่อบิล',
                                  onPressed: () =>
                                      _renameOrder(originalIndex, order),
                                ),
                                // ปุ่มลบ
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: Colors.red,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AppDialog(
                                        title: buildAppDialogTitle(
                                          context,
                                          title: 'ยืนยันการลบ',
                                          icon: Icons.delete_outline,
                                          iconColor: Colors.red,
                                        ),
                                        content: Text(
                                          'ต้องการลบบิล ${order.name} ใช่หรือไม่?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('ยกเลิก'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('ลบ'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      ref
                                          .read(holdOrdersProvider.notifier)
                                          .removeOrder(originalIndex);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'ลบ ${order.name} แล้ว',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              final hasCurrentItems = ref
                                  .read(cartProvider)
                                  .items
                                  .isNotEmpty;
                              ref
                                  .read(holdOrdersProvider.notifier)
                                  .recallOrder(originalIndex);
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    hasCurrentItems
                                        ? 'เรียก ${order.name} กลับมาและรวมกับบิลปัจจุบันแล้ว'
                                        : 'เรียก ${order.name} กลับมาแล้ว',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
