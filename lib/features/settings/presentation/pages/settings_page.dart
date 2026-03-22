// ignore_for_file: avoid_print
// lib/features/settings/presentation/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import '../../../../shared/theme/theme_provider.dart';


// ─────────────────────────────────────────────────────────────────
// SettingsState
// ─────────────────────────────────────────────────────────────────
class SettingsState {
  final String companyName;
  final String taxId;
  final String address;
  final String phone;
  final double vatRate;
  final bool enableVat;
  final bool enableLowStockAlert;
  final int lowStockThreshold;
  // ✅ Loyalty Points
  final bool enableLoyalty;
  final double pointsPerBaht;   // ทุกกี่บาท ได้ 1 แต้ม
  final double pointValue;      // 1 แต้ม = กี่บาท (สำหรับแลก)

  SettingsState({
    this.companyName          = 'บริษัท ทดสอบ POS จำกัด',
    this.taxId                = '1234567890123',
    this.address              = '123 ถนนทดสอบ กรุงเทพฯ 10100',
    this.phone                = '02-123-4567',
    this.vatRate              = 7.0,
    this.enableVat            = false,
    this.enableLowStockAlert  = true,
    this.lowStockThreshold    = 10,
    this.enableLoyalty        = true,
    this.pointsPerBaht        = 100.0,
    this.pointValue           = 1.0,
  });

  SettingsState copyWith({
    String? companyName,
    String? taxId,
    String? address,
    String? phone,
    double? vatRate,
    bool?   enableVat,
    bool?   enableLowStockAlert,
    int?    lowStockThreshold,
    bool?   enableLoyalty,
    double? pointsPerBaht,
    double? pointValue,
  }) {
    return SettingsState(
      companyName:         companyName         ?? this.companyName,
      taxId:               taxId               ?? this.taxId,
      address:             address             ?? this.address,
      phone:               phone               ?? this.phone,
      vatRate:             vatRate             ?? this.vatRate,
      enableVat:           enableVat           ?? this.enableVat,
      enableLowStockAlert: enableLowStockAlert ?? this.enableLowStockAlert,
      lowStockThreshold:   lowStockThreshold   ?? this.lowStockThreshold,
      enableLoyalty:       enableLoyalty       ?? this.enableLoyalty,
      pointsPerBaht:       pointsPerBaht       ?? this.pointsPerBaht,
      pointValue:          pointValue          ?? this.pointValue,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SettingsNotifier
// ─────────────────────────────────────────────────────────────────
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      companyName:         prefs.getString('company_name'),
      taxId:               prefs.getString('tax_id'),
      address:             prefs.getString('address'),
      phone:               prefs.getString('phone'),
      vatRate:             prefs.getDouble('vat_rate'),
      enableVat:           prefs.getBool('enable_vat'),
      enableLowStockAlert: prefs.getBool('enable_low_stock_alert'),
      lowStockThreshold:   prefs.getInt('low_stock_threshold'),
      enableLoyalty:       prefs.getBool('enable_loyalty'),
      pointsPerBaht:       prefs.getDouble('points_per_baht'),
      pointValue:          prefs.getDouble('point_value'),
    );
  }

  Future<void> updateCompanyInfo({
    String? companyName, String? taxId,
    String? address,    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (companyName != null) await prefs.setString('company_name', companyName);
    if (taxId       != null) await prefs.setString('tax_id', taxId);
    if (address     != null) await prefs.setString('address', address);
    if (phone       != null) await prefs.setString('phone', phone);
    state = state.copyWith(companyName: companyName, taxId: taxId,
        address: address, phone: phone);
  }

  Future<void> updateVatSettings({double? vatRate, bool? enableVat}) async {
    final prefs = await SharedPreferences.getInstance();
    if (vatRate   != null) await prefs.setDouble('vat_rate', vatRate);
    if (enableVat != null) await prefs.setBool('enable_vat', enableVat);
    state = state.copyWith(vatRate: vatRate, enableVat: enableVat);
  }

  Future<void> updateStockSettings({
    bool? enableLowStockAlert, int? lowStockThreshold,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enableLowStockAlert != null) {
      await prefs.setBool('enable_low_stock_alert', enableLowStockAlert);
    }
    if (lowStockThreshold != null) {
      await prefs.setInt('low_stock_threshold', lowStockThreshold);
    }
    state = state.copyWith(
      enableLowStockAlert: enableLowStockAlert,
      lowStockThreshold:   lowStockThreshold,
    );
  }

  // ✅ Loyalty Points
  Future<void> updateLoyaltySettings({
    bool?   enableLoyalty,
    double? pointsPerBaht,
    double? pointValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enableLoyalty != null) await prefs.setBool('enable_loyalty', enableLoyalty);
    if (pointsPerBaht != null) await prefs.setDouble('points_per_baht', pointsPerBaht);
    if (pointValue    != null) await prefs.setDouble('point_value', pointValue);
    state = state.copyWith(
      enableLoyalty: enableLoyalty,
      pointsPerBaht: pointsPerBaht,
      pointValue:    pointValue,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

// ─────────────────────────────────────────────────────────────────
// SettingsPage
// ─────────────────────────────────────────────────────────────────
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _taxIdController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _vatRateController;
  late TextEditingController _lowStockThresholdController;
  late TextEditingController _pointsPerBahtController;
  late TextEditingController _pointValueController;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _companyNameController       = TextEditingController(text: s.companyName);
    _taxIdController             = TextEditingController(text: s.taxId);
    _addressController           = TextEditingController(text: s.address);
    _phoneController             = TextEditingController(text: s.phone);
    _vatRateController           = TextEditingController(text: s.vatRate.toString());
    _lowStockThresholdController = TextEditingController(text: s.lowStockThreshold.toString());
    _pointsPerBahtController     = TextEditingController(text: s.pointsPerBaht.toStringAsFixed(0));
    _pointValueController        = TextEditingController(text: s.pointValue.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _vatRateController.dispose();
    _lowStockThresholdController.dispose();
    _pointsPerBahtController.dispose();
    _pointValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings   = ref.watch(settingsProvider);
    final themeMode  = ref.watch(themeModeProvider);
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar (เหมือน customer_list_page) ──────────────────
          _SettingsTopBar(isDark: isDark),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ══════════════════════════════════════════
                  // 🌙 การแสดงผล
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'การแสดงผล',
                    icon: Icons.palette_outlined,
                    isDark: isDark,
                    child: _buildThemeModeSelector(themeMode, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 🏢 ข้อมูลบริษัท
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ข้อมูลบริษัท',
                    icon: Icons.business_outlined,
                    isDark: isDark,
                    child: _buildCompanySection(isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 💰 ตั้งค่า VAT
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ตั้งค่า VAT',
                    icon: Icons.receipt_long_outlined,
                    isDark: isDark,
                    child: _buildVatSection(settings, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 📦 ตั้งค่าสต๊อก
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ตั้งค่าสต๊อก',
                    icon: Icons.inventory_2_outlined,
                    isDark: isDark,
                    child: _buildStockSection(settings, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 🎁 ตั้งค่าสะสมแต้มสมาชิก
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ระบบสะสมแต้มสมาชิก',
                    icon: Icons.card_membership_outlined,
                    isDark: isDark,
                    child: _buildLoyaltySection(settings, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // ⌨️ ปุ่มลัด
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ปุ่มลัด (Keyboard Shortcuts)',
                    icon: Icons.keyboard_outlined,
                    isDark: isDark,
                    child: _buildShortcutsSection(isDark),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Theme Mode Selector
  // ─────────────────────────────────────────────────────────────
  Widget _buildThemeModeSelector(ThemeMode currentMode, bool isDark) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('โหมดมืด (Dark Mode)',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500)),
          subtitle: Text(
            currentMode == ThemeMode.system
                ? 'ปัจจุบัน: ตามระบบ'
                : currentMode == ThemeMode.dark
                    ? 'ปัจจุบัน: มืด'
                    : 'ปัจจุบัน: สว่าง',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          secondary: Icon(
            currentMode == ThemeMode.dark
                ? Icons.dark_mode
                : currentMode == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
            color: AppTheme.primary,
          ),
          value: currentMode == ThemeMode.dark,
          activeColor: AppTheme.primary,
          onChanged: (isDark) {
            ref.read(themeModeProvider.notifier).toggleDarkMode(isDark);
          },
        ),
        const SizedBox(height: 12),
        Text('เลือกธีม',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppTheme.textSub)),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 18), label: Text('สว่าง')),
            ButtonSegment(value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 18), label: Text('มืด')),
            ButtonSegment(value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 18), label: Text('ตามระบบ')),
          ],
          selected: {currentMode},
          onSelectionChanged: (modes) {
            ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
          },
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Company Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildCompanySection(bool isDark) {
    final style = _inputStyle(isDark);
    return Column(
      children: [
        _field(_companyNameController, 'ชื่อบริษัท', Icons.business, style),
        const SizedBox(height: 12),
        _field(_taxIdController, 'เลขประจำตัวผู้เสียภาษี', Icons.numbers, style),
        const SizedBox(height: 12),
        _field(_addressController, 'ที่อยู่', Icons.location_on, style, maxLines: 2),
        const SizedBox(height: 12),
        _field(_phoneController, 'เบอร์โทรศัพท์', Icons.phone, style),
        const SizedBox(height: 16),
        _saveButton(
          label: 'บันทึกข้อมูลบริษัท',
          icon: Icons.save_outlined,
          onPressed: () async {
            await ref.read(settingsProvider.notifier).updateCompanyInfo(
              companyName: _companyNameController.text,
              taxId:       _taxIdController.text,
              address:     _addressController.text,
              phone:       _phoneController.text,
            );
            if (mounted) _showSuccess('บันทึกข้อมูลบริษัทสำเร็จ');
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VAT Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildVatSection(SettingsState settings, bool isDark) {
    final style = _inputStyle(isDark);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('เปิดใช้งาน VAT',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500)),
          subtitle: Text('คำนวณภาษีมูลค่าเพิ่มในใบเสร็จ',
              style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub)),
          value: settings.enableVat,
          activeColor: AppTheme.primary,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).updateVatSettings(enableVat: v),
        ),
        if (settings.enableVat) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _vatRateController,
            decoration: style.copyWith(
              labelText: 'อัตรา VAT',
              suffixText: '%',
              prefixIcon: const Icon(Icons.percent),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 12),
          _saveButton(
            label: 'บันทึกการตั้งค่า VAT',
            icon: Icons.save_outlined,
            onPressed: () async {
              final v = double.tryParse(_vatRateController.text);
              if (v != null) {
                await ref.read(settingsProvider.notifier)
                    .updateVatSettings(vatRate: v);
                if (mounted) _showSuccess('บันทึกการตั้งค่า VAT สำเร็จ');
              }
            },
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stock Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildStockSection(SettingsState settings, bool isDark) {
    final style = _inputStyle(isDark);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('แจ้งเตือนสต๊อกต่ำ',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500)),
          subtitle: Text('แสดงการแจ้งเตือนเมื่อสต๊อกต่ำกว่าที่กำหนด',
              style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub)),
          value: settings.enableLowStockAlert,
          activeColor: AppTheme.primary,
          onChanged: (v) => ref.read(settingsProvider.notifier)
              .updateStockSettings(enableLowStockAlert: v),
        ),
        if (settings.enableLowStockAlert) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _lowStockThresholdController,
            decoration: style.copyWith(
              labelText: 'จำนวนสต๊อกต่ำสุด',
              helperText: 'แจ้งเตือนเมื่อสต๊อกต่ำกว่าจำนวนนี้',
              prefixIcon: const Icon(Icons.warning_amber_outlined),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 12),
          _saveButton(
            label: 'บันทึกการตั้งค่าสต๊อก',
            icon: Icons.save_outlined,
            onPressed: () async {
              final v = int.tryParse(_lowStockThresholdController.text);
              if (v != null) {
                await ref.read(settingsProvider.notifier)
                    .updateStockSettings(lowStockThreshold: v);
                if (mounted) _showSuccess('บันทึกการตั้งค่าสต๊อกสำเร็จ');
              }
            },
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ Loyalty Points Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoyaltySection(SettingsState settings, bool isDark) {
    final style = _inputStyle(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('เปิดใช้งานระบบสะสมแต้ม',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500)),
          subtitle: Text('สะสมแต้มสำหรับลูกค้าที่มีรหัสสมาชิก',
              style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub)),
          secondary: Icon(Icons.star_outline, color: AppTheme.primary),
          value: settings.enableLoyalty,
          activeColor: AppTheme.primary,
          onChanged: (v) => ref.read(settingsProvider.notifier)
              .updateLoyaltySettings(enableLoyalty: v),
        ),

        if (settings.enableLoyalty) ...[
          const SizedBox(height: 16),

          // Preview chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ทุก ฿${settings.pointsPerBaht.toStringAsFixed(0)} ได้ 1 แต้ม  '
                    '•  1 แต้ม = ฿${settings.pointValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Row: pointsPerBaht + pointValue ──────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ทุกกี่บาท ได้ 1 แต้ม',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : AppTheme.textSub)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pointsPerBahtController,
                      decoration: style.copyWith(
                        labelText: 'บาท / 1 แต้ม',
                        prefixIcon: const Icon(Icons.currency_exchange),
                        suffixText: '฿',
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1 แต้ม มูลค่ากี่บาท (แลกส่วนลด)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : AppTheme.textSub)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pointValueController,
                      decoration: style.copyWith(
                        labelText: 'มูลค่า / แต้ม',
                        prefixIcon: const Icon(Icons.star_outline),
                        suffixText: '฿',
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quick preset chips ────────────────────────────────────
          Text('ตัวอย่างค่าที่นิยมใช้',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppTheme.textSub)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('ทุก 10฿ = 1 แต้ม',   10,   1,   isDark),
              _presetChip('ทุก 20฿ = 1 แต้ม',   20,   1,   isDark),
              _presetChip('ทุก 50฿ = 1 แต้ม',   50,   1,   isDark),
              _presetChip('ทุก 100฿ = 1 แต้ม',  100,  1,   isDark),
              _presetChip('ทุก 100฿ = 1 แต้ม (1฿)', 100, 1, isDark),
            ],
          ),
          const SizedBox(height: 16),
          _saveButton(
            label: 'บันทึกการตั้งค่าสะสมแต้ม',
            icon: Icons.save_outlined,
            onPressed: () async {
              final ppb = double.tryParse(_pointsPerBahtController.text);
              final pv  = double.tryParse(_pointValueController.text);
              if (ppb != null && pv != null && ppb > 0) {
                await ref.read(settingsProvider.notifier).updateLoyaltySettings(
                  pointsPerBaht: ppb,
                  pointValue:    pv,
                );
                if (mounted) _showSuccess('บันทึกการตั้งค่าสะสมแต้มสำเร็จ');
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _presetChip(String label, double ppb, double pv, bool isDark) {
    return ActionChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87)),
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : AppTheme.headerBg,
      side: BorderSide(color: isDark ? Colors.white24 : AppTheme.border),
      onPressed: () {
        setState(() {
          _pointsPerBahtController.text = ppb.toStringAsFixed(0);
          _pointValueController.text    = pv.toStringAsFixed(2);
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Shortcuts Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildShortcutsSection(bool isDark) {
    const shortcuts = [
      ('F1',  'เปิดหน้าจุดขาย (POS)'),
      ('F2',  'เปิดหน้าจัดการสินค้า'),
      ('F3',  'เปิดหน้าจัดการลูกค้า'),
      ('F4',  'เปิดหน้าประวัติการขาย'),
      ('F5',  'รีเฟรชหน้า'),
      ('F6',  'เปิดหน้าคลังสินค้า'),
      ('F7',  'เปิดหน้ารายงาน'),
      ('F10', 'เปิดหน้า Dashboard'),
      ('ESC', 'ยกเลิก/ปิด'),
    ];
    return Column(
      children: shortcuts.map((s) => _shortcutRow(s.$1, s.$2, isDark)).toList(),
    );
  }

  Widget _shortcutRow(String key, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : AppTheme.headerBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark ? Colors.white24 : AppTheme.border),
            ),
            child: Text(key,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(desc,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  InputDecoration _inputStyle(bool isDark) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white24 : AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white24 : AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
    InputDecoration baseStyle, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: baseStyle.copyWith(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
      ),
    );
  }

  Widget _saveButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
// _SettingsTopBar — เหมือน customer_list_page style
// ─────────────────────────────────────────────────────────────────
class _SettingsTopBar extends StatelessWidget {
  final bool isDark;
  const _SettingsTopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // ── Title ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_outlined,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ตั้งค่าระบบ',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.navy)),
              Text('จัดการการตั้งค่าทั้งหมด',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : AppTheme.textSub)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _SectionCard — card wrapper สำหรับแต่ละ section
// ─────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : AppTheme.headerBg,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(
                      color: isDark ? Colors.white12 : AppTheme.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.navy)),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}