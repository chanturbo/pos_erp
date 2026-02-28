class CustomerModel {
  final String customerId;
  final String customerCode;
  final String customerName;
  final String? customerGroupId;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxId;
  final double creditLimit;
  final int creditDays;
  final double currentBalance;
  final String? memberNo;
  final int points;
  final bool isActive;
  
  CustomerModel({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.customerGroupId,
    this.address,
    this.phone,
    this.email,
    this.taxId,
    this.creditLimit = 0,
    this.creditDays = 0,
    this.currentBalance = 0,
    this.memberNo,
    this.points = 0,
    this.isActive = true,
  });
  
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      customerId: json['customer_id'] as String,
      customerCode: json['customer_code'] as String,
      customerName: json['customer_name'] as String,
      customerGroupId: json['customer_group_id'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      taxId: json['tax_id'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      creditDays: json['credit_days'] as int? ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      memberNo: json['member_no'] as String?,
      points: json['points'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_code': customerCode,
      'customer_name': customerName,
      'customer_group_id': customerGroupId,
      'address': address,
      'phone': phone,
      'email': email,
      'tax_id': taxId,
      'credit_limit': creditLimit,
      'credit_days': creditDays,
      'current_balance': currentBalance,
      'member_no': memberNo,
      'points': points,
      'is_active': isActive,
    };
  }
}