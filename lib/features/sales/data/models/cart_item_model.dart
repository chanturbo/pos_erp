class CartItemModel {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double price;
  final double quantity;
  final double discount;
  final String? note;
  final double unitCost; // ต้นทุนเฉลี่ย (WAC) ณ เวลาเพิ่มสินค้าลงตะกร้า

  CartItemModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.price,
    this.quantity = 1,
    this.discount = 0,
    this.note,
    this.unitCost = 0,
  });

  // คำนวณราคารวม
  double get amount => (price * quantity) - discount;

  // ต้นทุนรวมรายการนี้
  double get cogsAmount => unitCost * quantity;

  // กำไรขั้นต้นรายการนี้
  double get grossProfit => amount - cogsAmount;

  CartItemModel copyWith({
    String? productId,
    String? productCode,
    String? productName,
    String? unit,
    double? price,
    double? quantity,
    double? discount,
    String? note,
    double? unitCost,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      note: note ?? this.note,
      unitCost: unitCost ?? this.unitCost,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_code': productCode,
      'product_name': productName,
      'unit': unit,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'note': note,
      'unit_cost': unitCost,
    };
  }
}