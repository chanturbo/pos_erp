import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/customer_model.dart';
import '../providers/customer_provider.dart';

// ─────────────────────────────────────────────────────────────────
// สีหลัก
// ─────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFFE8622A);
const _kPrimaryLight = Color(0xFFFFF3EE);
const _kBorder = Color(0xFFE0E0E0);
const _kSectionBg = Color(0xFFF9F9F9);
const _kTextSub = Color(0xFF8A8A8A);

class CustomerFormPage extends ConsumerStatefulWidget {
  final CustomerModel? customer;

  const CustomerFormPage({super.key, this.customer});

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerCodeController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _creditDaysController;
  late final TextEditingController _memberNoController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _customerCodeController = TextEditingController(text: c?.customerCode ?? '');
    _customerNameController = TextEditingController(text: c?.customerName ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _taxIdController = TextEditingController(text: c?.taxId ?? '');
    _creditLimitController =
        TextEditingController(text: c?.creditLimit.toString() ?? '0');
    _creditDaysController =
        TextEditingController(text: c?.creditDays.toString() ?? '0');
    _memberNoController = TextEditingController(text: c?.memberNo ?? '');
  }

  @override
  void dispose() {
    _customerCodeController.dispose();
    _customerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxIdController.dispose();
    _creditLimitController.dispose();
    _creditDaysController.dispose();
    _memberNoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? _nul(String v) => v.trim().isEmpty ? null : v.trim();

    final data = {
      'customer_code': _customerCodeController.text.trim(),
      'customer_name': _customerNameController.text.trim(),
      'address': _nul(_addressController.text),
      'phone': _nul(_phoneController.text),
      'email': _nul(_emailController.text),
      'tax_id': _nul(_taxIdController.text),
      'credit_limit': double.tryParse(_creditLimitController.text) ?? 0,
      'credit_days': int.tryParse(_creditDaysController.text) ?? 0,
      'member_no': _nul(_memberNoController.text),
    };

    final bool success;
    if (widget.customer == null) {
      success =
          await ref.read(customerListProvider.notifier).createCustomer(data);
    } else {
      success = await ref
          .read(customerListProvider.notifier)
          .updateCustomer(widget.customer!.customerId, data);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.customer == null
              ? 'เพิ่มลูกค้าสำเร็จ'
              : 'แก้ไขลูกค้าสำเร็จ'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    final isDialog = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Title Bar ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_add, color: _kPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'แก้ไขลูกค้า' : 'เพิ่มลูกค้า',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (isDialog)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 20, color: _kTextSub),
                    ),
                  ),
              ],
            ),
          ),

          // ── Form Body ─────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Row 1: ข้อมูลพื้นฐาน | วงเงินเครดิต | ข้อมูลสมาชิก
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // คอลัมน์ 1: ข้อมูลพื้นฐาน
                          Expanded(
                            child: _SectionCard(
                              icon: Icons.person_outline,
                              iconColor: _kPrimary,
                              title: 'ข้อมูลพื้นฐาน',
                              child: Column(
                                children: [
                                  _FormField(
                                    controller: _customerCodeController,
                                    label: 'รหัสลูกค้า',
                                    icon: Icons.qr_code,
                                    required: true,
                                    enabled: !_isLoading,
                                    validator: (v) =>
                                        (v == null || v.isEmpty)
                                            ? 'กรุณากรอกรหัสลูกค้า'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _customerNameController,
                                    label: 'ชื่อลูกค้า',
                                    icon: Icons.badge_outlined,
                                    required: true,
                                    enabled: !_isLoading,
                                    validator: (v) =>
                                        (v == null || v.isEmpty)
                                            ? 'กรุณากรอกชื่อลูกค้า'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _phoneController,
                                    label: 'โทรศัพท์',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    enabled: !_isLoading,
                                    helperText: 'จะถูกเข้ารหัสก่อนบันทึก',
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _emailController,
                                    label: 'อีเมล',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _taxIdController,
                                    label: 'เลขประจำตัวผู้เสียภาษี',
                                    icon: Icons.receipt_long_outlined,
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _addressController,
                                    label: 'ที่อยู่',
                                    icon: Icons.home_outlined,
                                    maxLines: 3,
                                    enabled: !_isLoading,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // คอลัมน์ 2: วงเงินเครดิต
                          Expanded(
                            child: _SectionCard(
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: const Color(0xFF1565C0),
                              title: 'วงเงินเครดิต',
                              child: Column(
                                children: [
                                  _FormField(
                                    controller: _creditLimitController,
                                    label: 'วงเงินเครดิต (฿)',
                                    icon: Icons.monetization_on_outlined,
                                    keyboardType: TextInputType.number,
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 14),
                                  _FormField(
                                    controller: _creditDaysController,
                                    label: 'ระยะเวลาเครดิต (วัน)',
                                    icon: Icons.calendar_today_outlined,
                                    keyboardType: TextInputType.number,
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 14),
                                  // Info box
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF90CAF9)),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16,
                                            color: Color(0xFF1565C0)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'วงเงินเครดิตจะถูกตรวจสอบอัตโนมัติเมื่อสร้างใบแจ้งหนี้ AR',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF1565C0),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // คอลัมน์ 3: ข้อมูลสมาชิก
                          Expanded(
                            child: _SectionCard(
                              icon: Icons.card_membership_outlined,
                              iconColor: const Color(0xFFFFB300),
                              title: 'ข้อมูลสมาชิก',
                              child: Column(
                                children: [
                                  _FormField(
                                    controller: _memberNoController,
                                    label: 'เลขที่สมาชิก',
                                    icon: Icons.badge_outlined,
                                    enabled: !_isLoading,
                                    helperText: 'สำหรับสะสมคะแนน',
                                  ),
                                  const SizedBox(height: 14),
                                  // Points display (edit mode only)
                                  if (isEdit &&
                                      (widget.customer?.points ?? 0) > 0)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFFFE082)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.stars,
                                              color: Color(0xFFFFB300),
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('คะแนนสะสม',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: _kTextSub)),
                                              Text(
                                                '${widget.customer!.points} คะแนน',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFE65100),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  // Info
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFFFE082)),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.star_outline,
                                            size: 16,
                                            color: Color(0xFFFFB300)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ทุก ฿100 ที่ซื้อ จะได้รับ 1 คะแนนสะสมอัตโนมัติ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFE65100),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Action Bar ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ยกเลิก',
                      style: TextStyle(color: _kTextSub)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(isEdit ? 'บันทึก' : 'เพิ่มลูกค้า',
                      style: const TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section Card
// ─────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _kSectionBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Form Field
// ─────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? helperText;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: const TextStyle(fontSize: 13, color: _kTextSub),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11, color: _kTextSub),
        prefixIcon: Icon(icon, size: 17, color: _kTextSub),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
      ),
    );
  }
}