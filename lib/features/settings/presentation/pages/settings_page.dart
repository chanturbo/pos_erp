import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/theme/theme_provider.dart';

// ─────────────────────────────────────────
// Settings State
// ─────────────────────────────────────────
class SettingsState {
  final String companyName;
  final String taxId;
  final String address;
  final String phone;
  final double vatRate;
  final bool enableVat;
  final bool enableLowStockAlert;
  final int lowStockThreshold;
  
  SettingsState({
    this.companyName = 'บริษัท ทดสอบ POS จำกัด',
    this.taxId = '1234567890123',
    this.address = '123 ถนนทดสอบ กรุงเทพฯ 10100',
    this.phone = '02-123-4567',
    this.vatRate = 7.0,
    this.enableVat = false,
    this.enableLowStockAlert = true,
    this.lowStockThreshold = 10,
  });
  
  SettingsState copyWith({
    String? companyName,
    String? taxId,
    String? address,
    String? phone,
    double? vatRate,
    bool? enableVat,
    bool? enableLowStockAlert,
    int? lowStockThreshold,
  }) {
    return SettingsState(
      companyName: companyName ?? this.companyName,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      vatRate: vatRate ?? this.vatRate,
      enableVat: enableVat ?? this.enableVat,
      enableLowStockAlert: enableLowStockAlert ?? this.enableLowStockAlert,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}

// ─────────────────────────────────────────
// Settings Notifier
// ─────────────────────────────────────────
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      companyName: prefs.getString('company_name'),
      taxId: prefs.getString('tax_id'),
      address: prefs.getString('address'),
      phone: prefs.getString('phone'),
      vatRate: prefs.getDouble('vat_rate'),
      enableVat: prefs.getBool('enable_vat'),
      enableLowStockAlert: prefs.getBool('enable_low_stock_alert'),
      lowStockThreshold: prefs.getInt('low_stock_threshold'),
    );
  }
  
  Future<void> updateCompanyInfo({
    String? companyName,
    String? taxId,
    String? address,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (companyName != null) await prefs.setString('company_name', companyName);
    if (taxId != null)       await prefs.setString('tax_id', taxId);
    if (address != null)     await prefs.setString('address', address);
    if (phone != null)       await prefs.setString('phone', phone);
    state = state.copyWith(
      companyName: companyName,
      taxId: taxId,
      address: address,
      phone: phone,
    );
  }
  
  Future<void> updateVatSettings({double? vatRate, bool? enableVat}) async {
    final prefs = await SharedPreferences.getInstance();
    if (vatRate != null)   await prefs.setDouble('vat_rate', vatRate);
    if (enableVat != null) await prefs.setBool('enable_vat', enableVat);
    state = state.copyWith(vatRate: vatRate, enableVat: enableVat);
  }
  
  Future<void> updateStockSettings({
    bool? enableLowStockAlert,
    int? lowStockThreshold,
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
      lowStockThreshold: lowStockThreshold,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

// ─────────────────────────────────────────
// Settings Page
// ─────────────────────────────────────────
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _taxIdController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _vatRateController;
  late TextEditingController _lowStockThresholdController;
  
  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _companyNameController = TextEditingController(text: settings.companyName);
    _taxIdController       = TextEditingController(text: settings.taxId);
    _addressController     = TextEditingController(text: settings.address);
    _phoneController       = TextEditingController(text: settings.phone);
    _vatRateController     = TextEditingController(text: settings.vatRate.toString());
    _lowStockThresholdController =
        TextEditingController(text: settings.lowStockThreshold.toString());
  }
  
  @override
  void dispose() {
    _companyNameController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _vatRateController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings  = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าระบบ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ════════════════════════════════
            // 🌙 การแสดงผล (Dark Mode)
            // ════════════════════════════════
            _buildSectionTitle('การแสดงผล'),
            const SizedBox(height: 16),
            _buildThemeModeSelector(themeMode),
            const SizedBox(height: 32),

            // ════════════════════════════════
            // ข้อมูลบริษัท
            // ════════════════════════════════
            _buildSectionTitle('ข้อมูลบริษัท'),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อบริษัท',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _taxIdController,
              decoration: const InputDecoration(
                labelText: 'เลขประจำตัวผู้เสียภาษี',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).updateCompanyInfo(
                  companyName: _companyNameController.text,
                  taxId: _taxIdController.text,
                  address: _addressController.text,
                  phone: _phoneController.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('บันทึกข้อมูลบริษัทสำเร็จ')),
                  );
                }
              },
              child: const Text('บันทึกข้อมูลบริษัท'),
            ),
            
            const SizedBox(height: 32),

            // ════════════════════════════════
            // ตั้งค่า VAT
            // ════════════════════════════════
            _buildSectionTitle('ตั้งค่า VAT'),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('เปิดใช้งาน VAT'),
              subtitle: const Text('คำนวณภาษีมูลค่าเพิ่มในใบเสร็จ'),
              value: settings.enableVat,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).updateVatSettings(enableVat: value);
              },
            ),
            
            if (settings.enableVat) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _vatRateController,
                decoration: const InputDecoration(
                  labelText: 'อัตรา VAT',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final vatRate = double.tryParse(_vatRateController.text);
                  if (vatRate != null) {
                    await ref.read(settingsProvider.notifier).updateVatSettings(vatRate: vatRate);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกการตั้งค่า VAT สำเร็จ')),
                      );
                    }
                  }
                },
                child: const Text('บันทึกการตั้งค่า VAT'),
              ),
            ],
            
            const SizedBox(height: 32),

            // ════════════════════════════════
            // ตั้งค่าสต๊อก
            // ════════════════════════════════
            _buildSectionTitle('ตั้งค่าสต๊อก'),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('แจ้งเตือนสต๊อกต่ำ'),
              subtitle: const Text('แสดงการแจ้งเตือนเมื่อสต๊อกต่ำกว่าที่กำหนด'),
              value: settings.enableLowStockAlert,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).updateStockSettings(
                  enableLowStockAlert: value,
                );
              },
            ),
            
            if (settings.enableLowStockAlert) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _lowStockThresholdController,
                decoration: const InputDecoration(
                  labelText: 'จำนวนสต๊อกต่ำสุด',
                  border: OutlineInputBorder(),
                  helperText: 'แจ้งเตือนเมื่อสต๊อกต่ำกว่าจำนวนนี้',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final threshold = int.tryParse(_lowStockThresholdController.text);
                  if (threshold != null) {
                    await ref.read(settingsProvider.notifier).updateStockSettings(
                      lowStockThreshold: threshold,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกการตั้งค่าสต๊อกสำเร็จ')),
                      );
                    }
                  }
                },
                child: const Text('บันทึกการตั้งค่าสต๊อก'),
              ),
            ],
            
            const SizedBox(height: 32),

            // ════════════════════════════════
            // ปุ่มลัด
            // ════════════════════════════════
            _buildSectionTitle('ปุ่มลัด'),
            const SizedBox(height: 16),
            _buildShortcutInfo('F1',  'เปิดหน้าจุดขาย (POS)'),
            _buildShortcutInfo('F2',  'เปิดหน้าจัดการสินค้า'),
            _buildShortcutInfo('F3',  'เปิดหน้าจัดการลูกค้า'),
            _buildShortcutInfo('F4',  'เปิดหน้าประวัติการขาย'),
            _buildShortcutInfo('F5',  'รีเฟรชหน้า'),
            _buildShortcutInfo('F6',  'เปิดหน้าคลังสินค้า'),
            _buildShortcutInfo('F7',  'เปิดหน้ารายงาน'),
            _buildShortcutInfo('F10', 'เปิดหน้า Dashboard'),
            _buildShortcutInfo('ESC', 'ยกเลิก/ปิด'),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 🌙 Theme Mode Selector Widget
  // ─────────────────────────────────────────
  Widget _buildThemeModeSelector(ThemeMode currentMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick toggle (Dark Mode on/off)
        SwitchListTile(
          title: const Text('โหมดมืด (Dark Mode)'),
          subtitle: Text(
            currentMode == ThemeMode.system
                ? 'ปัจจุบัน: ตามระบบ'
                : currentMode == ThemeMode.dark
                    ? 'ปัจจุบัน: มืด'
                    : 'ปัจจุบัน: สว่าง',
          ),
          secondary: Icon(
            currentMode == ThemeMode.dark
                ? Icons.dark_mode
                : currentMode == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
          ),
          value: currentMode == ThemeMode.dark,
          onChanged: (isDark) {
            ref.read(themeModeProvider.notifier).toggleDarkMode(isDark);
          },
        ),
        const SizedBox(height: 12),
        // 3-way segmented selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เลือกธีม',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 18),
                    label: Text('สว่าง'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 18),
                    label: Text('มืด'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto, size: 18),
                    label: Text('ตามระบบ'),
                  ),
                ],
                selected: {currentMode},
                onSelectionChanged: (modes) {
                  ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
  
  Widget _buildShortcutInfo(String key, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}