import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEE POS',
                    style: GoogleFonts.ibmPlexSansThai(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ระบบ POS สำหรับร้านค้าไทย\nใช้งานง่าย ราคาคุ้มค่า',
                    style: GoogleFonts.ibmPlexSansThai(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 48,
                children: [
                  _FooterColumn(title: 'ผลิตภัณฑ์', links: ['ฟีเจอร์', 'ราคา', 'อัปเดต']),
                  _FooterColumn(title: 'ช่วยเหลือ', links: ['คู่มือการใช้งาน', 'ติดต่อเรา', 'Line Support']),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF374151)),
          const SizedBox(height: 20),
          Text(
            '© 2025 DEE POS. All rights reserved.',
            style: GoogleFonts.ibmPlexSansThai(
              color: const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ],
      ),
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
                color: const Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
