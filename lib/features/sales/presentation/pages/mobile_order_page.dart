import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../shared/services/mobile_scanner_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/mobile_config.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/barcode_listener.dart';
import '../../../../routes/app_router.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/pages/sync_status_page.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../inventory/data/models/stock_balance_model.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../restaurant/data/models/dining_table_model.dart';
import '../../../restaurant/data/models/restaurant_order_context.dart';
import '../../../restaurant/data/models/table_session_model.dart';
import '../../../restaurant/presentation/providers/table_provider.dart';
import '../../../restaurant/presentation/widgets/open_table_dialog.dart';
import '../pages/payment_page.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import '../widgets/cart_panel.dart';
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
  final ScrollController _productListController = ScrollController();
  bool _isProductListScrolled = false;
  bool _showCart = true; // toggle ระหว่าง product list กับ cart
  int _cartPanelVersion = 0;
  bool _restoredRestaurantOrder = false;

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
      final isScrolled =
          _productListController.hasClients &&
          _productListController.offset > 6;
      if (isScrolled != _isProductListScrolled && mounted) {
        setState(() => _isProductListScrolled = isScrolled);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMobilePreferences();
      _restoreOpenRestaurantOrder();
    });
  }

  List<ProductModel> _filterProducts(
    List<ProductModel> src,
    Map<String, double> stockMap,
  ) {
    final restaurantContext = ref.read(restaurantOrderContextProvider);

    final filtered = src.where((p) {
      if (restaurantContext != null) {
        final serviceMode = p.serviceMode.toUpperCase();
        final supportsRestaurant =
            serviceMode == 'RESTAURANT' || serviceMode == 'BOTH';
        if (!supportsRestaurant || !p.dineInAvailable) return false;
      }

      final matchesGroup =
          _selectedGroupId == null || p.groupId == _selectedGroupId;
      if (!matchesGroup) return false;
      if (_hideInactiveProducts && !p.isActive) return false;
      if (_hideOutOfStockProducts &&
          p.isStockControl &&
          !p.allowNegativeStock &&
          (stockMap[p.productId] ?? 0) <= 0) {
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

  Future<void> _restoreOpenRestaurantOrder() async {
    if (_restoredRestaurantOrder) return;
    _restoredRestaurantOrder = true;

    final restaurantContext = ref.read(restaurantOrderContextProvider);
    final currentOrderId = restaurantContext?.currentOrderId;
    final cartState = ref.read(cartProvider);
    if (restaurantContext == null ||
        currentOrderId == null ||
        currentOrderId.isEmpty ||
        cartState.items.isNotEmpty ||
        cartState.freeItems.isNotEmpty) {
      return;
    }

    final order = await ref
        .read(salesHistoryProvider.notifier)
        .getOrderDetails(currentOrderId);
    if (!mounted || order == null || order.items == null) return;

    final regularItems = order.items!
        .where((item) => !item.isFreeItem)
        .map(
          (item) => CartItem(
            productId: item.productId,
            productCode: item.productCode,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            amount: item.amount,
            priceLevel1: item.unitPrice,
            note: item.specialInstructions,
            modifiers: item.modifiers
                .map(
                  (modifier) => CartItemModifier(
                    modifierId: modifier.modifierId,
                    modifierName: modifier.modifierName,
                    priceAdjustment: modifier.priceAdjustment,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final freeItems = order.items!
        .where((item) => item.isFreeItem)
        .map(
          (item) => CartItem(
            productId: item.productId,
            productCode: item.productCode,
            productName: item.productName,
            unit: item.unit,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            amount: item.amount,
            promotionName: item.promotionName,
            priceLevel1: item.unitPrice,
          ),
        )
        .toList();

    final totalDiscount = (order.subtotal - order.totalAmount).clamp(
      0,
      double.infinity,
    );

    ref
        .read(cartProvider.notifier)
        .replaceCart(
          CartState(
            items: regularItems,
            freeItems: freeItems,
            customerId: order.customerId ?? 'WALK_IN',
            customerName: order.customerName ?? 'ลูกค้าทั่วไป',
            discountAmount: totalDiscount.toDouble(),
          ),
        );

    ref.read(restaurantOrderContextProvider.notifier).state = restaurantContext
        .copyWith(currentOrderId: order.orderId, currentOrderNo: order.orderNo);
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
        builder: (_) => AppDialog(
          title: buildAppDialogTitle(
            context,
            title: 'อัปเดตราคาสินค้า',
            icon: Icons.sell_outlined,
            iconColor: AppTheme.warning,
          ),
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
    bool? openCartAfterAdd,
  }) {
    final priceLevel = ref.read(cartProvider).customerPriceLevel;
    final autoOpenCartOnTap = ref
        .read(settingsProvider)
        .mobilePosAutoOpenCartOnTap;
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

    final shouldOpenCart =
        openCartAfterAdd ?? (fromScan ? true : autoOpenCartOnTap);

    // Auto-switch ไปแท็บตะกร้าหลังเพิ่มสินค้า เฉพาะเมื่อกำหนดไว้
    if (shouldOpenCart && !_showCart && mounted) {
      _showCartAndRefocus();
    }

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

  void _showScannerErrorSnackBar(
    String message, {
    BuildContext? messengerContext,
  }) {
    if (!mounted) return;

    final messenger =
        (messengerContext != null
            ? ScaffoldMessenger.maybeOf(messengerContext)
            : null) ??
        ScaffoldMessenger.maybeOf(
          Navigator.of(context, rootNavigator: true).context,
        ) ??
        ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        ),
      );
  }

  void _showCartAndRefocus() {
    if (!mounted) return;
    setState(() {
      _showCart = true;
      _cartPanelVersion++;
    });
  }

  Future<void> _handleScannedValue(
    String value, {
    BuildContext? messengerContext,
  }) async {
    final products =
        ref.read(productListProvider).value ?? const <ProductModel>[];
    final matched = _matchScannedProduct(value, products);

    if (matched != null) {
      _showCartAndRefocus();
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

    _showScannerErrorSnackBar(
      'ไม่พบสินค้า: $value',
      messengerContext: messengerContext,
    );
  }

  Future<void> _openContinuousScanner() async {
    await MobileScannerService.openContinuous(
      context,
      onScanned: (result) => _handleScannedValue(result.value),
      onScannedInSheet: (sheetContext, result) =>
          _handleScannedValue(result.value, messengerContext: sheetContext),
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
                    borderRadius: AppRadius.pill,
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
            borderRadius: AppRadius.topLg,
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: AppRadius.pill,
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
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'พักบิล',
          icon: Icons.pause_circle_outline_rounded,
        ),
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

    final holdCtx = ref.read(restaurantOrderContextProvider);
    final isTakeaway = holdCtx?.isTakeaway ?? false;
    final skipKitchen = holdCtx?.skipKitchen ?? false;
    ref
        .read(cartProvider.notifier)
        .hold(holdName.trim(), isTakeaway: isTakeaway, skipKitchen: skipKitchen);
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

  Future<void> _openRestaurantModeSheet() async {
    await _feedbackSelection();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestaurantModeSheet(
        onClear: _clearRestaurantContext,
        onTakeaway: _startTakeawayContext,
        onSelectTable: _selectRestaurantTable,
      ),
    );
  }

  Future<void> _clearRestaurantContext() async {
    ref.read(restaurantOrderContextProvider.notifier).state = null;
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('เปลี่ยนเป็นโหมดขายปกติแล้ว')));
  }

  Future<void> _startTakeawayContext() async {
    final branch = ref.read(selectedBranchProvider);
    if (branch == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสาขาก่อนเริ่มออเดอร์ซื้อกลับบ้าน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(restaurantOrderContextProvider.notifier).state =
        RestaurantOrderContext.takeaway(branchId: branch.branchId);
    if (!mounted) return;
    Navigator.pop(context);
    _showCartAndRefocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เริ่มออเดอร์ซื้อกลับบ้านแล้ว')),
    );
  }

  Future<void> _selectRestaurantTable(DiningTableModel table) async {
    final branch = ref.read(selectedBranchProvider);
    if (branch == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสาขาก่อนเปิดโต๊ะ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    TableSessionModel? session;
    if (table.isAvailable) {
      final opened = await showDialog<bool>(
        context: context,
        builder: (_) => OpenTableDialog(
          table: table,
          branchId: branch.branchId,
          onConfirm: (guestCount) async {
            final authState = ref.read(authProvider);
            session = await ref
                .read(tableListProvider.notifier)
                .openTable(
                  tableId: table.tableId,
                  guestCount: guestCount,
                  branchId: branch.branchId,
                  openedBy: authState.user?.userId,
                );
            return session != null;
          },
        ),
      );
      if (opened != true) return;
      session ??= await ref
          .read(tableListProvider.notifier)
          .getActiveSession(table.tableId);
    } else if (table.isOccupied) {
      session = TableSessionModel(
        sessionId: table.activeSessionId ?? '',
        tableId: table.tableId,
        branchId: branch.branchId,
        openedAt: table.sessionOpenedAt ?? DateTime.now(),
        guestCount: table.activeGuestCount ?? 1,
        status: 'OPEN',
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('โต๊ะ ${table.displayName} ยังเปิดออเดอร์ไม่ได้'),
        ),
      );
      return;
    }

    final resolvedSession = session;
    if (resolvedSession == null || !mounted) return;
    ref
        .read(restaurantOrderContextProvider.notifier)
        .state = RestaurantOrderContext(
      tableId: table.tableId,
      tableName: table.displayName,
      sessionId: resolvedSession.sessionId,
      branchId: resolvedSession.branchId,
      guestCount: resolvedSession.guestCount,
      serviceType: 'DINE_IN',
      currentOrderId: table.currentOrderId,
    );
    Navigator.pop(context);
    _showCartAndRefocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เลือกโต๊ะ ${table.displayName} แล้ว')),
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
      ref
          .read(tableListProvider.notifier)
          .refresh(branchId: ref.read(selectedBranchProvider)?.branchId),
      ref.read(zoneListProvider.notifier).refresh(),
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
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ออกจากระบบ',
          icon: Icons.logout_rounded,
          iconColor: Colors.orange,
        ),
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
            borderRadius: AppRadius.topLg,
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
                    borderRadius: AppRadius.pill,
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
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
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
    ref.watch(tableStatusPollingProvider);

    final productAsync = ref.watch(productListProvider);
    final productGroupsAsync = ref.watch(productGroupsProvider);
    final stockAsync = ref.watch(stockBalanceProvider);
    final cartState = ref.watch(cartProvider);
    final restaurantContext = ref.watch(restaurantOrderContextProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final holdOrdersState = ref.watch(holdOrdersProvider);
    final settings = ref.watch(settingsProvider);
    final syncValue = syncAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final authState = ref.watch(authProvider);
    final stockMap = stockAsync.maybeWhen(
      data: (stocks) => _buildStockMap(stocks, selectedWarehouse?.warehouseId),
      orElse: () => const <String, double>{},
    );
    final isRestaurantFlow = restaurantContext != null;
    final isKitchenSent =
        restaurantContext?.currentOrderId?.isNotEmpty ?? false;
    final skipKitchen = restaurantContext?.skipKitchen ?? false;
    final isReadyForCheckout =
        cartState.items.isNotEmpty &&
        selectedBranch != null &&
        selectedWarehouse != null &&
        (!isRestaurantFlow || isKitchenSent || skipKitchen);
    final autoOpenCartOnTap = settings.mobilePosAutoOpenCartOnTap;

    final expectedFavoriteScope = _favoriteScopeKey(
      branchId: selectedBranch?.branchId,
    );
    if (_loadedFavoriteScope != expectedFavoriteScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFavoritePreferences(branchId: selectedBranch?.branchId);
      });
    }

    return BarcodeListener(
      enabled: true,
      onBarcodeScanned: _handleScannedValue,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColorOf(context),
        appBar: AppBar(
          leading: AppRouter.isCashierRole(authState.user?.roleId)
              ? IconButton(
                  tooltip: 'ออกจากระบบ',
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                )
              : IconButton(
                  tooltip: 'กลับหน้าหลัก',
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRouter.home),
                  icon: const Icon(Icons.home_rounded),
                ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('จุดรับออเดอร์', style: TextStyle(fontSize: 16)),
                    Text(
                      authState.user?.fullName ?? AppModeConfig.deviceName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Connection status pill — always visible
              connectionAsync.maybeWhen(
                data: (connection) => GestureDetector(
                  onTap: _openConnectionSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: connection.isConnected
                          ? AppTheme.successColor.withValues(alpha: 0.15)
                          : AppTheme.errorColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.xl,
                      border: Border.all(
                        color: connection.isConnected
                            ? AppTheme.successColor.withValues(alpha: 0.5)
                            : AppTheme.errorColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connection.isConnected
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          size: 12,
                          color: connection.isConnected
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connection.isConnected
                              ? (selectedBranch?.branchName ?? 'ออนไลน์')
                              : 'ออฟไลน์',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: connection.isConnected
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                        if ((syncValue?.pendingCount ?? 0) > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: AppRadius.sm,
                            ),
                            child: Text(
                              '${syncValue!.pendingCount}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
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
                        borderRadius: AppRadius.pill,
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
            // ── Always-visible header strip ────────────────────────
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Customer selector + branch status
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectCustomer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (cartState.customerId != null &&
                                      cartState.customerId != 'WALK_IN')
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.10,
                                    )
                                  : AppTheme.borderColorOf(
                                      context,
                                    ).withValues(alpha: 0.25),
                              borderRadius: AppRadius.xl,
                              border: Border.all(
                                color:
                                    (cartState.customerId != null &&
                                        cartState.customerId != 'WALK_IN')
                                    ? AppTheme.primaryColor.withValues(
                                        alpha: 0.4,
                                      )
                                    : AppTheme.borderColorOf(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 15,
                                  color:
                                      (cartState.customerId != null &&
                                          cartState.customerId != 'WALK_IN')
                                      ? AppTheme.primaryColor
                                      : AppTheme.subtextColorOf(context),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    cartState.customerName ?? 'ลูกค้าทั่วไป',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          (cartState.customerId != null &&
                                              cartState.customerId != 'WALK_IN')
                                          ? AppTheme.primaryColor
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 16,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (selectedBranch != null && selectedWarehouse != null)
                        GestureDetector(
                          onTap: _openConnectionSettings,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.borderColorOf(
                                context,
                              ).withValues(alpha: 0.25),
                              borderRadius: AppRadius.xl,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  selectedBranch.branchName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _openConnectionSettings,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: AppRadius.xl,
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'ตั้งค่าสาขา',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openRestaurantModeSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isRestaurantFlow
                            ? AppTheme.warningColor.withValues(alpha: 0.10)
                            : AppTheme.borderColorOf(
                                context,
                              ).withValues(alpha: 0.20),
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: isRestaurantFlow
                              ? AppTheme.warningColor.withValues(alpha: 0.30)
                              : AppTheme.borderColorOf(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isRestaurantFlow
                                ? (restaurantContext.isTakeaway
                                      ? Icons.takeout_dining_rounded
                                      : Icons.table_restaurant_rounded)
                                : Icons.restaurant_menu_rounded,
                            size: 17,
                            color: isRestaurantFlow
                                ? AppTheme.warningColor
                                : AppTheme.subtextColorOf(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isRestaurantFlow
                                  ? restaurantContext.displayName
                                  : 'โหมดขายปกติ',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isRestaurantFlow
                                    ? AppTheme.warningColor
                                    : null,
                              ),
                            ),
                          ),
                          if (isRestaurantFlow && !skipKitchen) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isKitchenSent
                                            ? AppTheme.successColor
                                            : AppTheme.infoColor)
                                        .withValues(alpha: 0.12),
                                borderRadius: AppRadius.pill,
                              ),
                              child: Text(
                                isKitchenSent ? 'ส่งครัวแล้ว' : 'รอส่งครัว',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isKitchenSent
                                      ? AppTheme.successColor
                                      : AppTheme.infoColor,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: AppTheme.subtextColorOf(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Favorites quick-sell strip (always visible)
                  if (_favoriteProductIds.isNotEmpty)
                    productAsync.maybeWhen(
                      data: (products) {
                        final favorites = _favoriteProductIds
                            .map(
                              (id) => products
                                  .where((p) => p.productId == id)
                                  .firstOrNull,
                            )
                            .whereType<ProductModel>()
                            .toList();
                        if (favorites.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 13,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ขายด่วน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _openFavoriteManager(products),
                                  child: Text(
                                    'จัดเรียง',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.subtextColorOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: favorites.length,
                                separatorBuilder: (context, idx) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final p = favorites[i];
                                  final color = _groupColor(p.groupId);
                                  return GestureDetector(
                                    onTap: () {
                                      _feedbackTap();
                                      _promptAddProduct(p);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: AppRadius.lg,
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _groupIcon(p.groupId),
                                            size: 14,
                                            color: color,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            p.productName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                          ),
                                        ],
                                      ),
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
                ],
              ),
            ),
            // ── Cart toggle: สินค้า / ตะกร้า ──────────────────────────
            if (_showCart) ...[
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(_cartPanelVersion),
                  child: const CartPanel(
                    showScanRow: true,
                    autofocusScan: true,
                    showCheckoutButton: false,
                  ),
                ),
              ),
            ] else ...[
              // (removed old collapsible header — content below is search/filter card)
              const SizedBox(height: 8),
              // ── Search + filter card ────────────────────────────────
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final searchHintColor = isDark
                      ? AppTheme.darkElement.withValues(alpha: 0.6)
                      : AppTheme.subtextColor;
                  final searchTextColor = isDark
                      ? Colors.white
                      : const Color(0xFF1A1A1A);
                  final searchIconColor = isDark
                      ? Colors.white70
                      : AppTheme.subtextColor;
                  final searchBorderColor = isDark
                      ? const Color(0xFF333333)
                      : AppTheme.border;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: _isProductListScrolled
                            ? AppTheme.primaryColor.withValues(alpha: 0.24)
                            : AppTheme.borderColorOf(
                                context,
                              ).withValues(alpha: 0.9),
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
                              child: SizedBox(
                                height: 34,
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: searchTextColor,
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText: 'บาร์โค้ด / รหัสสินค้า...',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: searchHintColor,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      size: 16,
                                      color: searchIconColor,
                                    ),
                                    suffixIcon: _searchQuery.isEmpty
                                        ? null
                                        : IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              size: 14,
                                              color: searchIconColor,
                                            ),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    filled: true,
                                    fillColor: isDark
                                        ? AppTheme.darkElement
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.sm,
                                      borderSide: BorderSide(
                                        color: searchBorderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: AppRadius.sm,
                                      borderSide: BorderSide(
                                        color: searchBorderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: AppRadius.sm,
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: AppRadius.sm,
                              ),
                              child: IconButton(
                                onPressed: _openContinuousScanner,
                                icon: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                padding: EdgeInsets.zero,
                                tooltip: 'สแกนต่อเนื่อง',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 38,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkElement
                                    : Colors.white,
                                borderRadius: AppRadius.sm,
                                border: Border.all(color: searchBorderColor),
                              ),
                              child: IconButton(
                                onPressed: _scanAndSearch,
                                icon: const Icon(
                                  Icons.fullscreen_rounded,
                                  size: 17,
                                ),
                                padding: EdgeInsets.zero,
                                tooltip: 'สแกนครั้งเดียว',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        productGroupsAsync.when(
                          data: (groups) => SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    selected: _selectedGroupId == null,
                                    backgroundColor: Colors.transparent,
                                    selectedColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.12),
                                    side: BorderSide(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                    visualDensity: const VisualDensity(
                                      horizontal: -3,
                                      vertical: -3,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    avatar: const Icon(
                                      Icons.apps_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'ทั้งหมด',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onSelected: (_) {
                                      _feedbackSelection();
                                      setState(() => _selectedGroupId = null);
                                    },
                                  ),
                                ),
                                for (final group in groups)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Builder(
                                      builder: (_) {
                                        final color = _groupColor(
                                          group.groupId,
                                        );
                                        return FilterChip(
                                          selected:
                                              _selectedGroupId == group.groupId,
                                          backgroundColor: color.withValues(
                                            alpha: 0.08,
                                          ),
                                          selectedColor: color.withValues(
                                            alpha: 0.18,
                                          ),
                                          side: BorderSide(
                                            color: color.withValues(
                                              alpha: 0.28,
                                            ),
                                          ),
                                          visualDensity: const VisualDensity(
                                            horizontal: -3,
                                            vertical: -3,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                          avatar: Icon(
                                            _groupIcon(group.groupId),
                                            size: 14,
                                            color: color,
                                          ),
                                          label: Text(
                                            group.groupName,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          onSelected: (_) {
                                            _feedbackSelection();
                                            setState(() {
                                              _selectedGroupId =
                                                  _selectedGroupId ==
                                                      group.groupId
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
                                          color: AppTheme.subtextColorOf(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _selectedGroupId = null,
                                      ),
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
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilterChip(
                                    selected: _hideInactiveProducts,
                                    visualDensity: const VisualDensity(
                                      horizontal: -3,
                                      vertical: -3,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    label: const Text(
                                      'ซ่อนสินค้าไม่ active',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onSelected: (value) {
                                      _feedbackSelection();
                                      setState(
                                        () => _hideInactiveProducts = value,
                                      );
                                    },
                                  ),
                                  FilterChip(
                                    selected: _hideOutOfStockProducts,
                                    visualDensity: const VisualDensity(
                                      horizontal: -3,
                                      vertical: -3,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    label: const Text(
                                      'ซ่อนสินค้าหมดสต๊อก',
                                      style: TextStyle(fontSize: 11),
                                    ),
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
                  );
                },
              ),
              Expanded(
                child: productAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                  data: (products) {
                    final filtered = _filterProducts(products, stockMap);
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('ไม่พบสินค้าที่ตรงเงื่อนไข'),
                      );
                    }

                    return ListView.separated(
                      controller: _productListController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, $i) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        final priceLevel = cartState.customerPriceLevel;
                        final lookup = getPriceByLevel(product, priceLevel);
                        final groupColor = _groupColor(product.groupId);
                        final actionColor = AppTheme.info;
                        final initial = product.productName.isNotEmpty
                            ? product.productName.substring(0, 1).toUpperCase()
                            : '?';
                        const avatarPalette = [
                          AppTheme.primary,
                          AppTheme.info,
                          AppTheme.success,
                          AppTheme.warning,
                          AppTheme.purpleColor,
                          AppTheme.tealColor,
                        ];
                        final avatarColor =
                            avatarPalette[product.productName.codeUnitAt(0) %
                                avatarPalette.length];
                        final availableStock = stockMap[product.productId] ?? 0;
                        final qtyInCart = cartState.items
                            .where(
                              (item) => item.productId == product.productId,
                            )
                            .fold<double>(
                              0,
                              (sum, item) => sum + item.quantity,
                            );
                        final screenWidth = MediaQuery.sizeOf(context).width;
                        final isCompactCard = screenWidth < 380;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md,
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: AppRadius.md,
                            onTap: () {
                              final stockMap = _currentStockMap();
                              if (!_ensureStockAvailable(
                                product,
                                1,
                                stockMap,
                              )) {
                                return;
                              }
                              _addProduct(product);
                            },
                            onLongPress: () => _showProductMetaSheet(
                              product,
                              lookup: lookup,
                              availableStock: availableStock,
                              qtyInCart: qtyInCart,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: isCompactCard ? 19 : 20,
                                        backgroundColor: avatarColor,
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!product.isStockControl)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: AppTheme.textSub,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 8,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                product.productName,
                                                maxLines: isCompactCard ? 1 : 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: product.isActive
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                                borderRadius:
                                                    AppRadius.md,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 5,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      color: product.isActive
                                                          ? const Color(
                                                              0xFF4CAF50,
                                                            )
                                                          : const Color(
                                                              0xFFF44336,
                                                            ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    product.isActive
                                                        ? 'ใช้งาน'
                                                        : 'ปิดใช้',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: product.isActive
                                                          ? const Color(
                                                              0xFF2E7D32,
                                                            )
                                                          : const Color(
                                                              0xFFC62828,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'รหัส: ${product.productCode}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSub,
                                          ),
                                        ),
                                        if (product.barcode != null &&
                                            product.barcode!.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.qr_code,
                                                size: 11,
                                                color: AppTheme.textSub,
                                              ),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  product.barcode!,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSub,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              '฿${lookup.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.info,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '/ ${product.baseUnit}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSub,
                                              ),
                                            ),
                                            if (product.standardCost > 0) ...[
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'ต้นทุน: ฿${product.standardCost.toStringAsFixed(2)}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSub,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: availableStock > 0
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                                borderRadius:
                                                    AppRadius.pill,
                                              ),
                                              child: Text(
                                                availableStock > 0
                                                    ? 'คงเหลือ ${availableStock.toStringAsFixed(0)}'
                                                    : 'หมดสต๊อก',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: availableStock > 0
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFFC62828),
                                                ),
                                              ),
                                            ),
                                            if (qtyInCart > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE8F5E9,
                                                  ),
                                                  borderRadius:
                                                      AppRadius.pill,
                                                ),
                                                child: Text(
                                                  'ในบิล ${qtyInCart.toStringAsFixed(qtyInCart % 1 == 0 ? 0 : 1)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                              ),
                                            if (lookup.isFallback) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      AppRadius.pill,
                                                ),
                                                child: Text(
                                                  'ใช้ราคา Lv.1',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        Colors.orange.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (product.groupId != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: groupColor.withValues(
                                                    alpha: 0.10,
                                                  ),
                                                  borderRadius:
                                                      AppRadius.pill,
                                                ),
                                                child: Text(
                                                  productGroupsAsync.maybeWhen(
                                                    data: (groups) =>
                                                        groups
                                                            .where(
                                                              (group) =>
                                                                  group
                                                                      .groupId ==
                                                                  product
                                                                      .groupId,
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
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Inline stepper when qty > 0, else "เพิ่ม" button
                                  qtyInCart > 0
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: actionColor.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: AppRadius.md,
                                            border: Border.all(
                                              color: actionColor.withValues(
                                                alpha: 0.20,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 32,
                                                height: 36,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    _feedbackTap();
                                                    ref
                                                        .read(
                                                          cartProvider.notifier,
                                                        )
                                                        .decreaseQuantity(
                                                          product.productId,
                                                        );
                                                  },
                                                  icon: Icon(
                                                    Icons.remove_rounded,
                                                    size: 15,
                                                    color: actionColor,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 28,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                    ),
                                                child: Text(
                                                  qtyInCart.toStringAsFixed(
                                                    qtyInCart % 1 == 0 ? 0 : 1,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: actionColor,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 32,
                                                height: 36,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    _feedbackTap();
                                                    final stockMap =
                                                        _currentStockMap();
                                                    if (!_ensureStockAvailable(
                                                      product,
                                                      1,
                                                      stockMap,
                                                    )) {
                                                      return;
                                                    }
                                                    _addProduct(product);
                                                  },
                                                  icon: Icon(
                                                    Icons.add_rounded,
                                                    size: 15,
                                                    color: actionColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : FilledButton(
                                          onPressed: () {
                                            _feedbackTap();
                                            final stockMap = _currentStockMap();
                                            if (!_ensureStockAvailable(
                                              product,
                                              1,
                                              stockMap,
                                            )) {
                                              return;
                                            }
                                            _addProduct(product);
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: actionColor
                                                .withValues(alpha: 0.10),
                                            foregroundColor: actionColor,
                                            elevation: 0,
                                            side: BorderSide(
                                              color: actionColor.withValues(
                                                alpha: 0.20,
                                              ),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isCompactCard
                                                  ? 10
                                                  : 16,
                                              vertical: isCompactCard ? 0 : 2,
                                            ),
                                            minimumSize: Size(
                                              0,
                                              isCompactCard ? 34 : 38,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  AppRadius.md,
                                            ),
                                          ),
                                          child: const Text(
                                            'เพิ่ม',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
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
            ], // end else (product list view)
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Material(
            elevation: 12,
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Tab toggle row ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.borderColorOf(
                        context,
                      ).withValues(alpha: 0.18),
                      borderRadius: AppRadius.md,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── ตะกร้า tab (อยู่ก่อน) ────────────────────
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _feedbackSelection();
                                _showCartAndRefocus();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _showCart
                                      ? Theme.of(context).cardColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _showCart
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag_rounded,
                                          size: 16,
                                          color: _showCart
                                              ? AppTheme.primaryColor
                                              : AppTheme.subtextColorOf(
                                                  context,
                                                ),
                                        ),
                                        if (cartState.itemCount > 0)
                                          Positioned(
                                            right: -7,
                                            top: -5,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                borderRadius:
                                                    AppRadius.sm,
                                              ),
                                              child: Text(
                                                '${cartState.itemCount}',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'ตะกร้า',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _showCart
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _showCart
                                            ? AppTheme.primaryColor
                                            : AppTheme.subtextColorOf(context),
                                      ),
                                    ),
                                    if (cartState.items.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '฿${cartState.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _showCart
                                              ? AppTheme.primaryColor
                                                    .withValues(alpha: 0.7)
                                              : AppTheme.subtextColorOf(
                                                  context,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // ── สินค้า tab ────────────────────────────────
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _feedbackSelection();
                                setState(() => _showCart = false);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: !_showCart
                                      ? Theme.of(context).cardColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !_showCart
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.grid_view_rounded,
                                      size: 16,
                                      color: !_showCart
                                          ? AppTheme.primaryColor
                                          : AppTheme.subtextColorOf(context),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'สินค้า',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_showCart
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !_showCart
                                            ? AppTheme.primaryColor
                                            : AppTheme.subtextColorOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            autoOpenCartOnTap
                                ? 'แตะสินค้าเพื่อเพิ่มและเปิดตะกร้าอัตโนมัติ, สแกนบาร์โค้ดแล้วจะเปิดตะกร้าอัตโนมัติ'
                                : 'แตะสินค้าเพื่อเพิ่ม, สแกนบาร์โค้ดแล้วจะเปิดตะกร้าอัตโนมัติ',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.subtextColorOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Action row: Hold + Checkout ─────────────────────
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: OutlinedButton(
                          onPressed: cartState.items.isEmpty
                              ? null
                              : _holdCurrentOrder,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md,
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pause_circle_outline_rounded,
                                  size: 17,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'พักบิล',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 11,
                        child: FilledButton.icon(
                          onPressed: isReadyForCheckout ? _goToCheckout : null,
                          icon: Icon(
                            selectedBranch == null || selectedWarehouse == null
                                ? Icons.settings_ethernet_rounded
                                : isRestaurantFlow &&
                                      !isKitchenSent &&
                                      !skipKitchen
                                ? Icons.lock_outline_rounded
                                : Icons.payment_rounded,
                            size: 18,
                          ),
                          label: Text(
                            cartState.items.isEmpty
                                ? 'ชำระเงิน'
                                : isRestaurantFlow &&
                                      !isKitchenSent &&
                                      !skipKitchen
                                ? 'กรุณาส่งเข้าครัวก่อน'
                                : 'ชำระเงิน  ฿${cartState.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.successColor
                                .withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white70,
                            minimumSize: const Size(0, 48),
                            alignment: Alignment.center,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _RestaurantModeSheet extends ConsumerWidget {
  final Future<void> Function() onClear;
  final Future<void> Function() onTakeaway;
  final Future<void> Function(DiningTableModel table) onSelectTable;

  const _RestaurantModeSheet({
    required this.onClear,
    required this.onTakeaway,
    required this.onSelectTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentContext = ref.watch(restaurantOrderContextProvider);
    final tablesAsync = ref.watch(tableListProvider);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.topLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'โหมดร้านอาหาร',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'รีเฟรชโต๊ะ',
                  onPressed: () => ref
                      .read(tableListProvider.notifier)
                      .refresh(
                        branchId: ref.read(selectedBranchProvider)?.branchId,
                      ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RestaurantModeAction(
                    icon: Icons.point_of_sale_rounded,
                    label: 'ขายปกติ',
                    active: currentContext == null,
                    color: AppTheme.primaryColor,
                    onTap: onClear,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RestaurantModeAction(
                    icon: Icons.takeout_dining_rounded,
                    label: 'ซื้อกลับบ้าน',
                    active: currentContext?.isTakeaway ?? false,
                    color: AppTheme.warningColor,
                    onTap: onTakeaway,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'โต๊ะอาหาร',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.subtextColorOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tablesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('โหลดโต๊ะไม่สำเร็จ: $e')),
                data: (tables) {
                  final selectable =
                      tables
                          .where(
                            (table) => !table.isDisabled && !table.isCleaning,
                          )
                          .toList()
                        ..sort((a, b) {
                          final zone = (a.zoneName ?? '').compareTo(
                            b.zoneName ?? '',
                          );
                          return zone != 0
                              ? zone
                              : a.tableNo.compareTo(b.tableNo);
                        });

                  if (selectable.isEmpty) {
                    return const Center(child: Text('ยังไม่มีโต๊ะที่เลือกได้'));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisExtent: 96,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: selectable.length,
                    itemBuilder: (_, index) {
                      final table = selectable[index];
                      final active = currentContext?.tableId == table.tableId;
                      final statusColor = table.isAvailable
                          ? AppTheme.successColor
                          : table.isOccupied
                          ? AppTheme.warningColor
                          : AppTheme.subtextColorOf(context);

                      return InkWell(
                        onTap: () => onSelectTable(table),
                        borderRadius: AppRadius.md,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.primaryColor.withValues(alpha: 0.10)
                                : statusColor.withValues(alpha: 0.08),
                            borderRadius: AppRadius.md,
                            border: Border.all(
                              color: active
                                  ? AppTheme.primaryColor
                                  : statusColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.table_restaurant_rounded,
                                    size: 16,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      table.displayName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                table.zoneName ?? 'ไม่ระบุโซน',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                table.isAvailable
                                    ? 'ว่าง'
                                    : table.isOccupied
                                    ? 'มีออเดอร์'
                                    : table.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _RestaurantModeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _RestaurantModeAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.14 : 0.07),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: color.withValues(alpha: active ? 0.45 : 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        borderRadius: AppRadius.pill,
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
          borderRadius: AppRadius.topLg,
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: AppRadius.pill,
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
                      borderRadius: AppRadius.pill,
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
                              borderRadius: AppRadius.md,
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
        borderRadius: AppRadius.md,
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
        borderRadius: AppRadius.md,
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
          borderRadius: AppRadius.topLg,
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
                borderRadius: AppRadius.pill,
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
