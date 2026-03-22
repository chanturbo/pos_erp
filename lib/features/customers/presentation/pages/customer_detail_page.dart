// lib/features/customers/presentation/pages/customer_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/customer_model.dart';
import 'customer_form_page.dart';

// ─────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────
class _OrderItem {
  final String itemId;
  final int lineNo;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;

  const _OrderItem({
    required this.itemId,
    required this.lineNo,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory _OrderItem.fromJson(Map<String, dynamic> j) => _OrderItem(
        itemId:      j['item_id']      as String,
        lineNo:      j['line_no']      as int,
        productName: j['product_name'] as String,
        unit:        j['unit']         as String,
        quantity:    (j['quantity']    as num).toDouble(),
        unitPrice:   (j['unit_price']  as num).toDouble(),
        amount:      (j['amount']      as num).toDouble(),
      );
}

class _Order {
  final String orderId;
  final String orderNo;
  final DateTime orderDate;
  final String paymentType;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final List<_OrderItem> items;

  const _Order({
    required this.orderId,
    required this.orderNo,
    required this.orderDate,
    required this.paymentType,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    required this.items,
  });

  factory _Order.fromJson(Map<String, dynamic> j) => _Order(
        orderId:        j['order_id']       as String,
        orderNo:        j['order_no']       as String,
        orderDate:      DateTime.parse(j['order_date'] as String),
        paymentType:    j['payment_type']   as String? ?? 'CASH',
        subtotal:       (j['subtotal']      as num).toDouble(),
        discountAmount: (j['discount_amount'] as num).toDouble(),
        totalAmount:    (j['total_amount']  as num).toDouble(),
        status:         j['status']         as String? ?? '',
        items: (j['items'] as List)
            .map((e) => _OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────
// CustomerDetailPage
// ─────────────────────────────────────────────────────────────────
class CustomerDetailPage extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const CustomerDetailPage({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailPage> createState() =>
      _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  bool _isLoading = true;
  String? _error;
  List<_Order> _orders = [];
  int _totalOrders = 0;
  double _totalSpent = 0;

  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');
  final _numFmt  = NumberFormat('#,##0.00');
  final _numFmtInt = NumberFormat('#,##0');

  // expanded order IDs
  final Set<String> _expanded = {};

  CustomerModel get _customer => widget.customer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/customers/${_customer.customerId}/orders');
      if (res.statusCode == 200) {
        final body = res.data as Map<String, dynamic>;
        final d    = body['data'] as Map<String, dynamic>;
        setState(() {
          _orders      = (d['orders'] as List)
              .map((e) => _Order.fromJson(e as Map<String, dynamic>))
              .toList();
          _totalOrders = d['total_orders'] as int;
          _totalSpent  = (d['total_spent'] as num).toDouble();
          _isLoading   = false;
        });
      }
    } catch (e) {
      setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  // ── Payment type label ──────────────────────────────────────────
  String _payLabel(String type) {
    switch (type) {
      case 'CASH':     return 'เงินสด';
      case 'CARD':     return 'บัตร';
      case 'TRANSFER': return 'โอน';
      default:         return type;
    }
  }

  IconData _payIcon(String type) {
    switch (type) {
      case 'CASH':     return Icons.money;
      case 'CARD':     return Icons.credit_card;
      case 'TRANSFER': return Icons.qr_code;
      default:         return Icons.payment;
    }
  }

  // ── PriceLevel label ────────────────────────────────────────────
  String _levelLabel(int level) {
    switch (level) {
      case 2: return 'สมาชิก';
      case 3: return 'ลูกค้าส่ง';
      case 4: return 'ตัวแทน';
      case 5: return 'VIP';
      default: return 'ทั่วไป';
    }
  }

  Color _levelColor(int level) {
    switch (level) {
      case 2: return const Color(0xFF2E7D32);
      case 3: return const Color(0xFFE65100);
      case 4: return const Color(0xFF6A1B9A);
      case 5: return const Color(0xFFC62828);
      default: return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _customer;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ─────────────────────────────────────────────
          _buildTopBar(isDark, c),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Info Card ────────────────────────────────────
                  _buildInfoCard(isDark, c),
                  const SizedBox(height: 12),

                  // ── Stats Row ────────────────────────────────────
                  _buildStatsRow(isDark),
                  const SizedBox(height: 16),

                  // ── Orders ───────────────────────────────────────
                  _buildOrdersSection(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark, CustomerModel c) {
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: isDark ? Colors.white : AppTheme.navyColor,
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.customerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  c.customerCode,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          // ── Edit Button ───────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: AppTheme.primary,
            tooltip: 'แก้ไขข้อมูล',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerFormPage(customer: c),
                ),
              );
              // ไม่ต้อง reload orders แค่ pop กลับไป customer list
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ── Info Card ─────────────────────────────────────────────────
  Widget _buildInfoCard(bool isDark, CustomerModel c) {
    final level = c.priceLevel;
    final lvlColor = _levelColor(level);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ชื่อ + Level badge ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  c.customerName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lvlColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lvlColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Lv.$level ${_levelLabel(level)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: lvlColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── rows of info ─────────────────────────────────────────
          _infoRow(isDark, Icons.phone_outlined,
              c.phone ?? '-', 'เบอร์โทร'),
          if (c.email != null) ...[
            const SizedBox(height: 6),
            _infoRow(isDark, Icons.email_outlined, c.email!, 'อีเมล'),
          ],
          if (c.address != null) ...[
            const SizedBox(height: 6),
            _infoRow(isDark, Icons.location_on_outlined, c.address!, 'ที่อยู่'),
          ],

          // ── Member + Points ─────────────────────────────────────
          if (c.memberNo != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoRow(isDark, Icons.badge_outlined,
                      c.memberNo!, 'เลขสมาชิก'),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_numFmtInt.format(c.points)} แต้ม',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // ── Credit ──────────────────────────────────────────────
          if (c.creditLimit > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    isDark,
                    Icons.credit_card_outlined,
                    '฿${_numFmt.format(c.creditLimit)}',
                    'วงเงินเครดิต',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _infoRow(
                    isDark,
                    Icons.account_balance_wallet_outlined,
                    '฿${_numFmt.format(c.currentBalance)}',
                    'ยอดค้างชำระ',
                    valueColor: c.currentBalance > 0
                        ? AppTheme.errorColor
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String value, String label,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 16,
            color: isDark ? Colors.white38 : AppTheme.textSub),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ??
                      (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppTheme.textSub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            isDark,
            label: 'ออเดอร์ทั้งหมด',
            value: _numFmtInt.format(_totalOrders),
            unit: 'รายการ',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.infoColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            isDark,
            label: 'ยอดซื้อรวม',
            value: '฿${_numFmt.format(_totalSpent)}',
            unit: 'บาท',
            icon: Icons.payments_outlined,
            color: AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard(bool isDark,
      {required String label,
      required String value,
      required String unit,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? Colors.white38 : AppTheme.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Orders Section ────────────────────────────────────────────
  Widget _buildOrdersSection(bool isDark) {
    if (_isLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ));
    }

    if (_error != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.errorColor, size: 48),
            const SizedBox(height: 8),
            Text('โหลดข้อมูลล้มเหลว',
                style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textSub)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.history, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'ประวัติการซื้อ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            if (_orders.isNotEmpty)
              Text(
                '$_totalOrders รายการ',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : AppTheme.textSub),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.white12 : AppTheme.borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'ยังไม่มีประวัติการซื้อ',
                    style: TextStyle(
                        color: isDark ? Colors.white38 : AppTheme.textSub),
                  ),
                ],
              ),
            ),
          )
        else
          ..._orders
              .map((order) => _buildOrderCard(isDark, order))
              .toList(),
      ],
    );
  }

  // ── Order Card (expandable) ───────────────────────────────────
  Widget _buildOrderCard(bool isDark, _Order order) {
    final isExpanded = _expanded.contains(order.orderId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : AppTheme.borderColor),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Order Header (กดเพื่อ expand) ────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              if (isExpanded) {
                _expanded.remove(order.orderId);
              } else {
                _expanded.add(order.orderId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ── Expand icon ────────────────────────────────
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: isExpanded
                          ? AppTheme.primary
                          : (isDark ? Colors.white38 : AppTheme.textSub),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Order No + Date ───────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNo,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateFmt.format(order.orderDate),
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textSub),
                        ),
                      ],
                    ),
                  ),

                  // ── Payment + Amount ──────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '฿${_numFmt.format(order.totalAmount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_payIcon(order.paymentType),
                              size: 11,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textSub),
                          const SizedBox(width: 3),
                          Text(
                            _payLabel(order.paymentType),
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : AppTheme.textSub),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Items (แสดงเมื่อ expand) ──────────────────────────
          if (isExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : AppTheme.borderColor,
            ),
            _buildItemList(isDark, order),
          ],
        ],
      ),
    );
  }

  // ── Item List ─────────────────────────────────────────────────
  Widget _buildItemList(bool isDark, _Order order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('สินค้า',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : AppTheme.textSub,
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('จำนวน',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : AppTheme.textSub,
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('ราคา',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : AppTheme.textSub,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items
          ...order.items.map((item) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.productName,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${_numFmtInt.format(item.quantity)} ${item.unit}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSub),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '฿${_numFmt.format(item.amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor),
                      ),
                    ),
                  ],
                ),
              )),

          // ── Subtotal + Discount + Total ───────────────────────
          const Divider(height: 1),
          if (order.discountAmount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ยอดก่อนส่วนลด',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white38
                              : AppTheme.textSub)),
                  Text('฿${_numFmt.format(order.subtotal)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white38
                              : AppTheme.textSub)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ส่วนลด',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.errorColor
                              .withValues(alpha: 0.8))),
                  Text('-฿${_numFmt.format(order.discountAmount)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดรวม',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                Text('฿${_numFmt.format(order.totalAmount)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}