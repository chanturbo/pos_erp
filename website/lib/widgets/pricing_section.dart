import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingSection extends StatelessWidget {
  const PricingSection({super.key});

  static const _plans = [
    (label: 'Founder Price', badge: 'เดือนที่ 1', price: '990',   discount: 'ประหยัด 80%', color: Color(0xFF7C3AED), highlight: false),
    (label: 'Early Bird',    badge: 'เดือนที่ 2', price: '1,490', discount: 'ประหยัด 70%', color: Color(0xFF1E88E5), highlight: true),
    (label: 'Beta Price',    badge: 'เดือนที่ 3', price: '1,990', discount: 'ประหยัด 60%', color: Color(0xFF059669), highlight: false),
    (label: 'ราคาปกติ',      badge: 'หลังจากนั้น', price: '4,990', discount: '',            color: Color(0xFF374151), highlight: false),
  ];

  static const _features = [
    'ขายสินค้าไม่จำกัด', 'จัดการสต็อกสินค้า', 'รายงานยอดขาย',
    'Backup Google Drive', 'ใช้ได้ทุกอุปกรณ์', 'อัปเดตฟรีตลอดปี', 'Support ทาง Line',
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 80,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⏰ ราคา Early Adopter — จำกัดเวลา',
              style: GoogleFonts.ibmPlexSansThai(
                color: const Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ราคาที่ดีที่สุด\nสำหรับผู้ใช้คนแรก ๆ',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: isMobile ? 28 : 40,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ทดลองใช้ฟรี 3 เดือน • ลงทะเบียนช่วงไหนได้ราคานั้น • ต่ออายุราคาเดิม',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(fontSize: 15, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: _plans.map((p) => _PriceCard(plan: p)).toList(),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Text(
                  'ทุกแพ็กเกจรวมถึง',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _features.map((f) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 6),
                      Text(f, style: GoogleFonts.ibmPlexSansThai(fontSize: 14, color: const Color(0xFF374151))),
                    ],
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final ({String label, String badge, String price, String discount, Color color, bool highlight}) plan;
  const _PriceCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: plan.highlight ? plan.color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.highlight ? plan.color : const Color(0xFFE5E7EB),
          width: plan.highlight ? 2 : 1,
        ),
        boxShadow: plan.highlight
            ? [BoxShadow(color: plan.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: plan.highlight
                  ? Colors.white.withValues(alpha: 0.2)
                  : plan.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              plan.badge,
              style: GoogleFonts.ibmPlexSansThai(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: plan.highlight ? Colors.white : plan.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plan.label,
            style: GoogleFonts.ibmPlexSansThai(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: plan.highlight ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${plan.price}',
                style: GoogleFonts.ibmPlexSansThai(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: plan.highlight ? Colors.white : plan.color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ปี',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 14,
                    color: plan.highlight ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          if (plan.discount.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.discount,
              style: GoogleFonts.ibmPlexSansThai(
                fontSize: 12,
                color: plan.highlight ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: plan.highlight ? Colors.white : plan.color,
                foregroundColor: plan.highlight ? plan.color : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                'เริ่มใช้งาน',
                style: GoogleFonts.ibmPlexSansThai(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
