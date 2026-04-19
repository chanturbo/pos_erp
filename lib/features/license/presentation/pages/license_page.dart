import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/license/license_models.dart';
import '../../../../core/services/license/license_service.dart';

class LicenseRegistrationPage extends ConsumerStatefulWidget {
  const LicenseRegistrationPage({super.key});

  @override
  ConsumerState<LicenseRegistrationPage> createState() => _LicensePageState();
}

class _LicensePageState extends ConsumerState<LicenseRegistrationPage> {
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _errorMsg;
  bool _obscureKey = true;

  static const _orange = Color(0xFFE57200);
  static const _navy = Color(0xFF16213E);

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final error =
        await ref.read(licenseServiceProvider.notifier).activateLicense(key);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      _keyController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลงทะเบียนสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeLicense() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ License'),
        content: const Text('ต้องการยกเลิก License Key ที่ลงทะเบียนไว้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ยืนยัน',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(licenseServiceProvider.notifier).removeLicense();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(licenseServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('License'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'ซิงค์เวลา NTP',
            onPressed: () async {
              await ref
                  .read(licenseServiceProvider.notifier)
                  .syncTimeAndRefresh();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ซิงค์เวลาเรียบร้อย')),
              );
            },
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (status) => _buildBody(status),
      ),
    );
  }

  Widget _buildBody(LicenseStatus status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(status: status),
          const SizedBox(height: 20),
          _DeviceInfoCard(status: status),
          const SizedBox(height: 20),
          if (status.isLicensed) ...[
            _ActiveLicenseCard(status: status, onRemove: _removeLicense),
          ] else ...[
            _PricingCard(status: status),
            const SizedBox(height: 20),
            _ActivationCard(
              controller: _keyController,
              loading: _loading,
              errorMsg: _errorMsg,
              obscure: _obscureKey,
              onToggleObscure: () =>
                  setState(() => _obscureKey = !_obscureKey),
              onActivate: _activate,
              orange: _orange,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Status Banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final LicenseStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.isLicensed
        ? Colors.green
        : (status.isTrialActive ? Colors.orange : Colors.red);

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              status.isLicensed
                  ? Icons.verified
                  : (status.isTrialActive ? Icons.timer_outlined : Icons.block),
              color: color,
              size: 44,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.isLicensed
                        ? 'ลงทะเบียนแล้ว'
                        : (status.isTrialActive
                            ? 'ช่วงทดลองใช้'
                            : 'หมดช่วงทดลองแล้ว'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (!status.isLicensed) ...[
                    Text(
                      status.trialPhaseLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'ใช้งานมาแล้ว ${status.daysSinceFirstLaunch} วัน'
                      '${status.isTrialActive ? ' (เหลือ ${status.daysRemainingInPhase} วันในราคานี้)' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ] else
                    Text(
                      'หมดอายุ: ${status.licenseExpireDate?.toIso8601String().substring(0, 10)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Device Info ──────────────────────────────────────────────────────────────

class _DeviceInfoCard extends StatelessWidget {
  final LicenseStatus status;
  const _DeviceInfoCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device ID (แจ้งให้ผู้ดูแลเพื่อออก License Key)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    status.deviceId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'คัดลอก',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: status.deviceId),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอก Device ID แล้ว')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pricing Card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final LicenseStatus status;
  const _PricingCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ราคา Subscription',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            _PriceRow(
              label: 'เดือนที่ 1 (วันที่ 1–30)',
              price: '990',
              isCurrent: status.trialPhase == TrialPhase.trial1,
            ),
            _PriceRow(
              label: 'เดือนที่ 2 (วันที่ 31–60)',
              price: '1,490',
              isCurrent: status.trialPhase == TrialPhase.trial2,
            ),
            _PriceRow(
              label: 'เดือนที่ 3 (วันที่ 61–90)',
              price: '1,990',
              isCurrent: status.trialPhase == TrialPhase.trial3,
            ),
            _PriceRow(
              label: 'หลังวันที่ 90',
              price: '4,990',
              isCurrent: status.trialPhase == TrialPhase.expired,
              isLast: true,
            ),
            if (!status.isLicensed) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 18, color: Color(0xFFE57200)),
                  const SizedBox(width: 8),
                  Text(
                    'ราคาปัจจุบัน: ${status.currentPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} บาท/เดือน',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE57200),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String price;
  final bool isCurrent;
  final bool isLast;

  const _PriceRow({
    required this.label,
    required this.price,
    required this.isCurrent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: isCurrent
          ? BoxDecoration(
              color: const Color(0xFFE57200).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        children: [
          if (isCurrent)
            const Icon(Icons.arrow_right,
                color: Color(0xFFE57200), size: 18)
          else
            const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight:
                    isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '$price บาท',
            style: TextStyle(
              fontWeight:
                  isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? const Color(0xFFE57200) : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activation Card ──────────────────────────────────────────────────────────

class _ActivationCard extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? errorMsg;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onActivate;
  final Color orange;

  const _ActivationCard({
    required this.controller,
    required this.loading,
    required this.errorMsg,
    required this.obscure,
    required this.onToggleObscure,
    required this.onActivate,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรอก License Key',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: obscure,
              maxLines: obscure ? 1 : 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'วางค่า License Key ที่ได้รับจากระบบ',
                border: const OutlineInputBorder(),
                errorText: errorMsg,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onActivate,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.vpn_key),
                label: Text(loading ? 'กำลังตรวจสอบ...' : 'ลงทะเบียน License'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active License Card ──────────────────────────────────────────────────────

class _ActiveLicenseCard extends StatelessWidget {
  final LicenseStatus status;
  final VoidCallback onRemove;

  const _ActiveLicenseCard({
    required this.status,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูล License',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            _InfoRow(
              label: 'อีเมล',
              value: status.licensedEmail ?? '-',
            ),
            _InfoRow(
              label: 'หมดอายุ',
              value: status.licenseExpireDate
                      ?.toIso8601String()
                      .substring(0, 10) ??
                  '-',
            ),
            _InfoRow(label: 'Device ID', value: status.deviceId),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'ลบ License Key',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
