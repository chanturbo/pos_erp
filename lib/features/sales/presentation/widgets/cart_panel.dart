import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../pages/payment_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';

// ── OAG Tokens ────────────────────────────────────────────────────
const _navy    = AppTheme.navyColor;
const _orange  = AppTheme.primaryColor;
const _surface = AppTheme.surfaceColor;
const _border  = AppTheme.borderColor;
const _success = AppTheme.successColor;
const _error   = AppTheme.errorColor;
const _info    = AppTheme.infoColor;

// ─────────────────────────────────────────────────────────────────
// CartPanel
// ─────────────────────────────────────────────────────────────────
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _CartHeader(
            itemCount: cartState.itemCount,
            onClear: cartState.items.isEmpty
                ? null
                : () => ref.read(cartProvider.notifier).clear(),
          ),

          // ── Column labels ────────────────────────────────────
          if (cartState.items.isNotEmpty) const _ColHeader(),

          // ── Cart Items ───────────────────────────────────────
          Expanded(
            child: cartState.items.isEmpty
                ? const _EmptyCart()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: cartState.items.length,
                    itemBuilder: (_, i) => _CartRow(
                      item: cartState.items[i],
                      isEven: i.isEven,
                    ),
                  ),
          ),

          // ── Summary ──────────────────────────────────────────
          _CartSummary(cartState: cartState),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Header — Navy bar + item count badge
// ─────────────────────────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  final int itemCount;
  final VoidCallback? onClear;

  const _CartHeader({required this.itemCount, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _navy,
        border: Border(
            bottom: BorderSide(color: AppTheme.navyBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long,
              color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          const Text(
            'รายการสินค้า',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 14,
                        color: Color(0xFFEF9A9A)),
                    SizedBox(width: 3),
                    Text('ล้าง',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF9A9A))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Column labels
// ─────────────────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  const _ColHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEEEEE),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: const Row(
        children: [
          SizedBox(width: 22),
          Expanded(
            flex: 5,
            child: Text('สินค้า',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
          ),
          SizedBox(
            width: 92,
            child: Center(
              child: Text('จำนวน',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
          ),
          SizedBox(
            width: 68,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('รวม',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
          ),
          SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Cart Row — compact single-line + inline qty edit
// แทนที่ Card ขนาดใหญ่ (~110px) ด้วย row (~42px)
// ─────────────────────────────────────────────────────────────────
class _CartRow extends ConsumerStatefulWidget {
  final CartItem item;
  final bool isEven;

  const _CartRow({required this.item, required this.isEven});

  @override
  ConsumerState<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends ConsumerState<_CartRow> {
  bool _editingQty = false;
  late TextEditingController _qtyCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.item.quantity.toStringAsFixed(0));
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editingQty) _commitQty();
    });
  }

  @override
  void didUpdateWidget(_CartRow old) {
    super.didUpdateWidget(old);
    // sync ตัวเลขเมื่อ quantity เปลี่ยนจากภายนอก
    if (!_editingQty &&
        old.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = widget.item.quantity.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitQty() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final safe = qty < 0.001 ? 1.0 : qty;
    ref
        .read(cartProvider.notifier)
        .setQuantity(widget.item.productId, safe);
    setState(() => _editingQty = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      color: widget.isEven ? Colors.white : const Color(0xFFF9F9F7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Delete button
          SizedBox(
            width: 28,
            child: InkWell(
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .removeItem(item.productId),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 13, color: _error),
              ),
            ),
          ),

          // Product name + unit price
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A)), // ✅ เข้มเสมอ
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    // ✅ รักษา unitPrice จากไฟล์เดิม
                    '฿${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.subtextColor),
                  ),
                ],
              ),
            ),
          ),

          // Qty control — inline edit เมื่อแตะตัวเลข
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease — ✅ รักษา decreaseQuantity จากไฟล์เดิม
                _QtyBtn(
                  icon: Icons.remove,
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .decreaseQuantity(item.productId),
                ),

                // Qty box — แตะเพื่อ edit inline
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _editingQty = true;
                      _qtyCtrl.text =
                          item.quantity.toStringAsFixed(0);
                      _qtyCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _qtyCtrl.text.length,
                      );
                    });
                    Future.microtask(
                        () => _focusNode.requestFocus());
                  },
                  child: Container(
                    width: 36,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            _editingQty ? _orange : _border,
                        width: _editingQty ? 1.5 : 1,
                      ),
                    ),
                    child: _editingQty
                        ? TextField(
                            controller: _qtyCtrl,
                            focusNode: _focusNode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A)), // ✅
                            keyboardType:
                                TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .allow(RegExp(r'[\d.]'))
                            ],
                            decoration:
                                const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _commitQty(),
                          )
                        : Text(
                            item.quantity.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A), // ✅ เข้มเสมอ
                            ),
                          ),
                  ),
                ),

                // Increase — ✅ รักษา increaseQuantity จากไฟล์เดิม
                _QtyBtn(
                  icon: Icons.add,
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .increaseQuantity(item.productId),
                ),
              ],
            ),
          ),

          // Amount — ✅ รักษา item.amount จากไฟล์เดิม
          SizedBox(
            width: 68,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '฿${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _info,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Qty +/- button
// ─────────────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 14, color: _navy),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty Cart
// ─────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 52, color: Colors.grey),
          SizedBox(height: 10),
          Text('ตะกร้าว่าง',
              style:
                  TextStyle(color: Colors.grey, fontSize: 13)),
          SizedBox(height: 4),
          Text('กดสินค้าเพื่อเพิ่มลงตะกร้า',
              style:
                  TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary + Pay button
// รักษา subtotal / totalDiscount / total จากไฟล์เดิม
// ─────────────────────────────────────────────────────────────────
class _CartSummary extends StatelessWidget {
  final CartState cartState;
  const _CartSummary({required this.cartState});

  @override
  Widget build(BuildContext context) {
    final totalFontSize = context.isMobile ? 18.0 : 20.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              children: [
                // ✅ รักษา subtotal จากไฟล์เดิม
                _SummaryRow(
                    label: 'รวม',
                    value:
                        '฿${cartState.subtotal.toStringAsFixed(2)}',
                    valueColor: const Color(0xFF1A1A1A)), // ✅

                // ✅ รักษา totalDiscount จากไฟล์เดิม
                if (cartState.totalDiscount > 0) ...[
                  const SizedBox(height: 3),
                  _SummaryRow(
                    label: 'ส่วนลด',
                    value:
                        '-฿${cartState.totalDiscount.toStringAsFixed(2)}',
                    valueColor: _error,
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: _border),
                ),

                // ✅ รักษา total จากไฟล์เดิม
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ยอดชำระ',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))), // ✅
                    Text(
                      '฿${cartState.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: totalFontSize,
                        fontWeight: FontWeight.bold,
                        color: _success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Item count strip
          if (cartState.itemCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cartState.itemCount} รายการ',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      'รวม ${cartState.items.fold<double>(0, (s, i) => s + i.quantity).toStringAsFixed(0)} ชิ้น',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // ✅ ปุ่มชำระเงิน รักษา PaymentPage navigate จากไฟล์เดิม
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              height: context.isMobile ? 44 : 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cartState.items.isEmpty
                      ? Colors.grey[300]
                      : _success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: cartState.items.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PaymentPage()),
                        ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cartState.items.isEmpty
                          ? 'ชำระเงิน'
                          : 'ชำระเงิน  ฿${cartState.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.subtextColor)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor)),
      ],
    );
  }
}