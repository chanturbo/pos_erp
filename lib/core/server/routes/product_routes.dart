// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../../utils/input_validators.dart';

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

  // ─────────────────────────────────────────────────────────────
  // Helper: Product row → Map
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> _productToMap(Product p) => {
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
      };

  // ─────────────────────────────────────────────────────────────
  // GET /api/products
  // รองรับ query params:
  //   ?limit=500&offset=0  → pagination
  //   ?search=xxx          → filter ฝั่ง server
  //   ?active_only=true    → กรองเฉพาะ active
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getProductsHandler(Request request) async {
    try {
      final params = request.url.queryParameters;

      // ── Pagination params ──
      final limit = int.tryParse(params['limit'] ?? '500') ?? 500;
      final offset = int.tryParse(params['offset'] ?? '0') ?? 0;

      // ── Optional filters ──
      final search = (params['search'] ?? '').trim().toLowerCase();
      final activeOnly = params['active_only'] == 'true';

      // ── Build WHERE clause ──
      final conditions = <String>[];
      final variables = <Variable>[];

      if (activeOnly) {
        conditions.add('is_active = 1');
      }
      if (search.isNotEmpty) {
        conditions.add(
          '(LOWER(product_name) LIKE ? OR LOWER(product_code) LIKE ? OR barcode LIKE ?)',
        );
        final pattern = '%$search%';
        variables.addAll([
          Variable.withString(pattern),
          Variable.withString(pattern),
          Variable.withString(pattern),
        ]);
      }

      final where =
          conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

      // ── COUNT query ──
      final countResult = await db
          .customSelect(
            'SELECT COUNT(*) as total FROM products $where',
            variables: variables,
          )
          .getSingle();
      final total = countResult.read<int>('total');

      // ── Data query with LIMIT/OFFSET ──
      variables.addAll([
        Variable.withInt(limit),
        Variable.withInt(offset),
      ]);

      final rows = await db
          .customSelect(
            '''
            SELECT
              product_id, product_code, product_name, barcode, group_id,
              base_unit, price_level1, price_level2, price_level3,
              price_level4, price_level5, standard_cost,
              is_stock_control, allow_negative_stock, is_active
            FROM products
            $where
            ORDER BY product_code ASC
            LIMIT ? OFFSET ?
            ''',
            variables: variables,
          )
          .get();

      final data = rows
          .map(
            (row) => {
              'product_id': row.read<String>('product_id'),
              'product_code': row.read<String>('product_code'),
              'product_name': row.read<String>('product_name'),
              'barcode': row.readNullable<String>('barcode'),
              'group_id': row.readNullable<String>('group_id'),
              'base_unit': row.read<String>('base_unit'),
              'price_level1': row.read<double>('price_level1'),
              'price_level2': row.read<double>('price_level2'),
              'price_level3': row.read<double>('price_level3'),
              'price_level4': row.read<double>('price_level4'),
              'price_level5': row.read<double>('price_level5'),
              'standard_cost': row.read<double>('standard_cost'),
              'is_stock_control': row.read<bool>('is_stock_control'),
              'allow_negative_stock': row.read<bool>('allow_negative_stock'),
              'is_active': row.read<bool>('is_active'),
            },
          )
          .toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': data,
          'pagination': {
            'total': total,
            'limit': limit,
            'offset': offset,
            'has_more': (offset + limit) < total,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
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
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบสินค้า'}),
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': _productToMap(product)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// POST /api/products - สร้างสินค้าใหม่
  Future<Response> _createProductHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // ✅ Validate ก่อน insert
      final errors = InputValidators.validateProduct(data);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      // ✅ ตรวจสอบ product_code ซ้ำ
      final existing = await (db.select(db.products)
            ..where((t) =>
                t.productCode.equals(data['product_code'] as String)))
          .getSingleOrNull();
      if (existing != null) {
        return InputValidators.badRequest(
            'รหัสสินค้า ${data['product_code']} มีอยู่ในระบบแล้ว');
      }

      final productId = 'PRD${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              productId: productId,
              productCode: data['product_code'] as String,
              productName: data['product_name'] as String,
              baseUnit: data['base_unit'] as String,
              barcode: Value(data['barcode'] as String?),
              groupId: Value(data['group_id'] as String?),
              // ✅ safe cast ผ่าน num? — ป้องกัน crash จาก int input
              priceLevel1: Value((data['price_level1'] as num?)?.toDouble() ?? 0),
              priceLevel2: Value((data['price_level2'] as num?)?.toDouble() ?? 0),
              priceLevel3: Value((data['price_level3'] as num?)?.toDouble() ?? 0),
              priceLevel4: Value((data['price_level4'] as num?)?.toDouble() ?? 0),
              priceLevel5: Value((data['price_level5'] as num?)?.toDouble() ?? 0),
              standardCost: Value((data['standard_cost'] as num?)?.toDouble() ?? 0),
              isStockControl: Value(data['is_stock_control'] as bool? ?? true),
              allowNegativeStock: Value(data['allow_negative_stock'] as bool? ?? false),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างสินค้าสำเร็จ',
          'data': {'product_id': productId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ POST /api/products error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// PUT /api/products/:id - แก้ไขสินค้า
  Future<Response> _updateProductHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // ✅ Validate ก่อน update
      final errors = InputValidators.validateProduct(data, isUpdate: true);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      // ✅ ตรวจสอบ product_code ซ้ำ (เฉพาะเมื่อเปลี่ยน code)
      if (data.containsKey('product_code')) {
        final dupe = await (db.select(db.products)
              ..where((t) =>
                  t.productCode.equals(data['product_code'] as String) &
                  t.productId.isNotValue(id)))
            .getSingleOrNull();
        if (dupe != null) {
          return InputValidators.badRequest(
              'รหัสสินค้า ${data['product_code']} มีอยู่ในระบบแล้ว');
        }
      }

      await (db.update(db.products)..where((t) => t.productId.equals(id)))
          .write(
        ProductsCompanion(
          productCode: data.containsKey('product_code')
              ? Value(data['product_code'] as String)
              : const Value.absent(),
          productName: data.containsKey('product_name')
              ? Value(data['product_name'] as String)
              : const Value.absent(),
          baseUnit: data.containsKey('base_unit')
              ? Value(data['base_unit'] as String)
              : const Value.absent(),
          barcode: Value(data['barcode'] as String?),
          groupId: Value(data['group_id'] as String?),
          // ✅ ใช้ price_level1 (ไม่มี underscore กลาง) ตรงกับ key ที่ client ส่งมา
          priceLevel1: Value((data['price_level1'] as num?)?.toDouble() ?? 0),
          priceLevel2: Value((data['price_level2'] as num?)?.toDouble() ?? 0),
          priceLevel3: Value((data['price_level3'] as num?)?.toDouble() ?? 0),
          priceLevel4: Value((data['price_level4'] as num?)?.toDouble() ?? 0),
          priceLevel5: Value((data['price_level5'] as num?)?.toDouble() ?? 0),
          standardCost: Value((data['standard_cost'] as num?)?.toDouble() ?? 0),
          isStockControl: Value(data['is_stock_control'] as bool? ?? true),
          allowNegativeStock: Value(data['allow_negative_stock'] as bool? ?? false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'แก้ไขสินค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PUT /api/products/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// DELETE /api/products/:id - ลบสินค้า
  Future<Response> _deleteProductHandler(Request request, String id) async {
    try {
      await (db.delete(db.products)..where((t) => t.productId.equals(id)))
          .go();

      return Response.ok(
        jsonEncode({'success': true, 'message': 'ลบสินค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// GET /api/products/barcode/:barcode - ค้นหาด้วย Barcode
  Future<Response> _getProductByBarcodeHandler(
      Request request, String barcode) async {
    try {
      final product = await (db.select(db.products)
            ..where((t) => t.barcode.equals(barcode)))
          .getSingleOrNull();

      if (product == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบสินค้า'}),
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': _productToMap(product)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }
}