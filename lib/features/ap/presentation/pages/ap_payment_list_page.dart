import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/ap_payment_provider.dart';
import '../../data/models/ap_payment_model.dart';
import 'ap_payment_form_page.dart';

class ApPaymentListPage extends ConsumerStatefulWidget {
  const ApPaymentListPage({super.key});

  @override
  ConsumerState<ApPaymentListPage> createState() => _ApPaymentListPageState();
}

class _ApPaymentListPageState extends ConsumerState<ApPaymentListPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(apPaymentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการจ่ายเงิน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(apPaymentListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) => _buildPaymentList(payments),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewPayment,
        icon: const Icon(Icons.add),
        label: const Text('จ่ายเงิน'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: TextField(
        decoration: InputDecoration(
          hintText: 'ค้นหาเลขที่ใบจ่ายเงิน, ซัพพลายเออร์...',
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
    );
  }

  Widget _buildPaymentList(List<ApPaymentModel> payments) {
    var filteredPayments = payments.where((payment) {
      return payment.paymentNo.toLowerCase().contains(_searchQuery) ||
          payment.supplierName.toLowerCase().contains(_searchQuery);
    }).toList();

    // เรียงจากใหม่ไปเก่า
    filteredPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    if (filteredPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีประวัติการจ่ายเงิน',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewPayment,
              icon: const Icon(Icons.add),
              label: const Text('จ่ายเงินใหม่'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPayments.length,
      itemBuilder: (context, index) {
        final payment = filteredPayments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(ApPaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewPaymentDetails(payment),
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
                          payment.paymentNo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.supplierName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPaymentMethodChip(payment.paymentMethod),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(payment.paymentDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.access_time,
                      DateFormat('HH:mm').format(payment.createdAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยอดจ่าย',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '฿${payment.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (payment.remark != null && payment.remark!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          payment.remark!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
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

  Widget _buildPaymentMethodChip(String method) {
    Color color;
    String label;
    IconData icon;

    switch (method) {
      case 'CASH':
        color = Colors.green;
        label = 'เงินสด';
        icon = Icons.money;
        break;
      case 'TRANSFER':
        color = Colors.blue;
        label = 'โอนเงิน';
        icon = Icons.account_balance;
        break;
      case 'CHEQUE':
        color = Colors.orange;
        label = 'เช็ค';
        icon = Icons.receipt;
        break;
      default:
        color = Colors.grey;
        label = method;
        icon = Icons.payment;
    }

    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: HSLColor.fromColor(color).withLightness(0.3).toColor(),
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: HSLColor.fromColor(color).withLightness(0.3).toColor(),
      ),
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
              ref.read(apPaymentListProvider.notifier).refresh();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewPayment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApPaymentFormPage()),
    );
    ref.read(apPaymentListProvider.notifier).refresh();
  }

  Future<void> _viewPaymentDetails(ApPaymentModel payment) async {
    // โหลดรายละเอียดพร้อม allocations
    final paymentDetails = await ref
        .read(apPaymentListProvider.notifier)
        .getPaymentDetails(payment.paymentId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(payment.paymentNo),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('ซัพพลายเออร์', payment.supplierName),
                _buildDetailRow(
                  'วันที่จ่าย',
                  DateFormat('dd/MM/yyyy').format(payment.paymentDate),
                ),
                _buildDetailRow(
                  'วิธีจ่าย',
                  _getPaymentMethodLabel(payment.paymentMethod),
                ),
                if (payment.bankName != null)
                  _buildDetailRow('ธนาคาร', payment.bankName!),
                if (payment.transferRef != null)
                  _buildDetailRow('เลขที่อ้างอิง', payment.transferRef!),
                if (payment.chequeNo != null)
                  _buildDetailRow('เลขที่เช็ค', payment.chequeNo!),
                _buildDetailRow(
                  'ยอดจ่าย',
                  '฿${payment.totalAmount.toStringAsFixed(2)}',
                ),
                if (payment.remark != null)
                  _buildDetailRow('หมายเหตุ', payment.remark!),

                if (paymentDetails?.allocations != null &&
                    paymentDetails!.allocations!.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'การจัดสรรเงิน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...paymentDetails.allocations!.map((alloc) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.grey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice ID: ${alloc.invoiceId}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '฿${alloc.allocatedAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          if (paymentDetails != null)
            ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('ยืนยันการลบ'),
                    content: Text('ต้องการลบ ${payment.paymentNo} ใช่หรือไม่?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('ยกเลิก'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('ลบ'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final success = await ref
                      .read(apPaymentListProvider.notifier)
                      .deletePayment(payment.paymentId);

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'ลบการจ่ายเงินสำเร็จ' : 'ลบไม่สำเร็จ',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'CHEQUE':
        return 'เช็ค';
      default:
        return method;
    }
  }
}
