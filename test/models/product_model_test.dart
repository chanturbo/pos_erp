import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/features/products/data/models/product_model.dart';

void main() {
  group('ProductModel', () {
    // ─── Fixture ──────────────────────────
    final baseJson = {
      'product_id': 'PRD001',
      'product_code': 'F001',
      'product_name': 'ข้าวผัดกุ้ง',
      'barcode': '8850001234567',
      'group_id': 'GRP001',
      'base_unit': 'จาน',
      'price_level1': 50.0,
      'price_level2': 45.0,
      'price_level3': 40.0,
      'price_level4': 0.0,
      'price_level5': 0.0,
      'standard_cost': 30.0,
      'is_stock_control': true,
      'allow_negative_stock': false,
      'is_active': true,
    };

    // ─── fromJson ─────────────────────────
    group('fromJson', () {
      test('parses all fields correctly', () {
        final model = ProductModel.fromJson(baseJson);

        expect(model.productId,          'PRD001');
        expect(model.productCode,        'F001');
        expect(model.productName,        'ข้าวผัดกุ้ง');
        expect(model.barcode,            '8850001234567');
        expect(model.groupId,            'GRP001');
        expect(model.baseUnit,           'จาน');
        expect(model.priceLevel1,        50.0);
        expect(model.priceLevel2,        45.0);
        expect(model.standardCost,       30.0);
        expect(model.isStockControl,     isTrue);
        expect(model.allowNegativeStock, isFalse);
        expect(model.isActive,           isTrue);
      });

      test('uses default values when optional fields are null', () {
        final minimalJson = {
          'product_id': 'PRD002',
          'product_code': 'F002',
          'product_name': 'น้ำเปล่า',
          'base_unit': 'ขวด',
          'price_level1': 10.0,
        };

        final model = ProductModel.fromJson(minimalJson);

        expect(model.barcode,            isNull);
        expect(model.groupId,            isNull);
        expect(model.priceLevel2,        0.0);
        expect(model.priceLevel3,        0.0);
        expect(model.standardCost,       0.0);
        expect(model.isStockControl,     isTrue);
        expect(model.allowNegativeStock, isFalse);
        expect(model.isActive,           isTrue);
      });

      test('handles integer price as double', () {
        final json = {...baseJson, 'price_level1': 50}; // int ไม่ใช่ double
        final model = ProductModel.fromJson(json);
        expect(model.priceLevel1, 50.0);
        expect(model.priceLevel1, isA<double>());
      });
    });

    // ─── toJson ───────────────────────────
    group('toJson', () {
      test('serializes all fields correctly', () {
        final model = ProductModel.fromJson(baseJson);
        final json  = model.toJson();

        expect(json['product_id'],           'PRD001');
        expect(json['product_code'],         'F001');
        expect(json['product_name'],         'ข้าวผัดกุ้ง');
        expect(json['price_level1'],         50.0);
        expect(json['is_stock_control'],     true);
        expect(json['allow_negative_stock'], false);
        expect(json['is_active'],            true);
      });

      test('fromJson -> toJson -> fromJson roundtrip is lossless', () {
        final original  = ProductModel.fromJson(baseJson);
        final json      = original.toJson();
        final recreated = ProductModel.fromJson(json);

        expect(recreated.productId,    original.productId);
        expect(recreated.productCode,  original.productCode);
        expect(recreated.productName,  original.productName);
        expect(recreated.priceLevel1,  original.priceLevel1);
        expect(recreated.standardCost, original.standardCost);
        expect(recreated.isActive,     original.isActive);
      });
    });
  });
}