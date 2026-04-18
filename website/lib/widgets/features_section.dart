import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

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
      color: const Color(0xFFF8FAFC),
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
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ออกแบบมาเพื่อร้านค้าไทยโดยเฉพาะ ใช้งานง่าย ไม่ต้องอบรม',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 16,
              color: const Color(0xFF6B7280),
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
              childAspectRatio: isMobile ? 3 : 1.4,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feature.icon, color: const Color(0xFF1E88E5), size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            feature.title,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.desc,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
