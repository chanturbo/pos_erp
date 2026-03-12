// ar_receipt_form_page.dart
// Day 39-40: AR Receipt Form Page — บันทึกรับเงินจากลูกค้า

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/ar_receipt_model.dart';
import '../../data/models/ar_receipt_allocation_model.dart';
import '../../data/models/ar_invoice_model.dart';
import '../providers/ar_receipt_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ArReceiptFormPage extends ConsumerStatefulWidget {
  /// ถ้าส่ง preselectedInvoice มา จะ pre-fill ลูกค้าและ allocate ให้อัตโนมัติ
  final ArInvoiceModel? preselectedInvoice;

  const ArReceiptFormPage({super.key, this.preselectedInvoice});

  @override
  ConsumerState<ArReceiptFormPage> createState() =>
      _ArReceiptFormPageState();
}

class _ArReceiptFormPageState extends ConsumerState<ArReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _receiptNoCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _chequeNoCtrl;
  late TextEditingController _transferRefCtrl;
  late TextEditingController _remarkCtrl;

  DateTime _receiptDate = DateTime.now();
  DateTime? _chequeDate;
  String? _customerId;
  String? _customerName;
  String _paymentMethod = 'CASH';

  List<ArInvoiceModel> _unpaidInvoices = [];
  final Map<String, TextEditingController> _allocCtrl = {};
  bool _isLoading = false;
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _receiptNoCtrl =
        TextEditingController(text: 'ARREC${ts.toString().substring(8)}');
    _bankNameCtrl = TextEditingController();
    _chequeNoCtrl = TextEditingController();
    _transferRefCtrl = TextEditingController();
    _remarkCtrl = TextEditingController();

    // Pre-fill ถ้ามี invoice ส่งมา
    if (widget.preselectedInvoice != null) {
      final inv = widget.preselectedInvoice!;
      _customerId = inv.customerId;
      _customerName = inv.customerName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUnpaidInvoices(inv.customerId, preselectInvoice: inv);
      });
    }
  }

  @override
  void dispose() {
    _receiptNoCtrl.dispose();
    _bankNameCtrl.dispose();
    _chequeNoCtrl.dispose();
    _transferRefCtrl.dispose();
    _remarkCtrl.dispose();
    for (final ctrl in _allocCtrl.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnpaidInvoices(String customerId,
      {ArInvoiceModel? preselectInvoice}) async {
    setState(() => _isLoadingInvoices = true);
    try {
      final apiClient =
          ref.read(apiClientProvider);
      final response = await apiClient
          .get('/api/ar-invoices/customer/$customerId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final invoices = data
            .map((j) =>
                ArInvoiceModel.fromJson(j as Map<String, dynamic>))
            .where((inv) => inv.status != 'PAID')
            .toList();

        setState(() {
          _unpaidInvoices = invoices;
          // สร้าง controller สำหรับแต่ละใบ
          for (final inv in invoices) {
            if (!_allocCtrl.containsKey(inv.invoiceId)) {
              // ถ้าเป็น preselect ให้ใส่ยอดค้างชำระเลย
              final defaultAmt = preselectInvoice?.invoiceId ==
                      inv.invoiceId
                  ? inv.remainingAmount.toStringAsFixed(2)
                  : '0';
              _allocCtrl[inv.invoiceId] =
                  TextEditingController(text: defaultAmt);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      setState(() => _isLoadingInvoices = false);
    }
  }

  double get _totalAllocated {
    return _allocCtrl.values
        .fold(0.0, (sum, ctrl) => sum + (double.tryParse(ctrl.text) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บันทึกรับเงิน (AR Receipt)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                    _buildReceiptInfoCard(),
                    const SizedBox(height: 16),
                    _buildPaymentMethodCard(),
                    const SizedBox(height: 16),
                    _buildInvoiceAllocationCard(),
                    const SizedBox(height: 16),
                    if (_totalAllocated > 0) _buildSummaryCard(),
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

  // ─── Receipt Info Card ────────────────────────────────────────────────────
  Widget _buildReceiptInfoCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลใบเสร็จ',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _receiptNoCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'เลขที่ใบเสร็จ',
                prefixIcon: Icon(Icons.receipt),
              ),
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.calendar_today, color: Colors.teal),
              title: const Text('วันที่รับเงิน'),
              subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(_receiptDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectReceiptDate,
            ),
            const Divider(),

            // ลูกค้า
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Colors.teal),
              title: const Text('ลูกค้า'),
              subtitle: Text(_customerName ?? 'เลือกลูกค้า'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectCustomer,
            ),
            const Divider(),

            TextFormField(
              controller: _remarkCtrl,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Payment Method Card ──────────────────────────────────────────────────
  Widget _buildPaymentMethodCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('วิธีการรับเงิน',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Method selector
            Wrap(
              spacing: 8,
              children: [
                _methodChip('CASH', '💵 เงินสด'),
                _methodChip('TRANSFER', '🏦 โอนเงิน'),
                _methodChip('CHEQUE', '📋 เช็ค'),
                _methodChip('CREDIT_CARD', '💳 บัตรเครดิต'),
              ],
            ),
            const SizedBox(height: 16),

            // Extra fields
            if (_paymentMethod == 'TRANSFER' ||
                _paymentMethod == 'CREDIT_CARD') ...[
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transferRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'เลขที่อ้างอิง',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
            ],

            if (_paymentMethod == 'CHEQUE') ...[
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _chequeNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'เลขที่เช็ค',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('วันที่เช็ค'),
                subtitle: Text(_chequeDate != null
                    ? DateFormat('dd/MM/yyyy').format(_chequeDate!)
                    : 'เลือกวันที่'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectChequeDate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final selected = _paymentMethod == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _paymentMethod = value),
      selectedColor: Colors.teal.withValues(alpha: 0.2),
      labelStyle: TextStyle(
          color: selected ? Colors.teal.shade800 : null,
          fontWeight:
              selected ? FontWeight.bold : FontWeight.normal),
    );
  }

  // ─── Invoice Allocation Card ──────────────────────────────────────────────
  Widget _buildInvoiceAllocationCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('จัดสรรกับใบแจ้งหนี้',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_customerId == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('กรุณาเลือกลูกค้าก่อน',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else if (_isLoadingInvoices)
              const Center(child: CircularProgressIndicator())
            else if (_unpaidInvoices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: Colors.green),
                      SizedBox(height: 8),
                      Text('ไม่มีใบแจ้งหนี้ค้างชำระ',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ..._unpaidInvoices.map((inv) => _buildInvoiceRow(inv)),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(ArInvoiceModel inv) {
    final fmt = NumberFormat('#,##0.00', 'th');
    final ctrl = _allocCtrl[inv.invoiceId]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                      Text(inv.invoiceNo,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (inv.dueDate != null)
                        Text(
                          'ครบกำหนด: ${DateFormat('dd/MM/yyyy').format(inv.dueDate!)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: inv.isOverdue
                                  ? Colors.red
                                  : Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (inv.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('เลยกำหนด',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade700)),
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
                      Text('ยอดรวม',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                      Text('฿${fmt.format(inv.totalAmount)}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('รับแล้ว',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                      Text('฿${fmt.format(inv.paidAmount)}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('คงค้าง',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                      Text(
                        '฿${fmt.format(inv.remainingAmount)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'จำนวนที่รับ',
                      prefixText: '฿ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ctrl.text =
                        inv.remainingAmount.toStringAsFixed(2);
                    setState(() {});
                  },
                  child: const Text('เต็มจำนวน'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Summary Card ─────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final fmt = NumberFormat('#,##0.00', 'th');
    final allocCount =
        _allocCtrl.values.where((c) => (double.tryParse(c.text) ?? 0) > 0).length;

    return Card(
      color: Colors.teal.withValues(alpha: 0.08),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนใบแจ้งหนี้ที่รับ'),
                Text('$allocCount ใบ'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดรับรวม',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '฿${fmt.format(_totalAllocated)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Actions ───────────────────────────────────────────────────────
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
              onPressed: _isLoading ? null : _saveReceipt,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึกรับเงิน'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Future<void> _selectReceiptDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _receiptDate = d);
  }

  Future<void> _selectChequeDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _chequeDate = d);
  }

  Future<void> _selectCustomer() async {
    final customersAsync = ref.read(customerListProvider);
    await customersAsync.when(
      data: (customers) async {
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('เลือกลูกค้า'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (ctx, i) {
                  final c = customers[i];
                  return ListTile(
                    leading:
                        const Icon(Icons.person, color: Colors.teal),
                    title: Text(c.customerName),
                    subtitle: Text(c.customerCode),
                    onTap: () => Navigator.pop(ctx, {
                      'id': c.customerId,
                      'name': c.customerName,
                    }),
                  );
                },
              ),
            ),
          ),
        );

        if (selected != null) {
          // clear old allocations
          for (final ctrl in _allocCtrl.values) {
            ctrl.dispose();
          }
          _allocCtrl.clear();
          setState(() {
            _customerId = selected['id'];
            _customerName = selected['name'];
            _unpaidInvoices = [];
          });
          await _loadUnpaidInvoices(selected['id']!);
        }
      },
      loading: () {},
      error: (err, stack) {},
    );
  }

  Future<void> _saveReceipt() async {
    if (_customerId == null) {
      _showError('กรุณาเลือกลูกค้า');
      return;
    }

    if (_totalAllocated <= 0) {
      _showError('กรุณาระบุจำนวนที่รับอย่างน้อย 1 ใบ');
      return;
    }

    // Validate ไม่เกินยอดค้าง
    for (final inv in _unpaidInvoices) {
      final amt =
          double.tryParse(_allocCtrl[inv.invoiceId]?.text ?? '0') ?? 0;
      if (amt > inv.remainingAmount + 0.01) {
        _showError(
            'จำนวนที่รับเกินยอดค้าง: ${inv.invoiceNo}\nยอดค้าง: ฿${inv.remainingAmount.toStringAsFixed(2)}');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.userId ?? 'unknown';

      // สร้าง allocations list
      final allocations = <ArReceiptAllocationModel>[];
      for (final inv in _unpaidInvoices) {
        final amt =
            double.tryParse(_allocCtrl[inv.invoiceId]?.text ?? '0') ??
                0;
        if (amt > 0) {
          allocations.add(ArReceiptAllocationModel(
            allocationId: '',
            receiptId: '',
            invoiceId: inv.invoiceId,
            invoiceNo: inv.invoiceNo,
            allocatedAmount: amt,
            createdAt: DateTime.now(),
          ));
        }
      }

      final receipt = ArReceiptModel(
        receiptId: '',
        receiptNo: _receiptNoCtrl.text.trim(),
        receiptDate: _receiptDate,
        customerId: _customerId!,
        customerName: _customerName!,
        totalAmount: _totalAllocated,
        paymentMethod: _paymentMethod,
        bankName: _bankNameCtrl.text.trim().isEmpty
            ? null
            : _bankNameCtrl.text.trim(),
        chequeNo: _chequeNoCtrl.text.trim().isEmpty
            ? null
            : _chequeNoCtrl.text.trim(),
        chequeDate: _chequeDate,
        transferRef: _transferRefCtrl.text.trim().isEmpty
            ? null
            : _transferRefCtrl.text.trim(),
        userId: userId,
        remark: _remarkCtrl.text.trim().isEmpty
            ? null
            : _remarkCtrl.text.trim(),
        createdAt: DateTime.now(),
        allocations: allocations,
      );

      final success = await ref
          .read(arReceiptListProvider.notifier)
          .createReceipt(receipt);

      setState(() => _isLoading = false);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ บันทึกรับเงินสำเร็จ'),
            backgroundColor: Colors.green,
          ));
        } else {
          _showError('บันทึกไม่สำเร็จ กรุณาลองใหม่');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('เกิดข้อผิดพลาด: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}