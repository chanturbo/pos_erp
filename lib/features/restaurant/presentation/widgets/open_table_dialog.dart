import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dining_table_model.dart';
import '../../../../shared/theme/app_theme.dart';

class OpenTableDialog extends ConsumerStatefulWidget {
  final DiningTableModel table;
  final String branchId;
  final Future<bool> Function(int guestCount) onConfirm;

  const OpenTableDialog({
    super.key,
    required this.table,
    required this.branchId,
    required this.onConfirm,
  });

  @override
  ConsumerState<OpenTableDialog> createState() => _OpenTableDialogState();
}

class _OpenTableDialogState extends ConsumerState<OpenTableDialog> {
  int _guestCount = 1;
  bool _loading = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.table_restaurant,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เปิดโต๊ะ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.table.displayName,
                  style: TextStyle(fontSize: 13, color: AppTheme.subtextColor),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('จำนวนลูกค้า', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CountButton(
                icon: Icons.remove,
                onTap: _guestCount > 1
                    ? () => setState(() => _guestCount--)
                    : null,
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_guestCount',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _CountButton(
                icon: Icons.add,
                onTap: _guestCount < widget.table.capacity
                    ? () => setState(() => _guestCount++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ความจุโต๊ะ ${widget.table.capacity} ที่นั่ง',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtextColor,
              ),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _confirm,
          icon: _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_loading ? 'กำลังเปิด...' : 'เปิดโต๊ะ'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final ok = await widget.onConfirm(_guestCount);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _loading = false;
          _errorText = 'เปิดโต๊ะไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'เปิดโต๊ะไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        });
      }
    }
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onTap != null ? AppTheme.primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: onTap != null ? Colors.white : Colors.grey.shade500,
        size: 20,
      ),
    ),
  );
}
