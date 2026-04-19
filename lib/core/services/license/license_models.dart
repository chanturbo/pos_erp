import 'dart:convert';

enum TrialPhase {
  trial1, // วันที่ 1–30 → 990 บาท
  trial2, // วันที่ 31–60 → 1,490 บาท
  trial3, // วันที่ 61–90 → 1,990 บาท
  expired, // วันที่ 91+ → 4,990 บาท
}

enum LicenseFeature {
  createEdit, // เพิ่ม / แก้ไข / ลบข้อมูล
  openSale, // ขาย / เปิดบิล
  printReceipt, // พิมพ์ใบเสร็จ
  exportReport, // Export รายงาน
}

class LicensePayload {
  final String email;
  final String deviceId;
  final DateTime expireDate;
  final DateTime issuedAt;

  const LicensePayload({
    required this.email,
    required this.deviceId,
    required this.expireDate,
    required this.issuedAt,
  });

  factory LicensePayload.fromJson(Map<String, dynamic> json) => LicensePayload(
    email: json['email'] as String,
    deviceId: json['device_id'] as String,
    expireDate: DateTime.parse(json['expire_date'] as String),
    issuedAt: DateTime.parse(json['issued_at'] as String),
  );

  factory LicensePayload.fromBase64(String base64Payload) {
    final bytes = base64Url.decode(base64Url.normalize(base64Payload));
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return LicensePayload.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'device_id': deviceId,
    'expire_date': expireDate.toIso8601String().substring(0, 10),
    'issued_at': issuedAt.toIso8601String().substring(0, 10),
  };
}

class LicenseStatus {
  final bool isLicensed;
  final bool isTrialActive;
  final TrialPhase trialPhase;
  final int daysSinceFirstLaunch;
  final DateTime? firstLaunchDate;
  final DateTime? licenseExpireDate;
  final String? licensedEmail;
  final String deviceId;

  const LicenseStatus({
    required this.isLicensed,
    required this.isTrialActive,
    required this.trialPhase,
    required this.daysSinceFirstLaunch,
    required this.deviceId,
    this.firstLaunchDate,
    this.licenseExpireDate,
    this.licensedEmail,
  });

  bool canUseFeature(LicenseFeature feature) {
    if (isLicensed) return true;
    if (isTrialActive) return true;
    // หมดช่วงทดลองและไม่มี license → ล็อคฟีเจอร์ทั้งหมดที่ระบุในแผน
    return false;
  }

  int get currentPrice => switch (trialPhase) {
    TrialPhase.trial1 => 990,
    TrialPhase.trial2 => 1490,
    TrialPhase.trial3 => 1990,
    TrialPhase.expired => 4990,
  };

  String get trialPhaseLabel => switch (trialPhase) {
    TrialPhase.trial1 => 'ทดลองใช้เดือนที่ 1 (990 บาท)',
    TrialPhase.trial2 => 'ทดลองใช้เดือนที่ 2 (1,490 บาท)',
    TrialPhase.trial3 => 'ทดลองใช้เดือนที่ 3 (1,990 บาท)',
    TrialPhase.expired => 'หมดช่วงทดลอง (4,990 บาท/เดือน)',
  };

  int get daysRemainingInPhase => switch (trialPhase) {
    TrialPhase.trial1 => 30 - daysSinceFirstLaunch,
    TrialPhase.trial2 => 60 - daysSinceFirstLaunch,
    TrialPhase.trial3 => 90 - daysSinceFirstLaunch,
    TrialPhase.expired => 0,
  };
}
