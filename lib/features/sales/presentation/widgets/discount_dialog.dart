import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/mobile_home_button.dart';

class DiscountDialog extends StatefulWidget {
  final double currentPercent;
  final double currentAmount;

  const DiscountDialog({
    super.key,
    this.currentPercent = 0,
    this.currentAmount  = 0,
  });

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late TextEditingController _percentController;
  late TextEditingController _amountController;
  late int _selectedTab; // 0 = percent, 1 = amount

  @override
  void initState() {
    super.initState();
    _percentController = TextEditingController(
      text: widget.currentPercent > 0
          ? _fmtValue(widget.currentPercent)
          : '',
    );
    _amountController = TextEditingController(
      text: widget.currentAmount > 0
          ? _fmtValue(widget.currentAmount)
          : '',
    );
    // ✅ แก้ bug: ถ้าไม่มีส่วนลดเลย → เปิด tab percent (0)
    //            ถ้ามีเปอร์เซ็นต์              → tab 0
    //            ถ้ามีแต่จำนวนเงิน             → tab 1
    _selectedTab = widget.currentAmount > 0 && widget.currentPercent == 0
        ? 1
        : 0;
  }

  @override
  void dispose() {
    _percentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // format ค่าทศนิยมไม่จำเป็น
  String _fmtValue(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? AppTheme.darkCard    : Colors.white;
    final textColor   = isDark ? Colors.white         : const Color(0xFF1A1A1A);
    final divColor    = isDark ? const Color(0xFF333333) : AppTheme.borderColor;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_offer,
                        size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ตั้งค่าส่วนลด',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  buildMobileCloseCompactButton(
                    context,
                    isDark: isDark,
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: divColor),
              ),

              // ── Tab selector ─────────────────────────────────────
              _TabSelector(
                selected: _selectedTab,
                isDark: isDark,
                onChanged: (v) => setState(() => _selectedTab = v),
              ),
              const SizedBox(height: 20),

              // ── Input area ───────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _selectedTab == 0
                    ? _PercentInput(
                        key: const ValueKey('percent'),
                        controller: _percentController,
                        isDark: isDark,
                      )
                    : _AmountInput(
                        key: const ValueKey('amount'),
                        controller: _amountController,
                        isDark: isDark,
                      ),
              ),

              const SizedBox(height: 24),

              // ── Actions ──────────────────────────────────────────
              Row(
                children: [
                  // ล้างส่วนลด
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, {
                        'percent': 0.0,
                        'amount':  0.0,
                      }),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('ล้างส่วนลด'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ตกลง
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _onConfirm,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('ยืนยัน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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

  void _onConfirm() {
    final percent = _selectedTab == 0
        ? double.tryParse(_percentController.text.trim()) ?? 0.0
        : 0.0;
    final amount = _selectedTab == 1
        ? double.tryParse(_amountController.text.trim()) ?? 0.0
        : 0.0;
    Navigator.pop(context, {'percent': percent, 'amount': amount});
  }
}

// ─────────────────────────────────────────────────────────────────
// Tab Selector
// ─────────────────────────────────────────────────────────────────
class _TabSelector extends StatelessWidget {
  final int      selected;
  final bool     isDark;
  final ValueChanged<int> onChanged;

  const _TabSelector({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          label: 'เปอร์เซ็นต์',
          icon: Icons.percent,
          active: selected == 0,
          isDark: isDark,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 8),
        _Tab(
          label: 'จำนวนเงิน',
          icon: Icons.payments_outlined,
          active: selected == 1,
          isDark: isDark,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     active;
  final bool     isDark;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primary;
    final inactiveColor = isDark ? Colors.white38 : AppTheme.subtextColor;
    final activeBg =
        AppTheme.primary.withValues(alpha: 0.10);
    final inactiveBg =
        isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? activeColor : inactiveColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Percent Input + Quick chips
// ─────────────────────────────────────────────────────────────────
class _PercentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _PercentInput({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller:     controller,
          autofocus:      true,
          keyboardType:   const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            labelText: 'ส่วนลด',
            labelStyle: const TextStyle(color: AppTheme.textSub),
            suffixText: '%',
            suffixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? AppTheme.darkElement
                : AppTheme.primary.withValues(alpha: 0.04),
          ),
        ),
        const SizedBox(height: 12),
        // Quick chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [5, 10, 15, 20, 25, 30].map((p) {
            final isSelected =
                controller.text.trim() == p.toString();
            return ChoiceChip(
              label: Text('$p%'),
              selected: isSelected,
              onSelected: (_) =>
                  controller.text = p.toString(),
              selectedColor:
                  AppTheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? Colors.white70 : AppTheme.subtextColor),
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : (isDark
                        ? const Color(0xFF444444)
                        : AppTheme.borderColor),
              ),
              backgroundColor:
                  isDark ? AppTheme.darkElement : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 2),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Amount Input + Quick chips
// ─────────────────────────────────────────────────────────────────
class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _AmountInput({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller:     controller,
          autofocus:      true,
          keyboardType:   const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            labelText: 'ส่วนลด',
            labelStyle: const TextStyle(color: AppTheme.textSub),
            prefixText: '฿ ',
            prefixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? AppTheme.darkElement
                : AppTheme.primary.withValues(alpha: 0.04),
          ),
        ),
        const SizedBox(height: 12),
        // Quick chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [10, 20, 50, 100, 200, 500].map((a) {
            final isSelected =
                controller.text.trim() == a.toString();
            return ChoiceChip(
              label: Text('฿$a'),
              selected: isSelected,
              onSelected: (_) =>
                  controller.text = a.toString(),
              selectedColor:
                  AppTheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? Colors.white70 : AppTheme.subtextColor),
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : (isDark
                        ? const Color(0xFF444444)
                        : AppTheme.borderColor),
              ),
              backgroundColor:
                  isDark ? AppTheme.darkElement : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 2),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }
}
