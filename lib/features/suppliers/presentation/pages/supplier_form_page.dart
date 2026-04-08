import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

class SupplierFormPage extends ConsumerStatefulWidget {
  final SupplierModel? supplier;

  const SupplierFormPage({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends ConsumerState<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _supplierCodeController;
  late TextEditingController _supplierNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _taxIdController;
  late TextEditingController _creditTermController;
  late TextEditingController _creditLimitController;

  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.supplier != null) {
      final supplier = widget.supplier!;
      _supplierCodeController = TextEditingController(
        text: supplier.supplierCode,
      );
      _supplierNameController = TextEditingController(
        text: supplier.supplierName,
      );
      _contactPersonController = TextEditingController(
        text: supplier.contactPerson ?? '',
      );
      _phoneController = TextEditingController(text: supplier.phone ?? '');
      _emailController = TextEditingController(text: supplier.email ?? '');
      _addressController = TextEditingController(text: supplier.address ?? '');
      _taxIdController = TextEditingController(text: supplier.taxId ?? '');
      _creditTermController = TextEditingController(
        text: supplier.creditTerm.toString(),
      );
      _creditLimitController = TextEditingController(
        text: supplier.creditLimit.toString(),
      );
      _isActive = supplier.isActive;
    } else {
      _supplierCodeController = TextEditingController();
      _supplierNameController = TextEditingController();
      _contactPersonController = TextEditingController();
      _phoneController = TextEditingController();
      _emailController = TextEditingController();
      _addressController = TextEditingController();
      _taxIdController = TextEditingController();
      _creditTermController = TextEditingController(text: '30');
      _creditLimitController = TextEditingController(text: '0');
      _isActive = true;
      _generateSupplierCode();
    }
  }

  void _generateSupplierCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = 'SUP${timestamp.toString().substring(8)}';
    _supplierCodeController.text = code;
  }

  @override
  void dispose() {
    _supplierCodeController.dispose();
    _supplierNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _creditTermController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'เพิ่มซัพพลายเออร์' : 'แก้ไขซัพพลายเออร์',
        ),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1180;
                    final isMedium = constraints.maxWidth >= 860;

                    final basicSection = _buildSectionGroup(
                      title: 'ข้อมูลพื้นฐาน',
                      icon: Icons.business,
                      child: _buildBasicInfoSection(),
                    );
                    final contactSection = _buildSectionGroup(
                      title: 'ข้อมูลติดต่อ',
                      icon: Icons.contact_phone,
                      child: _buildContactInfoSection(),
                    );
                    final taxSection = _buildSectionGroup(
                      title: 'ข้อมูลภาษี',
                      icon: Icons.receipt_long,
                      child: _buildTaxInfoSection(),
                    );
                    final paymentSection = _buildSectionGroup(
                      title: 'เงื่อนไขการชำระเงิน',
                      icon: Icons.payments,
                      child: _buildPaymentTermsSection(),
                    );
                    final statusSection = _buildSectionGroup(
                      title: 'สถานะ',
                      icon: Icons.toggle_on,
                      child: _buildStatusSection(),
                    );

                    if (isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: basicSection),
                              const SizedBox(width: 16),
                              Expanded(child: contactSection),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: taxSection),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: paymentSection),
                            ],
                          ),
                          const SizedBox(height: 16),
                          statusSection,
                          const SizedBox(height: 80),
                        ],
                      );
                    }

                    if (isMedium) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: basicSection),
                              const SizedBox(width: 16),
                              Expanded(child: contactSection),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: taxSection),
                              const SizedBox(width: 16),
                              Expanded(child: paymentSection),
                            ],
                          ),
                          const SizedBox(height: 16),
                          statusSection,
                          const SizedBox(height: 80),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        basicSection,
                        const SizedBox(height: 16),
                        contactSection,
                        const SizedBox(height: 16),
                        taxSection,
                        const SizedBox(height: 16),
                        paymentSection,
                        const SizedBox(height: 16),
                        statusSection,
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGroup({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildSectionHeader(title, icon), child],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _supplierCodeController,
              decoration: const InputDecoration(
                labelText: 'รหัสซัพพลายเออร์',
                hintText: 'SUP001',
                prefixIcon: Icon(Icons.tag),
                helperText: 'ระบบจะสร้างรหัสให้อัตโนมัติ',
              ),
              readOnly: true,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _supplierNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อซัพพลายเออร์ *',
                hintText: 'เช่น บริษัท ABC จำกัด',
                prefixIcon: Icon(Icons.business_center),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อซัพพลายเออร์';
                }
                if (value.trim().length < 3) {
                  return 'ชื่อซัพพลายเออร์ต้องมีอย่างน้อย 3 ตัวอักษร';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPersonController,
              decoration: const InputDecoration(
                labelText: 'ชื่อผู้ติดต่อ',
                hintText: 'เช่น คุณสมชาย ใจดี',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทรศัพท์ *',
                hintText: '0812345678',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกเบอร์โทรศัพท์';
                }
                final phoneRegex = RegExp(r'^0\d{9}$');
                if (!phoneRegex.hasMatch(value.trim())) {
                  return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง (10 หลัก)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                hintText: 'example@company.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'กรุณากรอกอีเมลให้ถูกต้อง';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                hintText: 'ระบุที่อยู่สำหรับจัดส่งสินค้า',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _taxIdController,
              decoration: const InputDecoration(
                labelText: 'เลขประจำตัวผู้เสียภาษี',
                hintText: '0123456789012',
                prefixIcon: Icon(Icons.numbers),
                helperText: '13 หลัก (ถ้ามี)',
              ),
              keyboardType: TextInputType.number,
              maxLength: 13,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length != 13) {
                    return 'เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _creditTermController,
              decoration: const InputDecoration(
                labelText: 'ระยะเวลาเครดิต (วัน)',
                hintText: '30',
                prefixIcon: Icon(Icons.calendar_today),
                suffixText: 'วัน',
                helperText: 'จำนวนวันที่ให้เครดิต (เช่น 30, 60, 90)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกระยะเวลาเครดิต';
                }
                final days = int.tryParse(value.trim());
                if (days == null || days < 0) {
                  return 'กรุณากรอกจำนวนวันที่ถูกต้อง';
                }
                if (days > 365) {
                  return 'ระยะเวลาเครดิตไม่ควรเกิน 365 วัน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _creditLimitController,
              decoration: const InputDecoration(
                labelText: 'วงเงินเครดิต (บาท)',
                hintText: '0',
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: '฿ ',
                helperText: 'วงเงินสูงสุดที่ให้เครดิต (0 = ไม่จำกัด)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกวงเงินเครดิต';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount < 0) {
                  return 'กรุณากรอกจำนวนเงินที่ถูกต้อง';
                }
                return null;
              },
            ),
            if (widget.supplier != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ยอดหนี้คงเหลือปัจจุบัน',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '฿${widget.supplier!.currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SwitchListTile(
          title: const Text('เปิดใช้งาน'),
          subtitle: Text(
            _isActive
                ? 'ซัพพลายเออร์นี้สามารถใช้งานได้'
                : 'ซัพพลายเออร์นี้ถูกปิดใช้งาน',
            style: TextStyle(
              fontSize: 12,
              color: _isActive ? Colors.green : Colors.red,
            ),
          ),
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
            });
          },
          secondary: Icon(
            _isActive ? Icons.check_circle : Icons.cancel,
            color: _isActive ? Colors.green : Colors.red,
          ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final cancelButton = OutlinedButton.icon(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.cancel),
            label: const Text('ยกเลิก'),
          );
          final saveButton = ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveSupplier,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [saveButton, const SizedBox(height: 10), cancelButton],
            );
          }

          return Row(
            children: [
              Expanded(child: cancelButton),
              const SizedBox(width: 16),
              Expanded(child: saveButton),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supplier = SupplierModel(
        supplierId: widget.supplier?.supplierId ?? '',
        supplierCode: _supplierCodeController.text.trim(),
        supplierName: _supplierNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        creditTerm: int.parse(_creditTermController.text.trim()),
        creditLimit: double.parse(_creditLimitController.text.trim()),
        currentBalance: widget.supplier?.currentBalance ?? 0,
        isActive: _isActive,
        createdAt: widget.supplier?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = widget.supplier == null
          ? await ref
                .read(supplierListProvider.notifier)
                .createSupplier(supplier)
          : await ref
                .read(supplierListProvider.notifier)
                .updateSupplier(supplier);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.supplier == null
                    ? 'เพิ่มซัพพลายเออร์สำเร็จ'
                    : 'แก้ไขซัพพลายเออร์สำเร็จ',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                'ข้อมูลที่ต้องกรอก',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• ชื่อซัพพลายเออร์ (บังคับ)'),
              Text('• เบอร์โทรศัพท์ (บังคับ)'),
              Text('• ระยะเวลาเครดิต (บังคับ)'),
              Text('• วงเงินเครดิต (บังคับ)'),
              SizedBox(height: 16),
              Text(
                'ระยะเวลาเครดิต',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('จำนวนวันที่ให้ผ่อนชำระหลังจากซื้อสินค้า'),
              Text('เช่น 30 วัน = ชำระภายใน 30 วัน'),
              SizedBox(height: 16),
              Text(
                'วงเงินเครดิต',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('ยอดเงินสูงสุดที่ยังค้างชำระได้'),
              Text('ใส่ 0 หากไม่จำกัดวงเงิน'),
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
