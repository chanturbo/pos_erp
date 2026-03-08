import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/ap_payment_model.dart';
import '../../data/models/ap_payment_allocation_model.dart';
import '../../data/models/ap_invoice_model.dart';
import '../providers/ap_payment_provider.dart';
import '../providers/ap_invoice_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ApPaymentFormPage extends ConsumerStatefulWidget {
  const ApPaymentFormPage({super.key});

  @override
  ConsumerState<ApPaymentFormPage> createState() => _ApPaymentFormPageState();
}

class _ApPaymentFormPageState extends ConsumerState<ApPaymentFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _paymentNoController;
  late TextEditingController _referenceNoController;
  late TextEditingController _bankNameController;
  late TextEditingController _remarkController;

  DateTime _paymentDate = DateTime.now();
  String? _supplierId;
  String? _supplierName;
  String _paymentMethod = 'CASH';

  List<ApInvoiceModel> _unpaidInvoices = [];
  final Map<String, double> _allocations = {}; // invoiceId -> amount
  bool _isLoading = false;
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _paymentNoController = TextEditingController(
      text: 'APPAY${timestamp.toString().substring(8)}',
    );
    _referenceNoController = TextEditingController();
    _bankNameController = TextEditingController();
    _remarkController = TextEditingController();
  }

  @override
  void dispose() {
    _paymentNoController.dispose();
    _referenceNoController.dispose();
    _bankNameController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จ่ายเงินซัพพลายเออร์'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaymentInfoCard(),
                    const SizedBox(height: 16),
                    _buildInvoiceAllocationCard(),
                    const SizedBox(height: 16),
                    if (_allocations.isNotEmpty) _buildSummaryCard(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลการจ่ายเงิน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // เลขที่ใบจ่ายเงิน
            TextFormField(
              controller: _paymentNoController,
              decoration: const InputDecoration(
                labelText: 'เลขที่ใบจ่ายเงิน',
                prefixIcon: Icon(Icons.receipt),
              ),
              readOnly: true,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // วันที่จ่าย
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่จ่าย'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_paymentDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectPaymentDate,
            ),

            const Divider(),

            // ซัพพลายเออร์
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business),
              title: const Text('ซัพพลายเออร์'),
              subtitle: Text(_supplierName ?? 'เลือกซัพพลายเออร์'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectSupplier,
            ),

            const Divider(),

            // วิธีจ่าย
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'วิธีจ่าย',
                prefixIcon: Icon(Icons.payment),
              ),
              initialValue: _paymentMethod,
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
                DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('เช็ค')),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // ฟิลด์เพิ่มเติมตามวิธีจ่าย
            if (_paymentMethod == 'TRANSFER') ...[
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceNoController,
                decoration: const InputDecoration(
                  labelText: 'เลขที่อ้างอิง',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
            ] else if (_paymentMethod == 'CHEQUE') ...[
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceNoController,
                decoration: const InputDecoration(
                  labelText: 'เลขที่เช็ค',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // หมายเหตุ
            TextFormField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceAllocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'จัดสรรเงินจ่าย',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_unpaidInvoices.isNotEmpty)
                  TextButton.icon(
                    onPressed: _autoAllocate,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('จัดสรรอัตโนมัติ'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_supplierId == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'กรุณาเลือกซัพพลายเออร์ก่อน',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoadingInvoices)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_unpaidInvoices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ไม่มีใบแจ้งหนี้ค้างชำระ',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._unpaidInvoices.map(
                (invoice) => _buildInvoiceAllocationRow(invoice),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceAllocationRow(ApInvoiceModel invoice) {
    final currentAllocation = _allocations[invoice.invoiceId] ?? 0;
    final controller = TextEditingController(
      text: currentAllocation > 0 ? currentAllocation.toStringAsFixed(2) : '',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'วันที่: ${DateFormat('dd/MM/yyyy').format(invoice.invoiceDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (invoice.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'เลยกำหนด',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ยอดคงเหลือ',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '฿${invoice.remainingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงินที่จ่าย',
                      prefixText: '฿',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      setState(() {
                        if (amount > 0) {
                          _allocations[invoice.invoiceId] = amount;
                        } else {
                          _allocations.remove(invoice.invoiceId);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    controller.text = invoice.remainingAmount.toStringAsFixed(
                      2,
                    );
                    setState(() {
                      _allocations[invoice.invoiceId] = invoice.remainingAmount;
                    });
                  },
                  child: const Text('จ่ายเต็ม'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalAmount = _allocations.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );

    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนใบแจ้งหนี้', style: TextStyle(fontSize: 14)),
                Text(
                  '${_allocations.length} ใบ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ยอดรวมที่จ่าย',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '฿${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _savePayment,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _paymentDate = date;
      });
    }
  }

  Future<void> _selectSupplier() async {
    final suppliersAsync = ref.read(supplierListProvider);

    await suppliersAsync.when(
      data: (suppliers) async {
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('เลือกซัพพลายเออร์'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    title: Text(supplier.supplierName),
                    subtitle: supplier.currentBalance > 0
                        ? Text(
                            'ค้างชำระ: ฿${supplier.currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.orange),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context, {
                        'id': supplier.supplierId,
                        'name': supplier.supplierName,
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        if (selected != null) {
          setState(() {
            _supplierId = selected['id'];
            _supplierName = selected['name'];
            _allocations.clear();
          });
          await _loadUnpaidInvoices();
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }

  Future<void> _loadUnpaidInvoices() async {
    if (_supplierId == null) return;

    setState(() {
      _isLoadingInvoices = true;
    });

    final invoices = await ref
        .read(apInvoiceListProvider.notifier)
        .getUnpaidInvoices(_supplierId!);

    setState(() {
      _unpaidInvoices = invoices;
      _isLoadingInvoices = false;
    });
  }

  void _autoAllocate() {
    setState(() {
      _allocations.clear();
      for (var invoice in _unpaidInvoices) {
        _allocations[invoice.invoiceId] = invoice.remainingAmount;
      }
    });
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_allocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาจัดสรรเงินให้กับใบแจ้งหนี้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกซัพพลายเออร์'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบว่าจัดสรรเกินจำนวนที่ค้างหรือไม่
    for (var entry in _allocations.entries) {
      final invoice = _unpaidInvoices.firstWhere(
        (inv) => inv.invoiceId == entry.key,
      );
      if (entry.value > invoice.remainingAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ใบแจ้งหนี้ ${invoice.invoiceNo} จ่ายเกินยอดคงเหลือ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final authState = ref.read(authProvider);
    final totalAmount = _allocations.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );

    final allocations = _allocations.entries.map((entry) {
      return ApPaymentAllocationModel(
        allocationId: '',
        paymentId: '',
        invoiceId: entry.key,
        allocatedAmount: entry.value,
        createdAt: DateTime.now(),
      );
    }).toList();

    final payment = ApPaymentModel(
      paymentId: '',
      paymentNo: _paymentNoController.text.trim(),
      paymentDate: _paymentDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: totalAmount,
      paymentMethod: _paymentMethod,
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      transferRef:
          _paymentMethod == 'TRANSFER' &&
              _referenceNoController.text.trim().isNotEmpty
          ? _referenceNoController.text.trim()
          : null,
      chequeNo:
          _paymentMethod == 'CHEQUE' &&
              _referenceNoController.text.trim().isNotEmpty
          ? _referenceNoController.text.trim()
          : null,
      userId: authState.user!.userId,
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      createdAt: DateTime.now(),
      allocations: allocations,
    );

    final success = await ref
        .read(apPaymentListProvider.notifier)
        .createPayment(payment);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        // Refresh invoice list
        ref.read(apInvoiceListProvider.notifier).refresh();
        // Refresh supplier list
        ref.read(supplierListProvider.notifier).refresh();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการจ่ายเงินสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกไม่สำเร็จ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('คำแนะนำ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'การจ่ายเงินซัพพลายเออร์',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'บันทึกการจ่ายเงินให้ซัพพลายเออร์และจัดสรรเงินให้กับใบแจ้งหนี้',
              ),
              SizedBox(height: 16),
              Text(
                'จัดสรรอัตโนมัติ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('กดปุ่ม "จัดสรรอัตโนมัติ" เพื่อจ่ายเต็มจำนวนทุกใบแจ้งหนี้'),
              SizedBox(height: 16),
              Text(
                'การอัพเดท',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'ระบบจะอัพเดทสถานะใบแจ้งหนี้และยอดค้างชำระของซัพพลายเออร์อัตโนมัติ',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
