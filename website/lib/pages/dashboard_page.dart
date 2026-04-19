import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _primary = Color(0xFF1E88E5);
  static const _maxKeys = 4;

  // TODO: แทนที่ด้วยข้อมูลจาก PHP API
  final List<Map<String, dynamic>> _keys = [];
  bool _loading = false;

  Future<void> _generateKey() async {
    if (_keys.length >= _maxKeys) return;
    setState(() => _loading = true);

    // TODO: เรียก PHP API เพื่อ sign key จริง
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _keys.add({
        'key': 'DEEPOS-XXXX-XXXX-XXXX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'device': 'รอการเปิดใช้งาน',
        'activated_at': null,
        'is_active': false,
      });
      _loading = false;
    });
  }

  Future<void> _revokeKey(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการยกเลิก Key', style: GoogleFonts.ibmPlexSansThai()),
        content: Text('Key นี้จะถูกปิดใช้งานทันที', style: GoogleFonts.ibmPlexSansThai()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก', style: GoogleFonts.ibmPlexSansThai())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ยืนยัน', style: GoogleFonts.ibmPlexSansThai(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _keys[index]['is_active'] = false);
      // TODO: เรียก PHP API revoke key
    }
  }

  void _copyKey(String key) {
    Clipboard.setData(ClipboardData(text: key));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('คัดลอก Key แล้ว', style: GoogleFonts.ibmPlexSansThai()),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 18, color: Color(0xFF6B7280)),
              label: Text(
                'ออกจากระบบ',
                style: GoogleFonts.ibmPlexSansThai(color: const Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserCard(user: user),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'License Keys (${_keys.length}/$_maxKeys)',
                  action: _keys.length < _maxKeys
                      ? ElevatedButton.icon(
                          onPressed: _loading ? null : _generateKey,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: Text('ออก Key ใหม่', style: GoogleFonts.ibmPlexSansThai(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      : Tooltip(
                          message: 'ครบ 4 Key แล้ว — ยกเลิก Key เก่าก่อน',
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.block, size: 18),
                            label: Text('ครบ 4 Key แล้ว', style: GoogleFonts.ibmPlexSansThai()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E7EB),
                              foregroundColor: const Color(0xFF9CA3AF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (_keys.isEmpty)
                  _EmptyKeyState(onGenerate: _generateKey)
                else
                  ...List.generate(
                    _keys.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _KeyCard(
                        keyData: _keys[i],
                        index: i + 1,
                        onCopy: () => _copyKey(_keys[i]['key']),
                        onRevoke: () => _revokeKey(i),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                _PricingReminderCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final dynamic user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            backgroundColor: const Color(0xFF1E88E5),
            child: user?.photoUrl == null
                ? Text(
                    (user?.displayName ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.ibmPlexSansThai(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'ผู้ใช้งาน',
                  style: GoogleFonts.ibmPlexSansThai(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.ibmPlexSansThai(fontSize: 13, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ทดลองใช้งาน',
              style: GoogleFonts.ibmPlexSansThai(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget action;
  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSansThai(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
        ),
        action,
      ],
    );
  }
}

class _KeyCard extends StatelessWidget {
  final Map<String, dynamic> keyData;
  final int index;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;
  const _KeyCard({required this.keyData, required this.index, required this.onCopy, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final isActive = keyData['is_active'] as bool;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? const Color(0xFF1E88E5) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Key #$index',
                style: GoogleFonts.ibmPlexSansThai(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF374151)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'ใช้งานอยู่' : 'รอเปิดใช้งาน',
                  style: GoogleFonts.ibmPlexSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    keyData['key'],
                    style: GoogleFonts.sourceCodePro(fontSize: 13, color: const Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(Icons.copy, size: 16, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.devices, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                keyData['device'],
                style: GoogleFonts.ibmPlexSansThai(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
              const Spacer(),
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: Text('ยกเลิก Key', style: GoogleFonts.ibmPlexSansThai(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyKeyState extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyKeyState({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.vpn_key_outlined, size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มี License Key',
            style: GoogleFonts.ibmPlexSansThai(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            'กด "ออก Key ใหม่" เพื่อรับ License Key\nสำหรับติดตั้งบนอุปกรณ์ของคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansThai(fontSize: 13, color: const Color(0xFF6B7280), height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _PricingReminderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ทดลองใช้ฟรี 3 เดือน',
            style: GoogleFonts.ibmPlexSansThai(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _PriceRow(label: 'เดือนที่ 1', price: '990 บาท'),
          _PriceRow(label: 'เดือนที่ 2', price: '1,490 บาท'),
          _PriceRow(label: 'เดือนที่ 3', price: '1,990 บาท'),
          _PriceRow(label: 'หลังจากนั้น', price: '4,990 บาท/เดือน'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E88E5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'ลงทะเบียนตอนนี้',
                style: GoogleFonts.ibmPlexSansThai(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String price;
  const _PriceRow({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSansThai(fontSize: 13, color: Colors.white70)),
          Text(price, style: GoogleFonts.ibmPlexSansThai(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
