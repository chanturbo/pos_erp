import 'package:shared_preferences/shared_preferences.dart';

import 'license_models.dart';

const _keyLastShownDay = 'license_notif_last_shown_day';

/// ข้อความแจ้งเตือนที่จะแสดงแก่ผู้ใช้
class LicenseNotice {
  final String title;
  final String body;
  final int price;
  final bool isUrgent; // แสดงด้วยสีแดง/เหลือง

  const LicenseNotice({
    required this.title,
    required this.body,
    required this.price,
    this.isUrgent = false,
  });
}

/// กำหนดตาราง milestone วันที่ต้องแจ้งเตือน (ตามแผนใน docs)
const _milestones = <int, LicenseNotice>{
  1: LicenseNotice(
    title: 'ยินดีต้อนรับ! เริ่มช่วงทดลองใช้',
    body: 'ทดลองใช้ฟรี 3 เดือน — ลงทะเบียนเดือนนี้เพียง 990 บาท',
    price: 990,
  ),
  15: LicenseNotice(
    title: 'เหลืออีก 15 วัน ในราคา 990 บาท',
    body: 'ลงทะเบียนก่อนหมดโปรโมชัน ราคาจะปรับเป็น 1,490 บาท',
    price: 990,
  ),
  25: LicenseNotice(
    title: 'เหลือเพียง 5 วัน! ราคา 990 บาท',
    body: 'หลังจากนี้ราคาจะขึ้นเป็น 1,490 บาท/เดือน',
    price: 990,
    isUrgent: true,
  ),
  31: LicenseNotice(
    title: 'ราคาปรับเป็น 1,490 บาท/เดือน',
    body: 'ยังทดลองใช้ฟรีถึงวันที่ 60 — รีบลงทะเบียนในราคานี้',
    price: 1490,
  ),
  50: LicenseNotice(
    title: 'เหลืออีก 10 วัน ในราคา 1,490 บาท',
    body: 'หลังจากนี้ราคาจะขึ้นเป็น 1,990 บาท/เดือน',
    price: 1490,
  ),
  61: LicenseNotice(
    title: 'ราคาปรับเป็น 1,990 บาท/เดือน',
    body: 'เหลือเวลาทดลองใช้อีก 30 วัน — ลงทะเบียนก่อนราคาเต็ม',
    price: 1990,
  ),
  80: LicenseNotice(
    title: 'เหลือ 10 วัน ก่อนหมดช่วงทดลอง',
    body: 'ลงทะเบียน 1,990 บาท ก่อนราคาเต็ม 4,990 บาท/เดือน',
    price: 1990,
    isUrgent: true,
  ),
  88: LicenseNotice(
    title: 'เหลือเพียง 2 วัน! ก่อนหมดทดลอง',
    body: 'หลังหมดช่วงทดลองราคา 4,990 บาท/เดือน — ลงทะเบียนด่วน!',
    price: 1990,
    isUrgent: true,
  ),
  91: LicenseNotice(
    title: 'หมดช่วงทดลองแล้ว',
    body: 'ลงทะเบียน 4,990 บาท/เดือน เพื่อใช้งานต่อโดยไม่ติดข้อจำกัด',
    price: 4990,
    isUrgent: true,
  ),
};

class LicenseNotificationService {
  /// คืน [LicenseNotice] ที่ควรแสดงตาม [status] ของ license
  /// หรือ null ถ้าไม่มีอะไรต้องแสดง (เช่น แสดงแล้ว หรือ licensed แล้ว)
  static Future<LicenseNotice?> getPendingNotice(LicenseStatus status) async {
    if (status.isLicensed) return null;

    final day = status.daysSinceFirstLaunch;
    final prefs = await SharedPreferences.getInstance();
    final lastShownDay = prefs.getInt(_keyLastShownDay) ?? 0;

    // หาว่า milestone ไหนที่ถึงแล้วและยังไม่ได้แสดง
    final milestone = _currentMilestone(day, lastShownDay);
    return milestone;
  }

  /// บันทึกว่าแสดง notification ของวันนี้แล้ว
  static Future<void> markShown(int currentDay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastShownDay, currentDay);
  }

  /// คืน notice ที่ควรแสดง (ถ้ามี) โดยไม่อัปเดต prefs
  static LicenseNotice? _currentMilestone(int day, int lastShownDay) {
    // วันที่ 91+ → แจ้งทุก 3 วัน
    if (day >= 91) {
      if (day - lastShownDay >= 3) {
        final notice = _milestones[91]!;
        // คำนวณวันที่ผ่านมาหลังหมดทดลอง
        final overdue = day - 90;
        return LicenseNotice(
          title: notice.title,
          body: 'ผ่านมาแล้ว $overdue วันหลังหมดทดลอง — ${notice.body}',
          price: notice.price,
          isUrgent: true,
        );
      }
      return null;
    }

    // หา milestone สูงสุดที่ <= day และยังไม่แสดง
    final candidates = _milestones.entries
        .where((e) => e.key <= day && e.key > lastShownDay)
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return candidates.isEmpty ? null : candidates.first.value;
  }

  /// รีเซ็ต (ใช้ตอน debug / testing)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastShownDay);
  }
}
