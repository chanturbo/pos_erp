import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ResponsivePreset { mobile, tablet, desktop }

enum PdfReportType {
  apInvoice,
  apPayment,
  customerList,
  productList,
  supplierList,
  stockBalance,
  stockMovementHistory,
  stockProductHistory,
  salesHistory,
  couponList,
  goodsReceipt,
  purchaseOrder,
  purchaseReturn,
}

class ResponsiveSettings {
  ResponsiveSettings._();

  static const double mobileMaxWidth = 599;
  static const double tabletMaxWidth = 1023;

  static double currentLogicalWidth() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    if (dispatcher.views.isEmpty) return 1200;
    final view = dispatcher.views.first;
    final ratio = view.devicePixelRatio == 0 ? 1.0 : view.devicePixelRatio;
    return view.physicalSize.width / ratio;
  }

  static ResponsivePreset presetForWidth(double width) {
    if (width <= mobileMaxWidth) return ResponsivePreset.mobile;
    if (width <= tabletMaxWidth) return ResponsivePreset.tablet;
    return ResponsivePreset.desktop;
  }

  static ResponsivePreset currentPreset() {
    return presetForWidth(currentLogicalWidth());
  }

  static int pick({
    required int mobile,
    required int tablet,
    required int desktop,
    double? width,
  }) {
    switch (presetForWidth(width ?? currentLogicalWidth())) {
      case ResponsivePreset.mobile:
        return mobile;
      case ResponsivePreset.tablet:
        return tablet;
      case ResponsivePreset.desktop:
        return desktop;
    }
  }

  static String keySuffix(ResponsivePreset preset) {
    switch (preset) {
      case ResponsivePreset.mobile:
        return 'mobile';
      case ResponsivePreset.tablet:
        return 'tablet';
      case ResponsivePreset.desktop:
        return 'desktop';
    }
  }

  static String label(ResponsivePreset preset) {
    switch (preset) {
      case ResponsivePreset.mobile:
        return 'Mobile';
      case ResponsivePreset.tablet:
        return 'Tablet';
      case ResponsivePreset.desktop:
        return 'Desktop';
    }
  }
}

class SettingsDefaults {
  SettingsDefaults._();

  static const int listPageSizeMobile = 20;
  static const int listPageSizeTablet = 50;
  static const int listPageSizeDesktop = 100;

  static const int dialogPageSizeMobile = 8;
  static const int dialogPageSizeTablet = 15;
  static const int dialogPageSizeDesktop = 20;

  static const int reportRowsPerPageMobile = 20;
  static const int reportRowsPerPageTablet = 28;
  static const int reportRowsPerPageDesktop = 32;
}

class SettingsStorage {
  SettingsStorage._();

  static Future<String> getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name')?.trim();
    if (companyName == null || companyName.isEmpty) {
      return 'บริษัท ทดสอบ POS จำกัด';
    }
    return companyName;
  }

  static Future<int> getReportRowsPerPage({double? width}) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getInt('report_rows_per_page');
    return ResponsiveSettings.pick(
      width: width,
      mobile:
          prefs.getInt('report_rows_per_page_mobile') ??
          legacy ??
          SettingsDefaults.reportRowsPerPageMobile,
      tablet:
          prefs.getInt('report_rows_per_page_tablet') ??
          legacy ??
          SettingsDefaults.reportRowsPerPageTablet,
      desktop:
          prefs.getInt('report_rows_per_page_desktop') ??
          legacy ??
          SettingsDefaults.reportRowsPerPageDesktop,
    );
  }

  static Future<int> getPdfReportRowsPerPage(
    PdfReportType report, {
    double? width,
  }) async {
    final baseRows = await getReportRowsPerPage(width: width);
    final maxSafeRows = switch (report) {
      PdfReportType.apInvoice => 16,
      PdfReportType.apPayment => 16,
      PdfReportType.stockBalance => 18,
      PdfReportType.stockMovementHistory => 18,
      PdfReportType.stockProductHistory => 18,
      PdfReportType.productList => 18,
      PdfReportType.couponList => 18,
      PdfReportType.goodsReceipt => 18,
      PdfReportType.purchaseOrder => 18,
      PdfReportType.purchaseReturn => 18,
      PdfReportType.salesHistory => 20,
      PdfReportType.customerList => 20,
      PdfReportType.supplierList => 20,
    };
    return baseRows.clamp(1, maxSafeRows);
  }
}
