import 'dart:convert';

import 'package:drift/drift.dart';
import 'customer_tables.dart';
import 'sales_tables.dart';
import 'user_tables.dart';

// ========================================
// PROMOTIONS
// ========================================
@DataClassName('Promotion')
class Promotions extends Table {
  TextColumn get promotionId => text()();
  TextColumn get promotionCode => text().withLength(max: 50)();
  TextColumn get promotionName => text().withLength(max: 200)();
  TextColumn get promotionType => text()();
  
  // Discount
  TextColumn get discountType => text().nullable().withLength(max: 20)();
  RealColumn get discountValue => real().withDefault(const Constant(0))();
  RealColumn get maxDiscountAmount => real().nullable()();
  
  // Buy X Get Y
  IntColumn get buyQty => integer().nullable()();
  IntColumn get getQty => integer().nullable()();
  TextColumn get getProductId => text().nullable()();
  
  // Conditions
  RealColumn get minAmount => real().withDefault(const Constant(0))();
  RealColumn get minQty => real().withDefault(const Constant(0))();
  TextColumn get applyTo => text()();
  TextColumn get applyToIds => text().nullable().map(const JsonConverter())();
  
  // Period
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get startTime => text().nullable().withLength(max: 8)();
  TextColumn get endTime => text().nullable().withLength(max: 8)();
  TextColumn get applyDays => text().nullable().map(const JsonConverter())();
  
  // Limits
  IntColumn get maxUses => integer().nullable()();
  IntColumn get maxUsesPerCustomer => integer().nullable()();
  IntColumn get currentUses => integer().withDefault(const Constant(0))();
  
  BoolColumn get isExclusive => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  TextColumn get createdBy => text().nullable().references(Users, #userId)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {promotionId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {promotionCode},
  ];
}

// ========================================
// PROMOTION USAGE
// ========================================
@DataClassName('PromotionUsage')
class PromotionUsages extends Table {
  TextColumn get usageId => text()();
  TextColumn get promotionId => text().references(Promotions, #promotionId)();
  TextColumn get orderId => text().references(SalesOrders, #orderId)();
  TextColumn get customerId => text().nullable().references(Customers, #customerId)();
  RealColumn get discountAmount => real()();
  DateTimeColumn get usedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {usageId};
}

// ========================================
// COUPONS
// ========================================
@DataClassName('Coupon')
class Coupons extends Table {
  TextColumn get couponId => text()();
  TextColumn get couponCode => text().withLength(max: 50)();
  TextColumn get promotionId => text().references(Promotions, #promotionId)();
  BoolColumn get isUsed => boolean().withDefault(const Constant(false))();
  TextColumn get usedBy => text().nullable().references(Customers, #customerId)();
  DateTimeColumn get usedAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {couponId};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {couponCode},
  ];
}

// JSON Converter (ถ้ายังไม่มี)
class JsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonConverter();
  
  @override
  Map<String, dynamic> fromSql(String fromDb) {
    return Map<String, dynamic>.from(
      const JsonCodec().decode(fromDb) as Map
    );
  }
  
  @override
  String toSql(Map<String, dynamic> value) {
    return const JsonCodec().encode(value);
  }
}