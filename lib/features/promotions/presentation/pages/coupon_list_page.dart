// coupon_list_page.dart
// Day 41-45: Coupon Management Page

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';

class CouponListPage extends ConsumerStatefulWidget {
  const CouponListPage({super.key});

  @override
  ConsumerState<CouponListPage> createState() => _CouponListPageState();
}

class _CouponListPageState extends ConsumerState<CouponListPage> {
  String _filter = 'ALL'; // ALL, VALID, USED, EXPIRED
  String _searchQuery = '';
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(couponListProvider);
    final promotionsAsync = ref.watch(promotionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคูปอง'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(couponListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: couponsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data: (coupons) {
                final filtered = _applyFilter(coupons);
                if (filtered.isEmpty) {
                  return _buildEmpty(promotionsAsync);
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(couponListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildCouponCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateDialog(),
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add),
        label: const Text('สร้างคูปอง'),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาโค้ดคูปอง...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'ทั้งหมด'),
                _filterChip('VALID', 'ใช้ได้', Colors.green),
                _filterChip('USED', 'ใช้แล้ว', Colors.grey),
                _filterChip('EXPIRED', 'หมดอายุ', Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, [Color? color]) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: (color ?? Colors.deepOrange).withValues(alpha: 0.2),
        checkmarkColor: color ?? Colors.deepOrange,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  List<CouponModel> _applyFilter(List<CouponModel> list) {
    return list.where((c) {
      if (_searchQuery.isNotEmpty) {
        if (!c.couponCode.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      switch (_filter) {
        case 'VALID':
          return c.isValid;
        case 'USED':
          return c.isUsed;
        case 'EXPIRED':
          return c.isExpired && !c.isUsed;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildCouponCard(CouponModel c) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (c.isUsed) {
      statusColor = Colors.grey;
      statusLabel = 'ใช้แล้ว';
      statusIcon = Icons.check_circle;
    } else if (c.isExpired) {
      statusColor = Colors.red;
      statusLabel = 'หมดอายุ';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.green;
      statusLabel = 'ใช้ได้';
      statusIcon = Icons.confirmation_number;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        title: Row(
          children: [
            Text(
              c.couponCode,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'monospace',
                decoration: c.isUsed ? TextDecoration.lineThrough : null,
                color: c.isUsed ? Colors.grey : null,
              ),
            ),
            const SizedBox(width: 8),
            if (!c.isUsed && !c.isExpired)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: c.couponCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('คัดลอก ${c.couponCode} แล้ว')),
                  );
                },
                child: const Icon(Icons.copy, size: 16, color: Colors.grey),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.promotionName != null)
              Text(c.promotionName!, style: const TextStyle(fontSize: 12)),
            if (c.expiresAt != null)
              Text(
                'หมดอายุ: ${_dateFmt.format(c.expiresAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            if (c.isUsed && c.usedAt != null)
              Text(
                'ใช้เมื่อ: ${_dateFmt.format(c.usedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AsyncValue<List<PromotionModel>> promotionsAsync) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีคูปอง',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showGenerateDialog(),
            icon: const Icon(Icons.add),
            label: const Text('สร้างคูปอง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Generate Coupon Dialog ───────────────────────────────────────────────
  void _showGenerateDialog() async {
    final promotionsAsync = ref.read(promotionListProvider);

    final promotions = promotionsAsync.hasValue
        ? promotionsAsync.value!
        : <PromotionModel>[];

    if (promotions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาสร้างโปรโมชั่นก่อน')));
      return;
    }

    String? selectedPromoId = promotions.first.promotionId;
    final countCtrl = TextEditingController(text: '1');
    final customCodeCtrl = TextEditingController();
    DateTime? expiresAt;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('สร้างคูปอง'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Promotion selector
                  const Text(
                    'โปรโมชั่น *',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPromoId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: promotions.map((p) {
                      return DropdownMenuItem(
                        value: p.promotionId,
                        child: Text(
                          p.promotionName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setStateDialog(() => selectedPromoId = v),
                  ),
                  const SizedBox(height: 12),
                  // Count
                  const Text(
                    'จำนวนคูปอง',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'ใบ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10, 20, 50].map((n) {
                      return ActionChip(
                        label: Text('$n'),
                        onPressed: () =>
                            setStateDialog(() => countCtrl.text = n.toString()),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Custom code (only for single)
                  const Text(
                    'โค้ดกำหนดเอง (ถ้าต้องการ)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customCodeCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'เว้นว่าง = สุ่มอัตโนมัติ',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  // Expires at
                  const Text(
                    'วันหมดอายุ (ถ้าต้องการ)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setStateDialog(() => expiresAt = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        expiresAt != null
                            ? DateFormat('dd/MM/yyyy').format(expiresAt!)
                            : 'ไม่จำกัด',
                        style: TextStyle(
                          color: expiresAt != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (selectedPromoId == null) return;
                final count = int.tryParse(countCtrl.text) ?? 1;
                final success = await ref
                    .read(couponListProvider.notifier)
                    .createCoupons(
                      promotionId: selectedPromoId!,
                      count: count,
                      expiresAt: expiresAt,
                      customCode: customCodeCtrl.text.isNotEmpty
                          ? customCodeCtrl.text.toUpperCase()
                          : null,
                    );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('สร้างคูปอง $count ใบแล้ว')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('สร้างคูปอง'),
            ),
          ],
        ),
      ),
    );
  }
}
