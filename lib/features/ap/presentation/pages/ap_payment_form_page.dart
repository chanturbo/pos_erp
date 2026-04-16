import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
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
  final Map<String, double> _allocations = {};
  bool _isLoading = false;
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _paymentNoController = TextEditingController(
      text: 'APPAY${ts.toString().substring(8)}',
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

  // ─────────────────────────────────────────────────────────────
  Color get _accentColor => AppTheme.tealColor;

  double get _totalAmount => _allocations.values.fold(0, (s, v) => s + v);

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF0F2F5),
      body: EscapePopScope(
        child: Column(
          children: [
            _PayFormTitleBar(isDark: isDark),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(isDark),
                      const SizedBox(height: 14),
                      _buildAllocationSection(isDark),
                      if (_allocations.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildSummarySection(isDark),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─── Section 1: ข้อมูลการจ่ายเงิน ──────────────────────────
  Widget _buildInfoSection(bool isDark) {
    return _SectionCard(
      icon: Icons.payments_outlined,
      title: 'ข้อมูลการจ่ายเงิน',
      color: _accentColor,
      isDark: isDark,
      child: Column(
        children: [
          // เลขที่ใบจ่ายเงิน
          _PayTextField(
            controller: _paymentNoController,
            hint: 'เลขที่ใบจ่ายเงิน',
            icon: Icons.receipt_outlined,
            isDark: isDark,
            readOnly: true,
          ),
          const SizedBox(height: 12),

          // วันที่จ่าย
          _DatePickerField(
            label: 'วันที่จ่าย',
            date: _paymentDate,
            isDark: isDark,
            accentColor: _accentColor,
            onPick: _selectPaymentDate,
          ),
          const SizedBox(height: 12),

          // ซัพพลายเออร์
          _SupplierPickerField(
            supplierName: _supplierName,
            isDark: isDark,
            accentColor: _accentColor,
            onPick: _selectSupplier,
          ),
          const SizedBox(height: 12),

          // วิธีจ่าย
          _PayMethodDropdown(
            value: _paymentMethod,
            isDark: isDark,
            accentColor: _accentColor,
            onChanged: (v) => setState(() {
              _paymentMethod = v!;
              _referenceNoController.clear();
              _bankNameController.clear();
            }),
          ),

          // ฟิลด์เพิ่มเติมตามวิธีจ่าย
          if (_paymentMethod == 'TRANSFER' || _paymentMethod == 'CHEQUE') ...[
            const SizedBox(height: 12),
            _PayTextField(
              controller: _bankNameController,
              hint: 'ธนาคาร',
              icon: Icons.account_balance_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _PayTextField(
              controller: _referenceNoController,
              hint: _paymentMethod == 'CHEQUE' ? 'เลขที่เช็ค' : 'เลขที่อ้างอิง',
              icon: Icons.confirmation_number_outlined,
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 12),

          // หมายเหตุ
          _PayTextField(
            controller: _remarkController,
            hint: 'หมายเหตุ',
            icon: Icons.notes_outlined,
            isDark: isDark,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ─── Section 2: จัดสรรเงินจ่าย ──────────────────────────────
  Widget _buildAllocationSection(bool isDark) {
    return _SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'จัดสรรเงินจ่าย',
      color: _accentColor,
      isDark: isDark,
      trailing: _unpaidInvoices.isNotEmpty
          ? GestureDetector(
              onTap: _autoAllocate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: _accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'จัดสรรอัตโนมัติ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      child: _supplierId == null
          ? _buildAllocationPlaceholder(
              icon: Icons.business_outlined,
              message: 'กรุณาเลือกซัพพลายเออร์ก่อน',
              isDark: isDark,
            )
          : _isLoadingInvoices
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          : _unpaidInvoices.isEmpty
          ? _buildAllocationPlaceholder(
              icon: Icons.check_circle_outline,
              message: 'ไม่มีใบแจ้งหนี้ค้างชำระ',
              color: AppTheme.success,
              isDark: isDark,
            )
          : Column(
              children: _unpaidInvoices
                  .map((inv) => _buildAllocationRow(inv, isDark))
                  .toList(),
            ),
    );
  }

  Widget _buildAllocationPlaceholder({
    required IconData icon,
    required String message,
    Color? color,
    required bool isDark,
  }) {
    final c = color ?? (isDark ? const Color(0xFF666666) : Colors.grey[400]!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: c),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF888888) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationRow(ApInvoiceModel invoice, bool isDark) {
    final currentAlloc = _allocations[invoice.invoiceId] ?? 0;
    final controller = TextEditingController(
      text: currentAlloc > 0 ? currentAlloc.toStringAsFixed(2) : '',
    );
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: invoice.isOverdue
              ? AppTheme.error.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF333333) : AppTheme.border),
        ),
      ),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(invoice.invoiceDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (invoice.isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'เลยกำหนด',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ยอดคงเหลือ',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : AppTheme.textSub,
                      ),
                    ),
                    Text(
                      '฿${fmt.format(invoice.remainingAmount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '฿',
                      hintStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF666666)
                            : Colors.grey[400],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF444444)
                              : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF444444)
                              : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _accentColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : Colors.white,
                    ),
                    onChanged: (v) {
                      final amount = double.tryParse(v) ?? 0;
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
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: () {
                    controller.text = invoice.remainingAmount.toStringAsFixed(
                      2,
                    );
                    setState(() {
                      _allocations[invoice.invoiceId] = invoice.remainingAmount;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side: BorderSide(color: _accentColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('เต็ม', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 3: สรุปยอด ─────────────────────────────────────
  Widget _buildSummarySection(bool isDark) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return _SectionCard(
      icon: Icons.summarize_outlined,
      title: 'สรุปยอด',
      color: _accentColor,
      isDark: isDark,
      child: Column(
        children: [
          _SummaryRow(
            label: 'จำนวนใบแจ้งหนี้',
            value: '${_allocations.length} ใบ',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF333333) : AppTheme.border,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ยอดรวมที่จ่าย',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '฿${fmt.format(_totalAmount)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.tealColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ──────────────────────────────────────────────
  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkTopBar : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(
                color: isDark ? Colors.white24 : AppTheme.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: isDark ? Colors.white60 : AppTheme.textSub,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _savePayment,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'บันทึกการจ่ายเงิน',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────
  Future<void> _selectPaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _paymentDate = date);
  }

  Future<void> _selectSupplier() async {
    final suppliersAsync = ref.read(supplierListProvider);
    await suppliersAsync.when(
      data: (suppliers) async {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) {
            String q = '';
            return StatefulBuilder(
              builder: (ctx2, setS) {
                final filtered = suppliers
                    .where((s) => s.supplierName.toLowerCase().contains(q))
                    .toList();
                return AppDialog(
                  backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: buildAppDialogTitle(
                    ctx2,
                    title: 'เลือกซัพพลายเออร์',
                    icon: Icons.business_outlined,
                    iconColor: AppTheme.primary,
                  ),
                  content: SizedBox(
                    width: 420,
                    height: 400,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 38,
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ค้นหา...',
                              prefixIcon: const Icon(Icons.search, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: isDark
                                  ? AppTheme.darkElement
                                  : const Color(0xFFF5F5F5),
                            ),
                            onChanged: (v) => setS(() => q = v.toLowerCase()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final s = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  s.supplierName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: s.currentBalance > 0
                                    ? Text(
                                        'ค้างชำระ: ฿${NumberFormat('#,##0.00', 'th_TH').format(s.currentBalance)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.warning,
                                        ),
                                      )
                                    : null,
                                onTap: () => Navigator.pop(ctx, {
                                  'id': s.supplierId,
                                  'name': s.supplierName,
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
      error: (_, _) {},
    );
  }

  Future<void> _loadUnpaidInvoices() async {
    if (_supplierId == null) return;
    setState(() => _isLoadingInvoices = true);
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
      for (final inv in _unpaidInvoices) {
        _allocations[inv.invoiceId] = inv.remainingAmount;
      }
    });
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_allocations.isEmpty) {
      _snackbar('กรุณาจัดสรรเงินให้กับใบแจ้งหนี้', isError: true);
      return;
    }
    if (_supplierId == null) {
      _snackbar('กรุณาเลือกซัพพลายเออร์', isError: true);
      return;
    }

    for (final entry in _allocations.entries) {
      final inv = _unpaidInvoices.firstWhere((i) => i.invoiceId == entry.key);
      if (entry.value > inv.remainingAmount) {
        _snackbar(
          'ใบแจ้งหนี้ ${inv.invoiceNo} จ่ายเกินยอดคงเหลือ',
          isError: true,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final authState = ref.read(authProvider);
    final allocations = _allocations.entries
        .map(
          (e) => ApPaymentAllocationModel(
            allocationId: '',
            paymentId: '',
            invoiceId: e.key,
            allocatedAmount: e.value,
            createdAt: DateTime.now(),
          ),
        )
        .toList();

    final payment = ApPaymentModel(
      paymentId: '',
      paymentNo: _paymentNoController.text.trim(),
      paymentDate: _paymentDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: _totalAmount,
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

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      ref.read(apInvoiceListProvider.notifier).refresh();
      ref.read(supplierListProvider.notifier).refresh();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('บันทึกการจ่ายเงินสำเร็จ'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _snackbar('บันทึกไม่สำเร็จ', isError: true);
    }
  }

  void _snackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PayFormTitleBar
// ════════════════════════════════════════════════════════════════
class _PayFormTitleBar extends StatelessWidget {
  final bool isDark;
  const _PayFormTitleBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (canPop) ...[
            context.isMobile
                ? buildMobileHomeCompactButton(context, isDark: isDark)
                : InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF333333)
                              : AppTheme.border,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 15,
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF8A8A8A),
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.tealColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: AppTheme.tealColor,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'จ่ายเงินซัพพลายเออร์',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                'บันทึกการชำระเงินและจัดสรรใบแจ้งหนี้',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF888888) : AppTheme.textSub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _SectionCard
// ════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : color.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
        ),
        // Body
        Padding(padding: const EdgeInsets.all(14), child: child),
      ],
    ),
  );
}

// ── Form Fields ────────────────────────────────────────────────

class _PayTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final bool readOnly;

  const _PayTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    readOnly: readOnly,
    style: TextStyle(
      fontSize: 13,
      color: isDark
          ? (readOnly ? Colors.white38 : Colors.white)
          : (readOnly ? Colors.black38 : Colors.black87),
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
      ),
      prefixIcon: Icon(
        icon,
        size: 17,
        color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.tealColor, width: 1.5),
      ),
      filled: true,
      fillColor: isDark
          ? AppTheme.darkElement
          : (readOnly ? const Color(0xFFF5F5F5) : Colors.white),
    ),
  );
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onPick;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.isDark,
    required this.accentColor,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPick,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 17,
            color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
          ),
        ],
      ),
    ),
  );
}

class _SupplierPickerField extends StatelessWidget {
  final String? supplierName;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onPick;

  const _SupplierPickerField({
    required this.supplierName,
    required this.isDark,
    required this.accentColor,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPick,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: supplierName == null
              ? (isDark ? const Color(0xFF3A3A3A) : AppTheme.border)
              : accentColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.business_outlined,
            size: 17,
            color: supplierName != null
                ? accentColor
                : (isDark ? const Color(0xFF666666) : AppTheme.textSub),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              supplierName ?? 'เลือกซัพพลายเออร์',
              style: TextStyle(
                fontSize: 13,
                color: supplierName != null
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? const Color(0xFF666666) : AppTheme.textSub),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
          ),
        ],
      ),
    ),
  );
}

class _PayMethodDropdown extends StatelessWidget {
  final String value;
  final bool isDark;
  final Color accentColor;
  final ValueChanged<String?> onChanged;

  const _PayMethodDropdown({
    required this.value,
    required this.isDark,
    required this.accentColor,
    required this.onChanged,
  });

  Color get _methodColor {
    switch (value) {
      case 'CASH':
        return AppTheme.success;
      case 'TRANSFER':
        return AppTheme.info;
      case 'CHEQUE':
        return AppTheme.warning;
      default:
        return accentColor;
    }
  }

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      prefixIcon: Icon(Icons.payment_outlined, size: 17, color: _methodColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkElement : Colors.white,
    ),
    dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
    style: TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    ),
    items: const [
      DropdownMenuItem(value: 'CASH', child: Text('เงินสด')),
      DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน')),
      DropdownMenuItem(value: 'CHEQUE', child: Text('เช็ค')),
    ],
    onChanged: onChanged,
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
    ],
  );
}
