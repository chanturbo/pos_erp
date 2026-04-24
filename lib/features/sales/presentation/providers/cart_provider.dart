import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_mode.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../promotions/data/models/promotion_model.dart';
import '../../../products/data/models/product_model.dart';
import '../../../restaurant/data/models/restaurant_order_context.dart';

// ─── Applied Coupon ───────────────────────────────────────────────
class AppliedCoupon {
  final String code;
  final double discount;
  final String promotionId;
  final String? promotionName;
  final bool isExclusive;

  const AppliedCoupon({
    required this.code,
    required this.discount,
    required this.promotionId,
    this.promotionName,
    this.isExclusive = false,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'discount': discount,
    'promotion_id': promotionId,
    'promotion_name': promotionName,
    'is_exclusive': isExclusive,
  };

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) => AppliedCoupon(
    code: json['code'] as String? ?? '',
    discount: (json['discount'] as num?)?.toDouble() ?? 0,
    promotionId: json['promotion_id'] as String? ?? '',
    promotionName: json['promotion_name'] as String?,
    isExclusive: json['is_exclusive'] as bool? ?? false,
  );
}

// Cart Item Model
class CartItem {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? groupId; // สำหรับ CATEGORY matching ใน BUY_X_GET_Y
  final String? promotionId; // โปรโมชั่นที่ให้ของแถมนี้ (freeItems เท่านั้น)
  final String? promotionName;
  final String? note;
  final List<CartItemModifier> modifiers;
  final int courseNo; // Course/Fire order — 1 = first course (default)

  // ✅ เก็บราคาทุก level ไว้ เพื่อให้ re-price ได้เมื่อเปลี่ยนลูกค้า
  final double priceLevel1;
  final double priceLevel2;
  final double priceLevel3;
  final double priceLevel4;
  final double priceLevel5;

  CartItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.groupId,
    this.promotionId,
    this.promotionName,
    this.note,
    this.modifiers = const [],
    this.courseNo = 1,
    this.priceLevel1 = 0,
    this.priceLevel2 = 0,
    this.priceLevel3 = 0,
    this.priceLevel4 = 0,
    this.priceLevel5 = 0,
  });

  /// ✅ คืนราคาตาม priceLevel (1-5), fallback = priceLevel1
  double priceForLevel(int level) {
    switch (level) {
      case 2:
        return priceLevel2 > 0 ? priceLevel2 : priceLevel1;
      case 3:
        return priceLevel3 > 0 ? priceLevel3 : priceLevel1;
      case 4:
        return priceLevel4 > 0 ? priceLevel4 : priceLevel1;
      case 5:
        return priceLevel5 > 0 ? priceLevel5 : priceLevel1;
      default:
        return priceLevel1;
    }
  }

  CartItem copyWith({
    double? quantity,
    double? unitPrice,
    double? amount,
    String? note,
    List<CartItemModifier>? modifiers,
    int? courseNo,
  }) {
    return CartItem(
      productId: productId,
      productCode: productCode,
      productName: productName,
      unit: unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      groupId: groupId,
      promotionId: promotionId,
      promotionName: promotionName,
      note: note ?? this.note,
      modifiers: modifiers ?? this.modifiers,
      courseNo: courseNo ?? this.courseNo,
      priceLevel1: priceLevel1,
      priceLevel2: priceLevel2,
      priceLevel3: priceLevel3,
      priceLevel4: priceLevel4,
      priceLevel5: priceLevel5,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_code': productCode,
    'product_name': productName,
    'unit': unit,
    'quantity': quantity,
    'unit_price': unitPrice,
    'amount': amount,
      'group_id': groupId,
      'promotion_id': promotionId,
      'promotion_name': promotionName,
      'note': note,
      'modifiers': modifiers.map((item) => item.toJson()).toList(),
      'course_no': courseNo,
      'price_level1': priceLevel1,
    'price_level2': priceLevel2,
    'price_level3': priceLevel3,
    'price_level4': priceLevel4,
    'price_level5': priceLevel5,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['product_id'] as String? ?? '',
    productCode: json['product_code'] as String? ?? '',
    productName: json['product_name'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    groupId: json['group_id'] as String?,
    promotionId: json['promotion_id'] as String?,
    promotionName: json['promotion_name'] as String?,
    note: json['note'] as String?,
    modifiers: (json['modifiers'] as List?)
            ?.map((item) => CartItemModifier.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList() ??
        const [],
    courseNo: json['course_no'] as int? ?? 1,
    priceLevel1: (json['price_level1'] as num?)?.toDouble() ?? 0,
    priceLevel2: (json['price_level2'] as num?)?.toDouble() ?? 0,
    priceLevel3: (json['price_level3'] as num?)?.toDouble() ?? 0,
    priceLevel4: (json['price_level4'] as num?)?.toDouble() ?? 0,
    priceLevel5: (json['price_level5'] as num?)?.toDouble() ?? 0,
  );
}

class CartItemModifier {
  final String modifierId;
  final String modifierName;
  final double priceAdjustment;

  const CartItemModifier({
    required this.modifierId,
    required this.modifierName,
    this.priceAdjustment = 0,
  });

  Map<String, dynamic> toJson() => {
        'modifier_id': modifierId,
        'modifier_name': modifierName,
        'price_adjustment': priceAdjustment,
      };

  factory CartItemModifier.fromJson(Map<String, dynamic> json) =>
      CartItemModifier(
        modifierId: json['modifier_id'] as String? ?? '',
        modifierName: json['modifier_name'] as String? ?? '',
        priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
      );
}

// Cart State
class CartState {
  final List<CartItem> items;
  final List<CartItem> freeItems; // ของแถมจาก BUY_X_GET_Y
  final String? customerId;
  final String? customerName;
  final int customerPriceLevel; // ✅ เพิ่ม: ระดับราคาของลูกค้า (1-5)
  final double discountPercent;
  final double discountAmount;
  final List<AppliedCoupon> appliedCoupons; // คูปองที่ใช้งาน (หลายใบ)

  CartState({
    this.items = const [],
    this.freeItems = const [],
    this.customerId = 'WALK_IN',
    this.customerName = 'ลูกค้าทั่วไป',
    this.customerPriceLevel = 1,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.appliedCoupons = const [],
  });

  // Calculated values
  double get subtotal => items.fold(0, (sum, item) => sum + item.amount);

  double get totalDiscount {
    if (discountPercent > 0) {
      return subtotal * discountPercent / 100;
    }
    return discountAmount;
  }

  double get totalCouponDiscount =>
      appliedCoupons.fold(0.0, (sum, c) => sum + c.discount);

  double get total => subtotal - totalDiscount - totalCouponDiscount;

  int get itemCount => items.length;
  bool get hasFreeItems => freeItems.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    List<CartItem>? freeItems,
    String? customerId,
    String? customerName,
    int? customerPriceLevel,
    double? discountPercent,
    double? discountAmount,
    List<AppliedCoupon>? appliedCoupons,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      freeItems: freeItems ?? this.freeItems,
      customerId: clearCustomer ? 'WALK_IN' : (customerId ?? this.customerId),
      customerName: clearCustomer
          ? 'ลูกค้าทั่วไป'
          : (customerName ?? this.customerName),
      customerPriceLevel: clearCustomer
          ? 1
          : (customerPriceLevel ?? this.customerPriceLevel),
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      appliedCoupons: appliedCoupons ?? this.appliedCoupons,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'free_items': freeItems.map((item) => item.toJson()).toList(),
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_price_level': customerPriceLevel,
    'discount_percent': discountPercent,
    'discount_amount': discountAmount,
    'applied_coupons': appliedCoupons.map((coupon) => coupon.toJson()).toList(),
  };

  factory CartState.fromJson(Map<String, dynamic> json) => CartState(
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    freeItems: ((json['free_items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    customerId: json['customer_id'] as String? ?? 'WALK_IN',
    customerName: json['customer_name'] as String? ?? 'ลูกค้าทั่วไป',
    customerPriceLevel: json['customer_price_level'] as int? ?? 1,
    discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    appliedCoupons: ((json['applied_coupons'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => AppliedCoupon.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

// Cart Provider
final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

final restaurantOrderContextProvider =
    StateProvider<RestaurantOrderContext?>((ref) => null);

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return CartState();
  }

  /// เพิ่มสินค้าในตะกร้า
  void addItem({
    required String productId,
    required String productCode,
    required String productName,
    required String unit,
    required double unitPrice,
    double quantity = 1,
    String? groupId,
    // ✅ รับราคาทุก level เพื่อให้ re-price ได้
    double priceLevel1 = 0,
    double priceLevel2 = 0,
    double priceLevel3 = 0,
    double priceLevel4 = 0,
    double priceLevel5 = 0,
  }) {
    final items = List<CartItem>.from(state.items);
    final existingIndex = items.indexWhere(
      (item) => item.productId == productId,
    );

    if (existingIndex >= 0) {
      // เพิ่มจำนวน (คงราคาเดิม)
      final existing = items[existingIndex];
      final newQuantity = existing.quantity + quantity;
      items[existingIndex] = existing.copyWith(
        quantity: newQuantity,
        amount: newQuantity * existing.unitPrice,
      );
    } else {
      // เพิ่มรายการใหม่
      final p1 = priceLevel1 > 0 ? priceLevel1 : unitPrice;
      items.add(
        CartItem(
          productId: productId,
          productCode: productCode,
          productName: productName,
          unit: unit,
          quantity: quantity,
          unitPrice: unitPrice,
          amount: quantity * unitPrice,
          groupId: groupId,
          priceLevel1: p1,
          priceLevel2: priceLevel2,
          priceLevel3: priceLevel3,
          priceLevel4: priceLevel4,
          priceLevel5: priceLevel5,
        ),
      );
    }

    state = state.copyWith(items: items);
  }

  /// เพิ่มจำนวน
  void increaseQuantity(String productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((item) => item.productId == productId);

    if (index >= 0) {
      final item = items[index];
      final newQuantity = item.quantity + 1;
      final newAmount = newQuantity * item.unitPrice;

      items[index] = item.copyWith(quantity: newQuantity, amount: newAmount);

      state = state.copyWith(items: items);
    }
  }

  /// ลดจำนวน
  void decreaseQuantity(String productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((item) => item.productId == productId);

    if (index >= 0) {
      final item = items[index];
      if (item.quantity <= 1) {
        // ถ้าเหลือ 1 แล้วลดอีก → ลบออกจากตะกร้า
        items.removeAt(index);
      } else {
        final newQuantity = item.quantity - 1;
        final newAmount = newQuantity * item.unitPrice;
        items[index] = item.copyWith(quantity: newQuantity, amount: newAmount);
      }
      state = state.copyWith(items: items);
    }
  }

  /// ตั้งค่าจำนวนโดยตรง — ใช้กับ inline edit ใน CartPanel
  void setQuantity(String productId, double quantity) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = items[index];
      final safe = quantity < 0.001 ? 1.0 : quantity;
      items[index] = item.copyWith(
        quantity: safe,
        amount: safe * item.unitPrice,
      );
      state = state.copyWith(items: items);
    }
  }

  /// ลบสินค้า
  void removeItem(String productId) {
    final items = state.items
        .where((item) => item.productId != productId)
        .toList();
    state = state.copyWith(items: items);
  }

  void setCourseNo(String productId, int courseNo) {
    final items = state.items.map((item) {
      if (item.productId != productId) return item;
      return item.copyWith(courseNo: courseNo);
    }).toList();
    state = state.copyWith(items: items);
  }

  /// ✅ ตั้งค่าลูกค้า พร้อม priceLevel (ไม่ re-price อัตโนมัติ)
  void setCustomer(
    String? customerId,
    String? customerName, {
    int priceLevel = 1,
  }) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      customerPriceLevel: priceLevel,
    );
  }

  /// ✅ คำนวณราคาสินค้าทุกรายการใหม่ตาม priceLevel ปัจจุบัน
  void repriceItems() {
    final level = state.customerPriceLevel;
    final repriced = state.items.map((item) {
      final newPrice = item.priceForLevel(level);
      return item.copyWith(
        unitPrice: newPrice,
        amount: item.quantity * newPrice,
      );
    }).toList();
    state = state.copyWith(items: repriced);
  }

  /// ✅ ตรวจว่า priceLevel ใหม่ต่างจากเดิมและมีสินค้าในตะกร้าหรือไม่
  bool hasItemsWithDifferentLevel(int newLevel) {
    return state.items.isNotEmpty && newLevel != state.customerPriceLevel;
  }

  /// ตั้งค่าส่วนลด
  void setDiscount({double? percent, double? amount}) {
    state = state.copyWith(
      discountPercent: percent ?? 0,
      discountAmount: amount ?? 0,
    );
  }

  /// เพิ่มคูปอง
  void applyCoupon(AppliedCoupon coupon) {
    state = state.copyWith(appliedCoupons: [...state.appliedCoupons, coupon]);
  }

  /// ลบคูปองรายใบ
  void removeCoupon(String code) {
    state = state.copyWith(
      appliedCoupons: state.appliedCoupons
          .where((c) => c.code != code)
          .toList(),
    );
  }

  /// ล้างคูปองทั้งหมด
  void clearAllCoupons() {
    state = state.copyWith(appliedCoupons: const []);
  }

  /// เคลียร์ตะกร้า
  void clear() {
    state = CartState(); // Reset เป็น default (freeItems = [] ด้วย)
  }

  /// ใช้ตอน restore order ที่เปิดค้างจากโต๊ะ
  void replaceCart(CartState nextState) {
    state = nextState;
  }

  /// คำนวณของแถม BUY_X_GET_Y และอัปเดต freeItems
  void syncFreeItems(
    List<PromotionModel> promos,
    List<ProductModel> allProducts,
  ) {
    final regularItems = state.items;
    // (promoId, freeProductId) → accumulated qty
    final freeMap = <String, _FreeEntry>{};

    for (final promo in promos) {
      if (promo.promotionType != 'BUY_X_GET_Y') continue;
      if (promo.buyQty == null || promo.getQty == null) continue;
      if (!promo.isRunning) continue;

      final buyQty = promo.buyQty!.toDouble();
      final getQty = promo.getQty!.toDouble();

      // กรองรายการที่ qualify
      List<CartItem> qualifying;
      switch (promo.applyTo) {
        case 'PRODUCT':
          final ids = Set<String>.from(promo.applyToIds ?? []);
          qualifying = regularItems
              .where((i) => ids.contains(i.productId))
              .toList();
          break;
        case 'CATEGORY':
          final gids = Set<String>.from(promo.applyToIds ?? []);
          qualifying = regularItems
              .where((i) => gids.contains(i.groupId))
              .toList();
          break;
        default: // ALL
          qualifying = regularItems;
      }

      for (final item in qualifying) {
        final freeQty = (item.quantity / buyQty).floor() * getQty;
        if (freeQty <= 0) continue;

        // หาสินค้าแถม
        String freeProductId;
        String freeProductName;
        String freeProductCode;
        String freeProductUnit;

        if (promo.getProductId != null) {
          final fp = allProducts
              .where((p) => p.productId == promo.getProductId)
              .firstOrNull;
          if (fp == null) continue; // ไม่พบสินค้าแถม → ข้าม
          freeProductId = fp.productId;
          freeProductName = fp.productName;
          freeProductCode = fp.productCode;
          freeProductUnit = fp.baseUnit;
        } else {
          // สินค้าเดิมที่ซื้อ
          freeProductId = item.productId;
          freeProductName = item.productName;
          freeProductCode = item.productCode;
          freeProductUnit = item.unit;
        }

        final key = '${promo.promotionId}__$freeProductId';
        if (freeMap.containsKey(key)) {
          freeMap[key] = freeMap[key]!.addQty(freeQty);
        } else {
          freeMap[key] = _FreeEntry(
            productId: freeProductId,
            productName: freeProductName,
            productCode: freeProductCode,
            unit: freeProductUnit,
            qty: freeQty,
            promoId: promo.promotionId,
            promoName: promo.promotionName,
          );
        }
      }
    }

    final newFreeItems = freeMap.values
        .map(
          (e) => CartItem(
            productId: e.productId,
            productCode: e.productCode,
            productName: e.productName,
            unit: e.unit,
            quantity: e.qty,
            unitPrice: 0,
            amount: 0,
            promotionId: e.promoId,
            promotionName: e.promoName,
          ),
        )
        .toList();

    state = state.copyWith(freeItems: newFreeItems);
  }

  /// พักบิล
  void hold(String name, {bool isTakeaway = false}) {
    ref.read(holdOrdersProvider.notifier).addOrder(name, state, isTakeaway: isTakeaway);
    clear();
  }
}

// ─── internal helper for syncFreeItems ──────────────────────────
class _FreeEntry {
  final String productId;
  final String productName;
  final String productCode;
  final String unit;
  final double qty;
  final String promoId;
  final String promoName;

  const _FreeEntry({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.unit,
    required this.qty,
    required this.promoId,
    required this.promoName,
  });

  _FreeEntry addQty(double extra) => _FreeEntry(
    productId: productId,
    productName: productName,
    productCode: productCode,
    unit: unit,
    qty: qty + extra,
    promoId: promoId,
    promoName: promoName,
  );
}

// Hold Order Model
class HoldOrder {
  final String name;
  final CartState cartState;
  final DateTime timestamp;
  final bool isTakeaway;

  HoldOrder({
    required this.name,
    required this.cartState,
    required this.timestamp,
    this.isTakeaway = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'cart_state': cartState.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'is_takeaway': isTakeaway,
  };

  factory HoldOrder.fromJson(Map<String, dynamic> json) => HoldOrder(
    name: json['name'] as String? ?? '',
    cartState: CartState.fromJson(
      Map<String, dynamic>.from(json['cart_state'] as Map? ?? const {}),
    ),
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    isTakeaway: json['is_takeaway'] as bool? ?? false,
  );
}

// Hold Orders State
class HoldOrdersState {
  final List<HoldOrder> orders;

  HoldOrdersState({this.orders = const []});

  HoldOrdersState copyWith({List<HoldOrder>? orders}) {
    return HoldOrdersState(orders: orders ?? this.orders);
  }
}

// Hold Orders Provider
final holdOrdersProvider =
    NotifierProvider<HoldOrdersNotifier, HoldOrdersState>(() {
      return HoldOrdersNotifier();
    });

class HoldOrdersNotifier extends Notifier<HoldOrdersState> {
  static const _prefsKeyPrefix = 'hold_orders_state_v1';
  String? _restoredScope;

  @override
  HoldOrdersState build() {
    final authState = ref.watch(authProvider);
    final scope = _scopeKey(authState.user?.userId);

    if (_restoredScope != scope) {
      _restoredScope = scope;
      Future.microtask(() => _restore(scope));
    }
    return HoldOrdersState();
  }

  void addOrder(String name, CartState cartState, {bool isTakeaway = false}) {
    final orders = List<HoldOrder>.from(state.orders);
    orders.add(
      HoldOrder(name: name, cartState: cartState, timestamp: DateTime.now(), isTakeaway: isTakeaway),
    );
    state = state.copyWith(orders: orders);
    _persist();
  }

  void renameOrder(int index, String name) {
    if (index < 0 || index >= state.orders.length) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final orders = List<HoldOrder>.from(state.orders);
    final current = orders[index];
    orders[index] = HoldOrder(
      name: trimmed,
      cartState: current.cartState,
      timestamp: current.timestamp,
      isTakeaway: current.isTakeaway,
    );
    state = state.copyWith(orders: orders);
    _persist();
  }

  void removeOrder(int index) {
    final orders = List<HoldOrder>.from(state.orders);
    orders.removeAt(index);
    state = state.copyWith(orders: orders);
    _persist();
  }

  void recallOrder(int index) {
    if (index >= 0 && index < state.orders.length) {
      final order = state.orders[index];
      final currentCart = ref.read(cartProvider);
      ref.read(cartProvider.notifier).state = _mergeCartStates(
        currentCart,
        order.cartState,
      );
      removeOrder(index);
    }
  }

  CartState _mergeCartStates(CartState current, CartState recalled) {
    if (current.items.isEmpty &&
        current.freeItems.isEmpty &&
        current.appliedCoupons.isEmpty &&
        current.discountAmount == 0 &&
        current.discountPercent == 0) {
      return recalled;
    }

    final mergedItems = _mergeCartItems(current.items, recalled.items);
    final mergedFreeItems = _mergeCartItems(
      current.freeItems,
      recalled.freeItems,
    );

    final currentHasCustomer =
        current.customerId != null &&
        current.customerId != 'WALK_IN' &&
        current.customerId!.isNotEmpty;
    final recalledHasCustomer =
        recalled.customerId != null &&
        recalled.customerId != 'WALK_IN' &&
        recalled.customerId!.isNotEmpty;

    return CartState(
      items: mergedItems,
      freeItems: mergedFreeItems,
      customerId: currentHasCustomer
          ? current.customerId
          : (recalledHasCustomer ? recalled.customerId : 'WALK_IN'),
      customerName: currentHasCustomer
          ? current.customerName
          : (recalledHasCustomer ? recalled.customerName : 'ลูกค้าทั่วไป'),
      customerPriceLevel: currentHasCustomer
          ? current.customerPriceLevel
          : recalled.customerPriceLevel,
      // เมื่อรวมหลายบิลเข้าด้วยกัน ให้เริ่มส่วนลด/คูปองใหม่เพื่อกันข้อมูลผิด
      discountPercent: 0,
      discountAmount: 0,
      appliedCoupons: const [],
    );
  }

  List<CartItem> _mergeCartItems(List<CartItem> first, List<CartItem> second) {
    final merged = <CartItem>[];

    void upsert(CartItem incoming) {
      final index = merged.indexWhere(
        (item) =>
            item.productId == incoming.productId &&
            item.unit == incoming.unit &&
            item.unitPrice == incoming.unitPrice &&
            item.promotionId == incoming.promotionId,
      );

      if (index == -1) {
        merged.add(incoming);
        return;
      }

      final existing = merged[index];
      final newQuantity = existing.quantity + incoming.quantity;
      merged[index] = existing.copyWith(
        quantity: newQuantity,
        amount: existing.unitPrice * newQuantity,
      );
    }

    for (final item in first) {
      upsert(item);
    }
    for (final item in second) {
      upsert(item);
    }

    return merged;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      state.orders.map((order) => order.toJson()).toList(),
    );
    await prefs.setString(_scopedPrefsKey(), payload);
  }

  Future<void> _restore(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_prefsKeyPrefix}_$scope');
    if (raw == null || raw.isEmpty) {
      state = state.copyWith(orders: []);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final orders = decoded
          .whereType<Map>()
          .map((item) => HoldOrder.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      state = state.copyWith(orders: orders);
    } catch (_) {
      await prefs.remove('${_prefsKeyPrefix}_$scope');
      state = state.copyWith(orders: []);
    }
  }

  String _scopeKey(String? userId) =>
      '${AppModeConfig.deviceName}_${userId ?? 'guest'}';

  String _scopedPrefsKey() =>
      '${_prefsKeyPrefix}_${_scopeKey(ref.read(authProvider).user?.userId)}';
}
