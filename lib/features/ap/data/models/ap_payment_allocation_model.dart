class ApPaymentAllocationModel {
  final String allocationId;
  final String paymentId;
  final String invoiceId;
  final double allocatedAmount;
  final DateTime createdAt;

  ApPaymentAllocationModel({
    required this.allocationId,
    required this.paymentId,
    required this.invoiceId,
    required this.allocatedAmount,
    required this.createdAt,
  });

  factory ApPaymentAllocationModel.fromJson(Map<String, dynamic> json) {
    return ApPaymentAllocationModel(
      allocationId: json['allocation_id'] as String,
      paymentId: json['payment_id'] as String,
      invoiceId: json['invoice_id'] as String,
      allocatedAmount: (json['allocated_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allocation_id': allocationId,
      'payment_id': paymentId,
      'invoice_id': invoiceId,
      'allocated_amount': allocatedAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ApPaymentAllocationModel copyWith({
    String? allocationId,
    String? paymentId,
    String? invoiceId,
    double? allocatedAmount,
    DateTime? createdAt,
  }) {
    return ApPaymentAllocationModel(
      allocationId: allocationId ?? this.allocationId,
      paymentId: paymentId ?? this.paymentId,
      invoiceId: invoiceId ?? this.invoiceId,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}