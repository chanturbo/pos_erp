import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product_model.dart';
import '../providers/product_provider.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final ProductModel? product;
  
  const ProductFormPage({super.key, this.product});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productCodeController;
  late TextEditingController _productNameController;
  late TextEditingController _barcodeController;
  late TextEditingController _baseUnitController;
  late TextEditingController _priceLevel1Controller;
  late TextEditingController _priceLevel2Controller;
  late TextEditingController _priceLevel3Controller;
  late TextEditingController _priceLevel4Controller;
  late TextEditingController _priceLevel5Controller;
  late TextEditingController _standardCostController;
  
  bool _isStockControl = true;
  bool _allowNegativeStock = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    final product = widget.product;
    _productCodeController = TextEditingController(text: product?.productCode ?? '');
    _productNameController = TextEditingController(text: product?.productName ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _baseUnitController = TextEditingController(text: product?.baseUnit ?? 'ชิ้น');
    _priceLevel1Controller = TextEditingController(
      text: product?.priceLevel1.toString() ?? '0',
    );
    _priceLevel2Controller = TextEditingController(
      text: product?.priceLevel2.toString() ?? '0',
    );
    _priceLevel3Controller = TextEditingController(
      text: product?.priceLevel3.toString() ?? '0',
    );
    _priceLevel4Controller = TextEditingController(
      text: product?.priceLevel4.toString() ?? '0',
    );
    _priceLevel5Controller = TextEditingController(
      text: product?.priceLevel5.toString() ?? '0',
    );
    _standardCostController = TextEditingController(
      text: product?.standardCost.toString() ?? '0',
    );
    
    _isStockControl = product?.isStockControl ?? true;
    _allowNegativeStock = product?.allowNegativeStock ?? false;
  }
  
  @override
  void dispose() {
    _productCodeController.dispose();
    _productNameController.dispose();
    _barcodeController.dispose();
    _baseUnitController.dispose();
    _priceLevel1Controller.dispose();
    _priceLevel2Controller.dispose();
    _priceLevel3Controller.dispose();
    _priceLevel4Controller.dispose();
    _priceLevel5Controller.dispose();
    _standardCostController.dispose();
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
      'product_code': _productCodeController.text.trim(),
      'product_name': _productNameController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty 
          ? null 
          : _barcodeController.text.trim(),
      'base_unit': _baseUnitController.text.trim(),
      'price_level1': double.tryParse(_priceLevel1Controller.text) ?? 0,
      'price_level2': double.tryParse(_priceLevel2Controller.text) ?? 0,
      'price_level3': double.tryParse(_priceLevel3Controller.text) ?? 0,
      'price_level4': double.tryParse(_priceLevel4Controller.text) ?? 0,
      'price_level5': double.tryParse(_priceLevel5Controller.text) ?? 0,
      'standard_cost': double.tryParse(_standardCostController.text) ?? 0,
      'is_stock_control': _isStockControl,
      'allow_negative_stock': _allowNegativeStock,
    };
    
    bool success;
    if (widget.product == null) {
      // Create
      success = await ref.read(productListProvider.notifier).createProduct(data);
    } else {
      // Update
      success = await ref.read(productListProvider.notifier).updateProduct(
        widget.product!.productId,
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
            content: Text(widget.product == null 
                ? 'เพิ่มสินค้าสำเร็จ' 
                : 'แก้ไขสินค้าสำเร็จ'),
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
            // รหัสสินค้า
            TextFormField(
              controller: _productCodeController,
              decoration: const InputDecoration(
                labelText: 'รหัสสินค้า *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสสินค้า';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // ชื่อสินค้า
            TextFormField(
              controller: _productNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อสินค้า *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกชื่อสินค้า';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.barcode_reader),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // หน่วยนับ
            TextFormField(
              controller: _baseUnitController,
              decoration: const InputDecoration(
                labelText: 'หน่วยนับ *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกหน่วยนับ';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            
            // ราคาขาย
            Text(
              'ราคาขาย',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceLevel1Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา 1 *',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกราคา';
                      }
                      if (double.tryParse(value) == null) {
                        return 'กรุณากรอกตัวเลข';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _priceLevel2Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา 2',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceLevel3Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา 3',
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
                    controller: _priceLevel4Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา 4',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceLevel5Controller,
                    decoration: const InputDecoration(
                      labelText: 'ราคา 5',
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
                    controller: _standardCostController,
                    decoration: const InputDecoration(
                      labelText: 'ต้นทุน',
                      border: OutlineInputBorder(),
                      prefixText: '฿',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // ตัวเลือก
            Text(
              'ตัวเลือก',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            SwitchListTile(
              title: const Text('ควบคุมสต๊อก'),
              subtitle: const Text('เปิดเพื่อให้ระบบตัดสต๊อกสินค้าอัตโนมัติ'),
              value: _isStockControl,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _isStockControl = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('อนุญาตให้สต๊อกติดลบ'),
              subtitle: const Text('เปิดเพื่อให้ขายได้แม้สต๊อกไม่พอ'),
              value: _allowNegativeStock,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _allowNegativeStock = value;
                });
              },
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
                        isEdit ? 'บันทึก' : 'เพิ่มสินค้า',
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