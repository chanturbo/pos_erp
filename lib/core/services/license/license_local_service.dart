import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'license_key_verifier.dart';
import 'license_models.dart';
import 'time_guard_service.dart';

const keyLicenseFirstLaunchDate = 'license_first_launch_date';
const keyLicenseDeviceId = 'license_device_id';
const keyLicenseSavedKey = 'license_saved_key';

const _licenseBackupChecksumSecret =
    'dee_pos_license_backup_checksum_v1_20260419';

class LicenseRestrictionException implements Exception {
  final LicenseFeature feature;
  final String message;

  const LicenseRestrictionException(this.feature, this.message);

  @override
  String toString() => message;
}

class LicenseBackupMetadata {
  final String firstLaunchDate;
  final String deviceId;
  final String checksum;
  final String? licensedEmail;

  const LicenseBackupMetadata({
    required this.firstLaunchDate,
    required this.deviceId,
    required this.checksum,
    this.licensedEmail,
  });

  Map<String, dynamic> toJson() => {
        'first_launch_date': firstLaunchDate,
        'device_id': deviceId,
        'checksum': checksum,
        'licensed_email': licensedEmail,
      };

  factory LicenseBackupMetadata.fromJson(Map<String, dynamic> json) {
    return LicenseBackupMetadata(
      firstLaunchDate: json['first_launch_date'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
      licensedEmail: json['licensed_email'] as String?,
    );
  }
}

class LicenseLocalService {
  LicenseLocalService._();

  static Future<LicenseStatus> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = await ensureIdentity(prefs: prefs);
    final firstLaunchDate = DateTime.parse(identity.firstLaunchDate);
    final now = await TimeGuardService.getReliableTime();
    final days = now.difference(firstLaunchDate).inDays + 1;
    final phase = _phaseForDay(days);
    final isTrialActive = phase != TrialPhase.expired;

    final savedKey = prefs.getString(keyLicenseSavedKey);
    LicensePayload? payload;
    if (savedKey != null) {
      payload = LicenseKeyVerifier.verify(
        licenseKey: savedKey,
        deviceId: identity.deviceId,
      );
      if (payload == null) {
        await prefs.remove(keyLicenseSavedKey);
      }
    }

    final isLicensed = payload != null && payload.expireDate.isAfter(now);

    return LicenseStatus(
      isLicensed: isLicensed,
      isTrialActive: isTrialActive,
      trialPhase: phase,
      daysSinceFirstLaunch: days,
      firstLaunchDate: firstLaunchDate,
      licenseExpireDate: payload?.expireDate,
      licensedEmail: payload?.email,
      deviceId: identity.deviceId,
    );
  }

  static Future<void> ensureFeatureAllowed(LicenseFeature feature) async {
    final status = await loadStatus();
    if (status.canUseFeature(feature)) return;
    throw LicenseRestrictionException(feature, featureLockedMessage(feature));
  }

  static String featureLockedMessage(LicenseFeature feature) {
    switch (feature) {
      case LicenseFeature.createEdit:
        return 'หมดช่วงทดลองแล้ว ต้องมี License ก่อนเพิ่ม แก้ไข หรือลบข้อมูล';
      case LicenseFeature.openSale:
        return 'หมดช่วงทดลองแล้ว ต้องมี License ก่อนเปิดบิลหรือขายสินค้า';
      case LicenseFeature.printReceipt:
        return 'หมดช่วงทดลองแล้ว ต้องมี License ก่อนพิมพ์ใบเสร็จ';
      case LicenseFeature.exportReport:
        return 'หมดช่วงทดลองแล้ว ต้องมี License ก่อนส่งออกรายงาน';
    }
  }

  static Future<LicenseIdentitySnapshot> ensureIdentity({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    var deviceId = resolvedPrefs.getString(keyLicenseDeviceId);
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await resolvedPrefs.setString(keyLicenseDeviceId, deviceId);
    }

    var firstLaunchDate = resolvedPrefs.getString(keyLicenseFirstLaunchDate);
    if (firstLaunchDate == null || firstLaunchDate.trim().isEmpty) {
      final reliable = await TimeGuardService.getReliableTime();
      firstLaunchDate = reliable.toIso8601String().substring(0, 10);
      await resolvedPrefs.setString(keyLicenseFirstLaunchDate, firstLaunchDate);
    }

    return LicenseIdentitySnapshot(
      deviceId: deviceId,
      firstLaunchDate: firstLaunchDate,
    );
  }

  static Future<LicenseBackupMetadata> buildBackupMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = await ensureIdentity(prefs: prefs);
    final status = await loadStatus();
    final licensedEmail = status.licensedEmail?.trim();
    final checksum = _buildChecksum(
      licensedEmail: licensedEmail,
      deviceId: identity.deviceId,
      firstLaunchDate: identity.firstLaunchDate,
    );

    return LicenseBackupMetadata(
      firstLaunchDate: identity.firstLaunchDate,
      deviceId: identity.deviceId,
      checksum: checksum,
      licensedEmail: licensedEmail?.isEmpty == true ? null : licensedEmail,
    );
  }

  static Future<void> restoreBackupMetadata(
    LicenseBackupMetadata metadata,
  ) async {
    if (metadata.firstLaunchDate.trim().isEmpty ||
        metadata.deviceId.trim().isEmpty ||
        metadata.checksum.trim().isEmpty) {
      throw const LicenseRestrictionException(
        LicenseFeature.createEdit,
        'license metadata ใน backup ไม่ครบ',
      );
    }

    final expected = _buildChecksum(
      licensedEmail: metadata.licensedEmail,
      deviceId: metadata.deviceId,
      firstLaunchDate: metadata.firstLaunchDate,
    );
    if (expected != metadata.checksum) {
      throw const LicenseRestrictionException(
        LicenseFeature.createEdit,
        'checksum ของ license metadata ไม่ถูกต้อง',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLicenseFirstLaunchDate, metadata.firstLaunchDate);
    await prefs.setString(keyLicenseDeviceId, metadata.deviceId);
  }

  static TrialPhase _phaseForDay(int day) {
    if (day <= 30) return TrialPhase.trial1;
    if (day <= 60) return TrialPhase.trial2;
    if (day <= 90) return TrialPhase.trial3;
    return TrialPhase.expired;
  }

  static String _buildChecksum({
    required String? licensedEmail,
    required String deviceId,
    required String firstLaunchDate,
  }) {
    final payload =
        '${licensedEmail?.trim() ?? ''}|$deviceId|$firstLaunchDate|$_licenseBackupChecksumSecret';
    return sha256.convert(utf8.encode(payload)).toString();
  }
}

class LicenseIdentitySnapshot {
  final String deviceId;
  final String firstLaunchDate;

  const LicenseIdentitySnapshot({
    required this.deviceId,
    required this.firstLaunchDate,
  });
}
