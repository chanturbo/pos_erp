// promotion_form_page.dart
// Day 41-45: Promotion Create / Edit Form

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';

class PromotionFormPage extends ConsumerStatefulWidget {
  final PromotionModel? promotion;

  const PromotionFormPage({super.key, this.promotion});

  @override
  ConsumerState<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends ConsumerState<PromotionFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _discountValueCtrl;
  late TextEditingController _maxDiscountCtrl;
  late TextEditingController _minAmountCtrl;
  late TextEditingController _buyQtyCtrl;
  late TextEditingController _getQtyCtrl;
  late TextEditingController _maxUsesCtrl;
  late TextEditingController _maxUsesPerCustomerCtrl;

  // State
  String _promotionType = 'DISCOUNT_PERCENT';
  String _applyTo = 'ALL';
  bool _isExclusive = false;
  bool _isActive = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate =
      DateTime.now().add(const Duration(days: 30));

  final _dateFmt = DateFormat('dd/MM/yyyy', 'th_TH');

  bool get isEdit => widget.promotion != null;

  @override
  void initState() {
    super.initState();
    final p = widget.promotion;
    _codeCtrl = TextEditingController(text: p?.promotionCode ?? '');
    _nameCtrl = TextEditingController(text: p?.promotionName ?? '');
    _discountValueCtrl = TextEditingController(
        text: p?.discountValue != null && p!.discountValue > 0
            ? p.discountValue.toString()
            : '');
    _maxDiscountCtrl = TextEditingController(
        text: p?.maxDiscountAmount?.toString() ?? '');
    _minAmountCtrl = TextEditingController(
        text: p?.minAmount != null && p!.minAmount > 0
            ? p.minAmount.toString()
            : '');
    _buyQtyCtrl =
        TextEditingController(text: p?.buyQty?.toString() ?? '');
    _getQtyCtrl =
        TextEditingController(text: p?.getQty?.toString() ?? '');
    _maxUsesCtrl =
        TextEditingController(text: p?.maxUses?.toString() ?? '');
    _maxUsesPerCustomerCtrl = TextEditingController(
        text: p?.maxUsesPerCustomer?.toString() ?? '');

    if (p != null) {
      _promotionType = p.promotionType;
      _applyTo = p.applyTo;
      _isExclusive = p.isExclusive;
      _isActive = p.isActive;
      _startDate = p.startDate;
      _endDate = p.endDate;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _discountValueCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _minAmountCtrl.dispose();
    _buyQtyCtrl.dispose();
    _getQtyCtrl.dispose();
    _maxUsesCtrl.dispose();
    _maxUsesPerCustomerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขโปรโมชั่น' : 'สร้างโปรโมชั่น'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('บันทึก',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBasicInfoCard(),
              const SizedBox(height: 12),
              _buildPromotionTypeCard(),
              const SizedBox(height: 12),
              _buildDiscountDetailCard(),
              const SizedBox(height: 12),
              _buildConditionCard(),
              const SizedBox(height: 12),
              _buildPeriodCard(),
              const SizedBox(height: 12),
              _buildLimitCard(),
              const SizedBox(height: 12),
              _buildSettingsCard(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Basic Info ───────────────────────────────────────────────────────────
  Widget _buildBasicInfoCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลทั่วไป',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'รหัสโปรโมชั่น *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณากรอกรหัส' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อโปรโมชั่น *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Promotion Type ───────────────────────────────────────────────────────
  Widget _buildPromotionTypeCard() {
    final types = [
      {
        'value': 'DISCOUNT_PERCENT',
        'label': 'ลดเปอร์เซ็นต์',
        'icon': Icons.percent,
        'color': Colors.purple,
      },
      {
        'value': 'DISCOUNT_AMOUNT',
        'label': 'ลดจำนวนเงิน',
        'icon': Icons.money,
        'color': Colors.green,
      },
      {
        'value': 'BUY_X_GET_Y',
        'label': 'ซื้อ X แถม Y',
        'icon': Icons.card_giftcard,
        'color': Colors.red,
      },
      {
        'value': 'FREE_ITEM',
        'label': 'ของแถมฟรี',
        'icon': Icons.free_breakfast,
        'color': Colors.teal,
      },
    ];

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ประเภทโปรโมชั่น',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3.0,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: types.map((t) {
                final selected = _promotionType == t['value'];
                final color = t['color'] as Color;
                return InkWell(
                  onTap: () => setState(
                      () => _promotionType = t['value'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha:0.15)
                          : Colors.grey[100],
                      border: Border.all(
                          color: selected ? color : Colors.grey[300]!,
                          width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t['icon'] as IconData,
                            color: selected ? color : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(t['label'] as String,
                            style: TextStyle(
                                color: selected ? color : Colors.grey[600],
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Discount Detail ──────────────────────────────────────────────────────
  Widget _buildDiscountDetailCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายละเอียดส่วนลด',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (_promotionType == 'DISCOUNT_PERCENT') ...[
              TextFormField(
                controller: _discountValueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ลด (%) *',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกค่า';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0 || n > 100) {
                    return 'ต้องอยู่ระหว่าง 1-100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Quick % buttons
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 20, 25, 30, 50].map((v) {
                  return ActionChip(
                    label: Text('$v%'),
                    onPressed: () => setState(
                        () => _discountValueCtrl.text = v.toString()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxDiscountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ลดสูงสุด (฿) — ไม่ระบุ = ไม่จำกัด',
                  border: OutlineInputBorder(),
                  prefixText: '฿ ',
                ),
              ),
            ] else if (_promotionType == 'DISCOUNT_AMOUNT') ...[
              TextFormField(
                controller: _discountValueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ลด (฿) *',
                  border: OutlineInputBorder(),
                  prefixText: '฿ ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกค่า';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'ต้องมากกว่า 0';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [20, 50, 100, 150, 200, 500].map((v) {
                  return ActionChip(
                    label: Text('฿$v'),
                    onPressed: () => setState(
                        () => _discountValueCtrl.text = v.toString()),
                  );
                }).toList(),
              ),
            ] else if (_promotionType == 'BUY_X_GET_Y') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyQtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ซื้อ (ชิ้น) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'กรุณากรอก' : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('แถม',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _getQtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ได้ฟรี (ชิ้น) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'กรุณากรอก' : null,
                    ),
                  ),
                ],
              ),
            ] else if (_promotionType == 'FREE_ITEM') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ของแถมฟรี — สามารถตั้งสินค้าแถมได้จากหน้าการขาย',
                        style: TextStyle(color: Colors.teal),
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

  // ─── Condition ────────────────────────────────────────────────────────────
  Widget _buildConditionCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เงื่อนไข',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ยอดซื้อขั้นต่ำ (฿) — ไม่ระบุ = ไม่มีขั้นต่ำ',
                border: OutlineInputBorder(),
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 16),
            const Text('ใช้ได้กับ',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'ALL', label: Text('ทุกสินค้า')),
                ButtonSegment(
                    value: 'PRODUCT', label: Text('สินค้าที่เลือก')),
                ButtonSegment(
                    value: 'CATEGORY', label: Text('หมวดหมู่')),
              ],
              selected: {_applyTo},
              onSelectionChanged: (s) =>
                  setState(() => _applyTo = s.first),
            ),
            if (_applyTo != 'ALL') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _applyTo == 'PRODUCT'
                          ? 'เลือกสินค้าที่ต้องการ (ยังไม่รองรับในเวอร์ชันนี้)'
                          : 'เลือกหมวดหมู่ (ยังไม่รองรับในเวอร์ชันนี้)',
                      style: const TextStyle(
                          color: Colors.blue, fontSize: 12),
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

  // ─── Period ───────────────────────────────────────────────────────────────
  Widget _buildPeriodCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ช่วงเวลา',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    label: 'เริ่มต้น',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    label: 'สิ้นสุด',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick duration buttons
            Wrap(
              spacing: 8,
              children: [
                _durationChip('7 วัน', 7),
                _durationChip('14 วัน', 14),
                _durationChip('30 วัน', 30),
                _durationChip('60 วัน', 60),
                _durationChip('90 วัน', 90),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_dateFmt.format(value)),
      ),
    );
  }

  Widget _durationChip(String label, int days) {
    return ActionChip(
      label: Text(label),
      onPressed: () => setState(() {
        _endDate = _startDate.add(Duration(days: days));
      }),
    );
  }

  // ─── Usage Limit ──────────────────────────────────────────────────────────
  Widget _buildLimitCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('จำกัดการใช้งาน',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'สูงสุด (ครั้ง) — ว่าง = ไม่จำกัด',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxUsesPerCustomerCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ต่อลูกค้า — ว่าง = ไม่จำกัด',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('การตั้งค่า',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            SwitchListTile(
              title: const Text('เปิดใช้งาน'),
              subtitle:
                  const Text('โปรโมชั่นนี้จะถูกใช้งานในระบบ'),
              value: _isActive,
              activeThumbColor: Colors.orange,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Exclusive'),
              subtitle: const Text(
                  'เมื่อ Exclusive — โปรโมชั่นอื่นจะไม่ถูกรวมด้วย'),
              value: _isExclusive,
              activeThumbColor: Colors.orange,
              onChanged: (v) => setState(() => _isExclusive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Date Picker ──────────────────────────────────────────────────────────
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('วันสิ้นสุดต้องหลังวันเริ่มต้น')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final promo = PromotionModel(
      promotionId: widget.promotion?.promotionId ??
          'PROMO${now.millisecondsSinceEpoch}',
      promotionCode: _codeCtrl.text.trim().toUpperCase(),
      promotionName: _nameCtrl.text.trim(),
      promotionType: _promotionType,
      discountType: _promotionType == 'DISCOUNT_PERCENT'
          ? 'PERCENT'
          : _promotionType == 'DISCOUNT_AMOUNT'
              ? 'AMOUNT'
              : null,
      discountValue:
          double.tryParse(_discountValueCtrl.text) ?? 0,
      maxDiscountAmount:
          double.tryParse(_maxDiscountCtrl.text),
      buyQty: int.tryParse(_buyQtyCtrl.text),
      getQty: int.tryParse(_getQtyCtrl.text),
      minAmount: double.tryParse(_minAmountCtrl.text) ?? 0,
      applyTo: _applyTo,
      startDate: _startDate,
      endDate: _endDate,
      maxUses: int.tryParse(_maxUsesCtrl.text),
      maxUsesPerCustomer:
          int.tryParse(_maxUsesPerCustomerCtrl.text),
      isExclusive: _isExclusive,
      isActive: _isActive,
      createdAt: widget.promotion?.createdAt ?? now,
      updatedAt: now,
    );

    bool success;
    if (isEdit) {
      success = await ref
          .read(promotionListProvider.notifier)
          .updatePromotion(promo);
    } else {
      success = await ref
          .read(promotionListProvider.notifier)
          .createPromotion(promo);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isEdit ? 'อัพเดทโปรโมชั่นแล้ว' : 'สร้างโปรโมชั่นแล้ว')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')),
        );
      }
    }
  }
}