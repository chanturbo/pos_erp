import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
// Permission Key Constants
// ─────────────────────────────────────────────────────────────────
class AppPermission {
  AppPermission._();

  static const dashboard      = 'dashboard';
  static const pos            = 'pos';
  static const salesHistory   = 'sales_history';
  static const promotions     = 'promotions';
  static const products       = 'products';
  static const stock          = 'stock';
  static const stockAdjust    = 'stock_adjust';
  static const customers      = 'customers';
  static const suppliers      = 'suppliers';
  static const purchaseOrder  = 'purchase';
  static const goodsReceipt   = 'goods_receipt';
  static const purchaseReturn = 'purchase_return';
  static const apInvoice      = 'ap_invoice';
  static const apPayment      = 'ap_payment';
  static const arInvoice      = 'ar_invoice';
  static const arReceipt      = 'ar_receipt';
  static const reports        = 'reports';
  static const customerDividend = 'customer_dividend';
  static const branch         = 'branch';
  static const sync           = 'sync';
  static const settings       = 'settings';
  static const rolePermissions = 'role_permissions';
  static const userManagement = 'user_management';

  static const all = [
    dashboard, pos, salesHistory, promotions,
    products, stock, stockAdjust,
    customers, suppliers,
    purchaseOrder, goodsReceipt, purchaseReturn,
    apInvoice, apPayment, arInvoice, arReceipt,
    reports, customerDividend, branch, sync, settings, rolePermissions, userManagement,
  ];
}

/// ชื่อภาษาไทยสำหรับแต่ละ permission key
const appPermissionLabels = <String, String>{
  AppPermission.dashboard:      'แดชบอร์ด',
  AppPermission.pos:            'หน้าขาย (POS)',
  AppPermission.salesHistory:   'รายการขาย',
  AppPermission.promotions:     'โปรโมชั่น',
  AppPermission.products:       'สินค้า',
  AppPermission.stock:          'สต๊อกสินค้า',
  AppPermission.stockAdjust:    'ปรับสต๊อก',
  AppPermission.customers:      'ลูกค้า',
  AppPermission.suppliers:      'ซัพพลายเออร์',
  AppPermission.purchaseOrder:  'ซื้อสินค้า',
  AppPermission.goodsReceipt:   'รับสินค้า',
  AppPermission.purchaseReturn: 'คืนสินค้า',
  AppPermission.apInvoice:      'ใบแจ้งหนี้ AP (ซัพฯ)',
  AppPermission.apPayment:      'จ่ายเงิน AP',
  AppPermission.arInvoice:      'ใบแจ้งหนี้ AR (ลูกค้า)',
  AppPermission.arReceipt:      'รับเงิน AR',
  AppPermission.reports:        'รายงาน',
  AppPermission.customerDividend: 'งวดปันผลลูกค้า',
  AppPermission.branch:         'จัดการสาขา',
  AppPermission.sync:           'การเชื่อมต่อ/ซิงก์',
  AppPermission.settings:       'ตั้งค่าระบบ',
  AppPermission.rolePermissions: 'จัดการสิทธิ์การใช้งาน',
  AppPermission.userManagement:  'จัดการผู้ใช้งาน',
};

/// กลุ่มของ permissions สำหรับแสดงผลในหน้าจัดการสิทธิ์
class PermissionGroup {
  final String label;
  final List<String> keys;
  const PermissionGroup(this.label, this.keys);
}

const appPermissionGroups = [
  PermissionGroup('หลัก', [AppPermission.dashboard]),
  PermissionGroup('การขาย', [
    AppPermission.pos,
    AppPermission.salesHistory,
    AppPermission.promotions,
  ]),
  PermissionGroup('สินค้า / คลัง', [
    AppPermission.products,
    AppPermission.stock,
    AppPermission.stockAdjust,
  ]),
  PermissionGroup('ผู้ติดต่อ', [
    AppPermission.customers,
    AppPermission.suppliers,
  ]),
  PermissionGroup('จัดซื้อ', [
    AppPermission.purchaseOrder,
    AppPermission.goodsReceipt,
    AppPermission.purchaseReturn,
  ]),
  PermissionGroup('บัญชี', [
    AppPermission.apInvoice,
    AppPermission.apPayment,
    AppPermission.arInvoice,
    AppPermission.arReceipt,
  ]),
  PermissionGroup('ระบบ', [
    AppPermission.reports,
    AppPermission.customerDividend,
    AppPermission.branch,
    AppPermission.sync,
    AppPermission.settings,
    AppPermission.rolePermissions,
    AppPermission.userManagement,
  ]),
];

// ─────────────────────────────────────────────────────────────────
// Role Info
// ─────────────────────────────────────────────────────────────────
class AppRoleInfo {
  final String roleId;
  final String label;
  final String description;
  const AppRoleInfo(this.roleId, this.label, this.description);
}

const appRoles = [
  AppRoleInfo('ADMIN',      'ผู้ดูแลระบบ',  'เข้าถึงได้ทุกหน้า ไม่สามารถแก้ไขสิทธิ์ได้'),
  AppRoleInfo('MANAGER',    'ผู้จัดการ',    'จัดการทั่วไปยกเว้นบางส่วน'),
  AppRoleInfo('CASHIER',    'แคชเชียร์',    'ขายสินค้าเท่านั้น'),
  AppRoleInfo('WAREHOUSE',  'คลังสินค้า',   'จัดการสินค้าและคลัง'),
  AppRoleInfo('ACCOUNTANT', 'บัญชี',        'ดูแลงานบัญชี AP/AR'),
];

// ─────────────────────────────────────────────────────────────────
// Default Permissions per Role
// ─────────────────────────────────────────────────────────────────
const defaultRolePermissions = <String, List<String>>{
  'ADMIN': AppPermission.all,
  'MANAGER': [
    AppPermission.dashboard,
    AppPermission.pos,
    AppPermission.salesHistory,
    AppPermission.promotions,
    AppPermission.products,
    AppPermission.stock,
    AppPermission.stockAdjust,
    AppPermission.customers,
    AppPermission.suppliers,
    AppPermission.purchaseOrder,
    AppPermission.goodsReceipt,
    AppPermission.purchaseReturn,
    AppPermission.apInvoice,
    AppPermission.apPayment,
    AppPermission.arInvoice,
    AppPermission.arReceipt,
    AppPermission.reports,
    AppPermission.customerDividend,
    AppPermission.branch,
    AppPermission.sync,
    AppPermission.settings,
    AppPermission.userManagement,
  ],
  'CASHIER': [
    AppPermission.pos,
  ],
  'WAREHOUSE': [
    AppPermission.products,
    AppPermission.stock,
    AppPermission.stockAdjust,
    AppPermission.goodsReceipt,
  ],
  'ACCOUNTANT': [
    AppPermission.apInvoice,
    AppPermission.apPayment,
    AppPermission.arInvoice,
    AppPermission.arReceipt,
    AppPermission.reports,
    AppPermission.customerDividend,
  ],
};

const _prefsKey = 'role_permissions_v1';

// ─────────────────────────────────────────────────────────────────
// RolePermissionsNotifier
// ─────────────────────────────────────────────────────────────────
class RolePermissionsNotifier
    extends AsyncNotifier<Map<String, List<String>>> {
  @override
  Future<Map<String, List<String>>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return _defaults();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    } catch (_) {
      return _defaults();
    }
  }

  Map<String, List<String>> _defaults() => defaultRolePermissions.map(
    (k, v) => MapEntry(k, List<String>.from(v)),
  );

  /// สลับ on/off permission สำหรับ role (ADMIN ไม่สามารถเปลี่ยนได้)
  Future<void> toggle(String roleId, String permission) async {
    if (roleId == 'ADMIN') return;
    final current = state.value ?? _defaults();
    final perms = List<String>.from(current[roleId] ?? []);
    if (perms.contains(permission)) {
      perms.remove(permission);
    } else {
      perms.add(permission);
    }
    final next = Map<String, List<String>>.from(current)..[roleId] = perms;
    await _persist(next);
    state = AsyncData(next);
  }

  /// คืนค่าเริ่มต้นสำหรับ role ที่ระบุ
  Future<void> resetRole(String roleId) async {
    if (roleId == 'ADMIN') return;
    final current = state.value ?? _defaults();
    final next = Map<String, List<String>>.from(current)
      ..[roleId] = List<String>.from(
        defaultRolePermissions[roleId] ?? [],
      );
    await _persist(next);
    state = AsyncData(next);
  }

  /// ตรวจสอบว่า roleId มีสิทธิ์ permission หรือไม่
  bool hasPermission(String? roleId, String permission) {
    if (roleId == null) return false;
    final upper = roleId.toUpperCase();
    // ADMIN มีสิทธิ์ทุกอย่างเสมอ
    if (upper == 'ADMIN') return true;
    final perms =
        state.value?[upper] ?? defaultRolePermissions[upper] ?? [];
    return perms.contains(permission);
  }

  Future<void> _persist(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(data));
  }
}

final rolePermissionsProvider = AsyncNotifierProvider<RolePermissionsNotifier,
    Map<String, List<String>>>(RolePermissionsNotifier.new);
