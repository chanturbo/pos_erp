import 'package:flutter_riverpod/flutter_riverpod.dart';

// Cart Item Model
class CartItem {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;

  CartItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  CartItem copyWith({
    double? quantity,
    double? amount,
  }) {
    return CartItem(
      productId: productId,
      productCode: productCode,
      productName: productName,
      unit: unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      amount: amount ?? this.amount,
    );
  }
}

// Cart State
class CartState {
  final List<CartItem> items;
  final String? customerId;
  final String? customerName;
  final int customerPriceLevel; // ✅ เพิ่ม: ระดับราคาของลูกค้า (1-5)
  final double discountPercent;
  final double discountAmount;

  CartState({
    this.items = const [],
    this.customerId = 'WALK_IN',
    this.customerName = 'ลูกค้าทั่วไป',
    this.customerPriceLevel = 1, // ✅ Default = ราคาปกติ
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  // Calculated values
  double get subtotal => items.fold(0, (sum, item) => sum + item.amount);

  double get totalDiscount {
    if (discountPercent > 0) {
      return subtotal * discountPercent / 100;
    }
    return discountAmount;
  }

  double get total => subtotal - totalDiscount;

  int get itemCount => items.length;

  CartState copyWith({
    List<CartItem>? items,
    String? customerId,
    String? customerName,
    int? customerPriceLevel,
    double? discountPercent,
    double? discountAmount,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: clearCustomer ? 'WALK_IN' : (customerId ?? this.customerId),
      customerName:
          clearCustomer ? 'ลูกค้าทั่วไป' : (customerName ?? this.customerName),
      customerPriceLevel:
          clearCustomer ? 1 : (customerPriceLevel ?? this.customerPriceLevel),
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
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
  }) {
    final items = List<CartItem>.from(state.items);
    final existingIndex =
        items.indexWhere((item) => item.productId == productId);

    if (existingIndex >= 0) {
      // เพิ่มจำนวน
      final existing = items[existingIndex];
      final newQuantity = existing.quantity + quantity;
      final newAmount = newQuantity * unitPrice;

      items[existingIndex] = existing.copyWith(
        quantity: newQuantity,
        amount: newAmount,
      );
    } else {
      // เพิ่มรายการใหม่
      items.add(CartItem(
        productId: productId,
        productCode: productCode,
        productName: productName,
        unit: unit,
        quantity: quantity,
        unitPrice: unitPrice,
        amount: quantity * unitPrice,
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

  /// ✅ ตั้งค่าลูกค้า พร้อม priceLevel
  void setCustomer(String? customerId, String? customerName,
      {int priceLevel = 1}) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      customerPriceLevel: priceLevel,
    );
  }

  /// ตั้งค่าส่วนลด
  void setDiscount({double? percent, double? amount}) {
    state = state.copyWith(
      discountPercent: percent ?? 0,
      discountAmount: amount ?? 0,
    );
  }

  /// เคลียร์ตะกร้า
  void clear() {
    state = CartState(); // Reset เป็น default
  }

  /// พักบิล
  void hold(String name) {
    ref.read(holdOrdersProvider.notifier).addOrder(name, state);
    clear();
  }
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