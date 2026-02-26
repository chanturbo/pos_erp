import 'package:drift/drift.dart';
import 'product_tables.dart';

// ========================================
// MODIFIER GROUPS
// ========================================
@DataClassName('ModifierGroup')
class ModifierGroups extends Table {
  TextColumn get modifierGroupId => text()();
  TextColumn get groupName => text().withLength(max: 200)();
  TextColumn get selectionType => text().withDefault(const Constant('SINGLE'))();
  IntColumn get minSelection => integer().withDefault(const Constant(0))();
  IntColumn get maxSelection => integer().withDefault(const Constant(1))();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {modifierGroupId};
}

// ========================================
// MODIFIERS
// ========================================
@DataClassName('Modifier')
class Modifiers extends Table {
  TextColumn get modifierId => text()();
  TextColumn get modifierGroupId => text().references(ModifierGroups, #modifierGroupId)();
  TextColumn get modifierName => text().withLength(max: 200)();
  RealColumn get priceAdjustment => real().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {modifierId};
}

// ========================================
// PRODUCT MODIFIERS (ผูกสินค้ากับ Modifier Group)
// ========================================
@DataClassName('ProductModifier')
class ProductModifiers extends Table {
  TextColumn get productId => text().references(Products, #productId)();
  TextColumn get modifierGroupId => text().references(ModifierGroups, #modifierGroupId)();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {productId, modifierGroupId};
}