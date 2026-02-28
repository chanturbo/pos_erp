import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  
  const CustomerFormPage({super.key, this.customer});

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerCodeController;
  late TextEditingController _customerNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _taxIdController;
  late TextEditingController _creditLimitController;
  late TextEditingController _creditDaysController;
  late TextEditingController _memberNoController;
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    final customer = widget.customer;
    _customerCodeController = TextEditingController(text: customer?.customerCode ?? '');
    _customerNameController = TextEditingController(text: customer?.customerName ?? '');
    _addressController = TextEditingController(text: customer?.address ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _taxIdController = TextEditingController(text: customer?.taxId ?? '');
    _creditLimitController = TextEditingController(
      text: customer?.creditLimit.toString() ?? '0',
    );
    _creditDaysController = TextEditingController(
      text: customer?.creditDays.toString() ?? '0',
    );
    _memberNoController = TextEditingController(text: customer?.memberNo ?? '');
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final data = {
      'customer_code': _customerCodeController.text.trim(),
      'customer_name': _customerNameController.text.trim(),
      'address': _addressController.text.trim().isEmpty 
          ? null 
          : _addressController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty 
          ? null 
          : _emailController.text.trim(),
      'tax_id': _taxIdController.text.trim().isEmpty 
          ? null 
          : _taxIdController.text.trim(),
      'credit_limit': double.tryParse(_creditLimitController.text) ?? 0,
      'credit_days': int.tryParse(_creditDaysController.text) ?? 0,
      'member_no': _memberNoController.text.trim().isEmpty 
          ? null 
          : _memberNoController.text.trim(),
    };
    
    bool success;
    if (widget.customer == null) {
      // Create
      success = await ref.read(customerListProvider.notifier).createCustomer(data);
    } else {
      // Update
      success = await ref.read(customerListProvider.notifier).updateCustomer(
        widget.customer!.customerId,
        data,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
    
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null 
                ? 'เพิ่มลูกค้าสำเร็จ' 
                : 'แก้ไขลูกค้าสำเร็จ'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขลูกค้า' : 'เพิ่มลูกค้า'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ข้อมูลพื้นฐาน
            Text(
              'ข้อมูลพื้นฐาน',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // รหัสลูกค้า
            TextFormField(
              controller: _customerCodeController,
              decoration: const InputDecoration(
                labelText: 'รหัสลูกค้า *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสลูกค้า';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // ชื่อลูกค้า
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อลูกค้า *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกชื่อลูกค้า';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // ที่อยู่
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // โทรศัพท์
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'โทรศัพท์',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // อีเมล
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // เลขประจำตัวผู้เสียภาษี
            TextFormField(
              controller: _taxIdController,
              decoration: const InputDecoration(
                labelText: 'เลขประจำตัวผู้เสียภาษี',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            
            // วงเงินเครดิต
            Text(
              'วงเงินเครดิต',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _creditLimitController,
                    decoration: const InputDecoration(
                      labelText: 'วงเงินเครดิต',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _creditDaysController,
                    decoration: const InputDecoration(
                      labelText: 'ระยะเวลาเครดิต (วัน)',
                      border: OutlineInputBorder(),
                      suffixText: 'วัน',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // ข้อมูลสมาชิก
            Text(
              'ข้อมูลสมาชิก',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // เลขที่สมาชิก
            TextFormField(
              controller: _memberNoController,
              decoration: const InputDecoration(
                labelText: 'เลขที่สมาชิก',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.card_membership),
                helperText: 'สำหรับสะสมคะแนน',
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 32),
            
            // ปุ่มบันทึก
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'บันทึก' : 'เพิ่มลูกค้า',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}