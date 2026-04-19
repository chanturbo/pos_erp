import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/license/license_models.dart';
import '../../core/services/license/license_service.dart';

/// Widget ที่ล็อคฟีเจอร์ตาม [LicenseFeature]
///
/// ตัวอย่าง:
/// ```dart
/// LicenseGuard(
///   feature: LicenseFeature.openSale,
///   child: ElevatedButton(onPressed: _openSale, child: Text('เปิดบิล')),
/// )
/// ```
class LicenseGuard extends ConsumerWidget {
  final LicenseFeature feature;
  final Widget child;

  /// Widget ที่แสดงแทนเมื่อฟีเจอร์ถูกล็อค (ถ้าไม่ระบุจะใช้ default banner)
  final Widget? lockedChild;

  const LicenseGuard({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(licenseServiceProvider);

    // ถ้ายังโหลดอยู่หรือ error → แสดง child ปกติ (fail-open ในช่วงโหลด)
    return statusAsync.when(
      loading: () => child,
      error: (_, _) => child,
      data: (status) {
        if (status.canUseFeature(feature)) return child;
        return lockedChild ?? _LockedBanner(feature: feature);
      },
    );
  }
}

/// ใช้แทน ElevatedButton เดิม — แสดงปุ่ม lock ถ้าหมดอายุ
class LicenseGuardButton extends ConsumerWidget {
  final LicenseFeature feature;
  final Widget label;
  final Widget? icon;
  final VoidCallback onPressed;
  final ButtonStyle? style;

  const LicenseGuardButton({
    super.key,
    required this.feature,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(licenseServiceProvider);

    return statusAsync.when(
      loading: () => _buildButton(onPressed),
      error: (_, _) => _buildButton(onPressed),
      data: (status) {
        if (status.canUseFeature(feature)) return _buildButton(onPressed);
        return _buildLockedButton(context);
      },
    );
  }

  Widget _buildButton(VoidCallback handler) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: handler,
        icon: icon!,
        label: label,
        style: style,
      );
    }
    return ElevatedButton(onPressed: handler, style: style, child: label);
  }

  Widget _buildLockedButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.of(context).pushNamed('/license'),
      icon: const Icon(Icons.lock_outline, size: 16),
      label: const Text('ต้องมี License'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade400,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  final LicenseFeature feature;
  const _LockedBanner({required this.feature});

  String get _label => switch (feature) {
    LicenseFeature.createEdit => 'เพิ่ม/แก้ไข/ลบข้อมูล',
    LicenseFeature.openSale => 'ขาย/เปิดบิล',
    LicenseFeature.printReceipt => 'พิมพ์ใบเสร็จ',
    LicenseFeature.exportReport => 'Export รายงาน',
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pushNamed('/license'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ฟีเจอร์ "$_label" ถูกล็อค',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'หมดช่วงทดลองแล้ว — แตะเพื่อดูข้อมูล License',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
