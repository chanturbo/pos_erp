import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _lineIdController = TextEditingController(); // ✅ เพิ่มบรรทัดนี้
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _creditTermController = TextEditingController();
  final _creditLimitController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.supplier != null) {
      // Edit mode
      _codeController.text = widget.supplier!.supplierCode;
      _nameController.text = widget.supplier!.supplierName;
      _contactController.text = widget.supplier!.contactPerson ?? '';
      _phoneController.text = widget.supplier!.phone ?? '';
      _emailController.text = widget.supplier!.email ?? '';
      _lineIdController.text =
          widget.supplier!.lineId ?? ''; // ✅ เพิ่มบรรทัดนี้
      _addressController.text = widget.supplier!.address ?? '';
      _taxIdController.text = widget.supplier!.taxId ?? '';
      _creditTermController.text = widget.supplier!.creditTerm.toString();
      _creditLimitController.text = widget.supplier!.creditLimit.toString();
      _isActive = widget.supplier!.isActive;
    } else {
      // Create mode - set defaults
      _creditTermController.text = '30';
      _creditLimitController.text = '0';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _lineIdController.dispose(); // ✅ เพิ่มบรรทัดนี้
    _addressController.dispose();
    _taxIdController.dispose();
    _creditTermController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      widget.supplier == null ? Icons.add_business : Icons.edit,
                      color: Colors.blue,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.supplier == null
                          ? 'เพิ่มซัพพลายเออร์'
                          : 'แก้ไขซัพพลายเออร์',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Supplier Code
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'รหัสซัพพลายเออร์ *',
                    border: OutlineInputBorder(),
                    hintText: 'เช่น SUP-001',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกรหัสซัพพลายเออร์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Supplier Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อซัพพลายเออร์ *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อซัพพลายเออร์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contact Person
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'ผู้ติดต่อ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Phone & Email
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'โทรศัพท์',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'อีเมล',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Line ID
                TextFormField(
                  controller: _lineIdController,
                  decoration: const InputDecoration(
                    labelText: 'Line ID',
                    border: OutlineInputBorder(),
                    hintText: 'เช่น @shopname',
                    prefixIcon: Icon(Icons.chat),
                  ),
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'ที่อยู่',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Tax ID
                TextFormField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(
                    labelText: 'เลขผู้เสียภาษี',
                    border: OutlineInputBorder(),
                    hintText: '13 หลัก',
                  ),
                ),
                const SizedBox(height: 16),

                // Credit Term & Credit Limit
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _creditTermController,
                        decoration: const InputDecoration(
                          labelText: 'เครดิต (วัน)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (int.tryParse(value) == null) {
                              return 'กรุณากรอกตัวเลข';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _creditLimitController,
                        decoration: const InputDecoration(
                          labelText: 'วงเงินเครดิต (฿)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value) == null) {
                              return 'กรุณากรอกตัวเลข';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active Status
                SwitchListTile(
                  title: const Text('สถานะ'),
                  subtitle: Text(_isActive ? 'ใช้งาน' : 'ระงับ'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('บันทึก'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final supplier = SupplierModel(
      supplierId: widget.supplier?.supplierId ?? '',
      supplierCode: _codeController.text.trim(),
      supplierName: _nameController.text.trim(),
      contactPerson: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      lineId:
          _lineIdController.text
              .trim()
              .isEmpty // ✅ เพิ่มบรรทัดนี้
          ? null
          : _lineIdController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      taxId: _taxIdController.text.trim().isEmpty
          ? null
          : _taxIdController.text.trim(),
      creditTerm: int.tryParse(_creditTermController.text) ?? 30,
      creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
      currentBalance: widget.supplier?.currentBalance ?? 0,
      isActive: _isActive,
      createdAt: widget.supplier?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (widget.supplier == null) {
      // Create
      success = await ref
          .read(supplierListProvider.notifier)
          .createSupplier(supplier);
    } else {
      // Update
      success = await ref
          .read(supplierListProvider.notifier)
          .updateSupplier(supplier);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? widget.supplier == null
                      ? 'เพิ่มซัพพลายเออร์สำเร็จ'
                      : 'อัพเดทซัพพลายเออร์สำเร็จ'
                : 'เกิดข้อผิดพลาด',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
