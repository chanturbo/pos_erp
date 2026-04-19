import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/license/license_notification_service.dart';
import '../../core/services/license/license_service.dart';
import '../../routes/app_router.dart';

/// Banner แจ้งเตือน License ที่แสดงที่บนสุดของหน้า
///
/// วางที่บน child ของ home page เพื่อแสดงเฉพาะเมื่อมี notice ที่ค้างอยู่
/// ผู้ใช้กด X เพื่อซ่อน (บันทึกว่าแสดงแล้ว) หรือกดปุ่มเพื่อไป license page
class LicenseNoticeBanner extends ConsumerStatefulWidget {
  final Widget child;

  const LicenseNoticeBanner({super.key, required this.child});

  @override
  ConsumerState<LicenseNoticeBanner> createState() =>
      _LicenseNoticeBannerState();
}

class _LicenseNoticeBannerState extends ConsumerState<LicenseNoticeBanner> {
  LicenseNotice? _notice;
  bool _dismissed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotice();
  }

  Future<void> _loadNotice() async {
    final statusAsync = ref.read(licenseServiceProvider);
    final status = statusAsync.asData?.value;
    if (status == null) return;

    final notice = await LicenseNotificationService.getPendingNotice(status);
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    final status = ref.read(licenseServiceProvider).asData?.value;
    if (status != null) {
      await LicenseNotificationService.markShown(status.daysSinceFirstLaunch);
    }
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    // รอโหลด license status ก่อน แล้วค่อย load notice
    ref.listen(licenseServiceProvider, (_, next) {
      if (!_loaded && next.hasValue) _loadNotice();
    });

    final showBanner = _loaded && _notice != null && !_dismissed;

    return Column(
      children: [
        if (showBanner) _BannerBar(
          notice: _notice!,
          onDismiss: _dismiss,
          onRegister: () {
            _dismiss();
            Navigator.of(context).pushNamed(AppRouter.license);
          },
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// ─── Banner UI ────────────────────────────────────────────────────────────────

class _BannerBar extends StatelessWidget {
  final LicenseNotice notice;
  final VoidCallback onDismiss;
  final VoidCallback onRegister;

  const _BannerBar({
    required this.notice,
    required this.onDismiss,
    required this.onRegister,
  });

  Color get _bgColor =>
      notice.isUrgent ? const Color(0xFFB71C1C) : const Color(0xFFE57200);

  @override
  Widget build(BuildContext context) {
    final formattedPrice = notice.price
        .toString()
        .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        );

    return Material(
      elevation: 2,
      child: Container(
        color: _bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // ── Icon ──────────────────────────────────────────────
            Icon(
              notice.isUrgent ? Icons.warning_amber_rounded : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),

            // ── Text ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notice.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    notice.body,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Register button ───────────────────────────────────
            OutlinedButton(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text('ลงทะเบียน $formattedPrice บาท'),
            ),
            const SizedBox(width: 4),

            // ── Dismiss button ────────────────────────────────────
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact banner for narrow screens (ใช้กับ MobileOrderPage ด้วย) ─────────

class LicenseNoticeCompactBanner extends ConsumerWidget {
  const LicenseNoticeCompactBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(licenseServiceProvider);
    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        if (status.isLicensed) return const SizedBox.shrink();
        if (status.isTrialActive && status.daysRemainingInPhase > 5) {
          return const SizedBox.shrink();
        }
        // แสดงเฉพาะเมื่อใกล้หมดหรือหมดแล้ว
        final color = status.isTrialActive
            ? const Color(0xFFE57200)
            : const Color(0xFFB71C1C);
        final text = status.isTrialActive
            ? 'เหลือ ${status.daysRemainingInPhase} วัน — ลงทะเบียน ${status.currentPrice} บาท'
            : 'หมดช่วงทดลอง — ลงทะเบียน ${status.currentPrice} บาท/เดือน';

        return GestureDetector(
          onTap: () => Navigator.of(context).pushNamed(AppRouter.license),
          child: Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
