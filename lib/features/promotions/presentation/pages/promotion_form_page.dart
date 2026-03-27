// promotion_form_page.dart
// Day 41-45: Promotion Create / Edit Form

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Title Bar ───────────────────────────────────────────
          _TitleBar(isEdit: isEdit, isLoading: _isLoading, onSave: _save),

          // ── Form Body ───────────────────────────────────────────
          Expanded(
            child: Form(
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Basic Info ───────────────────────────────────────────────────────────
  Widget _buildBasicInfoCard() {
    return _SectionCard(
      title: 'ข้อมูลทั่วไป',
      icon: Icons.local_offer_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: _codeCtrl,
            decoration: _inputDeco(label: 'รหัสโปรโมชั่น *', icon: Icons.tag),
            validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกรหัส' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDeco(label: 'ชื่อโปรโมชั่น *', icon: Icons.label_outline),
            validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({required String label, IconData? icon, String? prefix, String? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        prefixText: prefix,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  // ─── Promotion Type ───────────────────────────────────────────────────────
  Widget _buildPromotionTypeCard() {
    const types = [
      ('DISCOUNT_PERCENT', 'ลดเปอร์เซ็นต์', Icons.percent,     Color(0xFF9C27B0)),
      ('DISCOUNT_AMOUNT',  'ลดจำนวนเงิน',   Icons.money,        AppTheme.successColor),
      ('BUY_X_GET_Y',      'ซื้อ X แถม Y',   Icons.card_giftcard, AppTheme.errorColor),
      ('FREE_ITEM',        'ของแถมฟรี',       Icons.free_breakfast, Color(0xFF009688)),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionCard(
      title: 'ประเภทโปรโมชั่น',
      icon: Icons.category_outlined,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 3.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: types.map((t) {
          final selected = _promotionType == t.$1;
          final color = t.$4;
          return InkWell(
            onTap: () => setState(() => _promotionType = t.$1),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : (isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5)),
                border: Border.all(
                    color: selected ? color : AppTheme.border,
                    width: selected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.$3, color: selected ? color : AppTheme.textSub, size: 18),
                  const SizedBox(width: 6),
                  Text(t.$2,
                      style: TextStyle(
                          color: selected ? color : AppTheme.textSub,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Discount Detail ──────────────────────────────────────────────────────
  Widget _buildDiscountDetailCard() {
    return _SectionCard(
      title: 'รายละเอียดส่วนลด',
      icon: Icons.discount_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_promotionType == 'DISCOUNT_PERCENT') ...[
            TextFormField(
              controller: _discountValueCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(label: 'ลด (%) *', suffix: '%'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'กรุณากรอกค่า';
                final n = double.tryParse(v);
                if (n == null || n <= 0 || n > 100) return 'ต้องอยู่ระหว่าง 1-100';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 20, 25, 30, 50].map((v) => ActionChip(
                label: Text('$v%', style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _discountValueCtrl.text = v.toString()),
              )).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxDiscountCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(label: 'ลดสูงสุด (฿) — ไม่ระบุ = ไม่จำกัด', prefix: '฿ '),
            ),
          ] else if (_promotionType == 'DISCOUNT_AMOUNT') ...[
            TextFormField(
              controller: _discountValueCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(label: 'ลด (฿) *', prefix: '฿ '),
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
              children: [20, 50, 100, 150, 200, 500].map((v) => ActionChip(
                label: Text('฿$v', style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _discountValueCtrl.text = v.toString()),
              )).toList(),
            ),
          ] else if (_promotionType == 'BUY_X_GET_Y') ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(label: 'ซื้อ (ชิ้น) *'),
                    validator: (v) => v == null || v.isEmpty ? 'กรุณากรอก' : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('แถม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _getQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(label: 'ได้ฟรี (ชิ้น) *'),
                    validator: (v) => v == null || v.isEmpty ? 'กรุณากรอก' : null,
                  ),
                ),
              ],
            ),
          ] else if (_promotionType == 'FREE_ITEM') ...[
            _InfoBox(text: 'ของแถมฟรี — สามารถตั้งสินค้าแถมได้จากหน้าการขาย'),
          ],
        ],
      ),
    );
  }

  // ─── Condition ────────────────────────────────────────────────────────────
  Widget _buildConditionCard() {
    return _SectionCard(
      title: 'เงื่อนไข',
      icon: Icons.rule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _minAmountCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDeco(label: 'ยอดซื้อขั้นต่ำ (฿) — ไม่ระบุ = ไม่มีขั้นต่ำ', prefix: '฿ '),
          ),
          const SizedBox(height: 16),
          const Text('ใช้ได้กับ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSub)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ALL',      label: Text('ทุกสินค้า')),
              ButtonSegment(value: 'PRODUCT',  label: Text('สินค้าที่เลือก')),
              ButtonSegment(value: 'CATEGORY', label: Text('หมวดหมู่')),
            ],
            selected: {_applyTo},
            onSelectionChanged: (s) => setState(() => _applyTo = s.first),
          ),
          if (_applyTo != 'ALL') ...[
            const SizedBox(height: 8),
            _InfoBox(
              text: _applyTo == 'PRODUCT'
                  ? 'เลือกสินค้าที่ต้องการ (ยังไม่รองรับในเวอร์ชันนี้)'
                  : 'เลือกหมวดหมู่ (ยังไม่รองรับในเวอร์ชันนี้)',
            ),
          ],
        ],
      ),
    );
  }

  // ─── Period ───────────────────────────────────────────────────────────────
  Widget _buildPeriodCard() {
    return _SectionCard(
      title: 'ช่วงเวลา',
      icon: Icons.date_range_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _dateField(label: 'เริ่มต้น', value: _startDate, onTap: () => _pickDate(isStart: true))),
              const SizedBox(width: 12),
              Expanded(child: _dateField(label: 'สิ้นสุด', value: _endDate, onTap: () => _pickDate(isStart: false))),
            ],
          ),
          const SizedBox(height: 8),
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
    );
  }

  Widget _dateField({required String label, required DateTime value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          suffixIcon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSub),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(_dateFmt.format(value), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _durationChip(String label, int days) => ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => setState(() => _endDate = _startDate.add(Duration(days: days))),
      );

  // ─── Usage Limit ──────────────────────────────────────────────────────────
  Widget _buildLimitCard() {
    return _SectionCard(
      title: 'จำกัดการใช้งาน',
      icon: Icons.numbers_outlined,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _maxUsesCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(label: 'สูงสุด (ครั้ง) — ว่าง = ไม่จำกัด'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _maxUsesPerCustomerCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(label: 'ต่อลูกค้า — ว่าง = ไม่จำกัด'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return _SectionCard(
      title: 'การตั้งค่า',
      icon: Icons.settings_outlined,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('เปิดใช้งาน'),
            subtitle: const Text('โปรโมชั่นนี้จะถูกใช้งานในระบบ',
                style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
            value: _isActive,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (v) => setState(() => _isActive = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 1, color: AppTheme.border),
          SwitchListTile(
            title: const Text('Exclusive'),
            subtitle: const Text('เมื่อ Exclusive — โปรโมชั่นอื่นจะไม่ถูกรวมด้วย',
                style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
            value: _isExclusive,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (v) => setState(() => _isExclusive = v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
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

// ─────────────────────────────────────────────────────────────────
// Title Bar
// ─────────────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final bool isEdit;
  final bool isLoading;
  final VoidCallback onSave;

  const _TitleBar({
    required this.isEdit,
    required this.isLoading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (canPop) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.arrow_back, size: 20,
                    color: isDark ? Colors.white70 : AppTheme.textSub),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.infoContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_offer, color: AppTheme.infoColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'แก้ไขโปรโมชั่น' : 'สร้างโปรโมชั่น',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          ),
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor, strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('บันทึก'),
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
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkTopBar : AppTheme.headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.infoColor),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: null)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Body
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
// Info Box
// ─────────────────────────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.infoContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTheme.infoColor, fontSize: 12)),
            ),
          ],
        ),
      );
}