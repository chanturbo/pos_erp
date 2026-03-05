import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../../data/models/product_model.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final ProductModel? product;
  
  const ProductFormPage({super.key, this.product});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _unitController;
  late TextEditingController _price1Controller;
  late TextEditingController _price2Controller;
  late TextEditingController _price3Controller;
  late TextEditingController _price4Controller;
  late TextEditingController _price5Controller;
  late TextEditingController _costController;
  bool _isStockControl = true;
  bool _allowNegativeStock = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.product?.productCode ?? '');
    _nameController = TextEditingController(text: widget.product?.productName ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _unitController = TextEditingController(text: widget.product?.baseUnit ?? 'ชิ้น');
    _price1Controller = TextEditingController(text: widget.product?.priceLevel1.toString() ?? '0');
    _price2Controller = TextEditingController(text: widget.product?.priceLevel2.toString() ?? '0');
    _price3Controller = TextEditingController(text: widget.product?.priceLevel3.toString() ?? '0');
    _price4Controller = TextEditingController(text: widget.product?.priceLevel4.toString() ?? '0');
    _price5Controller = TextEditingController(text: widget.product?.priceLevel5.toString() ?? '0');
    _costController = TextEditingController(text: widget.product?.standardCost.toString() ?? '0');
    
    if (widget.product != null) {
      _isStockControl = widget.product!.isStockControl;
      _allowNegativeStock = widget.product!.allowNegativeStock;
    }
  }
  
  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _price1Controller.dispose();
    _price2Controller.dispose();
    _price3Controller.dispose();
    _price4Controller.dispose();
    _price5Controller.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขสินค้า' : 'เพิ่มสินค้า'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Code
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'รหัสสินค้า *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสสินค้า';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อสินค้า *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกชื่อสินค้า';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'บาร์โค้ด',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Unit
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'หน่วย *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกหน่วย';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Price Section
            const Text(
              'ราคาขาย',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price1Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา Level 1 *',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกราคา';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _price2Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา Level 2',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price3Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา Level 3',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _price4Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา Level 4',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _price5Controller,
              decoration: const InputDecoration(
                labelText: 'ราคา Level 5',
                border: OutlineInputBorder(),
                prefixText: '฿',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            
            // Cost
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'ต้นทุนมาตรฐาน',
                border: OutlineInputBorder(),
                prefixText: '฿',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            
            // Stock Control
            SwitchListTile(
              title: const Text('ควบคุมสต๊อก'),
              subtitle: const Text('ติดตามการเคลื่อนไหวสต๊อก'),
              value: _isStockControl,
              onChanged: (value) {
                setState(() {
                  _isStockControl = value;
                });
              },
            ),
            
            if (_isStockControl)
              SwitchListTile(
                title: const Text('อนุญาตให้ติดลบ'),
                subtitle: const Text('สามารถขายเมื่อสต๊อกไม่พอ'),
                value: _allowNegativeStock,
                onChanged: (value) {
                  setState(() {
                    _allowNegativeStock = value;
                  });
                },
              ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'บันทึก' : 'เพิ่มสินค้า'),
                  ),
                ),
              ],
            ),
          ],
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
    
    final productData = {
      'product_code': _codeController.text,
      'product_name': _nameController.text,
      'barcode': _barcodeController.text.isEmpty ? null : _barcodeController.text,
      'base_unit': _unitController.text,
      'price_level_1': double.parse(_price1Controller.text),
      'price_level_2': double.parse(_price2Controller.text.isEmpty ? '0' : _price2Controller.text),
      'price_level_3': double.parse(_price3Controller.text.isEmpty ? '0' : _price3Controller.text),
      'price_level_4': double.parse(_price4Controller.text.isEmpty ? '0' : _price4Controller.text),
      'price_level_5': double.parse(_price5Controller.text.isEmpty ? '0' : _price5Controller.text),
      'standard_cost': double.parse(_costController.text.isEmpty ? '0' : _costController.text),
      'is_stock_control': _isStockControl,
      'allow_negative_stock': _allowNegativeStock,
    };
    
    bool success;
    if (widget.product != null) {
      // ✅ Update
      success = await ref.read(productListProvider.notifier).updateProduct(
        widget.product!.productId,
        productData,
      );
    } else {
      // ✅ Add - เปลี่ยนจาก createProduct เป็น addProduct
      success = await ref.read(productListProvider.notifier).addProduct(productData);
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product != null ? 'แก้ไขสินค้าสำเร็จ' : 'เพิ่มสินค้าสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}