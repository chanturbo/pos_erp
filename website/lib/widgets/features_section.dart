import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  static const _navy = Color(0xFF16213E);
  static const _surface = Color(0xFFF4F4F0);
  static const _subtext = Color(0xFF757575);

  static const _features = [
    (
      icon: Icons.point_of_sale,
      title: 'ขายสินค้าได้ทันที',
      desc: 'Barcode scanner, รับเงินสด/QR Code, ออกใบเสร็จได้เลย',
    ),
    (
      icon: Icons.inventory_2,
      title: 'จัดการสต็อก',
      desc: 'ติดตามสินค้าคงเหลือ แจ้งเตือนสินค้าใกล้หมด',
    ),
    (
      icon: Icons.bar_chart,
      title: 'รายงานยอดขาย',
      desc: 'สรุปยอดขายรายวัน รายเดือน วิเคราะห์กำไร-ขาดทุน',
    ),
    (
      icon: Icons.wifi_off,
      title: 'ทำงาน Offline ได้',
      desc: 'ไม่ต้องกลัว Internet ล่ม ข้อมูลเก็บในเครื่อง',
    ),
    (
      icon: Icons.backup,
      title: 'Backup อัตโนมัติ',
      desc: 'สำรองข้อมูลไป Google Drive ทุกวัน ปลอดภัย 100%',
    ),
    (
      icon: Icons.devices,
      title: 'ใช้ได้ทุกอุปกรณ์',
      desc: 'Android, iOS, Windows, Mac รองรับทั้งหมด',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 80,
      ),
      child: Column(
        children: [
          Text(
            'ครบทุกฟีเจอร์ที่ร้านค้าต้องการ',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ออกแบบมาเพื่อร้านค้าไทยโดยเฉพาะ ใช้งานง่าย ไม่ต้องอบรม',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 16,
              color: _subtext,
            ),
          ),
          const SizedBox(height: 56),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: isMobile ? 3.5 : 1.5,
            ),
            itemCount: _features.length,
            itemBuilder: (context, i) => _FeatureCard(feature: _features[i]),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final ({IconData icon, String title, String desc}) feature;
  const _FeatureCard({required this.feature});

  static const _primary = Color(0xFFE57200);
  static const _navy = Color(0xFF16213E);
  static const _border = Color(0xFFE0E0E0);
  static const _subtext = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feature.icon, color: _primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            feature.title,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.desc,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 14,
              color: _subtext,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
