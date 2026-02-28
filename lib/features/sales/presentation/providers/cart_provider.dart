import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cart_item_model.dart';

// Cart State
class CartState {
  final List<CartItemModel> items;
  final String? customerId;
  final String? customerName;
  final double discountPercent;
  final double discountAmount;
  
  CartState({
    required this.items,
    this.customerId,
    this.customerName,
    this.discountPercent = 0,
    this.discountAmount = 0,
  });
  
  // คำนวณยอดรวม
  double get subtotal => items.fold(0, (sum, item) => sum + item.amount);
  
  double get totalDiscount => (subtotal * discountPercent / 100) + discountAmount;
  
  double get total => subtotal - totalDiscount;
  
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity.toInt());
  
  CartState copyWith({
    List<CartItemModel>? items,
    String? customerId,
    String? customerName,
    double? discountPercent,
    double? discountAmount,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
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
    return CartState(items: []);
  }
  
  /// เพิ่มสินค้าลงตะกร้า
  void addItem({
    required String productId,
    required String productCode,
    required String productName,
    required String unit,
    required double price,
    double quantity = 1,
  }) {
    final items = List<CartItemModel>.from(state.items);
    
    // ตรวจสอบว่ามีสินค้านี้แล้วหรือไม่
    final existingIndex = items.indexWhere((item) => item.productId == productId);
    
    if (existingIndex != -1) {
      // มีแล้ว เพิ่มจำนวน
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + quantity,
      );
    } else {
      // ยังไม่มี เพิ่มใหม่
      items.add(CartItemModel(
        productId: productId,
        productCode: productCode,
        productName: productName,
        unit: unit,
        price: price,
        quantity: quantity,
      ));
    }
    
    state = state.copyWith(items: items);
  }
  
  /// ลบสินค้าออกจากตะกร้า
  void removeItem(String productId) {
    final items = state.items.where((item) => item.productId != productId).toList();
    state = state.copyWith(items: items);
  }
  
  /// เปลี่ยนจำนวนสินค้า
  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    
    final items = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    
    state = state.copyWith(items: items);
  }
  
  /// เปลี่ยนส่วนลดของสินค้า
  void updateItemDiscount(String productId, double discount) {
    final items = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(discount: discount);
      }
      return item;
    }).toList();
    
    state = state.copyWith(items: items);
  }
  
  /// เพิ่มหมายเหตุ
  void updateItemNote(String productId, String note) {
    final items = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(note: note);
      }
      return item;
    }).toList();
    
    state = state.copyWith(items: items);
  }
  
  /// ตั้งค่าลูกค้า
  void setCustomer(String customerId, String customerName) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
    );
  }
  
  /// ตั้งค่าส่วนลดทั้งบิล
  void setDiscount({double? percent, double? amount}) {
    state = state.copyWith(
      discountPercent: percent ?? state.discountPercent,
      discountAmount: amount ?? state.discountAmount,
    );
  }
  
  /// ล้างตะกร้า
  void clear() {
    state = CartState(items: []);
  }
}