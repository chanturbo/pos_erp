class StockMovementModel {
  final String movementId;
  final DateTime movementDate;
  final String movementType;
  final String productId;
  final String warehouseId;
  final double quantity;
  final double unitCost;    // ต้นทุนต่อหน่วย ณ เวลาที่เคลื่อนไหว
  final double avgCostAfter; // ต้นทุนเฉลี่ย (WAC) หลังจากทำรายการ
  final String? referenceNo;
  final String? remark;

  /// มูลค่ารายการ = quantity × unitCost
  double get lineValue => quantity.abs() * unitCost;

  StockMovementModel({
    required this.movementId,
    required this.movementDate,
    required this.movementType,
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    this.unitCost = 0,
    this.avgCostAfter = 0,
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
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      avgCostAfter: (json['avg_cost_after'] as num?)?.toDouble() ?? 0,
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