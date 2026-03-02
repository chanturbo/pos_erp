class StockMovementModel {
  final String movementId;
  final DateTime movementDate;
  final String movementType;
  final String productId;
  final String warehouseId;
  final double quantity;
  final String? referenceNo;
  final String? remark;
  
  StockMovementModel({
    required this.movementId,
    required this.movementDate,
    required this.movementType,
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    this.referenceNo,
    this.remark,
  });
  
  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      movementId: json['movement_id'] as String,
      movementDate: DateTime.parse(json['movement_date'] as String),
      movementType: json['movement_type'] as String,
      productId: json['product_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      referenceNo: json['reference_no'] as String?,
      remark: json['remark'] as String?,
    );
  }
  
  String get movementTypeText {
    switch (movementType) {
      case 'IN':
        return 'รับเข้า';
      case 'OUT':
        return 'เบิกออก';
      case 'ADJUST':
        return 'ปรับสต๊อก';
      case 'TRANSFER':
        return 'โอนย้าย';
      default:
        return movementType;
    }
  }
}