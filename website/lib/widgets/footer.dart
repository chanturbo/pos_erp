import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  static const _navy = Color(0xFF16213E);
  static const _navyDark = Color(0xFF0D1528);
  static const _primary = Color(0xFFE57200);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _navyDark,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 48,
      ),
      child: Column(
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 32),
                    _buildLinks(),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildBrand(), _buildLinks()],
                ),
          const SizedBox(height: 32),
          Divider(color: _navy),
          const SizedBox(height: 20),
          Text(
            '© 2025 DEE POS. All rights reserved.',
            style: GoogleFonts.ibmPlexSansThai(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEE POS',
          style: GoogleFonts.ibmPlexSansThai(
            color: _primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ระบบ POS สำหรับร้านค้าไทย\nใช้งานง่าย ราคาคุ้มค่า',
          style: GoogleFonts.ibmPlexSansThai(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildLinks() {
    return Wrap(
      spacing: 48,
      runSpacing: 24,
      children: [
        _FooterColumn(title: 'ผลิตภัณฑ์', links: ['ฟีเจอร์', 'ราคา', 'อัปเดต']),
        _FooterColumn(title: 'ช่วยเหลือ', links: ['คู่มือการใช้งาน', 'ติดต่อเรา', 'Line Support']),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;
  const _FooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSansThai(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l,
              style: GoogleFonts.ibmPlexSansThai(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
