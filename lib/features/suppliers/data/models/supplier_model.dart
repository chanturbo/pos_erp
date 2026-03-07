class SupplierModel {
  final String supplierId;
  final String supplierCode;
  final String supplierName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? lineId;  // ✅ เพิ่มบรรทัดนี้
  final String? address;
  final String? taxId;
  final int creditTerm;
  final double creditLimit;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    this.contactPerson,
    this.phone,
    this.email,
    this.lineId,  // ✅ เพิ่มบรรทัดนี้
    this.address,
    this.taxId,
    this.creditTerm = 30,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      supplierId: json['supplier_id'] as String,
      supplierCode: json['supplier_code'] as String,
      supplierName: json['supplier_name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      lineId: json['line_id'] as String?,  // ✅ เพิ่มบรรทัดนี้
      address: json['address'] as String?,
      taxId: json['tax_id'] as String?,
      creditTerm: json['credit_term'] as int? ?? 30,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'supplier_code': supplierCode,
      'supplier_name': supplierName,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'line_id': lineId,  // ✅ เพิ่มบรรทัดนี้
      'address': address,
      'tax_id': taxId,
      'credit_term': creditTerm,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplierModel copyWith({
    String? supplierId,
    String? supplierCode,
    String? supplierName,
    String? contactPerson,
    String? phone,
    String? email,
    String? lineId,  // ✅ เพิ่มบรรทัดนี้
    String? address,
    String? taxId,
    int? creditTerm,
    double? creditLimit,
    double? currentBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      supplierId: supplierId ?? this.supplierId,
      supplierCode: supplierCode ?? this.supplierCode,
      supplierName: supplierName ?? this.supplierName,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lineId: lineId ?? this.lineId,  // ✅ เพิ่มบรรทัดนี้
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      creditTerm: creditTerm ?? this.creditTerm,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}