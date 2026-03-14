import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/ap_invoice_provider.dart';
import '../../data/models/ap_invoice_model.dart';
import 'ap_invoice_form_page.dart';
// chanchai
class ApInvoiceListPage extends ConsumerStatefulWidget {
  const ApInvoiceListPage({super.key});

  @override
  ConsumerState<ApInvoiceListPage> createState() => _ApInvoiceListPageState();
}

class _ApInvoiceListPageState extends ConsumerState<ApInvoiceListPage> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(apInvoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบแจ้งหนี้ค้างชำระ (AP)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(apInvoiceListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: invoicesAsync.when(
              data: (invoices) => _buildInvoiceList(invoices),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewInvoice,
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบแจ้งหนี้'),
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
                hintText: 'ค้นหาเลขที่ใบแจ้งหนี้, ซัพพลายเออร์...',
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
              DropdownMenuItem(value: 'UNPAID', child: Text('ยังไม่จ่าย')),
              DropdownMenuItem(value: 'PARTIAL', child: Text('จ่ายบางส่วน')),
              DropdownMenuItem(value: 'PAID', child: Text('จ่ายครบแล้ว')),
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

  Widget _buildInvoiceList(List<ApInvoiceModel> invoices) {
    var filteredInvoices = invoices.where((invoice) {
      final matchesSearch = invoice.invoiceNo.toLowerCase().contains(_searchQuery) ||
          invoice.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus = _statusFilter == 'ALL' || invoice.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    if (filteredInvoices.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  Widget _buildInvoiceCard(ApInvoiceModel invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewInvoiceDetails(invoice),
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
                          invoice.invoiceNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.supplierName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(invoice),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(invoice.invoiceDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.event_available,
                      invoice.dueDate != null
                          ? DateFormat('dd/MM/yyyy').format(invoice.dueDate!)
                          : '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดรวม',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '฿${invoice.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จ่ายแล้ว',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '฿${invoice.paidAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คงเหลือ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '฿${invoice.remainingAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: invoice.remainingAmount > 0
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (invoice.isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'เลยกำหนดชำระ',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
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

  Widget _buildStatusChip(ApInvoiceModel invoice) {
    Color color;
    String label;

    switch (invoice.status) {
      case 'UNPAID':
        color = Colors.orange;
        label = 'ยังไม่จ่าย';
        break;
      case 'PARTIAL':
        color = Colors.blue;
        label = 'จ่ายบางส่วน';
        break;
      case 'PAID':
        color = Colors.green;
        label = 'จ่ายครบแล้ว';
        break;
      default:
        color = Colors.grey;
        label = invoice.status;
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
              ref.read(apInvoiceListProvider.notifier).refresh();
            },
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
        builder: (context) => const ApInvoiceFormPage(),
      ),
    );
  }

  Future<void> _viewInvoiceDetails(ApInvoiceModel invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApInvoiceFormPage(invoice: invoice),
      ),
    );
  }
}