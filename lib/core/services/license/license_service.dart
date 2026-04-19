// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'license_key_verifier.dart';
import 'license_models.dart';
import 'time_guard_service.dart';

const _keyFirstLaunchDate = 'license_first_launch_date';
const _keyDeviceId = 'license_device_id';
const _keyLicenseKey = 'license_saved_key';

final licenseServiceProvider =
    AsyncNotifierProvider<LicenseService, LicenseStatus>(LicenseService.new);

class LicenseService extends AsyncNotifier<LicenseStatus> {
  @override
  Future<LicenseStatus> build() => _loadStatus();

  Future<LicenseStatus> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Device ID ────────────────────────────────────────────────────
    if (prefs.getString(_keyDeviceId) == null) {
      final id = const Uuid().v4();
      await prefs.setString(_keyDeviceId, id);
      print('[License] New device ID: $id');
    }
    final deviceId = prefs.getString(_keyDeviceId)!;

    // ── First launch date ─────────────────────────────────────────────
    if (prefs.getString(_keyFirstLaunchDate) == null) {
      final reliable = await TimeGuardService.getReliableTime();
      final dateStr = reliable.toIso8601String().substring(0, 10);
      await prefs.setString(_keyFirstLaunchDate, dateStr);
      print('[License] First launch recorded: $dateStr');
    }
    final firstLaunchDate = DateTime.parse(prefs.getString(_keyFirstLaunchDate)!);

    // ── Days elapsed (clock-safe) ─────────────────────────────────────
    final now = await TimeGuardService.getReliableTime();
    final days = now.difference(firstLaunchDate).inDays + 1;
    final phase = _phaseForDay(days);
    final isTrialActive = phase != TrialPhase.expired;

    // ── Saved license key ─────────────────────────────────────────────
    final savedKey = prefs.getString(_keyLicenseKey);
    LicensePayload? payload;
    if (savedKey != null) {
      payload = LicenseKeyVerifier.verify(
        licenseKey: savedKey,
        deviceId: deviceId,
      );
      if (payload == null) {
        print('[License] Saved key is no longer valid — clearing');
        await prefs.remove(_keyLicenseKey);
      }
    }

    final isLicensed = payload != null && payload.expireDate.isAfter(now);
    if (payload != null && !isLicensed) {
      print('[License] License expired: ${payload.expireDate}');
    }

    return LicenseStatus(
      isLicensed: isLicensed,
      isTrialActive: isTrialActive,
      trialPhase: phase,
      daysSinceFirstLaunch: days,
      firstLaunchDate: firstLaunchDate,
      licenseExpireDate: payload?.expireDate,
      licensedEmail: payload?.email,
      deviceId: deviceId,
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// ลงทะเบียน License Key
  /// คืน error message (Thai) หรือ null ถ้าสำเร็จ
  Future<String?> activateLicense(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_keyDeviceId) ?? '';

    final payload = LicenseKeyVerifier.verify(
      licenseKey: key.trim(),
      deviceId: deviceId,
    );

    if (payload == null) {
      return 'License Key ไม่ถูกต้องหรือไม่ตรงกับเครื่องนี้';
    }

    final now = await TimeGuardService.getReliableTime();
    if (payload.expireDate.isBefore(now)) {
      return 'License Key หมดอายุแล้ว (หมดอายุวันที่ ${payload.expireDate.toIso8601String().substring(0, 10)})';
    }

    await prefs.setString(_keyLicenseKey, key.trim());
    print('[License] Activated for ${payload.email}, expires ${payload.expireDate}');
    ref.invalidateSelf();
    return null;
  }

  /// ลบ License Key ออก
  Future<void> removeLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLicenseKey);
    ref.invalidateSelf();
  }

  /// คืน Device ID ของเครื่องนี้
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId) ?? '';
  }

  /// คืน first_launch_date เป็น string YYYY-MM-DD
  Future<String?> getFirstLaunchDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFirstLaunchDate);
  }

  /// ซิงค์เวลากับ NTP แล้ว reload status
  Future<void> syncTimeAndRefresh() async {
    await TimeGuardService.syncNtpTime();
    ref.invalidateSelf();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static TrialPhase _phaseForDay(int day) {
    if (day <= 30) return TrialPhase.trial1;
    if (day <= 60) return TrialPhase.trial2;
    if (day <= 90) return TrialPhase.trial3;
    return TrialPhase.expired;
  }
}
