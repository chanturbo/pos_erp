import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../promotions/data/models/promotion_model.dart';
import '../../../products/data/models/product_model.dart';

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
  final String? groupId;      // สำหรับ CATEGORY matching ใน BUY_X_GET_Y
  final String? promotionId;  // โปรโมชั่นที่ให้ของแถมนี้ (freeItems เท่านั้น)
  final String? promotionName;

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
    this.priceLevel1 = 0,
    this.priceLevel2 = 0,
    this.priceLevel3 = 0,
    this.priceLevel4 = 0,
    this.priceLevel5 = 0,
  });

  /// ✅ คืนราคาตาม priceLevel (1-5), fallback = priceLevel1
  double priceForLevel(int level) {
    switch (level) {
      case 2: return priceLevel2 > 0 ? priceLevel2 : priceLevel1;
      case 3: return priceLevel3 > 0 ? priceLevel3 : priceLevel1;
      case 4: return priceLevel4 > 0 ? priceLevel4 : priceLevel1;
      case 5: return priceLevel5 > 0 ? priceLevel5 : priceLevel1;
      default: return priceLevel1;
    }
  }

  CartItem copyWith({
    double? quantity,
    double? unitPrice,
    double? amount,
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
      priceLevel1: priceLevel1,
      priceLevel2: priceLevel2,
      priceLevel3: priceLevel3,
      priceLevel4: priceLevel4,
      priceLevel5: priceLevel5,
    );
  }
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
      customerName:
          clearCustomer ? 'ลูกค้าทั่วไป' : (customerName ?? this.customerName),
      customerPriceLevel:
          clearCustomer ? 1 : (customerPriceLevel ?? this.customerPriceLevel),
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      appliedCoupons: appliedCoupons ?? this.appliedCoupons,
    );
  }
}

// Cart Provider
final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

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
    final existingIndex =
        items.indexWhere((item) => item.productId == productId);

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
      items.add(CartItem(
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
      ));
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

      items[index] = item.copyWith(
        quantity: newQuantity,
        amount: newAmount,
      );

      state = state.copyWith(items: items);
    }
  }

  /// ลดจำนวน
  void decreaseQuantity(String productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((item) => item.productId == productId);

    if (index >= 0) {
      final item = items[index];
      if (item.quantity > 1) {
        final newQuantity = item.quantity - 1;
        final newAmount = newQuantity * item.unitPrice;

        items[index] = item.copyWith(
          quantity: newQuantity,
          amount: newAmount,
        );

        state = state.copyWith(items: items);
      }
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
    final items =
        state.items.where((item) => item.productId != productId).toList();
    state = state.copyWith(items: items);
  }

  /// ✅ ตั้งค่าลูกค้า พร้อม priceLevel (ไม่ re-price อัตโนมัติ)
  void setCustomer(String? customerId, String? customerName,
      {int priceLevel = 1}) {
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
    return state.items.isNotEmpty &&
        newLevel != state.customerPriceLevel;
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
    state = state.copyWith(
      appliedCoupons: [...state.appliedCoupons, coupon],
    );
  }

  /// ลบคูปองรายใบ
  void removeCoupon(String code) {
    state = state.copyWith(
      appliedCoupons:
          state.appliedCoupons.where((c) => c.code != code).toList(),
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
          qualifying =
              regularItems.where((i) => ids.contains(i.productId)).toList();
          break;
        case 'CATEGORY':
          final gids = Set<String>.from(promo.applyToIds ?? []);
          qualifying =
              regularItems.where((i) => gids.contains(i.groupId)).toList();
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
          final fp = allProducts.where((p) => p.productId == promo.getProductId).firstOrNull;
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
        .map((e) => CartItem(
              productId: e.productId,
              productCode: e.productCode,
              productName: e.productName,
              unit: e.unit,
              quantity: e.qty,
              unitPrice: 0,
              amount: 0,
              promotionId: e.promoId,
              promotionName: e.promoName,
            ))
        .toList();

    state = state.copyWith(freeItems: newFreeItems);
  }

  /// พักบิล
  void hold(String name) {
    ref.read(holdOrdersProvider.notifier).addOrder(name, state);
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

  HoldOrder({
    required this.name,
    required this.cartState,
    required this.timestamp,
  });
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
  @override
  HoldOrdersState build() {
    return HoldOrdersState();
  }

  void addOrder(String name, CartState cartState) {
    final orders = List<HoldOrder>.from(state.orders);
    orders.add(HoldOrder(
      name: name,
      cartState: cartState,
      timestamp: DateTime.now(),
    ));
    state = state.copyWith(orders: orders);
  }

  void removeOrder(int index) {
    final orders = List<HoldOrder>.from(state.orders);
    orders.removeAt(index);
    state = state.copyWith(orders: orders);
  }

  void recallOrder(int index) {
    if (index >= 0 && index < state.orders.length) {
      final order = state.orders[index];
      ref.read(cartProvider.notifier).state = order.cartState;
      removeOrder(index);
    }
  }
}