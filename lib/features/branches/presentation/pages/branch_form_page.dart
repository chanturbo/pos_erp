// branch_form_page.dart — Week 7: Branch Create/Edit + Warehouse Management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../restaurant/data/models/restaurant_enums.dart';
import '../providers/branch_provider.dart';
import '../../data/models/branch_model.dart';

class BranchFormPage extends ConsumerStatefulWidget {
  final BranchModel? branch;
  const BranchFormPage({super.key, this.branch});

  @override
  ConsumerState<BranchFormPage> createState() => _BranchFormPageState();
}

class _BranchFormPageState extends ConsumerState<BranchFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late TabController _tabCtrl;

  // Branch fields
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  bool _isActive = true;
  BusinessMode _businessMode = BusinessMode.retail;

  // Warehouse form
  final _whCodeCtrl = TextEditingController();
  final _whNameCtrl = TextEditingController();

  bool get isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final b = widget.branch;
    _codeCtrl = TextEditingController(text: b?.branchCode ?? '');
    _nameCtrl = TextEditingController(text: b?.branchName ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _isActive = b?.isActive ?? true;
    _businessMode = BusinessMode.fromString(b?.businessMode);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whCodeCtrl.dispose();
    _whNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: Text(isEdit ? 'แก้ไขสาขา' : 'เพิ่มสาขา'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('บันทึก',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'ข้อมูลสาขา'),
            Tab(icon: Icon(Icons.warehouse), text: 'คลังสินค้า'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildBranchTab(),
            _buildWarehouseTab(),
          ],
        ),
      ),
    );
  }

  // ── Branch Info Tab ────────────────────────────────────────────────────────
  Widget _buildBranchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ข้อมูลทั่วไป',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'รหัสสาขา *',
                            border: OutlineInputBorder(),
                            hintText: 'BKK01',
                          ),
                          textCapitalization:
                              TextCapitalization.characters,
                          validator: (v) => v == null || v.isEmpty
                              ? 'กรุณากรอกรหัส'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อสาขา *',
                            border: OutlineInputBorder(),
                            hintText: 'สาขากรุงเทพ',
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'กรุณากรอกชื่อ'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'เบอร์โทรศัพท์',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ที่อยู่',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BusinessMode>(
                    initialValue: _businessMode,
                    decoration: const InputDecoration(
                      labelText: 'โหมดธุรกิจ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: BusinessMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _businessMode = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('เปิดใช้งาน'),
                    value: _isActive,
                    activeThumbColor: Colors.indigo,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Warehouse Tab ──────────────────────────────────────────────────────────
  Widget _buildWarehouseTab() {
    if (!isEdit) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'บันทึกสาขาก่อน จึงจะสามารถเพิ่มคลังสินค้าได้\n(ระบบจะสร้างคลังหลักให้อัตโนมัติ)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final warehousesAsync = ref.watch(warehouseListProvider);

    return warehousesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (warehouses) {
        final myWarehouses = warehouses
            .where((w) => w.branchId == widget.branch!.branchId)
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add warehouse form
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เพิ่มคลังสินค้า',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _whCodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'รหัส',
                                border: OutlineInputBorder(),
                                hintText: 'WH01',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _whNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อคลัง',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addWarehouse,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16)),
                            child: const Text('เพิ่ม'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('คลังสินค้าทั้งหมด (${myWarehouses.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                child: myWarehouses.isEmpty
                    ? Center(
                        child: Text('ยังไม่มีคลังสินค้า',
                            style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: myWarehouses.length,
                        itemBuilder: (ctx, i) {
                          final wh = myWarehouses[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha:0.1),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.warehouse,
                                    color: Colors.indigo, size: 20),
                              ),
                              title: Text(wh.warehouseName),
                              subtitle: Text(wh.warehouseCode),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: wh.isActive
                                      ? Colors.green.withValues(alpha:0.1)
                                      : Colors.grey.withValues(alpha:0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(
                                  wh.isActive ? 'เปิด' : 'ปิด',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: wh.isActive
                                          ? Colors.green
                                          : Colors.grey),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addWarehouse() async {
    if (_whCodeCtrl.text.isEmpty || _whNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกรหัสและชื่อคลัง')));
      return;
    }

    final wh = WarehouseModel(
      warehouseId: 'WH${DateTime.now().millisecondsSinceEpoch}',
      warehouseCode: _whCodeCtrl.text.trim().toUpperCase(),
      warehouseName: _whNameCtrl.text.trim(),
      branchId: widget.branch!.branchId,
      createdAt: DateTime.now(),
    );

    final ok = await ref
        .read(warehouseListProvider.notifier)
        .createWarehouse(wh);

    if (ok && mounted) {
      _whCodeCtrl.clear();
      _whNameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มคลังสินค้าแล้ว')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final branch = BranchModel(
      branchId: widget.branch?.branchId ??
          'BR${now.millisecondsSinceEpoch}',
      companyId: widget.branch?.companyId ?? 'COMP001',
      branchCode: _codeCtrl.text.trim().toUpperCase(),
      branchName: _nameCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      phone: _phoneCtrl.text.trim().isNotEmpty
          ? _phoneCtrl.text.trim()
          : null,
      isActive: _isActive,
      businessMode: _businessMode.value,
      createdAt: widget.branch?.createdAt ?? now,
      updatedAt: now,
    );

    bool ok;
    if (isEdit) {
      ok = await ref
          .read(branchListProvider.notifier)
          .updateBranch(branch);
    } else {
      ok = await ref
          .read(branchListProvider.notifier)
          .createBranch(branch);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isEdit ? 'อัพเดทสาขาแล้ว' : 'สร้างสาขาแล้ว')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')));
      }
    }
  }
}
