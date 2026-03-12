// promotion_model.dart
// Day 41-45: Promotion & Coupon Model

class PromotionModel {
  final String promotionId;
  final String promotionCode;
  final String promotionName;

  /// DISCOUNT_PERCENT, DISCOUNT_AMOUNT, BUY_X_GET_Y, FREE_ITEM
  final String promotionType;

  /// PERCENT, AMOUNT
  final String? discountType;
  final double discountValue;
  final double? maxDiscountAmount;

  // Buy X Get Y
  final int? buyQty;
  final int? getQty;
  final String? getProductId;

  // Conditions
  final double minAmount;
  final double minQty;

  /// ALL, PRODUCT, CATEGORY
  final String applyTo;
  final List<String>? applyToIds;

  // Period
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime; // HH:mm
  final String? endTime;
  final List<int>? applyDays; // 1=Mon ... 7=Sun

  // Limits
  final int? maxUses;
  final int? maxUsesPerCustomer;
  final int currentUses;

  final bool isExclusive;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromotionModel({
    required this.promotionId,
    required this.promotionCode,
    required this.promotionName,
    required this.promotionType,
    this.discountType,
    this.discountValue = 0,
    this.maxDiscountAmount,
    this.buyQty,
    this.getQty,
    this.getProductId,
    this.minAmount = 0,
    this.minQty = 0,
    this.applyTo = 'ALL',
    this.applyToIds,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    this.applyDays,
    this.maxUses,
    this.maxUsesPerCustomer,
    this.currentUses = 0,
    this.isExclusive = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isStarted => DateTime.now().isAfter(startDate);
  bool get isRunning => isStarted && !isExpired && isActive;
  bool get isUsageLimitReached =>
      maxUses != null && currentUses >= maxUses!;

  /// คำนวณส่วนลดจาก subtotal
  double calculateDiscount(double subtotal, {int itemQty = 0}) {
    if (!isRunning) return 0;
    if (subtotal < minAmount) return 0;
    if (itemQty < minQty) return 0;

    double discount = 0;

    switch (promotionType) {
      case 'DISCOUNT_PERCENT':
        discount = subtotal * (discountValue / 100);
        if (maxDiscountAmount != null) {
          discount = discount.clamp(0, maxDiscountAmount!);
        }
        break;
      case 'DISCOUNT_AMOUNT':
        discount = discountValue;
        break;
      default:
        discount = 0;
    }

    return discount;
  }

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      promotionId: json['promotion_id'] as String,
      promotionCode: json['promotion_code'] as String,
      promotionName: json['promotion_name'] as String,
      promotionType: json['promotion_type'] as String,
      discountType: json['discount_type'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount:
          (json['max_discount_amount'] as num?)?.toDouble(),
      buyQty: json['buy_qty'] as int?,
      getQty: json['get_qty'] as int?,
      getProductId: json['get_product_id'] as String?,
      minAmount: (json['min_amount'] as num?)?.toDouble() ?? 0,
      minQty: (json['min_qty'] as num?)?.toDouble() ?? 0,
      applyTo: json['apply_to'] as String? ?? 'ALL',
      applyToIds: json['apply_to_ids'] != null
          ? List<String>.from(json['apply_to_ids'] as List)
          : null,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      applyDays: json['apply_days'] != null
          ? List<int>.from(json['apply_days'] as List)
          : null,
      maxUses: json['max_uses'] as int?,
      maxUsesPerCustomer: json['max_uses_per_customer'] as int?,
      currentUses: json['current_uses'] as int? ?? 0,
      isExclusive: json['is_exclusive'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'promotion_id': promotionId,
      'promotion_code': promotionCode,
      'promotion_name': promotionName,
      'promotion_type': promotionType,
      'discount_type': discountType,
      'discount_value': discountValue,
      'max_discount_amount': maxDiscountAmount,
      'buy_qty': buyQty,
      'get_qty': getQty,
      'get_product_id': getProductId,
      'min_amount': minAmount,
      'min_qty': minQty,
      'apply_to': applyTo,
      'apply_to_ids': applyToIds,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'apply_days': applyDays,
      'max_uses': maxUses,
      'max_uses_per_customer': maxUsesPerCustomer,
      'current_uses': currentUses,
      'is_exclusive': isExclusive,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PromotionModel copyWith({
    String? promotionId,
    String? promotionCode,
    String? promotionName,
    String? promotionType,
    String? discountType,
    double? discountValue,
    double? maxDiscountAmount,
    int? buyQty,
    int? getQty,
    String? getProductId,
    double? minAmount,
    double? minQty,
    String? applyTo,
    List<String>? applyToIds,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    List<int>? applyDays,
    int? maxUses,
    int? maxUsesPerCustomer,
    int? currentUses,
    bool? isExclusive,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromotionModel(
      promotionId: promotionId ?? this.promotionId,
      promotionCode: promotionCode ?? this.promotionCode,
      promotionName: promotionName ?? this.promotionName,
      promotionType: promotionType ?? this.promotionType,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      buyQty: buyQty ?? this.buyQty,
      getQty: getQty ?? this.getQty,
      getProductId: getProductId ?? this.getProductId,
      minAmount: minAmount ?? this.minAmount,
      minQty: minQty ?? this.minQty,
      applyTo: applyTo ?? this.applyTo,
      applyToIds: applyToIds ?? this.applyToIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      applyDays: applyDays ?? this.applyDays,
      maxUses: maxUses ?? this.maxUses,
      maxUsesPerCustomer:
          maxUsesPerCustomer ?? this.maxUsesPerCustomer,
      currentUses: currentUses ?? this.currentUses,
      isExclusive: isExclusive ?? this.isExclusive,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Coupon Model ─────────────────────────────────────────────────────────────
class CouponModel {
  final String couponId;
  final String couponCode;
  final String promotionId;
  final String? promotionName;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  CouponModel({
    required this.couponId,
    required this.couponCode,
    required this.promotionId,
    this.promotionName,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isValid => !isUsed && !isExpired;

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      couponId: json['coupon_id'] as String,
      couponCode: json['coupon_code'] as String,
      promotionId: json['promotion_id'] as String,
      promotionName: json['promotion_name'] as String?,
      isUsed: json['is_used'] as bool? ?? false,
      usedBy: json['used_by'] as String?,
      usedAt:
          json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coupon_id': couponId,
      'coupon_code': couponCode,
      'promotion_id': promotionId,
      'promotion_name': promotionName,
      'is_used': isUsed,
      'used_by': usedBy,
      'used_at': usedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}