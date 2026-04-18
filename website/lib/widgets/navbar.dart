import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Navbar extends StatelessWidget {
  const Navbar({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DEE POS',
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E88E5),
            ),
          ),
          if (!isMobile)
            Row(
              children: [
                _NavLink(label: 'ฟีเจอร์', anchor: '#features'),
                const SizedBox(width: 32),
                _NavLink(label: 'ราคา', anchor: '#pricing'),
                const SizedBox(width: 32),
                _NavLink(label: 'คู่มือ', anchor: '#docs'),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'ทดลองฟรี 3 เดือน',
                    style: GoogleFonts.ibmPlexSansThai(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final String anchor;

  const _NavLink({required this.label, required this.anchor});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansThai(
          color: const Color(0xFF374151),
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }
}
