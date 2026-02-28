import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class ProductRoutes {
  final AppDatabase db;
  
  ProductRoutes(this.db);
  
  Router get router {
    final router = Router();
    
    router.get('/', _getProductsHandler);
    router.get('/<id>', _getProductHandler);
    router.post('/', _createProductHandler);
    router.put('/<id>', _updateProductHandler);
    router.delete('/<id>', _deleteProductHandler);
    router.get('/barcode/<barcode>', _getProductByBarcodeHandler);
    
    return router;
  }
  
  /// GET /api/products - รายการสินค้าทั้งหมด
  Future<Response> _getProductsHandler(Request request) async {
    try {
      final products = await db.select(db.products).get();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': products.map((p) => {
          'product_id': p.productId,
          'product_code': p.productCode,
          'product_name': p.productName,
          'barcode': p.barcode,
          'group_id': p.groupId,
          'base_unit': p.baseUnit,
          'price_level1': p.priceLevel1,
          'price_level2': p.priceLevel2,
          'price_level3': p.priceLevel3,
          'price_level4': p.priceLevel4,
          'price_level5': p.priceLevel5,
          'standard_cost': p.standardCost,
          'is_stock_control': p.isStockControl,
          'allow_negative_stock': p.allowNegativeStock,
          'is_active': p.isActive,
        }).toList(),
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// GET /api/products/:id - ดึงสินค้า 1 รายการ
  Future<Response> _getProductHandler(Request request, String id) async {
    try {
      final product = await (db.select(db.products)
            ..where((t) => t.productId.equals(id)))
          .getSingleOrNull();
      
      if (product == null) {
        return Response.notFound(jsonEncode({
          'success': false,
          'message': 'ไม่พบสินค้า',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'product_id': product.productId,
          'product_code': product.productCode,
          'product_name': product.productName,
          'barcode': product.barcode,
          'group_id': product.groupId,
          'base_unit': product.baseUnit,
          'price_level1': product.priceLevel1,
          'price_level2': product.priceLevel2,
          'price_level3': product.priceLevel3,
          'price_level4': product.priceLevel4,
          'price_level5': product.priceLevel5,
          'standard_cost': product.standardCost,
          'is_stock_control': product.isStockControl,
          'allow_negative_stock': product.allowNegativeStock,
          'is_active': product.isActive,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// POST /api/products - สร้างสินค้าใหม่
  Future<Response> _createProductHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Generate Product ID
      final productId = 'PRD${DateTime.now().millisecondsSinceEpoch}';
      
      await db.into(db.products).insert(ProductsCompanion.insert(
        productId: productId,
        productCode: data['product_code'] as String,
        productName: data['product_name'] as String,
        baseUnit: data['base_unit'] as String,
        barcode: Value(data['barcode'] as String?),
        groupId: Value(data['group_id'] as String?),
        priceLevel1: Value(data['price_level1'] as double? ?? 0),
        priceLevel2: Value(data['price_level2'] as double? ?? 0),
        priceLevel3: Value(data['price_level3'] as double? ?? 0),
        priceLevel4: Value(data['price_level4'] as double? ?? 0),
        priceLevel5: Value(data['price_level5'] as double? ?? 0),
        standardCost: Value(data['standard_cost'] as double? ?? 0),
        isStockControl: Value(data['is_stock_control'] as bool? ?? true),
        allowNegativeStock: Value(data['allow_negative_stock'] as bool? ?? false),
      ));
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'สร้างสินค้าสำเร็จ',
        'data': {'product_id': productId},
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// PUT /api/products/:id - แก้ไขสินค้า
  Future<Response> _updateProductHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      await (db.update(db.products)..where((t) => t.productId.equals(id)))
          .write(ProductsCompanion(
        productCode: Value(data['product_code'] as String),
        productName: Value(data['product_name'] as String),
        baseUnit: Value(data['base_unit'] as String),
        barcode: Value(data['barcode'] as String?),
        groupId: Value(data['group_id'] as String?),
        priceLevel1: Value(data['price_level1'] as double? ?? 0),
        priceLevel2: Value(data['price_level2'] as double? ?? 0),
        priceLevel3: Value(data['price_level3'] as double? ?? 0),
        priceLevel4: Value(data['price_level4'] as double? ?? 0),
        priceLevel5: Value(data['price_level5'] as double? ?? 0),
        standardCost: Value(data['standard_cost'] as double? ?? 0),
        isStockControl: Value(data['is_stock_control'] as bool? ?? true),
        allowNegativeStock: Value(data['allow_negative_stock'] as bool? ?? false),
        updatedAt: Value(DateTime.now()),
      ));
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'แก้ไขสินค้าสำเร็จ',
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// DELETE /api/products/:id - ลบสินค้า
  Future<Response> _deleteProductHandler(Request request, String id) async {
    try {
      await (db.delete(db.products)..where((t) => t.productId.equals(id))).go();
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'ลบสินค้าสำเร็จ',
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// GET /api/products/barcode/:barcode - ค้นหาด้วย Barcode
  Future<Response> _getProductByBarcodeHandler(Request request, String barcode) async {
    try {
      final product = await (db.select(db.products)
            ..where((t) => t.barcode.equals(barcode)))
          .getSingleOrNull();
      
      if (product == null) {
        return Response.notFound(jsonEncode({
          'success': false,
          'message': 'ไม่พบสินค้า',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'product_id': product.productId,
          'product_code': product.productCode,
          'product_name': product.productName,
          'barcode': product.barcode,
          'price_level1': product.priceLevel1,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
}