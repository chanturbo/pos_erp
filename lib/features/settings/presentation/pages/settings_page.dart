// ignore_for_file: avoid_print
// lib/features/settings/presentation/pages/settings_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_erp/main.dart'
    show
        applyRestoreInPlace,
        factoryResetInPlace,
        factoryResetSkipSeedKey,
        getMasterBackgroundHostRunning;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../core/config/app_mode.dart';
import '../../../../core/services/backup/backup_service.dart';
import '../../../../core/services/backup/google_drive_backup_service.dart';
import '../../../../core/services/backup/models/backup_result.dart';
import '../../../../routes/app_router.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../shared/settings_defaults.dart';

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
  final double pointsPerBaht; // ทุกกี่บาท ได้ 1 แต้ม
  final double pointValue; // 1 แต้ม = กี่บาท (สำหรับแลก)
  // ✅ PromptPay
  final String promptPayId;
  // ✅ POS View Mode
  final String posProductViewMode; // 'list' | 'grid'
  final bool mobilePosAutoOpenCartOnTap;
  final int listPageSizeMobile;
  final int listPageSizeTablet;
  final int listPageSizeDesktop;
  final int dialogPageSizeMobile;
  final int dialogPageSizeTablet;
  final int dialogPageSizeDesktop;
  final int reportRowsPerPageMobile;
  final int reportRowsPerPageTablet;
  final int reportRowsPerPageDesktop;
  final bool enableDirectThermalPrint;
  final bool autoPrintReceipt;
  final bool desktopUseTcpPrint;
  final bool mobileUseNativePrint;
  final String thermalPrinterHost;
  final int thermalPrinterPort;
  final int thermalPaperWidthMm;
  // ✅ Restaurant
  final double defaultServiceChargeRate;
  final String managerPin;
  final bool autoPrintKitchenTicket;
  final bool takeawayAutoRefreshEnabled;
  final int takeawayPollingIntervalSeconds;
  final bool restaurantAlertSoundEnabled;

  SettingsState({
    this.companyName = '',
    this.taxId = '1234567890123',
    this.address = '123 ถนนทดสอบ กรุงเทพฯ 10100',
    this.phone = '02-123-4567',
    this.vatRate = 7.0,
    this.enableVat = false,
    this.enableLowStockAlert = true,
    this.lowStockThreshold = 10,
    this.enableLoyalty = true,
    this.pointsPerBaht = 100.0,
    this.pointValue = 1.0,
    this.promptPayId = '',
    this.posProductViewMode = 'list',
    this.mobilePosAutoOpenCartOnTap = false,
    this.listPageSizeMobile = SettingsDefaults.listPageSizeMobile,
    this.listPageSizeTablet = SettingsDefaults.listPageSizeTablet,
    this.listPageSizeDesktop = SettingsDefaults.listPageSizeDesktop,
    this.dialogPageSizeMobile = SettingsDefaults.dialogPageSizeMobile,
    this.dialogPageSizeTablet = SettingsDefaults.dialogPageSizeTablet,
    this.dialogPageSizeDesktop = SettingsDefaults.dialogPageSizeDesktop,
    this.reportRowsPerPageMobile = SettingsDefaults.reportRowsPerPageMobile,
    this.reportRowsPerPageTablet = SettingsDefaults.reportRowsPerPageTablet,
    this.reportRowsPerPageDesktop = SettingsDefaults.reportRowsPerPageDesktop,
    this.enableDirectThermalPrint = false,
    this.autoPrintReceipt = false,
    this.desktopUseTcpPrint = false,
    this.mobileUseNativePrint = false,
    this.thermalPrinterHost = '',
    this.thermalPrinterPort = 9100,
    this.thermalPaperWidthMm = 80,
    this.defaultServiceChargeRate = 0,
    this.managerPin = '',
    this.autoPrintKitchenTicket = false,
    this.takeawayAutoRefreshEnabled = true,
    this.takeawayPollingIntervalSeconds = 15,
    this.restaurantAlertSoundEnabled = true,
  });

  bool get managerPinConfigured => managerPin.isNotEmpty;

  int get listPageSize => ResponsiveSettings.pick(
    mobile: listPageSizeMobile,
    tablet: listPageSizeTablet,
    desktop: listPageSizeDesktop,
  );

  int get dialogPageSize => ResponsiveSettings.pick(
    mobile: dialogPageSizeMobile,
    tablet: dialogPageSizeTablet,
    desktop: dialogPageSizeDesktop,
  );

  int get reportRowsPerPage => ResponsiveSettings.pick(
    mobile: reportRowsPerPageMobile,
    tablet: reportRowsPerPageTablet,
    desktop: reportRowsPerPageDesktop,
  );

  SettingsState copyWith({
    String? companyName,
    String? taxId,
    String? address,
    String? phone,
    double? vatRate,
    bool? enableVat,
    bool? enableLowStockAlert,
    int? lowStockThreshold,
    bool? enableLoyalty,
    double? pointsPerBaht,
    double? pointValue,
    String? promptPayId,
    String? posProductViewMode,
    bool? mobilePosAutoOpenCartOnTap,
    int? listPageSizeMobile,
    int? listPageSizeTablet,
    int? listPageSizeDesktop,
    int? dialogPageSizeMobile,
    int? dialogPageSizeTablet,
    int? dialogPageSizeDesktop,
    int? reportRowsPerPageMobile,
    int? reportRowsPerPageTablet,
    int? reportRowsPerPageDesktop,
    bool? enableDirectThermalPrint,
    bool? autoPrintReceipt,
    bool? desktopUseTcpPrint,
    bool? mobileUseNativePrint,
    String? thermalPrinterHost,
    int? thermalPrinterPort,
    int? thermalPaperWidthMm,
    double? defaultServiceChargeRate,
    String? managerPin,
    bool? autoPrintKitchenTicket,
    bool? takeawayAutoRefreshEnabled,
    int? takeawayPollingIntervalSeconds,
    bool? restaurantAlertSoundEnabled,
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
      enableLoyalty: enableLoyalty ?? this.enableLoyalty,
      pointsPerBaht: pointsPerBaht ?? this.pointsPerBaht,
      pointValue: pointValue ?? this.pointValue,
      promptPayId: promptPayId ?? this.promptPayId,
      posProductViewMode: posProductViewMode ?? this.posProductViewMode,
      mobilePosAutoOpenCartOnTap:
          mobilePosAutoOpenCartOnTap ?? this.mobilePosAutoOpenCartOnTap,
      listPageSizeMobile: listPageSizeMobile ?? this.listPageSizeMobile,
      listPageSizeTablet: listPageSizeTablet ?? this.listPageSizeTablet,
      listPageSizeDesktop: listPageSizeDesktop ?? this.listPageSizeDesktop,
      dialogPageSizeMobile: dialogPageSizeMobile ?? this.dialogPageSizeMobile,
      dialogPageSizeTablet: dialogPageSizeTablet ?? this.dialogPageSizeTablet,
      dialogPageSizeDesktop:
          dialogPageSizeDesktop ?? this.dialogPageSizeDesktop,
      reportRowsPerPageMobile:
          reportRowsPerPageMobile ?? this.reportRowsPerPageMobile,
      reportRowsPerPageTablet:
          reportRowsPerPageTablet ?? this.reportRowsPerPageTablet,
      reportRowsPerPageDesktop:
          reportRowsPerPageDesktop ?? this.reportRowsPerPageDesktop,
      enableDirectThermalPrint:
          enableDirectThermalPrint ?? this.enableDirectThermalPrint,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      desktopUseTcpPrint: desktopUseTcpPrint ?? this.desktopUseTcpPrint,
      mobileUseNativePrint: mobileUseNativePrint ?? this.mobileUseNativePrint,
      thermalPrinterHost: thermalPrinterHost ?? this.thermalPrinterHost,
      thermalPrinterPort: thermalPrinterPort ?? this.thermalPrinterPort,
      thermalPaperWidthMm: thermalPaperWidthMm ?? this.thermalPaperWidthMm,
      defaultServiceChargeRate:
          defaultServiceChargeRate ?? this.defaultServiceChargeRate,
      managerPin: managerPin ?? this.managerPin,
      autoPrintKitchenTicket:
          autoPrintKitchenTicket ?? this.autoPrintKitchenTicket,
      takeawayAutoRefreshEnabled:
          takeawayAutoRefreshEnabled ?? this.takeawayAutoRefreshEnabled,
      takeawayPollingIntervalSeconds:
          takeawayPollingIntervalSeconds ?? this.takeawayPollingIntervalSeconds,
      restaurantAlertSoundEnabled:
          restaurantAlertSoundEnabled ?? this.restaurantAlertSoundEnabled,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SettingsNotifier
// ─────────────────────────────────────────────────────────────────
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // ✅ โหลดค่าจาก SharedPreferences หลัง build เสร็จ
    Future.microtask(() => _loadSettings());
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyList = prefs.getInt('list_page_size');
    final legacyDialog = prefs.getInt('dialog_page_size');
    final legacyReport = prefs.getInt('report_rows_per_page');
    state = state.copyWith(
      // ✅ ใช้ ?? เพื่อไม่ overwrite default ด้วย null
      companyName: prefs.getString('company_name') ?? state.companyName,
      taxId: prefs.getString('tax_id') ?? state.taxId,
      address: prefs.getString('address') ?? state.address,
      phone: prefs.getString('phone') ?? state.phone,
      vatRate: prefs.getDouble('vat_rate') ?? state.vatRate,
      enableVat: prefs.getBool('enable_vat') ?? state.enableVat,
      enableLowStockAlert:
          prefs.getBool('enable_low_stock_alert') ?? state.enableLowStockAlert,
      lowStockThreshold:
          prefs.getInt('low_stock_threshold') ?? state.lowStockThreshold,
      enableLoyalty: prefs.getBool('enable_loyalty') ?? state.enableLoyalty,
      pointsPerBaht: prefs.getDouble('points_per_baht') ?? state.pointsPerBaht,
      pointValue: prefs.getDouble('point_value') ?? state.pointValue,
      promptPayId: prefs.getString('promptpay_id') ?? state.promptPayId,
      posProductViewMode:
          prefs.getString('pos_product_view_mode') ?? state.posProductViewMode,
      mobilePosAutoOpenCartOnTap:
          prefs.getBool('mobile_pos_auto_open_cart_on_tap') ??
          state.mobilePosAutoOpenCartOnTap,
      listPageSizeMobile:
          prefs.getInt('list_page_size_mobile') ??
          legacyList ??
          state.listPageSizeMobile,
      listPageSizeTablet:
          prefs.getInt('list_page_size_tablet') ??
          legacyList ??
          state.listPageSizeTablet,
      listPageSizeDesktop:
          prefs.getInt('list_page_size_desktop') ??
          legacyList ??
          state.listPageSizeDesktop,
      dialogPageSizeMobile:
          prefs.getInt('dialog_page_size_mobile') ??
          legacyDialog ??
          state.dialogPageSizeMobile,
      dialogPageSizeTablet:
          prefs.getInt('dialog_page_size_tablet') ??
          legacyDialog ??
          state.dialogPageSizeTablet,
      dialogPageSizeDesktop:
          prefs.getInt('dialog_page_size_desktop') ??
          legacyDialog ??
          state.dialogPageSizeDesktop,
      reportRowsPerPageMobile:
          prefs.getInt('report_rows_per_page_mobile') ??
          legacyReport ??
          state.reportRowsPerPageMobile,
      reportRowsPerPageTablet:
          prefs.getInt('report_rows_per_page_tablet') ??
          legacyReport ??
          state.reportRowsPerPageTablet,
      reportRowsPerPageDesktop:
          prefs.getInt('report_rows_per_page_desktop') ??
          legacyReport ??
          state.reportRowsPerPageDesktop,
      enableDirectThermalPrint:
          prefs.getBool('enable_direct_thermal_print') ??
          state.enableDirectThermalPrint,
      autoPrintReceipt:
          prefs.getBool('auto_print_receipt') ?? state.autoPrintReceipt,
      desktopUseTcpPrint:
          prefs.getBool('desktop_use_tcp_print') ?? state.desktopUseTcpPrint,
      mobileUseNativePrint:
          prefs.getBool('mobile_use_native_print') ??
          state.mobileUseNativePrint,
      thermalPrinterHost:
          prefs.getString('thermal_printer_host') ?? state.thermalPrinterHost,
      thermalPrinterPort:
          prefs.getInt('thermal_printer_port') ?? state.thermalPrinterPort,
      thermalPaperWidthMm:
          prefs.getInt('thermal_paper_width_mm') ?? state.thermalPaperWidthMm,
      defaultServiceChargeRate:
          prefs.getDouble('default_service_charge_rate') ??
          state.defaultServiceChargeRate,
      managerPin: prefs.getString('manager_pin') ?? state.managerPin,
      autoPrintKitchenTicket:
          prefs.getBool('auto_print_kitchen_ticket') ??
          state.autoPrintKitchenTicket,
      takeawayAutoRefreshEnabled:
          prefs.getBool('takeaway_auto_refresh_enabled') ??
          state.takeawayAutoRefreshEnabled,
      takeawayPollingIntervalSeconds:
          prefs.getInt('takeaway_polling_interval_seconds') ??
          state.takeawayPollingIntervalSeconds,
      restaurantAlertSoundEnabled:
          prefs.getBool('restaurant_alert_sound_enabled') ??
          state.restaurantAlertSoundEnabled,
    );
  }

  Future<void> updateRestaurantSettings({
    double? defaultServiceChargeRate,
    String? managerPin,
    bool? autoPrintKitchenTicket,
    bool? takeawayAutoRefreshEnabled,
    int? takeawayPollingIntervalSeconds,
    bool? restaurantAlertSoundEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (defaultServiceChargeRate != null) {
      await prefs.setDouble(
        'default_service_charge_rate',
        defaultServiceChargeRate,
      );
    }
    if (managerPin != null) {
      final toStore = managerPin.isEmpty
          ? ''
          : CryptoUtils.hashPassword(managerPin);
      await prefs.setString('manager_pin', toStore);
    }
    if (autoPrintKitchenTicket != null) {
      await prefs.setBool('auto_print_kitchen_ticket', autoPrintKitchenTicket);
    }
    if (takeawayAutoRefreshEnabled != null) {
      await prefs.setBool(
        'takeaway_auto_refresh_enabled',
        takeawayAutoRefreshEnabled,
      );
    }
    if (takeawayPollingIntervalSeconds != null) {
      await prefs.setInt(
        'takeaway_polling_interval_seconds',
        takeawayPollingIntervalSeconds,
      );
    }
    if (restaurantAlertSoundEnabled != null) {
      await prefs.setBool(
        'restaurant_alert_sound_enabled',
        restaurantAlertSoundEnabled,
      );
    }
    state = state.copyWith(
      defaultServiceChargeRate: defaultServiceChargeRate,
      managerPin: managerPin,
      autoPrintKitchenTicket: autoPrintKitchenTicket,
      takeawayAutoRefreshEnabled: takeawayAutoRefreshEnabled,
      takeawayPollingIntervalSeconds: takeawayPollingIntervalSeconds,
      restaurantAlertSoundEnabled: restaurantAlertSoundEnabled,
    );
  }

  Future<void> updateCompanyInfo({
    String? companyName,
    String? taxId,
    String? address,
    String? phone,
    String? promptPayId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (companyName != null) await prefs.setString('company_name', companyName);
    if (taxId != null) await prefs.setString('tax_id', taxId);
    if (address != null) await prefs.setString('address', address);
    if (phone != null) await prefs.setString('phone', phone);
    if (promptPayId != null) await prefs.setString('promptpay_id', promptPayId);
    state = state.copyWith(
      companyName: companyName,
      taxId: taxId,
      address: address,
      phone: phone,
      promptPayId: promptPayId,
    );
  }

  Future<void> updateVatSettings({double? vatRate, bool? enableVat}) async {
    final prefs = await SharedPreferences.getInstance();
    if (vatRate != null) await prefs.setDouble('vat_rate', vatRate);
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

  // ✅ POS View Mode
  Future<void> updatePosViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_product_view_mode', mode);
    state = state.copyWith(posProductViewMode: mode);
  }

  Future<void> updateMobilePosAutoOpenCartOnTap(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobile_pos_auto_open_cart_on_tap', enabled);
    state = state.copyWith(mobilePosAutoOpenCartOnTap: enabled);
  }

  // ✅ List Page Size
  Future<void> updateListPageSize(ResponsivePreset preset, int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'list_page_size_${ResponsiveSettings.keySuffix(preset)}',
      size,
    );
    switch (preset) {
      case ResponsivePreset.mobile:
        state = state.copyWith(listPageSizeMobile: size);
        break;
      case ResponsivePreset.tablet:
        state = state.copyWith(listPageSizeTablet: size);
        break;
      case ResponsivePreset.desktop:
        state = state.copyWith(listPageSizeDesktop: size);
        break;
    }
  }

  Future<void> updateDialogPageSize(ResponsivePreset preset, int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'dialog_page_size_${ResponsiveSettings.keySuffix(preset)}',
      size,
    );
    switch (preset) {
      case ResponsivePreset.mobile:
        state = state.copyWith(dialogPageSizeMobile: size);
        break;
      case ResponsivePreset.tablet:
        state = state.copyWith(dialogPageSizeTablet: size);
        break;
      case ResponsivePreset.desktop:
        state = state.copyWith(dialogPageSizeDesktop: size);
        break;
    }
  }

  Future<void> updateReportRowsPerPage(
    ResponsivePreset preset,
    int size,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'report_rows_per_page_${ResponsiveSettings.keySuffix(preset)}',
      size,
    );
    switch (preset) {
      case ResponsivePreset.mobile:
        state = state.copyWith(reportRowsPerPageMobile: size);
        break;
      case ResponsivePreset.tablet:
        state = state.copyWith(reportRowsPerPageTablet: size);
        break;
      case ResponsivePreset.desktop:
        state = state.copyWith(reportRowsPerPageDesktop: size);
        break;
    }
  }

  // ✅ Loyalty Points
  Future<void> updateLoyaltySettings({
    bool? enableLoyalty,
    double? pointsPerBaht,
    double? pointValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enableLoyalty != null) {
      await prefs.setBool('enable_loyalty', enableLoyalty);
    }
    if (pointsPerBaht != null) {
      await prefs.setDouble('points_per_baht', pointsPerBaht);
    }
    if (pointValue != null) await prefs.setDouble('point_value', pointValue);
    state = state.copyWith(
      enableLoyalty: enableLoyalty,
      pointsPerBaht: pointsPerBaht,
      pointValue: pointValue,
    );
  }

  Future<void> updateReceiptPrintSettings({
    bool? enableDirectThermalPrint,
    bool? autoPrintReceipt,
    bool? desktopUseTcpPrint,
    bool? mobileUseNativePrint,
    String? thermalPrinterHost,
    int? thermalPrinterPort,
    int? thermalPaperWidthMm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enableDirectThermalPrint != null) {
      await prefs.setBool(
        'enable_direct_thermal_print',
        enableDirectThermalPrint,
      );
    }
    if (autoPrintReceipt != null) {
      await prefs.setBool('auto_print_receipt', autoPrintReceipt);
    }
    if (desktopUseTcpPrint != null) {
      await prefs.setBool('desktop_use_tcp_print', desktopUseTcpPrint);
    }
    if (mobileUseNativePrint != null) {
      await prefs.setBool('mobile_use_native_print', mobileUseNativePrint);
    }
    if (thermalPrinterHost != null) {
      await prefs.setString('thermal_printer_host', thermalPrinterHost.trim());
    }
    if (thermalPrinterPort != null) {
      await prefs.setInt('thermal_printer_port', thermalPrinterPort);
    }
    if (thermalPaperWidthMm != null) {
      await prefs.setInt('thermal_paper_width_mm', thermalPaperWidthMm);
    }
    state = state.copyWith(
      enableDirectThermalPrint: enableDirectThermalPrint,
      autoPrintReceipt: autoPrintReceipt,
      desktopUseTcpPrint: desktopUseTcpPrint,
      mobileUseNativePrint: mobileUseNativePrint,
      thermalPrinterHost: thermalPrinterHost,
      thermalPrinterPort: thermalPrinterPort,
      thermalPaperWidthMm: thermalPaperWidthMm,
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
  static const _backupLastPathKey = 'backup_last_path';
  static const _backupLastAtKey = 'backup_last_at';
  static const _backupLastSizeKey = 'backup_last_size';

  final _formKey = GlobalKey<FormState>();
  final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  // Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _taxIdController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _vatRateController;
  late TextEditingController _lowStockThresholdController;
  late TextEditingController _pointsPerBahtController;
  late TextEditingController _pointValueController;
  late TextEditingController _promptPayController; // ✅
  late TextEditingController _thermalPrinterHostController;
  late TextEditingController _thermalPrinterPortController;
  bool _isCreatingBackup = false;
  bool _isPreparingRestore = false;
  bool _isConnectingGoogleDrive = false;
  bool _isUploadingGoogleDrive = false;
  bool _isDriveListLoading = false;
  bool _isRestoringFromDrive = false;
  bool _isFactoryResetting = false;
  bool _skipSeedAfterFactoryReset = false;
  String? _lastBackupPath;
  DateTime? _lastBackupAt;
  int? _lastBackupSize;
  String? _googleDriveEmail;
  bool? _masterBackgroundHostRunning;

  @override
  void initState() {
    super.initState();
    // init ด้วยค่า default ก่อน (state ยังโหลดไม่เสร็จ)
    _companyNameController = TextEditingController();
    _taxIdController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _vatRateController = TextEditingController();
    _lowStockThresholdController = TextEditingController();
    _pointsPerBahtController = TextEditingController();
    _pointValueController = TextEditingController();
    _promptPayController = TextEditingController();
    _thermalPrinterHostController = TextEditingController();
    _thermalPrinterPortController = TextEditingController();
    // ✅ รอ state โหลดเสร็จแล้วค่อย sync ค่าเข้า controllers
    Future.microtask(() {
      if (!mounted) return;
      _syncControllers(ref.read(settingsProvider));
      _loadBackupMetadata();
      _loadGoogleDriveConfig();
      _loadFactoryResetPreference();
      _refreshMasterBackgroundHostStatus();
    });
  }

  Future<void> _refreshMasterBackgroundHostStatus() async {
    final running = await getMasterBackgroundHostRunning();
    if (!mounted) return;
    setState(() => _masterBackgroundHostRunning = running);
  }

  /// ✅ Sync ค่าจาก SettingsState เข้า controllers ทั้งหมด
  void _syncControllers(SettingsState s) {
    _companyNameController.text = s.companyName;
    _taxIdController.text = s.taxId;
    _addressController.text = s.address;
    _phoneController.text = s.phone;
    _vatRateController.text = s.vatRate.toString();
    _lowStockThresholdController.text = s.lowStockThreshold.toString();
    _pointsPerBahtController.text = s.pointsPerBaht.toStringAsFixed(0);
    _pointValueController.text = s.pointValue.toStringAsFixed(2);
    _promptPayController.text = s.promptPayId;
    _thermalPrinterHostController.text = s.thermalPrinterHost;
    _thermalPrinterPortController.text = s.thermalPrinterPort.toString();
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
    _promptPayController.dispose(); // ✅
    _thermalPrinterHostController.dispose();
    _thermalPrinterPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ เมื่อ state โหลดเสร็จจาก SharedPreferences → sync controllers
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      // sync เฉพาะรอบแรกที่ข้อมูลโหลดมา (controller ยังว่างอยู่)
      if (previous != null &&
          previous.promptPayId != next.promptPayId &&
          _promptPayController.text.isEmpty) {
        _syncControllers(next);
      }
      // sync company name รอบแรก ถ้า controller ยังว่างอยู่
      if (previous != null &&
          previous.companyName != next.companyName &&
          _companyNameController.text.trim().isEmpty) {
        _syncControllers(next);
      }
    });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
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
                  // 🔤 ฟอนต์และขนาดตัวอักษร
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ฟอนต์และขนาดตัวอักษร',
                    icon: Icons.text_fields_outlined,
                    isDark: isDark,
                    child: _buildFontSection(isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 📋 การแสดงรายการข้อมูล
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'การแสดงรายการข้อมูล',
                    icon: Icons.format_list_numbered_outlined,
                    isDark: isDark,
                    child: _buildListDisplaySection(settings, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // 🛒 ตั้งค่าหน้าขาย
                  // ══════════════════════════════════════════
                  _SectionCard(
                    title: 'ตั้งค่าหน้าขาย (POS)',
                    icon: Icons.point_of_sale_outlined,
                    isDark: isDark,
                    child: _buildPosSection(settings, isDark),
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

                  _SectionCard(
                    title: 'ใบเสร็จ / เครื่องพิมพ์',
                    icon: Icons.print_outlined,
                    isDark: isDark,
                    child: _buildReceiptPrintSection(settings, isDark),
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
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'ร้านอาหาร',
                    icon: Icons.restaurant_outlined,
                    isDark: isDark,
                    child: _buildRestaurantSection(settings, isDark),
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'สำรองข้อมูล',
                    icon: Icons.backup_outlined,
                    isDark: isDark,
                    child: _buildBackupSection(settings, isDark),
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
          title: Text(
            'โหมดมืด (Dark Mode)',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
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
          activeThumbColor: AppTheme.primary,
          onChanged: (isDark) {
            ref.read(themeModeProvider.notifier).toggleDarkMode(isDark);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'เลือกธีม',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : AppTheme.textSub,
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
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Font Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildFontSection(bool isDark) {
    final fontSettings = ref.watch(fontSettingsProvider);

    const fonts = [
      ('ibmPlexSansThai', 'IBM Plex Sans Thai'),
      ('sarabun', 'Sarabun'),
      ('kanit', 'Kanit'),
      ('prompt', 'Prompt'),
      ('notoSansThai', 'Noto Sans Thai'),
    ];

    const scales = [
      (0.85, 'เล็ก'),
      (1.0, 'ปกติ'),
      (1.15, 'ใหญ่'),
      (1.3, 'ใหญ่มาก'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ฟอนต์',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'เลือกแบบอักษรที่ต้องการใช้งานทั่วทั้งแอป',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fonts
              .map(
                (f) => _paginationChip(
                  label: f.$2,
                  selected: fontSettings.fontFamily == f.$1,
                  isDark: isDark,
                  onTap: () {
                    ref.read(fontSettingsProvider.notifier).setFontFamily(f.$1);
                    _showSuccess('บันทึกการตั้งค่าแล้ว');
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'ขนาดตัวอักษร',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ปรับขนาดตัวอักษรทั่วทั้งแอป (ปกติ = 100%)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: scales
              .map(
                (s) => _paginationChip(
                  label: s.$2,
                  selected: fontSettings.fontScale == s.$1,
                  isDark: isDark,
                  onTap: () {
                    ref.read(fontSettingsProvider.notifier).setFontScale(s.$1);
                    _showSuccess('บันทึกการตั้งค่าแล้ว');
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // POS Section
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  // List Display Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildListDisplaySection(SettingsState settings, bool isDark) {
    const listPresets = [10, 20, 50, 100];
    const dialogPresets = [5, 10, 15, 20, 30];
    const reportPresets = [20, 24, 30, 32, 35, 38, 40];
    final currentPreset = ResponsiveSettings.presetForWidth(
      MediaQuery.sizeOf(context).width,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.devices_outlined,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'หน้าจอปัจจุบันใช้ preset ${ResponsiveSettings.label(currentPreset)} อัตโนมัติ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'จำนวนรายการต่อหน้า - หน้าหลัก',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ใช้กับทุกหน้าที่แสดงรายการ เช่น สินค้า ลูกค้า ประวัติการขาย สต๊อก',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        ...ResponsivePreset.values.map(
          (preset) => _presetSizeGroup(
            isDark: isDark,
            preset: preset,
            values: listPresets,
            selectedValue: _valueForPreset(
              preset: preset,
              mobile: settings.listPageSizeMobile,
              tablet: settings.listPageSizeTablet,
              desktop: settings.listPageSizeDesktop,
            ),
            unitLabel: 'รายการ',
            onSelected: (size) async {
              await ref
                  .read(settingsProvider.notifier)
                  .updateListPageSize(preset, size);
              if (mounted) _showSuccess('บันทึกการตั้งค่าแล้ว');
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'จำนวนรายการต่อหน้า - Dialog/Popup',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ใช้กับหน้าต่างประวัติหรือ popup ที่มีการแบ่งหน้าแยกจากหน้าหลัก',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        ...ResponsivePreset.values.map(
          (preset) => _presetSizeGroup(
            isDark: isDark,
            preset: preset,
            values: dialogPresets,
            selectedValue: _valueForPreset(
              preset: preset,
              mobile: settings.dialogPageSizeMobile,
              tablet: settings.dialogPageSizeTablet,
              desktop: settings.dialogPageSizeDesktop,
            ),
            unitLabel: 'รายการ',
            onSelected: (size) async {
              await ref
                  .read(settingsProvider.notifier)
                  .updateDialogPageSize(preset, size);
              if (mounted) _showSuccess('บันทึกการตั้งค่าแล้ว');
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'จำนวนแถวต่อหน้า - รายงาน PDF',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ใช้กับการตัดหน้ารายงาน PDF เพื่อแยกจากหน้าหลักและ dialog',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        ...ResponsivePreset.values.map(
          (preset) => _presetSizeGroup(
            isDark: isDark,
            preset: preset,
            values: reportPresets,
            selectedValue: _valueForPreset(
              preset: preset,
              mobile: settings.reportRowsPerPageMobile,
              tablet: settings.reportRowsPerPageTablet,
              desktop: settings.reportRowsPerPageDesktop,
            ),
            unitLabel: 'แถว',
            onSelected: (size) async {
              await ref
                  .read(settingsProvider.notifier)
                  .updateReportRowsPerPage(preset, size);
              if (mounted) _showSuccess('บันทึกการตั้งค่าแล้ว');
            },
          ),
        ),
      ],
    );
  }

  int _valueForPreset({
    required ResponsivePreset preset,
    required int mobile,
    required int tablet,
    required int desktop,
  }) {
    switch (preset) {
      case ResponsivePreset.mobile:
        return mobile;
      case ResponsivePreset.tablet:
        return tablet;
      case ResponsivePreset.desktop:
        return desktop;
    }
  }

  Widget _presetSizeGroup({
    required bool isDark,
    required ResponsivePreset preset,
    required List<int> values,
    required int selectedValue,
    required String unitLabel,
    required Future<void> Function(int size) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ResponsiveSettings.label(preset),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (size) => _paginationChip(
                    label: '$size $unitLabel',
                    selected: selectedValue == size,
                    isDark: isDark,
                    onTap: () {
                      onSelected(size);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _paginationChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected
            ? AppTheme.primary
            : (isDark ? Colors.white70 : AppTheme.textSub),
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : (isDark ? Colors.white24 : AppTheme.border),
      ),
      backgroundColor: isDark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFF5F5F5),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildPosSection(SettingsState settings, bool isDark) {
    final isGrid = settings.posProductViewMode == 'grid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปแบบแสดงรายการสินค้าเริ่มต้น',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'เลือกรูปแบบที่ต้องการแสดงเมื่อเปิดหน้าขาย',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _viewModeOption(
                label: 'Grid View',
                icon: Icons.grid_view,
                selected: isGrid,
                isDark: isDark,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .updatePosViewMode('grid'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _viewModeOption(
                label: 'List View',
                icon: Icons.view_list,
                selected: !isGrid,
                isDark: isDark,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .updatePosViewMode('list'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'แตะสินค้าแล้วเปิดตะกร้าอัตโนมัติ',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'ปิดไว้จะเหมาะกับ POS มากกว่า เพราะแตะสินค้าได้ต่อเนื่องโดยไม่เด้งไปแท็บตะกร้าทุกครั้ง',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          secondary: const Icon(
            Icons.shopping_cart_checkout_outlined,
            color: AppTheme.primary,
          ),
          value: settings.mobilePosAutoOpenCartOnTap,
          activeThumbColor: AppTheme.primary,
          onChanged: (value) async {
            await ref
                .read(settingsProvider.notifier)
                .updateMobilePosAutoOpenCartOnTap(value);
            if (mounted) _showSuccess('บันทึกการตั้งค่าแล้ว');
          },
        ),
      ],
    );
  }

  Widget _viewModeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : (isDark ? Colors.white24 : AppTheme.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected
                  ? AppTheme.primary
                  : (isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? AppTheme.primary
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
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
        _field(
          _taxIdController,
          'เลขประจำตัวผู้เสียภาษี',
          Icons.numbers,
          style,
        ),
        const SizedBox(height: 12),
        _field(
          _addressController,
          'ที่อยู่',
          Icons.location_on,
          style,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(_phoneController, 'เบอร์โทรศัพท์', Icons.phone, style),
        const SizedBox(height: 12),
        // ✅ PromptPay
        TextField(
          controller: _promptPayController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: style.copyWith(
            labelText: 'เลข PromptPay',
            hintText: 'เบอร์โทร 10 หลัก หรือเลขประจำตัว 13 หลัก',
            prefixIcon: const Icon(Icons.qr_code),
            helperText: 'ใช้แสดง QR Code รับชำระเงินในหน้า POS',
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(
          label: 'บันทึกข้อมูลบริษัท',
          icon: Icons.save_outlined,
          onPressed: () async {
            await ref
                .read(settingsProvider.notifier)
                .updateCompanyInfo(
                  companyName: _companyNameController.text,
                  taxId: _taxIdController.text,
                  address: _addressController.text,
                  phone: _phoneController.text,
                  promptPayId: _promptPayController.text.trim(), // ✅
                );
            if (mounted) _showSuccess('บันทึกข้อมูลบริษัทสำเร็จ');
          },
        ),
      ],
    );
  }

  Widget _buildReceiptPrintSection(SettingsState settings, bool isDark) {
    final style = _inputStyle(isDark);
    final captionColor = isDark ? Colors.white54 : AppTheme.textSub;
    final boxColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : AppTheme.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'โหมดนี้รองรับการพิมพ์ตรงผ่านเครื่องพิมพ์ LAN/TCP แบบ ESC/POS บน Android, Windows และ macOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ถ้าปิดไว้ ระบบจะแสดงใบเสร็จแบบ preview อย่างเดียว และยังไม่ส่งงานพิมพ์ตรงไปที่เครื่องสลิป',
                style: TextStyle(fontSize: 12, color: captionColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'เปิดใช้งาน Direct Thermal Print',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            settings.enableDirectThermalPrint
                ? 'เปิดอยู่: ระบบจะใช้ค่าเครื่องพิมพ์ที่ตั้งไว้'
                : 'ปิดอยู่: แสดง preview ใบเสร็จอย่างเดียว',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          secondary: const Icon(Icons.print_outlined, color: AppTheme.primary),
          value: settings.enableDirectThermalPrint,
          activeThumbColor: AppTheme.primary,
          onChanged: (value) {
            ref
                .read(settingsProvider.notifier)
                .updateReceiptPrintSettings(enableDirectThermalPrint: value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'พิมพ์อัตโนมัติหลังชำระเงิน',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'ใช้กับ flow ขายหน้าร้าน หลังบันทึกบิลสำเร็จแล้วระบบจะพยายามส่งไปยังเครื่องพิมพ์ทันที',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          secondary: const Icon(
            Icons.local_printshop_outlined,
            color: AppTheme.primary,
          ),
          value: settings.autoPrintReceipt,
          activeThumbColor: AppTheme.primary,
          onChanged: settings.enableDirectThermalPrint
              ? (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateReceiptPrintSettings(autoPrintReceipt: value);
                }
              : null,
        ),
        if (Platform.isMacOS || Platform.isWindows)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'ใช้ Direct TCP แทน Native Print Dialog (Desktop)',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.desktopUseTcpPrint
                  ? 'เปิดอยู่: กดพิมพ์จะแสดง dialog กรอก IP:Port เหมือน Android'
                  : 'ปิดอยู่: กดพิมพ์จะเปิด native print dialog ของ OS',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSub,
              ),
            ),
            secondary: const Icon(
              Icons.swap_horiz_outlined,
              color: AppTheme.primary,
            ),
            value: settings.desktopUseTcpPrint,
            activeThumbColor: AppTheme.primary,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .updateReceiptPrintSettings(desktopUseTcpPrint: value);
            },
          ),
        if (Platform.isAndroid || Platform.isIOS)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'ใช้ Native Print Dialog (Android / iOS)',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              settings.mobileUseNativePrint
                  ? 'เปิดอยู่: ใช้ Android Print / AirPrint เลือก printer จาก OS'
                  : 'ปิดอยู่: กดพิมพ์จะแสดง dialog กรอก IP:Port (ESC/POS TCP)',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSub,
              ),
            ),
            secondary: const Icon(
              Icons.print_outlined,
              color: AppTheme.primary,
            ),
            value: settings.mobileUseNativePrint,
            activeThumbColor: AppTheme.primary,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .updateReceiptPrintSettings(mobileUseNativePrint: value);
            },
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รูปแบบกระดาษใบเสร็จ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ใช้ค่าเดียวกันทั้ง preview และ direct print เพื่อให้ layout ใกล้กับกระดาษจริงมากขึ้น',
                style: TextStyle(fontSize: 12, color: captionColor),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _paginationChip(
                    label: '58 mm',
                    selected: settings.thermalPaperWidthMm == 58,
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .updateReceiptPrintSettings(thermalPaperWidthMm: 58);
                    },
                  ),
                  _paginationChip(
                    label: '80 mm',
                    selected: settings.thermalPaperWidthMm == 80,
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .updateReceiptPrintSettings(thermalPaperWidthMm: 80);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _thermalPrinterHostController,
                decoration: style.copyWith(
                  labelText: 'Printer IP / Host',
                  hintText: 'เช่น 192.168.1.120',
                  helperText: 'รองรับเครื่องพิมพ์เครือข่ายที่เปิดพอร์ต TCP',
                  prefixIcon: const Icon(Icons.router_outlined),
                ),
                keyboardType: TextInputType.url,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _thermalPrinterPortController,
                decoration: style.copyWith(
                  labelText: 'Port',
                  hintText: '9100',
                  helperText: 'ค่ามาตรฐานของเครื่องพิมพ์สลิปส่วนใหญ่คือ 9100',
                  prefixIcon: const Icon(Icons.settings_ethernet_outlined),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(
          label: 'บันทึกการตั้งค่าเครื่องพิมพ์',
          icon: Icons.save_outlined,
          onPressed: () async {
            final port = int.tryParse(
              _thermalPrinterPortController.text.trim(),
            );
            if (port == null || port <= 0) {
              _showError('กรุณาระบุพอร์ตเครื่องพิมพ์ให้ถูกต้อง');
              return;
            }

            await ref
                .read(settingsProvider.notifier)
                .updateReceiptPrintSettings(
                  thermalPrinterHost: _thermalPrinterHostController.text.trim(),
                  thermalPrinterPort: port,
                );
            if (mounted) _showSuccess('บันทึกการตั้งค่าเครื่องพิมพ์สำเร็จ');
          },
        ),
        const SizedBox(height: 12),
        Text(
          'หมายเหตุ: เวอร์ชันนี้เน้น direct print ผ่าน LAN/TCP (ESC/POS) ก่อน ถ้าเป็น USB/Bluetooth thermal printer จะต้องเพิ่ม integration แยกในเฟสถัดไป',
          style: TextStyle(fontSize: 12, color: captionColor),
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
          title: Text(
            'เปิดใช้งาน VAT',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'คำนวณภาษีมูลค่าเพิ่มในใบเสร็จ',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          value: settings.enableVat,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .updateVatSettings(enableVat: v),
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
                await ref
                    .read(settingsProvider.notifier)
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
          title: Text(
            'แจ้งเตือนสต๊อกต่ำ',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'แสดงการแจ้งเตือนเมื่อสต๊อกต่ำกว่าที่กำหนด',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          value: settings.enableLowStockAlert,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
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
                await ref
                    .read(settingsProvider.notifier)
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
          title: Text(
            'เปิดใช้งานระบบสะสมแต้ม',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'สะสมแต้มสำหรับลูกค้าที่มีรหัสสมาชิก',
            style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textSub),
          ),
          secondary: Icon(Icons.star_outline, color: AppTheme.primary),
          value: settings.enableLoyalty,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
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
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ทุก ฿${settings.pointsPerBaht.toStringAsFixed(0)} ได้ 1 แต้ม  '
                    '•  1 แต้ม = ฿${settings.pointValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
                    Text(
                      'ทุกกี่บาท ได้ 1 แต้ม',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppTheme.textSub,
                      ),
                    ),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
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
                    Text(
                      '1 แต้ม มูลค่ากี่บาท (แลกส่วนลด)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppTheme.textSub,
                      ),
                    ),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quick preset chips ────────────────────────────────────
          Text(
            'ตัวอย่างค่าที่นิยมใช้',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : AppTheme.textSub,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('ทุก 10฿ = 1 แต้ม', 10, 1, isDark),
              _presetChip('ทุก 20฿ = 1 แต้ม', 20, 1, isDark),
              _presetChip('ทุก 50฿ = 1 แต้ม', 50, 1, isDark),
              _presetChip('ทุก 100฿ = 1 แต้ม', 100, 1, isDark),
              _presetChip('ทุก 100฿ = 1 แต้ม (1฿)', 100, 1, isDark),
            ],
          ),
          const SizedBox(height: 16),
          _saveButton(
            label: 'บันทึกการตั้งค่าสะสมแต้ม',
            icon: Icons.save_outlined,
            onPressed: () async {
              final ppb = double.tryParse(_pointsPerBahtController.text);
              final pv = double.tryParse(_pointValueController.text);
              if (ppb != null && pv != null && ppb > 0) {
                await ref
                    .read(settingsProvider.notifier)
                    .updateLoyaltySettings(pointsPerBaht: ppb, pointValue: pv);
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
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : AppTheme.headerBg,
      side: BorderSide(color: isDark ? Colors.white24 : AppTheme.border),
      onPressed: () {
        setState(() {
          _pointsPerBahtController.text = ppb.toStringAsFixed(0);
          _pointValueController.text = pv.toStringAsFixed(2);
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Shortcuts Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildShortcutsSection(bool isDark) {
    const shortcuts = [
      ('F1', 'เปิดหน้าจุดขาย (POS)'),
      ('F2', 'เปิดหน้าจัดการสินค้า'),
      ('F3', 'เปิดหน้าจัดการลูกค้า'),
      ('F4', 'เปิดหน้าประวัติการขาย'),
      ('F5', 'รีเฟรชหน้า'),
      ('F6', 'เปิดหน้าคลังสินค้า'),
      ('F7', 'เปิดหน้ารายงาน'),
      ('F10', 'เปิดหน้า Dashboard'),
      ('ESC', 'ยกเลิก/ปิด'),
    ];
    return Column(
      children: shortcuts.map((s) => _shortcutRow(s.$1, s.$2, isDark)).toList(),
    );
  }

  Widget _buildRestaurantSection(SettingsState settings, bool isDark) {
    final scCtrl = TextEditingController(
      text: settings.defaultServiceChargeRate > 0
          ? settings.defaultServiceChargeRate.toStringAsFixed(
              settings.defaultServiceChargeRate ==
                      settings.defaultServiceChargeRate.truncateToDouble()
                  ? 0
                  : 1,
            )
          : '0',
    );
    final pinCtrl = TextEditingController();
    const pollingIntervals = [5, 10, 15, 30, 60];

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.percent, color: Colors.orange),
          title: Text(
            'Service Charge เริ่มต้น (%)',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            settings.defaultServiceChargeRate > 0
                ? 'ใช้ ${settings.defaultServiceChargeRate.toStringAsFixed(1)}% อัตโนมัติเมื่อเปิดบิล'
                : 'ไม่ตั้งค่า (กรอกเองที่หน้าบิล)',
            style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSub),
          ),
          trailing: SizedBox(
            width: 90,
            child: TextFormField(
              controller: scCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixText: '%',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onFieldSubmitted: (v) {
                final rate = double.tryParse(v) ?? 0;
                ref
                    .read(settingsProvider.notifier)
                    .updateRestaurantSettings(defaultServiceChargeRate: rate);
              },
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline, color: Colors.purple),
          title: Text(
            'Manager PIN (สำหรับยกเลิกรายการ)',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            settings.managerPinConfigured
                ? 'ตั้ง PIN แล้ว (กรอก PIN ใหม่เพื่อเปลี่ยน)'
                : 'ไม่ตั้ง PIN (ยกเลิกได้ทันที)',
            style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSub),
          ),
          trailing: SizedBox(
            width: 140,
            child: TextFormField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: settings.managerPinConfigured ? '••••' : 'ไม่ตั้งค่า',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onFieldSubmitted: (v) {
                ref
                    .read(settingsProvider.notifier)
                    .updateRestaurantSettings(managerPin: v.trim());
              },
            ),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.print_outlined, color: Colors.teal),
          title: Text(
            'พิมพ์ใบสั่งครัวอัตโนมัติ',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            settings.autoPrintKitchenTicket
                ? 'พิมพ์ Kitchen Ticket ทุกครั้งที่ส่งออเดอร์'
                : 'ไม่พิมพ์อัตโนมัติ',
            style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSub),
          ),
          value: settings.autoPrintKitchenTicket,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .updateRestaurantSettings(autoPrintKitchenTicket: v),
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.sync_outlined, color: Colors.indigo),
          title: Text(
            'รีเฟรชบิลกลับบ้านอัตโนมัติ',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            settings.takeawayAutoRefreshEnabled
                ? 'Home, โต๊ะอาหาร และหน้าบิลกลับบ้านจะอัปเดตตามรอบเวลาเดียวกัน'
                : 'อัปเดตเฉพาะตอนกดรีเฟรชเอง',
            style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSub),
          ),
          value: settings.takeawayAutoRefreshEnabled,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .updateRestaurantSettings(takeawayAutoRefreshEnabled: v),
        ),
        if (settings.takeawayAutoRefreshEnabled) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ช่วงเวลา polling',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ใช้ค่าเดียวกันสำหรับ badge และรายการ takeaway',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppTheme.textSub,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pollingIntervals
                  .map(
                    (seconds) => _paginationChip(
                      label: '$seconds วิ',
                      selected:
                          settings.takeawayPollingIntervalSeconds == seconds,
                      isDark: isDark,
                      onTap: () async {
                        await ref
                            .read(settingsProvider.notifier)
                            .updateRestaurantSettings(
                              takeawayPollingIntervalSeconds: seconds,
                            );
                        if (mounted) _showSuccess('บันทึกการตั้งค่าแล้ว');
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.deepOrange,
          ),
          title: Text(
            'เปิดเสียงแจ้งเตือนร้านอาหาร',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            settings.restaurantAlertSoundEnabled
                ? 'เล่นเสียงเมื่อมีบิล takeaway ใหม่หรือ ticket ครัวใหม่'
                : 'ปิดเสียงไว้ แต่ยังแสดง badge / highlight / snackbar ตามปกติ',
            style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSub),
          ),
          value: settings.restaurantAlertSoundEnabled,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .updateRestaurantSettings(restaurantAlertSoundEnabled: v),
        ),
      ],
    );
  }

  Widget _buildBackupSection(SettingsState settings, bool isDark) {
    final captionColor = isDark ? Colors.white54 : AppTheme.textSub;
    final boxColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : AppTheme.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ระบบจะรวมฐานข้อมูล, รูปสินค้า และ manifest ก่อนเข้ารหัสด้วย AES-256-GCM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildMasterBackgroundHostCard(isDark),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _backupInfoRow(
                label: 'สถานะล่าสุด',
                value: _isCreatingBackup
                    ? 'กำลังสร้างไฟล์สำรองข้อมูล...'
                    : (_lastBackupAt != null ? 'สำเร็จ' : 'ยังไม่เคยสำรอง'),
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _backupInfoRow(
                label: 'เวลาล่าสุด',
                value: _lastBackupAt != null
                    ? _dateTimeFmt.format(_lastBackupAt!)
                    : '-',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _backupInfoRow(
                label: 'ขนาดไฟล์ล่าสุด',
                value: _lastBackupSize != null
                    ? _formatBytes(_lastBackupSize!)
                    : '-',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _backupInfoRow(
                label: 'ไฟล์ล่าสุด',
                value: _lastBackupPath ?? '-',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: _isCreatingBackup
                    ? null
                    : () => _createEncryptedBackup(settings),
                icon: _isCreatingBackup
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_alt_outlined, size: 18),
                label: Text(
                  _isCreatingBackup ? 'กำลังสำรอง...' : 'สำรองข้อมูลตอนนี้',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                onPressed: _isPreparingRestore || _isCreatingBackup
                    ? null
                    : _prepareRestoreFlow,
                icon: const Icon(
                  Icons.settings_backup_restore_outlined,
                  size: 18,
                ),
                label: Text(
                  _isPreparingRestore ? 'กำลังเตรียม...' : 'กู้คืนข้อมูล',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'หมายเหตุ: เก็บรหัสเข้ารหัสไว้ให้ดี หากลืมจะไม่สามารถถอดไฟล์สำรองข้อมูลได้',
          style: TextStyle(fontSize: 12, color: captionColor),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 18),
        _buildGoogleDriveSection(isDark),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A1F1F) : const Color(0xFFFFF4F4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.redAccent.withValues(alpha: 0.35)
                  : const Color(0xFFFFD0D0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Factory Reset',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ล้างฐานข้อมูลในเครื่องและ session ปัจจุบันทั้งหมด เหมาะสำหรับทดสอบการเริ่มระบบใหม่หรือเคลียร์เครื่องก่อน restore',
                style: TextStyle(fontSize: 12, color: captionColor),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _skipSeedAfterFactoryReset,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.error,
                onChanged: _isFactoryResetting
                    ? null
                    : _setSkipSeedAfterFactoryReset,
                title: const Text('Skip seed หลังล้างข้อมูล'),
                subtitle: Text(
                  _skipSeedAfterFactoryReset
                      ? 'หลังรีเซ็ตจะไม่สร้างข้อมูลตั้งต้นและจะไม่มีผู้ใช้เริ่มต้น'
                      : 'หลังรีเซ็ตจะสร้างข้อมูลตั้งต้นและผู้ใช้เริ่มต้นกลับมาใหม่',
                  style: TextStyle(fontSize: 12, color: captionColor),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: _isFactoryResetting ? null : _confirmFactoryReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isFactoryResetting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined, size: 18),
                  label: Text(
                    _isFactoryResetting
                        ? 'กำลังล้างข้อมูล...'
                        : 'Factory Reset ตอนนี้',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMasterBackgroundHostCard(bool isDark) {
    final boxColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : AppTheme.border;

    final (
      icon,
      color,
      title,
      subtitle,
    ) = switch (_masterBackgroundHostRunning) {
      true => (
        Icons.verified_rounded,
        AppTheme.successColor,
        'Master background host: ทำงานอยู่',
        'Android foreground service กำลังช่วยคงการทำงานของโหมด Master',
      ),
      false => (
        AppModeConfig.isMaster
            ? Icons.warning_amber_rounded
            : Icons.pause_circle_outline_rounded,
        AppModeConfig.isMaster ? Colors.orange : AppTheme.infoColor,
        AppModeConfig.isMaster
            ? 'Master background host: ยังไม่ทำงาน'
            : 'Master background host: ปิดอยู่',
        AppModeConfig.isMaster
            ? 'หากเพิ่งสลับเป็น Master ลองกลับเข้าหน้านี้อีกครั้ง'
            : 'เป็นปกติเมื่อเครื่องนี้ไม่ได้อยู่ในโหมด Master',
      ),
      null => (
        Icons.info_outline_rounded,
        AppTheme.infoColor,
        'Master background host: ไม่รองรับ/ยังไม่ทราบสถานะ',
        'บน Android จะแสดงสถานะจริงจาก native service ส่วนแพลตฟอร์มอื่นอาจไม่รองรับ',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'รีเฟรชสถานะ',
            onPressed: _refreshMasterBackgroundHostStatus,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleDriveSection(bool isDark) {
    final googleDrive = ref.read(googleDriveBackupServiceProvider);
    final canUseGoogleDrive = googleDrive.isPlatformSupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 18,
              color: canUseGoogleDrive
                  ? AppTheme.primary
                  : (isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              'Google Drive',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          canUseGoogleDrive
              ? 'อัปโหลดไฟล์สำรองข้อมูลที่เข้ารหัสแล้วขึ้น appDataFolder ของ Google Drive'
              : 'รอบนี้รองรับ Google Drive บน Android, iOS และ macOS',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white12 : AppTheme.border,
            ),
          ),
          child: Text(
            _googleDriveEmail == null
                ? 'สถานะ: ยังไม่ได้เชื่อมต่อ'
                : 'เชื่อมต่อแล้ว: $_googleDriveEmail',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: canUseGoogleDrive && !_isConnectingGoogleDrive
                    ? _connectGoogleDrive
                    : null,
                icon: _isConnectingGoogleDrive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_outlined, size: 18),
                label: Text(
                  _isConnectingGoogleDrive
                      ? 'กำลังเชื่อมต่อ...'
                      : 'เชื่อมต่อ Google',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: canUseGoogleDrive && _googleDriveEmail != null
                  ? _disconnectGoogleDrive
                  : null,
              icon: const Icon(Icons.logout_outlined, size: 18),
              label: const Text('ยกเลิกการเชื่อมต่อ'),
            ),
            ElevatedButton.icon(
              onPressed:
                  canUseGoogleDrive &&
                      !_isUploadingGoogleDrive &&
                      _googleDriveEmail != null
                  ? () => _backupAndUploadToGoogleDrive(
                      settings: ref.read(settingsProvider),
                    )
                  : null,
              icon: _isUploadingGoogleDrive
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                _isUploadingGoogleDrive
                    ? 'กำลังอัปโหลด...'
                    : 'สำรองและอัปโหลดขึ้น Drive',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed:
                    canUseGoogleDrive &&
                        !_isDriveListLoading &&
                        !_isRestoringFromDrive &&
                        _googleDriveEmail != null
                    ? _browseAndRestoreFromDrive
                    : null,
                icon: _isDriveListLoading || _isRestoringFromDrive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text(
                  _isRestoringFromDrive
                      ? 'กำลังดาวน์โหลด...'
                      : _isDriveListLoading
                      ? 'กำลังโหลด...'
                      : 'ดูและกู้คืนจาก Drive',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _backupInfoRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : AppTheme.textSub,
            ),
          ),
        ),
      ],
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
                color: isDark ? Colors.white24 : AppTheme.border,
              ),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
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
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
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
      decoration: baseStyle.copyWith(labelText: label, prefixIcon: Icon(icon)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _applyRestore(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop(); // ปิด dialog ก่อน
    try {
      await applyRestoreInPlace(); // swap DB + rebuild ProviderScope
    } catch (e) {
      if (mounted) _showError('กู้คืนข้อมูลไม่สำเร็จ: $e');
    }
  }

  String _restoreTableLabel(String table) {
    switch (table) {
      case 'companies':
        return 'บริษัท';
      case 'branches':
        return 'สาขา';
      case 'warehouses':
        return 'คลัง';
      case 'products':
        return 'สินค้า';
      case 'customers':
        return 'ลูกค้า';
      case 'sales_orders':
        return 'ออเดอร์ขาย';
      case 'users':
        return 'ผู้ใช้';
      default:
        return table;
    }
  }

  Future<void> _showRestoreInspectionDialog(
    RestorePreparationResult result,
  ) async {
    final createdAt = DateTime.tryParse(result.manifest.createdAt)?.toLocal();
    final imageCount = result.inspection.productImageCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('ตรวจสอบ Backup ก่อนกู้คืน'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ระบบตรวจสอบไฟล์สำรองข้อมูลเรียบร้อยแล้ว กรุณาตรวจสอบจำนวนข้อมูลก่อนโหลดชุดข้อมูลนี้',
                ),
                const SizedBox(height: 16),
                _backupInfoRow(
                  label: 'ชุดข้อมูล',
                  value: result.manifest.companyName.isNotEmpty
                      ? result.manifest.companyName
                      : '-',
                  isDark: isDark,
                ),
                _backupInfoRow(
                  label: 'สร้างเมื่อ',
                  value: createdAt != null
                      ? _dateTimeFmt.format(createdAt)
                      : result.manifest.createdAt,
                  isDark: isDark,
                ),
                _backupInfoRow(
                  label: 'ไฟล์ในชุดสำรอง',
                  value:
                      '${result.manifest.fileCount} ไฟล์ • ${_formatBytes(result.manifest.totalBytes)}',
                  isDark: isDark,
                ),
                _backupInfoRow(
                  label: 'รูปสินค้า',
                  value: '$imageCount ไฟล์',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Text(
                  'จำนวนข้อมูลในฐานข้อมูลสำรอง',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                ...BackupService.trackedInspectionTables.map((table) {
                  final count = result.inspection.tableCounts[table] ?? 0;
                  return _backupInfoRow(
                    label: _restoreTableLabel(table),
                    value: NumberFormat.decimalPattern().format(count),
                    isDark: isDark,
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            onPressed: () => _applyRestore(context),
            icon: const Icon(Icons.refresh),
            label: const Text('โหลดข้อมูลที่กู้คืน'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _loadBackupMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastBackupPath = prefs.getString(_backupLastPathKey);
      final rawAt = prefs.getString(_backupLastAtKey);
      _lastBackupAt = rawAt == null ? null : DateTime.tryParse(rawAt);
      _lastBackupSize = prefs.getInt(_backupLastSizeKey);
    });
  }

  Future<void> _loadGoogleDriveConfig() async {
    final googleDrive = ref.read(googleDriveBackupServiceProvider);
    final lastEmail = await googleDrive.loadLastEmail();
    final session = await googleDrive.tryRestoreSession();
    if (!mounted) return;
    setState(() {
      _googleDriveEmail = session?.email ?? lastEmail;
    });
  }

  Future<void> _loadFactoryResetPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _skipSeedAfterFactoryReset =
          prefs.getBool(factoryResetSkipSeedKey) ?? false;
    });
  }

  Future<void> _setSkipSeedAfterFactoryReset(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(factoryResetSkipSeedKey, value);
    if (!mounted) return;
    setState(() => _skipSeedAfterFactoryReset = value);
  }

  Future<void> _persistBackupMetadata({
    required String path,
    required DateTime createdAt,
    required int outputSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupLastPathKey, path);
    await prefs.setString(_backupLastAtKey, createdAt.toIso8601String());
    await prefs.setInt(_backupLastSizeKey, outputSize);
    if (!mounted) return;
    setState(() {
      _lastBackupPath = path;
      _lastBackupAt = createdAt;
      _lastBackupSize = outputSize;
    });
  }

  Future<void> _createEncryptedBackup(SettingsState settings) async {
    final passphrase = await _promptBackupPassphrase();
    if (passphrase == null || !mounted) return;

    final backupService = ref.read(backupServiceProvider);
    final suggestedPath = await backupService.pickBackupSavePath(
      now: DateTime.now(),
      companyName: settings.companyName,
    );
    if ((suggestedPath == null || suggestedPath.isEmpty) && mounted) {
      return;
    }

    setState(() => _isCreatingBackup = true);
    try {
      final result = await backupService.createEncryptedBackup(
        passphrase: passphrase,
        companyName: settings.companyName,
        outputPath: suggestedPath,
      );
      await _persistBackupMetadata(
        path: result.outputPath,
        createdAt: result.createdAt,
        outputSize: result.outputSize,
      );
      if (mounted) {
        _showSuccess('สำรองข้อมูลสำเร็จแล้ว: ${p.basename(result.outputPath)}');
      }
    } on BackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('ไม่สามารถสำรองข้อมูลได้: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreatingBackup = false);
      }
    }
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _isConnectingGoogleDrive = true);
    try {
      final googleDrive = ref.read(googleDriveBackupServiceProvider);
      final session = await googleDrive.signIn();
      if (!mounted) return;
      setState(() => _googleDriveEmail = session.email);
      _showSuccess('เชื่อมต่อ Google Drive แล้ว: ${session.email}');
    } on GoogleDriveBackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('เชื่อมต่อ Google Drive ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isConnectingGoogleDrive = false);
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    try {
      final googleDrive = ref.read(googleDriveBackupServiceProvider);
      await googleDrive.signOut();
      if (!mounted) return;
      setState(() => _googleDriveEmail = null);
      _showSuccess('ยกเลิกการเชื่อมต่อ Google Drive แล้ว');
    } catch (e) {
      if (mounted) _showError('ยกเลิกการเชื่อมต่อไม่สำเร็จ: $e');
    }
  }

  Future<void> _backupAndUploadToGoogleDrive({
    required SettingsState settings,
  }) async {
    final passphrase = await _promptBackupPassphrase();
    if (passphrase == null || !mounted) return;

    setState(() => _isUploadingGoogleDrive = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final result = await backupService.createEncryptedBackup(
        passphrase: passphrase,
        companyName: settings.companyName,
      );
      await _persistBackupMetadata(
        path: result.outputPath,
        createdAt: result.createdAt,
        outputSize: result.outputSize,
      );

      final googleDrive = ref.read(googleDriveBackupServiceProvider);
      final uploadResult = await googleDrive.uploadBackupFile(
        encryptedBackupFile: File(result.outputPath),
        manifest: result.manifest,
      );
      if (mounted) {
        _showSuccess(
          'อัปโหลดขึ้น Google Drive สำเร็จ: ${uploadResult.fileName}',
        );
      }
    } on BackupException catch (e) {
      if (mounted) _showError(e.message);
    } on GoogleDriveBackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('ไม่สามารถอัปโหลดขึ้น Google Drive ได้: $e');
    } finally {
      if (mounted) setState(() => _isUploadingGoogleDrive = false);
    }
  }

  Future<String?> _promptBackupPassphrase() async {
    final passphraseCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('ตั้งรหัสเข้ารหัสไฟล์สำรองข้อมูล'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passphraseCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'รหัสเข้ารหัส',
                        hintText: 'อย่างน้อย 8 ตัวอักษร',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setLocalState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 8) {
                          return 'กรุณาตั้งรหัสอย่างน้อย 8 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'ยืนยันรหัสเข้ารหัส',
                      ),
                      validator: (value) {
                        if ((value ?? '') != passphraseCtrl.text) {
                          return 'รหัสเข้ารหัสไม่ตรงกัน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'รหัสนี้จะไม่ถูกเก็บอัตโนมัติในระบบ เพื่อความปลอดภัย กรุณาเก็บไว้เอง',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : AppTheme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(passphraseCtrl.text.trim());
                    }
                  },
                  child: const Text('ถัดไป'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _browseAndRestoreFromDrive() async {
    setState(() => _isDriveListLoading = true);
    List<DriveBackupItem> items = [];
    try {
      final googleDrive = ref.read(googleDriveBackupServiceProvider);
      items = await googleDrive.listBackups();
    } on GoogleDriveBackupException catch (e) {
      if (mounted) _showError(e.message);
      return;
    } catch (e) {
      if (mounted) _showError('โหลดรายการไฟล์สำรองไม่สำเร็จ: $e');
      return;
    } finally {
      if (mounted) setState(() => _isDriveListLoading = false);
    }

    if (!mounted) return;

    final selectedItem = await showDialog<DriveBackupItem>(
      context: context,
      builder: (context) => _DriveBackupListDialog(
        items: items,
        formatBytes: _formatBytes,
        dateTimeFmt: _dateTimeFmt,
      ),
    );
    if (selectedItem == null || !mounted) return;

    final passphrase = await _promptRestorePassphrase();
    if (passphrase == null || !mounted) return;

    setState(() => _isRestoringFromDrive = true);
    try {
      final googleDrive = ref.read(googleDriveBackupServiceProvider);
      final tempFile = await googleDrive.downloadBackup(
        fileId: selectedItem.fileId,
        fileName: selectedItem.fileName,
      );

      final backupService = ref.read(backupServiceProvider);
      late RestorePreparationResult result;
      try {
        result = await backupService.prepareRestore(
          encryptedBackupFile: tempFile,
          passphrase: passphrase,
        );
      } finally {
        if (tempFile.existsSync()) await tempFile.delete();
      }

      if (!mounted) return;
      await _showRestoreInspectionDialog(result);
    } on BackupException catch (e) {
      if (mounted) _showError(e.message);
    } on GoogleDriveBackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('กู้คืนข้อมูลจาก Drive ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isRestoringFromDrive = false);
    }
  }

  Future<String?> _promptRestorePassphrase() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('ใส่รหัสเข้ารหัสไฟล์สำรองข้อมูล'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'รหัสเข้ารหัส',
                  suffixIcon: IconButton(
                    onPressed: () => setLocalState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ใส่รหัสที่ใช้ตอนสร้างไฟล์สำรองข้อมูล',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : AppTheme.textSub,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.length >= 8) {
                  Navigator.of(context).pop(text);
                }
              },
              child: const Text('ถัดไป'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _prepareRestoreFlow() async {
    final backupService = ref.read(backupServiceProvider);
    final restorePath = await backupService.pickBackupRestorePath();
    if (restorePath == null || restorePath.isEmpty || !mounted) return;

    final passphrase = await _promptRestorePassphrase();
    if (passphrase == null || !mounted) return;

    setState(() => _isPreparingRestore = true);
    try {
      final result = await backupService.prepareRestore(
        encryptedBackupFile: File(restorePath),
        passphrase: passphrase,
      );
      if (!mounted) return;
      await _showRestoreInspectionDialog(result);
    } on BackupException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('ไม่สามารถเตรียมกู้คืนข้อมูลได้: $e');
    } finally {
      if (mounted) {
        setState(() => _isPreparingRestore = false);
      }
    }
  }

  Future<void> _confirmFactoryReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การดำเนินการนี้จะล้างฐานข้อมูล, รูปสินค้า, backup ในเครื่อง และ session ปัจจุบันทั้งหมด',
            ),
            const SizedBox(height: 12),
            Text(
              _skipSeedAfterFactoryReset
                  ? 'เปิดโหมด Skip seed อยู่: หลังรีเซ็ต แอปจะไม่สร้างข้อมูลตั้งต้นและจะไม่มีผู้ใช้เริ่มต้นจนกว่าจะ restore backup'
                  : 'ปิดโหมด Skip seed อยู่: หลังรีเซ็ต แอปจะสร้างข้อมูลตั้งต้นและผู้ใช้เริ่มต้นกลับมาใหม่',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ล้างข้อมูลทั้งหมด'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isFactoryResetting = true);
    try {
      await factoryResetInPlace(skipSeedAfterReset: _skipSeedAfterFactoryReset);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
    } catch (e) {
      if (mounted) _showError('Factory reset ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isFactoryResetting = false);
    }
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final decimals = unitIndex == 0 ? 0 : 2;
    return '${size.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }
}

// ─────────────────────────────────────────────────────────────────
// _DriveBackupListDialog — แสดงรายการไฟล์สำรองบน Drive
// ─────────────────────────────────────────────────────────────────
class _DriveBackupListDialog extends StatelessWidget {
  final List<DriveBackupItem> items;
  final String Function(int bytes) formatBytes;
  final DateFormat dateTimeFmt;

  const _DriveBackupListDialog({
    required this.items,
    required this.formatBytes,
    required this.dateTimeFmt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.cloud_outlined, color: Color(0xFF1A73E8), size: 22),
          SizedBox(width: 10),
          Text('ไฟล์สำรองบน Google Drive'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 480,
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'ไม่พบไฟล์สำรองข้อมูลบน Google Drive',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  DateTime? createdAt;
                  if (item.createdAt != null) {
                    createdAt = DateTime.tryParse(item.createdAt!);
                  }
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.backup_outlined,
                        color: Color(0xFF1A73E8),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.companyName?.isNotEmpty == true
                          ? item.companyName!
                          : item.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (createdAt != null)
                          Text(
                            dateTimeFmt.format(createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        Text(
                          '${item.fileName}  •  ${formatBytes(item.fileSize)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).pop(item),
                      child: const Text(
                        'กู้คืน',
                        style: TextStyle(color: Color(0xFF1A73E8)),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
      ],
    );
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
            child: const Icon(
              Icons.settings_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ตั้งค่าระบบ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.navy,
                ),
              ),
              Text(
                'จัดการการตั้งค่าทั้งหมด',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppTheme.textSub,
                ),
              ),
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
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
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
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : AppTheme.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.navy,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
