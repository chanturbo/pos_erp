import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _primary = Color(0xFF1E88E5);
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final success = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'DEE POS',
          style: GoogleFonts.ibmPlexSansThai(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.point_of_sale, color: _primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'เข้าสู่ระบบ DEE POS',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ใช้ Google Account เพื่อจัดการ\nLicense Key ของคุณ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton(
                          onPressed: _signIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _GoogleLogo(size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'เข้าสู่ระบบด้วย Google',
                                style: GoogleFonts.ibmPlexSansThai(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                Text(
                  '1 บัญชี Google สามารถออก License Key ได้สูงสุด 4 ชุด',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;

    // วาด G ด้วยสี Google สี่สี
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    final paint = Paint()..style = PaintingStyle.fill;

    // Blue arc (top-right)
    paint.color = blue;
    canvas.drawArc(rect, -1.57, 1.57, true, paint);

    // Red arc (bottom-right)
    paint.color = red;
    canvas.drawArc(rect, 0, 1.57, true, paint);

    // Yellow arc (bottom-left)
    paint.color = yellow;
    canvas.drawArc(rect, 1.57, 1.57, true, paint);

    // Green arc (top-left)
    paint.color = green;
    canvas.drawArc(rect, 3.14, 1.57, true, paint);

    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);

    // Blue right bar (แท่งขวาของ G)
    paint.color = blue;
    final barRect = Rect.fromLTWH(center.dx, center.dy - radius * 0.2, radius, radius * 0.4);
    canvas.drawRect(barRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
