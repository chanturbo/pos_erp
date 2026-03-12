// ar_receipt_list_page.dart
// Day 39-40: AR Receipt List Page — ประวัติการรับเงินจากลูกค้า

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/ar_receipt_provider.dart';
import '../../data/models/ar_receipt_model.dart';
import 'ar_receipt_form_page.dart';

class ArReceiptListPage extends ConsumerStatefulWidget {
  const ArReceiptListPage({super.key});

  @override
  ConsumerState<ArReceiptListPage> createState() =>
      _ArReceiptListPageState();
}

class _ArReceiptListPageState extends ConsumerState<ArReceiptListPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(arReceiptListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติรับเงิน (AR Receipt)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(arReceiptListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: receiptsAsync.when(
              data: (receipts) => _buildReceiptList(receipts),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewReceipt,
        icon: const Icon(Icons.add),
        label: const Text('รับเงิน'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: TextField(
        decoration: InputDecoration(
          hintText: 'ค้นหาเลขที่ใบเสร็จ, ลูกค้า...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (val) =>
            setState(() => _searchQuery = val.toLowerCase()),
      ),
    );
  }

  Widget _buildReceiptList(List<ArReceiptModel> receipts) {
    final filtered = receipts.where((rec) {
      return rec.receiptNo.toLowerCase().contains(_searchQuery) ||
          rec.customerName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('ไม่มีรายการรับเงิน',
                style:
                    TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewReceipt,
              icon: const Icon(Icons.add),
              label: const Text('บันทึกรับเงินใหม่'),
            ),
          ],
        ),
      );
    }

    // Summary
    final totalReceived =
        filtered.fold(0.0, (s, r) => s + r.totalAmount);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.teal.withValues(alpha: 0.07),
          child: Row(
            children: [
              const Icon(Icons.payments, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text('รวมรับ ${filtered.length} รายการ',
                  style: TextStyle(color: Colors.grey[700])),
              const Spacer(),
              Text(
                '฿${NumberFormat('#,##0.00', 'th').format(totalReceived)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _buildReceiptCard(filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(ArReceiptModel receipt) {
    final fmt = NumberFormat('#,##0.00', 'th');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(receipt.receiptNo,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(receipt.customerName,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '฿${fmt.format(receipt.totalAmount)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('dd/MM/yyyy').format(receipt.receiptDate),
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    _paymentIcon(receipt.paymentMethod),
                    _paymentLabel(receipt.paymentMethod),
                  ),
                ),
              ],
            ),
            if (receipt.remark != null &&
                receipt.remark!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(receipt.remark!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
            // Delete action
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteReceipt(receipt),
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                label: const Text('ลบ',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'CASH':
        return Icons.payments;
      case 'TRANSFER':
        return Icons.account_balance;
      case 'CHEQUE':
        return Icons.article;
      case 'CREDIT_CARD':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'CHEQUE':
        return 'เช็ค';
      case 'CREDIT_CARD':
        return 'บัตรเครดิต';
      default:
        return method;
    }
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
            onPressed: () =>
                ref.read(arReceiptListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewReceipt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (ctx) => const ArReceiptFormPage()),
    );
    ref.read(arReceiptListProvider.notifier).refresh();
  }

  Future<void> _deleteReceipt(ArReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'ต้องการลบใบเสร็จ ${receipt.receiptNo} ใช่หรือไม่?\nยอดในใบแจ้งหนี้จะถูกคืน'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(arReceiptListProvider.notifier)
          .deleteReceipt(receipt.receiptId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '✅ ลบใบเสร็จสำเร็จ' : '❌ ลบไม่สำเร็จ'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    }
  }
}