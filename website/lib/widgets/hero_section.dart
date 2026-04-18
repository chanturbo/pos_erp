import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  static const _primary = Color(0xFFE57200);
  static const _navy = Color(0xFF16213E);
  static const _navyLight = Color(0xFF1F2E54);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyLight, Color(0xFF2A3A60)],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              '🎉 ทดลองใช้ฟรี 3 เดือน — ไม่ต้องใช้บัตรเครดิต',
              style: GoogleFonts.ibmPlexSansThai(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'ระบบ POS ที่ออกแบบ\nสำหรับร้านค้าไทย',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              color: Colors.white,
              fontSize: isMobile ? 36 : 56,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ใช้งานได้ทุกอุปกรณ์ • ทำงาน Offline ได้ • Backup อัตโนมัติ\nราคาเริ่มต้นเพียง 990 บาท/ปี',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: isMobile ? 16 : 20,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'เริ่มใช้งานฟรี',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'ดูคู่มือการใช้งาน',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 40,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _Stat(value: '1,000+', label: 'ร้านค้าที่ใช้งาน'),
              _Divider(),
              _Stat(value: '99.9%', label: 'Uptime'),
              _Divider(),
              _Stat(value: '4.9★', label: 'คะแนนรีวิว'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexSansThai(
            color: const Color(0xFFE57200),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansThai(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
