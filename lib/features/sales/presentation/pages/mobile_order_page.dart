import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../shared/services/mobile_scanner_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/mobile_config.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/pages/sync_status_page.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../inventory/data/models/stock_balance_model.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../pages/payment_page.dart';
import '../providers/cart_provider.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/hold_orders_dialog.dart';
import '../widgets/product_grid.dart';

class MobileOrderPage extends ConsumerStatefulWidget {
  const MobileOrderPage({super.key});

  @override
  ConsumerState<MobileOrderPage> createState() => _MobileOrderPageState();
}

class _MobileOrderPageState extends ConsumerState<MobileOrderPage> {
  static const _scanModePrefsPrefix = 'mobile_scan_mode';
  static const _productUsagePrefsPrefix = 'mobile_product_usage';
  static const _favoriteProductPrefsPrefix = 'mobile_favorite_products';
  static const _hideInactivePrefsPrefix = 'mobile_hide_inactive_products';
  static const _hideOutOfStockPrefsPrefix = 'mobile_hide_out_of_stock_products';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroupId;
  bool _hideInactiveProducts = true;
  bool _hideOutOfStockProducts = true;
  String? _lastScannedProductId;
  DateTime? _lastScannedAt;
  int _scanBurstCount = 0;
  String _scanDefaultMode = 'unit';
  Map<String, int> _productUsageCounts = const {};
  List<String> _favoriteProductIds = const [];
  String? _loadedFavoriteScope;
  bool _showMobileHeaderDetails = false;
  final ScrollController _productListController = ScrollController();
  bool _isProductListScrolled = false;

  static const _groupPalette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF5D4037),
    Color(0xFFAD1457),
  ];

  static const _groupIcons = <IconData>[
    Icons.local_drink_outlined,
    Icons.fastfood_outlined,
    Icons.icecream_outlined,
    Icons.shopping_basket_outlined,
    Icons.spa_outlined,
    Icons.kitchen_outlined,
    Icons.inventory_2_outlined,
    Icons.sell_outlined,
  ];

  @override
  void dispose() {
    _productListController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _productListController.addListener(() {
      final isScrolled = _productListController.hasClients &&
          _productListController.offset > 6;
      if (isScrolled != _isProductListScrolled && mounted) {
        setState(() => _isProductListScrolled = isScrolled);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMobilePreferences();
    });
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> src,
    Map<String, double> stockMap,
  ) {
    final filtered = src.where((p) {
      final matchesGroup =
          _selectedGroupId == null || p.groupId == _selectedGroupId;
      if (!matchesGroup) return false;
      if (_hideInactiveProducts && !p.isActive) return false;
      if (_hideOutOfStockProducts && (stockMap[p.productId] ?? 0) <= 0) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) return true;

      final q = _searchQuery.trim().toLowerCase();
      return p.productName.toLowerCase().contains(q) ||
          p.productCode.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
    }).toList();

    filtered.sort((a, b) {
      final usageCompare = (_productUsageCounts[b.productId] ?? 0).compareTo(
        _productUsageCounts[a.productId] ?? 0,
      );
      if (usageCompare != 0) return usageCompare;
      return a.productName.compareTo(b.productName);
    });

    return filtered;
  }

  int _groupSeed(String? groupId) {
    final key = (groupId == null || groupId.isEmpty) ? 'ungrouped' : groupId;
    return key.codeUnits.fold<int>(0, (sum, code) => sum + code);
  }

  String _prefsScopeKey() {
    final userId = ref.read(authProvider).user?.userId ?? 'guest';
    return '${AppModeConfig.deviceName}_$userId';
  }

  String _favoriteScopeKey({String? branchId}) {
    final resolvedBranchId =
        branchId ?? ref.read(selectedBranchProvider)?.branchId ?? 'unassigned';
    return '${_prefsScopeKey()}_$resolvedBranchId';
  }

  Future<void> _loadMobilePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _prefsScopeKey();
    final favoriteScope = _favoriteScopeKey();
    final mode = prefs.getString('${_scanModePrefsPrefix}_$scope');
    final usageRaw = prefs.getString('${_productUsagePrefsPrefix}_$scope');
    final hideInactive =
        prefs.getBool('${_hideInactivePrefsPrefix}_$scope') ?? true;
    final hideOutOfStock =
        prefs.getBool('${_hideOutOfStockPrefsPrefix}_$scope') ?? true;

    Map<String, int> usage = const {};
    List<String> favorites = const [];
    if (usageRaw != null && usageRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(usageRaw) as Map<String, dynamic>;
        usage = decoded.map(
          (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
        );
      } catch (_) {
        usage = const {};
      }
    }
    favorites = _decodeFavoriteIds(
      prefs.getString('${_favoriteProductPrefsPrefix}_$favoriteScope'),
    );

    if (!mounted) return;
    setState(() {
      _scanDefaultMode = mode ?? 'unit';
      _productUsageCounts = usage;
      _favoriteProductIds = favorites;
      _hideInactiveProducts = hideInactive;
      _hideOutOfStockProducts = hideOutOfStock;
      _loadedFavoriteScope = favoriteScope;
    });
  }

  List<String> _decodeFavoriteIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadFavoritePreferences({String? branchId}) async {
    final scope = _favoriteScopeKey(branchId: branchId);
    if (_loadedFavoriteScope == scope) return;

    final prefs = await SharedPreferences.getInstance();
    final favorites = _decodeFavoriteIds(
      prefs.getString('${_favoriteProductPrefsPrefix}_$scope'),
    );

    if (!mounted) return;
    setState(() {
      _favoriteProductIds = favorites;
      _loadedFavoriteScope = scope;
    });
  }

  Future<void> _persistFavoritePreferences(List<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _favoriteScopeKey();
    await prefs.setString(
      '${_favoriteProductPrefsPrefix}_$scope',
      jsonEncode(favorites),
    );
    _loadedFavoriteScope = scope;
  }

  Future<void> _persistScanDefaultMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_scanModePrefsPrefix}_${_prefsScopeKey()}',
      _scanDefaultMode,
    );
  }

  Future<void> _persistVisibilitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _prefsScopeKey();
    await prefs.setBool(
      '${_hideInactivePrefsPrefix}_$scope',
      _hideInactiveProducts,
    );
    await prefs.setBool(
      '${_hideOutOfStockPrefsPrefix}_$scope',
      _hideOutOfStockProducts,
    );
  }

  Future<void> _incrementProductUsage(String productId) async {
    final updated = Map<String, int>.from(_productUsageCounts);
    updated[productId] = (updated[productId] ?? 0) + 1;
    if (mounted) {
      setState(() {
        _productUsageCounts = updated;
      });
    } else {
      _productUsageCounts = updated;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_productUsagePrefsPrefix}_${_prefsScopeKey()}',
      jsonEncode(updated),
    );
  }

  Future<void> _toggleFavoriteProduct(String productId) async {
    final updated = List<String>.from(_favoriteProductIds);
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }

    setState(() {
      _favoriteProductIds = updated;
    });

    await _persistFavoritePreferences(updated);
  }

  Future<void> _reorderFavorites(int oldIndex, int newIndex) async {
    final updated = List<String>.from(_favoriteProductIds);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() {
      _favoriteProductIds = updated;
    });
    await _persistFavoritePreferences(updated);
  }

  Future<void> _feedbackSuccess() async {
    await SystemSound.play(SystemSoundType.click);
    await MobileConfig.hapticSuccess();
  }

  Future<void> _feedbackError() async {
    await SystemSound.play(SystemSoundType.alert);
    await MobileConfig.hapticError();
  }

  Future<void> _feedbackTap() async {
    await HapticFeedback.lightImpact();
  }

  Future<void> _feedbackSelection() async {
    await HapticFeedback.selectionClick();
  }

  Map<String, double> _currentStockMap() {
    final selectedWarehouse = ref.read(selectedWarehouseProvider);
    final stocks =
        ref.read(stockBalanceProvider).value ?? const <StockBalanceModel>[];
    return _buildStockMap(stocks, selectedWarehouse?.warehouseId);
  }

  bool _ensureStockAvailable(
    ProductModel product,
    double quantity,
    Map<String, double> stockMap,
  ) {
    if (!product.isStockControl || product.allowNegativeStock) return true;

    final qtyInCart = ref
        .read(cartProvider)
        .items
        .where((item) => item.productId == product.productId)
        .fold<double>(0, (sum, item) => sum + item.quantity);
    final available = stockMap[product.productId] ?? 0;
    final nextQty = qtyInCart + quantity;

    if (nextQty <= available) return true;
    if (!mounted) return false;

    _feedbackError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'สต๊อก ${product.productName} ไม่พอ คงเหลือ ${available.toStringAsFixed(0)} แต่จะใช้ ${nextQty.toStringAsFixed(nextQty % 1 == 0 ? 0 : 2)}',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }

  ({double quantity, String label}) _scanQuantityForProduct(
    ProductModel product,
  ) {
    if (_scanDefaultMode == 'pack') {
      final pack = product.unitConversions.firstWhere(
        (unit) => unit.unit.contains('แพ็ค') || unit.unit.contains('pack'),
        orElse: () => product.unitConversions.isNotEmpty
            ? product.unitConversions.first
            : ProductUnitOption(unit: product.baseUnit, factor: 1),
      );
      return (quantity: pack.factor, label: pack.unit);
    }

    if (_scanDefaultMode == 'case') {
      final sorted = [...product.unitConversions]
        ..sort((a, b) => b.factor.compareTo(a.factor));
      final caseUnit = sorted.firstWhere(
        (unit) => unit.unit.contains('ลัง') || unit.unit.contains('case'),
        orElse: () => sorted.isNotEmpty
            ? sorted.first
            : ProductUnitOption(unit: product.baseUnit, factor: 1),
      );
      return (quantity: caseUnit.factor, label: caseUnit.unit);
    }

    return (quantity: 1, label: product.baseUnit);
  }

  ({
    ProductModel product,
    double quantity,
    String label,
    bool matchedByUnitBarcode,
  })?
  _matchScannedProduct(String value, List<ProductModel> products) {
    final normalized = value.trim().toLowerCase();

    for (final product in products) {
      if ((product.barcode?.trim().toLowerCase() == normalized) ||
          product.productCode.trim().toLowerCase() == normalized) {
        final config = _scanQuantityForProduct(product);
        return (
          product: product,
          quantity: config.quantity,
          label: config.label,
          matchedByUnitBarcode: false,
        );
      }

      for (final unit in product.unitConversions) {
        final unitBarcode = unit.barcode?.trim().toLowerCase();
        if (unitBarcode != null &&
            unitBarcode.isNotEmpty &&
            unitBarcode == normalized) {
          return (
            product: product,
            quantity: unit.factor,
            label: unit.unit,
            matchedByUnitBarcode: true,
          );
        }
      }
    }

    return null;
  }

  Future<void> _selectCustomer() async {
    final result = await showDialog<CustomerModel?>(
      context: context,
      builder: (_) => const CustomerSelectorDialog(),
    );
    if (result == null) return;

    final notifier = ref.read(cartProvider.notifier);
    final newLevel = result.priceLevel;

    if (notifier.hasItemsWithDifferentLevel(newLevel) && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('อัปเดตราคาสินค้า'),
          content: Text(
            'ลูกค้า "${result.customerName}" ใช้ระดับราคา Level $newLevel ต้องการคำนวณราคาสินค้าในตะกร้าใหม่ด้วยไหม?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('คงราคาเดิม'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('อัปเดทราคา'),
            ),
          ],
        ),
      );

      notifier.setCustomer(
        result.customerId,
        result.customerName,
        priceLevel: newLevel,
      );
      if (confirm == true) {
        notifier.repriceItems();
      }
      return;
    }

    notifier.setCustomer(
      result.customerId,
      result.customerName,
      priceLevel: newLevel,
    );
  }

  void _addProduct(
    ProductModel product, {
    bool fromScan = false,
    double quantity = 1,
  }) {
    final priceLevel = ref.read(cartProvider).customerPriceLevel;
    final lookup = getPriceByLevel(product, priceLevel);

    ref
        .read(cartProvider.notifier)
        .addItem(
          productId: product.productId,
          productCode: product.productCode,
          productName: product.productName,
          unit: product.baseUnit,
          unitPrice: lookup.price,
          quantity: quantity,
          groupId: product.groupId,
          priceLevel1: product.priceLevel1,
          priceLevel2: product.priceLevel2,
          priceLevel3: product.priceLevel3,
          priceLevel4: product.priceLevel4,
          priceLevel5: product.priceLevel5,
        );
    _incrementProductUsage(product.productId);
    _feedbackSuccess();

    if (!fromScan || !mounted) return;

    final now = DateTime.now();
    final isSameBurst =
        _lastScannedProductId == product.productId &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!).inSeconds <= 2;
    _lastScannedProductId = product.productId;
    _lastScannedAt = now;
    _scanBurstCount = isSameBurst ? _scanBurstCount + 1 : 1;

    final currentQty = ref
        .read(cartProvider)
        .items
        .where((item) => item.productId == product.productId)
        .fold<double>(0, (sum, item) => sum + item.quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _scanBurstCount > 1
              ? 'สแกน ${product.productName} ต่อเนื่อง x$_scanBurstCount รวมในบิล ${currentQty.toStringAsFixed(currentQty % 1 == 0 ? 0 : 2)}'
              : 'เพิ่ม ${product.productName} เข้าบิลแล้ว',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  bool _shouldPromptQuantityOnScan(
    ProductModel product, {
    required bool matchedByUnitBarcode,
  }) {
    if (matchedByUnitBarcode) return false;
    if (product.unitConversions.length > 1) return true;
    return product.unitConversions.any((unit) => unit.factor > 1);
  }

  ProductGroupModel? _groupFor(String? groupId) {
    if (groupId == null || groupId.isEmpty) return null;
    final groups = ref.read(productGroupsProvider).value ?? const [];
    for (final group in groups) {
      if (group.groupId == groupId) return group;
    }
    return null;
  }

  Color _parseConfiguredColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return Colors.transparent;
    final value = raw.trim();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6 || hex.length == 8) {
        final normalized = hex.length == 6 ? 'FF$hex' : hex;
        final parsed = int.tryParse(normalized, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }

    switch (value.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'deeppurple':
      case 'deep_purple':
        return Colors.deepPurple;
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'lightblue':
      case 'light_blue':
        return Colors.lightBlue;
      case 'cyan':
        return Colors.cyan;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'lightgreen':
        return Colors.lightGreen;
      case 'lime':
        return Colors.lime;
      case 'yellow':
        return Colors.yellow;
      case 'amber':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'deeporange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      case 'bluegrey':
      case 'blue_gray':
        return Colors.blueGrey;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return Colors.transparent;
    }
  }

  IconData _iconFromKey(String? key) {
    switch (key?.trim().toLowerCase()) {
      case 'apps':
        return Icons.apps_rounded;
      case 'inventory':
        return Icons.inventory_outlined;
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'shopping_basket':
        return Icons.shopping_basket_outlined;
      case 'sell':
        return Icons.sell_outlined;
      case 'local_drink':
        return Icons.local_drink_outlined;
      case 'fastfood':
        return Icons.fastfood_outlined;
      case 'icecream':
        return Icons.icecream_outlined;
      case 'kitchen':
        return Icons.kitchen_outlined;
      case 'spa':
        return Icons.spa_outlined;
      case 'bakery_dining':
        return Icons.bakery_dining_outlined;
      case 'lunch_dining':
        return Icons.lunch_dining_outlined;
      case 'local_cafe':
        return Icons.local_cafe_outlined;
      case 'storefront':
        return Icons.storefront_outlined;
      case 'pets':
        return Icons.pets_outlined;
      case 'medication':
        return Icons.medication_outlined;
      case 'cleaning_services':
        return Icons.cleaning_services_outlined;
      default:
        return _groupIcon(null);
    }
  }

  Color _groupColor(String? groupId) {
    final configured = _parseConfiguredColor(_groupFor(groupId)?.mobileColor);
    if (configured != Colors.transparent) return configured;
    final index = _groupSeed(groupId) % _groupPalette.length;
    return _groupPalette[index];
  }

  IconData _groupIcon(String? groupId) {
    final configured = _groupFor(groupId)?.mobileIcon;
    if (configured != null && configured.trim().isNotEmpty) {
      return _iconFromKey(configured);
    }
    final index = _groupSeed(groupId) % _groupIcons.length;
    return _groupIcons[index];
  }

  Future<void> _promptAddProduct(
    ProductModel product, {
    double initialQuantity = 1,
    String? helperText,
    bool fromScan = false,
  }) async {
    final qty = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QuantityPickerSheet(
        product: product,
        color: _groupColor(product.groupId),
        initialQuantity: initialQuantity,
        helperText: helperText,
      ),
    );
    if (qty == null || qty <= 0) return;
    final stockMap = _currentStockMap();
    if (!_ensureStockAvailable(product, qty, stockMap)) return;
    _addProduct(product, quantity: qty, fromScan: fromScan);
  }

  Future<void> _scanAndSearch() async {
    final result = await MobileScannerService.scan(context);
    if (result == null) return;
    _handleScannedValue(result.value);
  }

  Future<void> _handleScannedValue(String value) async {
    final products =
        ref.read(productListProvider).value ?? const <ProductModel>[];
    final matched = _matchScannedProduct(value, products);

    if (matched != null) {
      if (_shouldPromptQuantityOnScan(
        matched.product,
        matchedByUnitBarcode: matched.matchedByUnitBarcode,
      )) {
        await _promptAddProduct(
          matched.product,
          fromScan: true,
          initialQuantity: matched.quantity,
          helperText:
              'สินค้านี้มีหลายหน่วยขาย ระบบจึงให้ยืนยันจำนวนก่อนเพิ่มจากการสแกน ${matched.label}',
        );
        return;
      }

      final stockMap = _currentStockMap();
      if (!_ensureStockAvailable(matched.product, matched.quantity, stockMap)) {
        return;
      }
      _addProduct(matched.product, fromScan: true, quantity: matched.quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'สแกนเข้า ${matched.label} (${matched.quantity.toStringAsFixed(matched.quantity % 1 == 0 ? 0 : 2)} ${matched.product.baseUnit})',
            ),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
      return;
    }

    setState(() {
      _searchQuery = value;
      _searchController.text = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ไม่พบรหัสตรงตัว จึงค้นหา "$value" ให้แทน'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _openContinuousScanner() async {
    await MobileScannerService.openContinuous(
      context,
      onScanned: (result) => _handleScannedValue(result.value),
    );
  }

  Future<void> _openEmployeeSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Text(
                  'ตั้งค่ามือถือพนักงาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  ref.read(authProvider).user?.fullName ??
                      AppModeConfig.deviceName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('โหมดสแกนเริ่มต้น'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'unit', label: Text('1')),
                    ButtonSegment<String>(value: 'pack', label: Text('แพ็ก')),
                    ButtonSegment<String>(value: 'case', label: Text('ลัง')),
                  ],
                  selected: {_scanDefaultMode},
                  onSelectionChanged: (selection) {
                    final next = selection.first;
                    setState(() => _scanDefaultMode = next);
                    setSheetState(() {});
                    _persistScanDefaultMode();
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ซ่อนสินค้าไม่ active'),
                  value: _hideInactiveProducts,
                  onChanged: (value) {
                    setState(() => _hideInactiveProducts = value);
                    setSheetState(() {});
                    _persistVisibilitySettings();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ซ่อนสินค้าหมดสต๊อก'),
                  value: _hideOutOfStockProducts,
                  onChanged: (value) {
                    setState(() => _hideOutOfStockProducts = value);
                    setSheetState(() {});
                    _persistVisibilitySettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFavoriteManager(List<ProductModel> products) async {
    final favorites = _favoriteProductIds
        .map(
          (id) =>
              products.where((product) => product.productId == id).firstOrNull,
        )
        .whereType<ProductModel>()
        .toList();
    if (favorites.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'จัดเรียงปุ่มขายด่วน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: favorites.length,
                  onReorder: _reorderFavorites,
                  itemBuilder: (_, index) {
                    final product = favorites[index];
                    final color = _groupColor(product.groupId);
                    return ListTile(
                      key: ValueKey(product.productId),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(_groupIcon(product.groupId), color: color),
                      ),
                      title: Text(product.productName),
                      subtitle: Text(product.productCode),
                      trailing: const Icon(Icons.drag_handle),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _holdCurrentOrder() async {
    await _feedbackSelection();
    if (!mounted) return;
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีสินค้าในบิลสำหรับพักบิล')),
      );
      return;
    }

    final ctrl = TextEditingController(
      text:
          cartState.customerName != null &&
              cartState.customerName != 'ลูกค้าทั่วไป'
          ? 'บิล ${cartState.customerName}'
          : 'บิล ${TimeOfDay.now().format(context)}',
    );

    final holdName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('พักบิล'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อบิลที่พัก',
            hintText: 'เช่น โต๊ะ 3 / ลูกค้ารอจ่าย',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('พักบิล'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (holdName == null || holdName.trim().isEmpty) return;

    ref.read(cartProvider.notifier).hold(holdName.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('พักบิล "$holdName" แล้ว')));
  }

  Future<void> _openHeldOrders() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const HoldOrdersDialog(),
    );
  }

  Future<void> _openOrderSummarySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobileOrderSummarySheet(),
    );
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobileCartSheet(),
    );
  }

  Future<void> _goToCheckout() async {
    await _feedbackTap();
    if (!mounted) return;
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;
    if (ref.read(selectedBranchProvider) == null ||
        ref.read(selectedWarehouseProvider) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสาขาและคลังของเครื่องนี้ก่อนเปิดบิลจริง'),
          backgroundColor: Colors.orange,
        ),
      );
      await _openConnectionSettings();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );
  }

  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(productListProvider.notifier).refresh(),
      ref.read(customerListProvider.notifier).refresh(),
      ref.read(branchListProvider.notifier).refresh(),
      ref.read(warehouseListProvider.notifier).refresh(),
    ]);
    ref.invalidate(syncStatusProvider);
    ref.invalidate(connectionStatusProvider);
  }

  Future<void> _openConnectionSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncStatusPage()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text(
          'ต้องการออกจากระบบจากเครื่องรับออเดอร์นี้ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
  }

  String _groupNameOf(String? groupId) {
    if (groupId == null || groupId.isEmpty) return 'ไม่ระบุหมวด';
    final groups = ref.read(productGroupsProvider).value ?? const [];
    for (final group in groups) {
      if (group.groupId == groupId) return group.groupName;
    }
    return 'หมวดสินค้า';
  }

  void _showProductMetaSheet(
    ProductModel product, {
    required PriceLookupResult lookup,
    required double availableStock,
    required double qtyInCart,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                product.productName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CompactStatusChip(
                    icon: Icons.qr_code_2_rounded,
                    label: product.productCode,
                    color: AppTheme.primaryColor,
                  ),
                  _CompactStatusChip(
                    icon: Icons.category_outlined,
                    label: _groupNameOf(product.groupId),
                    color: _groupColor(product.groupId),
                  ),
                  _CompactStatusChip(
                    icon: availableStock > 0
                        ? Icons.inventory_2_outlined
                        : Icons.inventory_2_rounded,
                    label: availableStock > 0
                        ? 'คงเหลือ ${availableStock.toStringAsFixed(0)}'
                        : 'หมดสต๊อก',
                    color: availableStock > 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  if (qtyInCart > 0)
                    _CompactStatusChip(
                      icon: Icons.shopping_bag_outlined,
                      label:
                          'ในบิล ${qtyInCart.toStringAsFixed(qtyInCart % 1 == 0 ? 0 : 2)}',
                      color: AppTheme.successColor,
                    ),
                  if (!product.isActive)
                    const _CompactStatusChip(
                      icon: Icons.hide_source,
                      label: 'Inactive',
                      color: Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'ราคาขาย ฿${lookup.price.toStringAsFixed(2)} / ${product.baseUnit}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              if (lookup.isFallback) ...[
                const SizedBox(height: 8),
                Text(
                  'ราคา Level ที่เลือกยังไม่ได้ตั้งค่า ระบบจึงใช้ราคา Level 1 แทน',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(posContextBootstrapProvider);

    final productAsync = ref.watch(productListProvider);
    final productGroupsAsync = ref.watch(productGroupsProvider);
    final stockAsync = ref.watch(stockBalanceProvider);
    final cartState = ref.watch(cartProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final holdOrdersState = ref.watch(holdOrdersProvider);
    final syncValue = syncAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final authState = ref.watch(authProvider);
    final stockMap = stockAsync.maybeWhen(
      data: (stocks) => _buildStockMap(stocks, selectedWarehouse?.warehouseId),
      orElse: () => const <String, double>{},
    );
    final isReadyForCheckout =
        cartState.items.isNotEmpty &&
        selectedBranch != null &&
        selectedWarehouse != null;

    final expectedFavoriteScope = _favoriteScopeKey(
      branchId: selectedBranch?.branchId,
    );
    if (_loadedFavoriteScope != expectedFavoriteScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFavoritePreferences(branchId: selectedBranch?.branchId);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'ออกจากระบบ',
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mobile Order'),
            Text(
              authState.user?.fullName ?? AppModeConfig.deviceName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'บิลที่พัก',
                onPressed: _openHeldOrders,
                icon: const Icon(Icons.pause_circle_outline_rounded),
              ),
              if (holdOrdersState.orders.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${holdOrdersState.orders.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                    ),
                ],
              ),
          PopupMenuButton<String>(
            tooltip: 'ตัวเลือกเพิ่มเติม',
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  _openEmployeeSettings();
                  break;
                case 'refresh':
                  _refreshData();
                  break;
                case 'connection':
                  _openConnectionSettings();
                  break;
                case 'summary':
                  _openOrderSummarySheet();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('ตั้งค่ามือถือ'),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Text('รีเฟรชข้อมูล'),
              ),
              const PopupMenuItem<String>(
                value: 'connection',
                child: Text('การเชื่อมต่อ/ซิงก์'),
              ),
              if (cartState.items.isNotEmpty)
                const PopupMenuItem<String>(
                  value: 'summary',
                  child: Text('สรุปออเดอร์'),
                ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Theme.of(context).cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(
                    () => _showMobileHeaderDetails = !_showMobileHeaderDetails,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColorOf(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cartState.customerName ?? 'ลูกค้าทั่วไป',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'สินค้า ${cartState.items.fold<double>(0, (sum, item) => sum + item.quantity).toStringAsFixed(0)} • บิลพัก ${holdOrdersState.orders.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showMobileHeaderDetails
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _showMobileHeaderDetails
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _selectCustomer,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColorOf(context),
                            ),
                            color: AppTheme.primary.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cartState.customerName ?? 'ลูกค้าทั่วไป',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'แตะเพื่อเลือกลูกค้าสำหรับเปิดบิล',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.subtextColorOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      connectionAsync.when(
                  data: (connection) => InkWell(
                    onTap: _openConnectionSettings,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: connection.isConnected
                            ? AppTheme.successColor.withValues(alpha: 0.08)
                            : AppTheme.errorColor.withValues(alpha: 0.08),
                        border: Border.all(
                          color: connection.isConnected
                              ? AppTheme.successColor.withValues(alpha: 0.24)
                              : AppTheme.errorColor.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            connection.isConnected
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 18,
                            color: connection.isConnected
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              connection.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: connection.isConnected
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                          ),
                          if ((syncValue?.pendingCount ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'รอส่ง ${syncValue!.pendingCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                      const SizedBox(height: 10),
                      Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CompactStatusChip(
                      icon: Icons.pause_circle_outline,
                      label: 'บิลพัก ${holdOrdersState.orders.length}',
                      color: Colors.orange,
                    ),
                    _CompactStatusChip(
                      icon: Icons.shopping_bag_outlined,
                      label:
                          'สินค้า ${cartState.items.fold<double>(0, (sum, item) => sum + item.quantity).toStringAsFixed(0)}',
                      color: AppTheme.primaryColor,
                    ),
                    _CompactStatusChip(
                      icon: Icons.sync_problem_outlined,
                      label: 'รอส่ง ${syncValue?.pendingCount ?? 0}',
                      color: Colors.teal,
                    ),
                  ],
                ),
                      const SizedBox(height: 10),
                      if (_favoriteProductIds.isNotEmpty)
                        productAsync.maybeWhen(
                          data: (products) {
                            final favorites = _favoriteProductIds
                                .map(
                                  (id) => products
                                      .where(
                                        (product) => product.productId == id,
                                      )
                                      .firstOrNull,
                                )
                                .whereType<ProductModel>()
                                .toList();

                            if (favorites.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'ปุ่มขายด่วน',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _openFavoriteManager(products),
                                      icon: const Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                      ),
                                      label: const Text('จัดเรียง'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 44,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: favorites.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) {
                                      final product = favorites[index];
                                      final color = _groupColor(product.groupId);
                                      return FilledButton.tonal(
                                        onPressed: () =>
                                            _promptAddProduct(product),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: color.withValues(
                                            alpha: 0.12,
                                          ),
                                          foregroundColor: color,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _groupIcon(product.groupId),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(product.productName),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.storefront_outlined,
                              label:
                                  selectedBranch?.branchName ??
                                  'ยังไม่ได้เลือกสาขา',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.warehouse_outlined,
                              label:
                                  selectedWarehouse?.warehouseName ??
                                  'ยังไม่ได้เลือกคลัง',
                            ),
                          ),
                        ],
                      ),
                      if (selectedBranch == null || selectedWarehouse == null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _openConnectionSettings,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.orange.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'ตั้งค่าสาขาและคลังของเครื่องนี้ก่อน เพื่อให้บิลถูกบันทึกลงปลายทางที่ถูกต้อง',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isProductListScrolled
                          ? AppTheme.primaryColor.withValues(alpha: 0.24)
                          : AppTheme.borderColorOf(context).withValues(alpha: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isProductListScrolled ? 0.10 : 0.06,
                        ),
                        blurRadius: _isProductListScrolled ? 22 : 16,
                        spreadRadius: _isProductListScrolled ? 0.5 : 0,
                        offset: Offset(0, _isProductListScrolled ? 8 : 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'ค้นหาสินค้า / บาร์โค้ด',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _scanAndSearch,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(52, 52),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.fullscreen),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _openContinuousScanner,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(52, 52),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.qr_code_scanner),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      productGroupsAsync.when(
                        data: (groups) => SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  selected: _selectedGroupId == null,
                                  backgroundColor: Colors.transparent,
                                  selectedColor:
                                      AppTheme.primaryColor.withValues(alpha: 0.12),
                                  side: BorderSide(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                  avatar: const Icon(Icons.apps_rounded, size: 18),
                                  label: const Text('ทั้งหมด'),
                                  onSelected: (_) {
                                    _feedbackSelection();
                                    setState(() => _selectedGroupId = null);
                                  },
                                ),
                              ),
                              for (final group in groups)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Builder(
                                    builder: (_) {
                                      final color = _groupColor(group.groupId);
                                      return FilterChip(
                                        selected:
                                            _selectedGroupId == group.groupId,
                                        backgroundColor: color.withValues(
                                          alpha: 0.08,
                                        ),
                                        selectedColor:
                                            color.withValues(alpha: 0.18),
                                        side: BorderSide(
                                          color: color.withValues(alpha: 0.28),
                                        ),
                                        avatar: Icon(
                                          _groupIcon(group.groupId),
                                          size: 18,
                                          color: color,
                                        ),
                                        label: Text(group.groupName),
                                        onSelected: (_) {
                                          _feedbackSelection();
                                          setState(() {
                                            _selectedGroupId =
                                                _selectedGroupId == group.groupId
                                                ? null
                                                : group.groupId;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _isProductListScrolled ? 1 : 0.92,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedGroupId != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'กำลังกรองตามหมวดสินค้า',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedGroupId = null),
                              child: const Text('ล้าง'),
                            ),
                          ],
                        ),
                            ],
                            if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ค้นหา "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtextColorOf(context),
                          ),
                        ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  selected: _hideInactiveProducts,
                                  label: const Text('ซ่อนสินค้าไม่ active'),
                                  onSelected: (value) {
                                    _feedbackSelection();
                                    setState(() => _hideInactiveProducts = value);
                                  },
                                ),
                                FilterChip(
                                  selected: _hideOutOfStockProducts,
                                  label: const Text('ซ่อนสินค้าหมดสต๊อก'),
                                  onSelected: (value) {
                                    _feedbackSelection();
                                    setState(
                                      () => _hideOutOfStockProducts = value,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: productAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
              data: (products) {
                final filtered = _filterProducts(products, stockMap);
                if (filtered.isEmpty) {
                  return const Center(child: Text('ไม่พบสินค้าที่ตรงเงื่อนไข'));
                }

                return ListView.separated(
                  controller: _productListController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final product = filtered[index];
                    final priceLevel = cartState.customerPriceLevel;
                    final lookup = getPriceByLevel(product, priceLevel);
                    final groupColor = _groupColor(product.groupId);
                    final availableStock = stockMap[product.productId] ?? 0;
                    final qtyInCart = cartState.items
                        .where((item) => item.productId == product.productId)
                        .fold<double>(0, (sum, item) => sum + item.quantity);
                    final screenWidth = MediaQuery.sizeOf(context).width;
                    final isCompactCard = screenWidth < 380;
                    final isRegularCard = !isCompactCard;

                    return Material(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _promptAddProduct(product),
                        onLongPress: () => _showProductMetaSheet(
                          product,
                          lookup: lookup,
                          availableStock: availableStock,
                          qtyInCart: qtyInCart,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isCompactCard ? 11 : 15),
                          child: Row(
                            children: [
                              Container(
                                width: isCompactCard ? 38 : 46,
                                height: isCompactCard ? 38 : 46,
                                decoration: BoxDecoration(
                                  color: groupColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _groupIcon(product.groupId),
                                  color: groupColor,
                                ),
                              ),
                              SizedBox(width: isCompactCard ? 10 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product.productName,
                                            maxLines: isCompactCard ? 1 : 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: isCompactCard ? 12.5 : 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _toggleFavoriteProduct(
                                                product.productId,
                                              ),
                                          icon: Icon(
                                            _favoriteProductIds.contains(
                                                  product.productId,
                                                )
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color:
                                                _favoriteProductIds.contains(
                                                  product.productId,
                                                )
                                                ? Colors.amber.shade700
                                                : Colors.grey.shade500,
                                          ),
                                          tooltip: 'ปักหมุดขายด่วน',
                                        ),
                                      ],
                                    ),
                                    if (isRegularCard) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        product.productCode,
                                        style: TextStyle(
                                          fontSize: isCompactCard ? 11 : 12,
                                          color: AppTheme.subtextColorOf(context),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: isCompactCard ? 3 : 4),
                                    Row(
                                      children: [
                                        if (isRegularCard && !product.isActive)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Inactive',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isCompactCard ? 6 : 8,
                                            vertical: isCompactCard ? 2 : 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: availableStock > 0
                                                ? AppTheme.successColor
                                                      .withValues(alpha: 0.12)
                                                : AppTheme.errorColor
                                                      .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            availableStock > 0
                                                ? isCompactCard
                                                    ? 'สต๊อก ${availableStock.toStringAsFixed(0)}'
                                                    : 'คงเหลือ ${availableStock.toStringAsFixed(0)}'
                                                : 'หมดสต๊อก',
                                            style: TextStyle(
                                              fontSize: isCompactCard ? 9.5 : 10,
                                              fontWeight: FontWeight.w700,
                                              color: availableStock > 0
                                                  ? AppTheme.successColor
                                                  : AppTheme.errorColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isRegularCard && product.groupId != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: groupColor.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          productGroupsAsync.maybeWhen(
                                            data: (groups) =>
                                                groups
                                                    .where(
                                                      (group) =>
                                                          group.groupId ==
                                                          product.groupId,
                                                    )
                                                    .firstOrNull
                                                    ?.groupName ??
                                                'หมวดสินค้า',
                                            orElse: () => 'หมวดสินค้า',
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: groupColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          '฿${lookup.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: isCompactCard ? 12.5 : 14,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (lookup.isFallback) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'ใช้ราคา Lv.1',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isCompactCard && qtyInCart > 0) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'ในบิล ${qtyInCart.toStringAsFixed(qtyInCart % 1 == 0 ? 0 : 2)}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.successColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  if (isRegularCard && qtyInCart > 0)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'ในบิล ${qtyInCart.toStringAsFixed(qtyInCart % 1 == 0 ? 0 : 2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.successColor,
                                        ),
                                      ),
                                    ),
                                  FilledButton(
                                    onPressed: () {
                                      _feedbackTap();
                                      _promptAddProduct(product);
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: groupColor,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompactCard ? 10 : 16,
                                        vertical: isCompactCard ? 0 : 2,
                                      ),
                                      minimumSize: Size(0, isCompactCard ? 34 : 38),
                                    ),
                                    child: const Text('เพิ่ม'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 16,
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: cartState.items.isEmpty
                            ? null
                            : () {
                                _feedbackTap();
                                _openCartSheet();
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColorOf(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ตะกร้า ${cartState.itemCount} รายการ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      cartState.items.isEmpty
                                          ? 'ยังไม่มีสินค้าในบิล'
                                          : 'ยอดรวม ฿${cartState.total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.subtextColorOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: cartState.items.isEmpty ? null : _holdCurrentOrder,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 56),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.pause_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isReadyForCheckout ? _goToCheckout : null,
                    icon: Icon(
                      selectedBranch == null || selectedWarehouse == null
                          ? Icons.settings_ethernet_rounded
                          : Icons.receipt_long_outlined,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    label: Text(
                      selectedBranch == null || selectedWarehouse == null
                          ? 'ตั้งค่าสาขา/คลังก่อนชำระเงิน'
                          : 'ชำระเงิน ฿${cartState.total.toStringAsFixed(2)}',
                    ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, double> _buildStockMap(
  List<StockBalanceModel> stocks,
  String? warehouseId,
) {
  final map = <String, double>{};
  for (final stock in stocks) {
    if (warehouseId != null && stock.warehouseId != warehouseId) continue;
    map[stock.productId] = (map[stock.productId] ?? 0) + stock.balance;
  }
  return map;
}

class _CompactStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCartSheet extends ConsumerWidget {
  const _MobileCartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (_, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'ตะกร้าสินค้า',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: cartState.items.isEmpty ? null : notifier.clear,
                    child: const Text('ล้างทั้งหมด'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cartState.items.isEmpty
                  ? const Center(child: Text('ยังไม่มีสินค้าในตะกร้า'))
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: cartState.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = cartState.items[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColorOf(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '฿${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    onPressed: () => notifier.decreaseQuantity(
                                      item.productId,
                                    ),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: Center(
                                      child: Text(
                                        item.quantity.toStringAsFixed(
                                          item.quantity % 1 == 0 ? 0 : 2,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton.filled(
                                    onPressed: () => notifier.increaseQuantity(
                                      item.productId,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '฿${item.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () =>
                                        notifier.removeItem(item.productId),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileOrderSummarySheet extends ConsumerWidget {
  const _MobileOrderSummarySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final groupsAsync = ref.watch(productGroupsProvider);

    final groupNames = groupsAsync.maybeWhen(
      data: (groups) => {
        for (final group in groups) group.groupId: group.groupName,
      },
      orElse: () => const <String, String>{},
    );
    final groupModels = groupsAsync.maybeWhen(
      data: (groups) => {for (final group in groups) group.groupId: group},
      orElse: () => const <String, ProductGroupModel>{},
    );

    final groupedItems = <String, List<CartItem>>{};
    final groupColors = <String, Color>{};
    for (final item in cartState.items) {
      final key = groupNames[item.groupId] ?? 'ไม่ระบุหมวด';
      groupedItems.putIfAbsent(key, () => []).add(item);
      groupColors.putIfAbsent(
        key,
        () => _summaryGroupColor(groupModels[item.groupId], item.groupId, key),
      );
    }

    final sortedEntries = groupedItems.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'สรุปออเดอร์ตามหมวดสินค้า',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${cartState.itemCount} รายการ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cartState.items.isEmpty
                  ? const Center(child: Text('ยังไม่มีสินค้าในบิล'))
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SummaryStatChip(
                              label: 'จำนวนชิ้นรวม',
                              value: cartState.items
                                  .fold<double>(
                                    0,
                                    (sum, item) => sum + item.quantity,
                                  )
                                  .toStringAsFixed(0),
                            ),
                            _SummaryStatChip(
                              label: 'ยอดรวม',
                              value: '฿${cartState.total.toStringAsFixed(2)}',
                            ),
                            _SummaryStatChip(
                              label: 'หมวดสินค้า',
                              value: '${sortedEntries.length}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final entry in sortedEntries)
                          _SummaryGroupCard(
                            title: entry.key,
                            items: entry.value,
                            color:
                                groupColors[entry.key] ?? AppTheme.primaryColor,
                          ),
                        if (cartState.freeItems.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppTheme.successColor.withValues(
                                alpha: 0.08,
                              ),
                              border: Border.all(
                                color: AppTheme.successColor.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ของแถม',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final item in cartState.freeItems)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(item.productName)),
                                        Text(
                                          '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.unit}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.primary.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.subtextColorOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGroupCard extends StatelessWidget {
  final String title;
  final List<CartItem> items;
  final Color color;

  const _SummaryGroupCard({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${items.length} รายการ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtextColorOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '฿${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            if (item != items.last) const Divider(height: 16),
          ],
        ],
      ),
    );
  }
}

Color _summaryGroupColor(
  ProductGroupModel? group,
  String? groupId,
  String fallbackKey,
) {
  final configured = _summaryConfiguredColor(group?.mobileColor);
  if (configured != null) return configured;
  final seedKey = groupId ?? fallbackKey;
  final index =
      seedKey.codeUnits.fold<int>(0, (sum, code) => sum + code) %
      _MobileOrderPageState._groupPalette.length;
  return _MobileOrderPageState._groupPalette[index];
}

Color? _summaryConfiguredColor(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('#')) {
    final hex = value.substring(1);
    if (hex.length == 6 || hex.length == 8) {
      final normalized = hex.length == 6 ? 'FF$hex' : hex;
      final parsed = int.tryParse(normalized, radix: 16);
      if (parsed != null) return Color(parsed);
    }
  }

  switch (value.toLowerCase()) {
    case 'red':
      return Colors.red;
    case 'pink':
      return Colors.pink;
    case 'purple':
      return Colors.purple;
    case 'deeppurple':
    case 'deep_purple':
      return Colors.deepPurple;
    case 'indigo':
      return Colors.indigo;
    case 'blue':
      return Colors.blue;
    case 'lightblue':
    case 'light_blue':
      return Colors.lightBlue;
    case 'cyan':
      return Colors.cyan;
    case 'teal':
      return Colors.teal;
    case 'green':
      return Colors.green;
    case 'lightgreen':
      return Colors.lightGreen;
    case 'lime':
      return Colors.lime;
    case 'yellow':
      return Colors.yellow;
    case 'amber':
      return Colors.amber;
    case 'orange':
      return Colors.orange;
    case 'deeporange':
    case 'deep_orange':
      return Colors.deepOrange;
    case 'brown':
      return Colors.brown;
    case 'bluegrey':
    case 'blue_gray':
      return Colors.blueGrey;
    case 'grey':
    case 'gray':
      return Colors.grey;
    default:
      return null;
  }
}

class _QuantityPickerSheet extends StatefulWidget {
  final ProductModel product;
  final Color color;
  final double initialQuantity;
  final String? helperText;

  const _QuantityPickerSheet({
    required this.product,
    required this.color,
    this.initialQuantity = 1,
    this.helperText,
  });

  @override
  State<_QuantityPickerSheet> createState() => _QuantityPickerSheetState();
}

class _QuantityPickerSheetState extends State<_QuantityPickerSheet> {
  late final TextEditingController _controller;
  double _selectedQty = 1;

  static const _quickQty = <double>[1, 2, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _selectedQty = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
    _controller = TextEditingController(
      text: _selectedQty.toStringAsFixed(_selectedQty % 1 == 0 ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQty(double qty) {
    setState(() {
      _selectedQty = qty;
      _controller.text = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              widget.product.productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.product.productCode,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtextColorOf(context),
              ),
            ),
            if (widget.helperText != null &&
                widget.helperText!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.helperText!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtextColorOf(context),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  <double>{
                    ..._quickQty,
                    widget.initialQuantity > 0 ? widget.initialQuantity : 1,
                  }.map((qty) {
                    final selected = _selectedQty == qty;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)),
                      selectedColor: widget.color.withValues(alpha: 0.18),
                      onSelected: (_) => _setQty(qty),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'จำนวน',
                prefixIcon: Icon(Icons.tag),
              ),
              onChanged: (value) {
                final qty = double.tryParse(value);
                if (qty != null && qty > 0) {
                  _selectedQty = qty;
                }
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final qty = double.tryParse(_controller.text) ?? _selectedQty;
                  Navigator.pop(context, qty > 0 ? qty : 1);
                },
                style: FilledButton.styleFrom(backgroundColor: widget.color),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('เพิ่มเข้าบิล'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
