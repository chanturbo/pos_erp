// promotion_list_page.dart
// Day 41-45: Promotion Management List Page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/promotion_provider.dart';
import '../../data/models/promotion_model.dart';
import 'promotion_form_page.dart';
import 'coupon_list_page.dart';

class PromotionListPage extends ConsumerStatefulWidget {
  const PromotionListPage({super.key});

  @override
  ConsumerState<PromotionListPage> createState() => _PromotionListPageState();
}

class _PromotionListPageState extends ConsumerState<PromotionListPage> {
  String _searchQuery = '';
  String _filter = 'ALL'; // ALL, ACTIVE, EXPIRED, INACTIVE

  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _dateFmt = DateFormat('dd/MM/yyyy', 'th_TH');

  @override
  Widget build(BuildContext context) {
    final promotionsAsync = ref.watch(promotionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรโมชั่น'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'จัดการคูปอง',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CouponListPage())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(promotionListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: promotionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data: (promotions) {
                final filtered = _applyFilter(promotions);
                if (filtered.isEmpty) {
                  return _buildEmpty();
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(promotionListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _buildPromotionCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('สร้างโปรโมชั่น'),
      ),
    );
  }

  // ─── Search & Filter ──────────────────────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาโปรโมชั่น...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
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
                _filterChip('ACTIVE', 'กำลังใช้งาน', Colors.green),
                _filterChip('UPCOMING', 'เร็วๆ นี้', Colors.blue),
                _filterChip('EXPIRED', 'หมดอายุ', Colors.red),
                _filterChip('INACTIVE', 'ปิดการใช้งาน', Colors.grey),
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
        selectedColor: (color ?? Colors.orange).withOpacity(0.2),
        checkmarkColor: color ?? Colors.orange,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  // ─── Filter Logic ─────────────────────────────────────────────────────────
  List<PromotionModel> _applyFilter(List<PromotionModel> list) {
    final now = DateTime.now();
    return list.where((p) {
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.promotionName.toLowerCase().contains(q) &&
            !p.promotionCode.toLowerCase().contains(q)) {
          return false;
        }
      }
      // Status filter
      switch (_filter) {
        case 'ACTIVE':
          return p.isActive &&
              now.isAfter(p.startDate) &&
              now.isBefore(p.endDate);
        case 'UPCOMING':
          return p.isActive && now.isBefore(p.startDate);
        case 'EXPIRED':
          return now.isAfter(p.endDate);
        case 'INACTIVE':
          return !p.isActive;
        default:
          return true;
      }
    }).toList();
  }

  // ─── Promotion Card ───────────────────────────────────────────────────────
  Widget _buildPromotionCard(PromotionModel p) {
    final now = DateTime.now();
    final isRunning =
        p.isActive && now.isAfter(p.startDate) && now.isBefore(p.endDate);
    final isUpcoming = p.isActive && now.isBefore(p.startDate);
    final isExpired = now.isAfter(p.endDate);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!p.isActive) {
      statusColor = Colors.grey;
      statusLabel = 'ปิด';
      statusIcon = Icons.block;
    } else if (isRunning) {
      statusColor = Colors.green;
      statusLabel = 'ใช้งานอยู่';
      statusIcon = Icons.play_circle;
    } else if (isUpcoming) {
      statusColor = Colors.blue;
      statusLabel = 'เร็วๆ นี้';
      statusIcon = Icons.schedule;
    } else {
      statusColor = Colors.red;
      statusLabel = 'หมดอายุ';
      statusIcon = Icons.cancel;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _typeIcon(p.promotionType),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.promotionName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(p.promotionCode,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon,
                            size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Discount info
              Row(
                children: [
                  Icon(Icons.local_offer,
                      size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Text(
                    _discountLabel(p),
                    style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  if (p.minAmount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_cart,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'ขั้นต่ำ ฿${_fmt.format(p.minAmount)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // Period
              Row(
                children: [
                  Icon(Icons.date_range,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${_dateFmt.format(p.startDate)} – ${_dateFmt.format(p.endDate)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (p.maxUses != null) ...[
                    const Spacer(),
                    Icon(Icons.people,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${p.currentUses}/${p.maxUses} ครั้ง',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              // Usage progress if has maxUses
              if (p.maxUses != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.maxUses! > 0
                        ? p.currentUses / p.maxUses!
                        : 0,
                    backgroundColor: Colors.grey[200],
                    color: p.currentUses >= p.maxUses!
                        ? Colors.red
                        : Colors.orange,
                    minHeight: 6,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRunning || isUpcoming)
                    TextButton.icon(
                      onPressed: () => _toggleActive(p),
                      icon: Icon(Icons.pause_circle,
                          size: 16, color: Colors.orange),
                      label: const Text('หยุดชั่วคราว',
                          style: TextStyle(color: Colors.orange)),
                    ),
                  if (!p.isActive && !isExpired)
                    TextButton.icon(
                      onPressed: () => _toggleActive(p),
                      icon: const Icon(Icons.play_circle,
                          size: 16, color: Colors.green),
                      label: const Text('เปิดใช้งาน',
                          style: TextStyle(color: Colors.green)),
                    ),
                  TextButton.icon(
                    onPressed: () => _openForm(p),
                    icon: const Icon(Icons.edit,
                        size: 16, color: Colors.blue),
                    label: const Text('แก้ไข',
                        style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(p),
                    icon: const Icon(Icons.delete,
                        size: 16, color: Colors.red),
                    label: const Text('ลบ',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(String type) {
    IconData icon;
    Color color;
    String label;
    switch (type) {
      case 'DISCOUNT_PERCENT':
        icon = Icons.percent;
        color = Colors.purple;
        label = '%';
        break;
      case 'DISCOUNT_AMOUNT':
        icon = Icons.money;
        color = Colors.green;
        label = '฿';
        break;
      case 'BUY_X_GET_Y':
        icon = Icons.card_giftcard;
        color = Colors.red;
        label = 'B1G1';
        break;
      case 'FREE_ITEM':
        icon = Icons.free_breakfast;
        color = Colors.teal;
        label = 'ฟรี';
        break;
      default:
        icon = Icons.local_offer;
        color = Colors.orange;
        label = '';
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _discountLabel(PromotionModel p) {
    switch (p.promotionType) {
      case 'DISCOUNT_PERCENT':
        return 'ลด ${p.discountValue.toStringAsFixed(0)}%'
            '${p.maxDiscountAmount != null ? ' (สูงสุด ฿${_fmt.format(p.maxDiscountAmount!)})' : ''}';
      case 'DISCOUNT_AMOUNT':
        return 'ลด ฿${_fmt.format(p.discountValue)}';
      case 'BUY_X_GET_Y':
        return 'ซื้อ ${p.buyQty} แถม ${p.getQty}';
      case 'FREE_ITEM':
        return 'ของแถมฟรี';
      default:
        return p.promotionType;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('ยังไม่มีโปรโมชั่น',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _openForm(null),
            icon: const Icon(Icons.add),
            label: const Text('สร้างโปรโมชั่น'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  void _openForm(PromotionModel? promo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PromotionFormPage(promotion: promo)),
    );
    ref.read(promotionListProvider.notifier).refresh();
  }

  void _toggleActive(PromotionModel p) async {
    final updated = p.copyWith(isActive: !p.isActive);
    await ref.read(promotionListProvider.notifier).updatePromotion(updated);
  }

  void _confirmDelete(PromotionModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบโปรโมชั่น "${p.promotionName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(promotionListProvider.notifier)
                  .deletePromotion(p.promotionId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ลบโปรโมชั่นแล้ว')),
                );
              }
            },
            child: const Text('ลบ',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}