// ignore_for_file: avoid_print
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ป้องกันการย้อนนาฬิกาเพื่อโกงช่วงทดลองใช้
///
/// หลักการ:
/// - เมื่อมีเน็ต ดึงเวลาจาก worldtimeapi.org แล้วเก็บคู่ (ntp_time, device_time)
/// - เมื่อ offline ประมาณเวลาจริงด้วย: real_time ≈ last_ntp + (device_now - last_device)
/// - ถ้า device_now < last_device_time → ตรวจพบว่าย้อนนาฬิกา
class TimeGuardService {
  static const _keyLastNtpTime = 'tg_last_ntp_time';
  static const _keyLastDeviceTime = 'tg_last_device_time';
  static const _ntpUrl = 'https://worldtimeapi.org/api/timezone/Asia/Bangkok';

  /// ซิงค์เวลากับ NTP server — เรียกตอน app เปิด (ถ้ามีเน็ต)
  static Future<void> syncNtpTime() async {
    try {
      final dio = Dio();
      final resp = await dio.get<Map<String, dynamic>>(
        _ntpUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      final utcStr = resp.data?['utc_datetime'] as String?;
      if (utcStr == null) return;

      final ntpTime = DateTime.parse(utcStr).toLocal();
      final deviceTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastNtpTime, ntpTime.toIso8601String());
      await prefs.setString(_keyLastDeviceTime, deviceTime.toIso8601String());
      print('[TimeGuard] NTP synced: $ntpTime (device: $deviceTime)');
    } catch (e) {
      print('[TimeGuard] NTP sync skipped (offline?): $e');
    }
  }

  /// คืนเวลาที่น่าเชื่อถือ (รวม offset จากครั้งล่าสุดที่ sync)
  static Future<DateTime> getReliableTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNtpStr = prefs.getString(_keyLastNtpTime);
    final lastDeviceStr = prefs.getString(_keyLastDeviceTime);

    if (lastNtpStr == null || lastDeviceStr == null) {
      return DateTime.now();
    }

    final lastNtp = DateTime.parse(lastNtpStr);
    final lastDevice = DateTime.parse(lastDeviceStr);
    final deviceNow = DateTime.now();

    // ถ้า device_now < last_device → ย้อนนาฬิกา → ใช้เวลา NTP ที่เก็บไว้
    if (deviceNow.isBefore(lastDevice.subtract(const Duration(minutes: 2)))) {
      print('[TimeGuard] Clock rollback detected! Using last NTP time.');
      return lastNtp;
    }

    final elapsed = deviceNow.difference(lastDevice);
    return lastNtp.add(elapsed);
  }

  /// ตรวจจับการย้อนนาฬิกา
  static Future<bool> isClockRolledBack() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceStr = prefs.getString(_keyLastDeviceTime);
    if (lastDeviceStr == null) return false;

    final lastDevice = DateTime.parse(lastDeviceStr);
    return DateTime.now().isBefore(
      lastDevice.subtract(const Duration(minutes: 2)),
    );
  }
}
