// coupon_dialog.dart
// Day 41-45: Apply Coupon Dialog (ใช้ใน POS)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/promotion_provider.dart';

class CouponDialog extends ConsumerStatefulWidget {
  const CouponDialog({super.key});

  @override
  ConsumerState<CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends ConsumerState<CouponDialog> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _validatedCoupon;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.confirmation_number,
                      color: Colors.deepOrange, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('ใช้คูปองส่วนลด',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Input
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'รหัสคูปอง',
                  hintText: 'กรอกโค้ดคูปอง...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _validateCoupon,
                        ),
                  errorText: _errorMessage,
                ),
                onSubmitted: (_) => _validateCoupon(),
                onChanged: (_) {
                  if (_errorMessage != null || _validatedCoupon != null) {
                    setState(() {
                      _errorMessage = null;
                      _validatedCoupon = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Validated result
              if (_validatedCoupon != null)
                _buildValidatedCard(_validatedCoupon!),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _validatedCoupon != null
                          ? () => Navigator.pop(context, _validatedCoupon)
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white),
                      child: const Text('ใช้คูปองนี้'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedCard(Map<String, dynamic> coupon) {
    final discountType = coupon['discount_type'] as String?;
    final discountValue =
        (coupon['discount_value'] as num?)?.toDouble() ?? 0;
    final maxDiscount =
        (coupon['max_discount_amount'] as num?)?.toDouble();

    String discountLabel;
    if (discountType == 'PERCENT') {
      discountLabel = 'ลด ${discountValue.toStringAsFixed(0)}%'
          '${maxDiscount != null ? ' (สูงสุด ฿${maxDiscount.toStringAsFixed(0)})' : ''}';
    } else if (discountType == 'AMOUNT') {
      discountLabel = 'ลด ฿${discountValue.toStringAsFixed(2)}';
    } else {
      discountLabel = coupon['promotion_type'] as String? ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon['promotion_name'] as String? ?? 'โปรโมชั่น',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  discountLabel,
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'โค้ด: ${coupon['coupon_code']}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _validateCoupon() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _validatedCoupon = null;
    });

    final result = await ref
        .read(couponListProvider.notifier)
        .validateCoupon(code);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _validatedCoupon = result;
      } else {
        _errorMessage = 'คูปองไม่ถูกต้อง หมดอายุ หรือถูกใช้แล้ว';
      }
    });
  }
}