import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_key_verifier.dart';
import 'license_local_service.dart';
import 'license_models.dart';
import 'time_guard_service.dart';
import 'package:flutter/foundation.dart';

final licenseServiceProvider =
    AsyncNotifierProvider<LicenseService, LicenseStatus>(LicenseService.new);

class LicenseService extends AsyncNotifier<LicenseStatus> {
  @override
  Future<LicenseStatus> build() => LicenseLocalService.loadStatus();

  // ── Public API ────────────────────────────────────────────────────────────

  /// ลงทะเบียน License Key
  /// คืน error message (Thai) หรือ null ถ้าสำเร็จ
  Future<String?> activateLicense(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final identity = await LicenseLocalService.ensureIdentity(prefs: prefs);

    final payload = LicenseKeyVerifier.verify(
      licenseKey: key.trim(),
      deviceId: identity.deviceId,
    );

    if (payload == null) {
      return 'License Key ไม่ถูกต้องหรือไม่ตรงกับเครื่องนี้';
    }

    final now = await TimeGuardService.getReliableTime();
    if (payload.expireDate.isBefore(now)) {
      return 'License Key หมดอายุแล้ว (หมดอายุวันที่ ${payload.expireDate.toIso8601String().substring(0, 10)})';
    }

    await prefs.setString(keyLicenseSavedKey, key.trim());
    if (kDebugMode) {
      debugPrint('[License] Activated for ${payload.email}, expires ${payload.expireDate}');
    }
    ref.invalidateSelf();
    return null;
  }

  /// ลบ License Key ออก
  Future<void> removeLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLicenseSavedKey);
    ref.invalidateSelf();
  }

  /// คืน Device ID ของเครื่องนี้
  Future<String> getDeviceId() async {
    final identity = await LicenseLocalService.ensureIdentity();
    return identity.deviceId;
  }

  /// คืน first_launch_date เป็น string YYYY-MM-DD
  Future<String?> getFirstLaunchDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLicenseFirstLaunchDate);
  }

  /// ซิงค์เวลากับ NTP แล้ว reload status
  Future<void> syncTimeAndRefresh() async {
    await TimeGuardService.syncNtpTime();
    ref.invalidateSelf();
  }
}
