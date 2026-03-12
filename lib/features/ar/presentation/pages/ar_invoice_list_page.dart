// ar_invoice_list_page.dart
// Day 36-38: AR Invoice List Page — รายการใบแจ้งหนี้ลูกหนี้

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/ar_invoice_provider.dart';
import '../../data/models/ar_invoice_model.dart';
import 'ar_invoice_form_page.dart';

class ArInvoiceListPage extends ConsumerStatefulWidget {
  const ArInvoiceListPage({super.key});

  @override
  ConsumerState<ArInvoiceListPage> createState() =>
      _ArInvoiceListPageState();
}

class _ArInvoiceListPageState extends ConsumerState<ArInvoiceListPage> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(arInvoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบแจ้งหนี้ลูกค้า (AR)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(arInvoiceListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: invoicesAsync.when(
              data: (invoices) => _buildInvoiceList(invoices),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewInvoice,
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบแจ้งหนี้'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                hintText: 'ค้นหาเลขที่ใบแจ้งหนี้, ลูกค้า...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
              DropdownMenuItem(
                  value: 'UNPAID', child: Text('ยังไม่รับ')),
              DropdownMenuItem(
                  value: 'PARTIAL', child: Text('รับบางส่วน')),
              DropdownMenuItem(value: 'PAID', child: Text('รับครบแล้ว')),
            ],
            onChanged: (value) =>
                setState(() => _statusFilter = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<ArInvoiceModel> invoices) {
    final filtered = invoices.where((inv) {
      final matchSearch = inv.invoiceNo
              .toLowerCase()
              .contains(_searchQuery) ||
          inv.customerName.toLowerCase().contains(_searchQuery);
      final matchStatus =
          _statusFilter == 'ALL' || inv.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีใบแจ้งหนี้',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewInvoice,
              icon: const Icon(Icons.add),
              label: const Text('สร้างใบแจ้งหนี้ใหม่'),
            ),
          ],
        ),
      );
    }

    // Summary bar
    final totalAR = filtered.fold(0.0, (s, i) => s + i.totalAmount);
    final totalPaid = filtered.fold(0.0, (s, i) => s + i.paidAmount);
    final totalRemaining = totalAR - totalPaid;

    return Column(
      children: [
        _buildSummaryBar(totalAR, totalPaid, totalRemaining),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _buildInvoiceCard(filtered[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(
      double totalAR, double totalPaid, double totalRemaining) {
    final fmt = NumberFormat('#,##0.00', 'th');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.teal.withValues(alpha: 0.07),
      child: Row(
        children: [
          _buildSummaryItem('ยอดรวม', '฿${fmt.format(totalAR)}',
              Colors.teal.shade700),
          const SizedBox(width: 16),
          _buildSummaryItem(
              'รับแล้ว', '฿${fmt.format(totalPaid)}', Colors.green),
          const SizedBox(width: 16),
          _buildSummaryItem('คงค้าง',
              '฿${fmt.format(totalRemaining)}', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(ArInvoiceModel invoice) {
    final fmt = NumberFormat('#,##0.00', 'th');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _viewInvoiceDetails(invoice),
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
                        Text(
                          invoice.invoiceNo,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              invoice.customerName,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(invoice),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'วันที่',
                      DateFormat('dd/MM/yyyy').format(invoice.invoiceDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.event_available,
                      'ครบกำหนด',
                      invoice.dueDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(invoice.dueDate!)
                          : '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildAmountItem(
                      'ยอดรวม', fmt.format(invoice.totalAmount), Colors.teal),
                  _buildAmountItem(
                      'รับแล้ว', fmt.format(invoice.paidAmount), Colors.green),
                  _buildAmountItem(
                    'คงค้าง',
                    fmt.format(invoice.remainingAmount),
                    invoice.remainingAmount > 0
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ],
              ),
              if (invoice.isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'เลยกำหนดชำระ',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text('฿$value',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ArInvoiceModel invoice) {
    final Map<String, (Color, String)> statusMap = {
      'UNPAID': (Colors.orange, 'ยังไม่รับ'),
      'PARTIAL': (Colors.blue, 'รับบางส่วน'),
      'PAID': (Colors.green, 'รับครบแล้ว'),
      'CANCELLED': (Colors.grey, 'ยกเลิก'),
    };

    final (color, label) =
        statusMap[invoice.status] ?? (Colors.grey, invoice.status);

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
          color: HSLColor.fromColor(color).withLightness(0.3).toColor()),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
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
            onPressed: () =>
                ref.read(arInvoiceListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewInvoice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const ArInvoiceFormPage()),
    );
    ref.read(arInvoiceListProvider.notifier).refresh();
  }

  Future<void> _viewInvoiceDetails(ArInvoiceModel invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ArInvoiceFormPage(invoice: invoice)),
    );
    ref.read(arInvoiceListProvider.notifier).refresh();
  }
}