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

  static final RegExp _hexColorRegex = RegExp(
    r'#?[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?',
  );
  static final RegExp _namedColorRegex = RegExp(
    r'(?:color|colour)\s*[:=]\s*([A-Za-z0-9#_-]+)',
    caseSensitive: false,
  );
  static final RegExp _iconRegex = RegExp(
    r'icon\s*[:=]\s*([A-Za-z0-9._-]+)',
    caseSensitive: false,
  );

  Router get router {
    final router = Router();

    router.get('/', _getProductsHandler);
    router.get('/groups', _getGroupsHandler);
    router.get('/groups/<id>/check-delete', _checkDeleteGroupHandler);
    router.post('/groups', _createGroupHandler);
    router.put('/groups/<id>', _updateGroupHandler);
    router.delete('/groups/<id>', _deleteGroupHandler);
    router.get('/<id>/check-delete', _checkDeleteProductHandler);
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
    'unit_conversion': p.unitConversion, // JSON: [{"unit":"ลัง","factor":24}]
    'price_level1': p.priceLevel1,
    'price_level2': p.priceLevel2,
    'price_level3': p.priceLevel3,
    'price_level4': p.priceLevel4,
    'price_level5': p.priceLevel5,
    'standard_cost': p.standardCost,
    'is_stock_control': p.isStockControl,
    'allow_negative_stock': p.allowNegativeStock,
    'is_active': p.isActive,
    'image_path': p.imagePath,
    'service_mode': p.serviceMode,
    'prep_station': p.prepStation,
    'requires_preparation': p.requiresPreparation,
    'dine_in_available': p.dineInAvailable,
    'takeaway_available': p.takeawayAvailable,
  };

  // ─────────────────────────────────────────────────────────────
  // GET /api/products/groups — คืน product groups ทั้งหมด
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getGroupsHandler(Request request) async {
    try {
      final rows = await db.select(db.productGroups).get();
      final data =
          rows
              .map(
                (g) => {
                  'group_id': g.groupId,
                  'group_code': g.groupCode,
                  'group_name': g.groupName,
                  'group_type': g.groupType,
                  'image_url': g.imageUrl,
                  'mobile_color': _extractGroupColor(g),
                  'mobile_icon': _extractGroupIcon(g),
                },
              )
              .toList()
            ..sort(
              (a, b) => (a['group_name'] as String).compareTo(
                b['group_name'] as String,
              ),
            );
      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String? _extractGroupColor(ProductGroup group) {
    for (final raw in [group.imageUrl, group.groupType]) {
      if (raw == null || raw.trim().isEmpty) continue;
      final named = _namedColorRegex.firstMatch(raw)?.group(1);
      final match = named ?? _hexColorRegex.firstMatch(raw)?.group(0);
      final normalized = _normalizeColorToken(match);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _extractGroupIcon(ProductGroup group) {
    for (final raw in [group.groupType, group.imageUrl]) {
      if (raw == null || raw.trim().isEmpty) continue;
      final iconToken = _iconRegex.firstMatch(raw)?.group(1);
      if (iconToken != null && iconToken.trim().isNotEmpty) {
        return iconToken.trim().toLowerCase();
      }

      final normalized = raw.trim().toLowerCase();
      if (_looksLikeIconKey(normalized)) return normalized;
    }
    return null;
  }

  String? _normalizeColorToken(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (_hexColorRegex.hasMatch(value)) {
      final match = _hexColorRegex.firstMatch(value)?.group(0);
      if (match == null || match.isEmpty) return null;
      return match.startsWith('#') ? match : '#$match';
    }

    final lower = value.toLowerCase();
    const supported = {
      'red',
      'pink',
      'purple',
      'deeppurple',
      'deep_purple',
      'indigo',
      'blue',
      'lightblue',
      'light_blue',
      'cyan',
      'teal',
      'green',
      'lightgreen',
      'light_green',
      'lime',
      'yellow',
      'amber',
      'orange',
      'deeporange',
      'deep_orange',
      'brown',
      'bluegrey',
      'blue_grey',
      'gray',
      'grey',
    };
    return supported.contains(lower) ? lower : null;
  }

  bool _looksLikeIconKey(String value) {
    const known = {
      'apps',
      'inventory',
      'inventory_2',
      'shopping_basket',
      'sell',
      'local_drink',
      'fastfood',
      'icecream',
      'kitchen',
      'spa',
      'bakery_dining',
      'lunch_dining',
      'local_cafe',
      'storefront',
      'pets',
      'medication',
      'cleaning_services',
    };
    return known.contains(value);
  }

  String _encodeGroupType({required String iconKey}) {
    return 'GENERAL|icon:${iconKey.trim().toLowerCase()}';
  }

  String? _encodeGroupImage({String? colorHex}) {
    final color = colorHex?.trim();
    if (color == null || color.isEmpty) return null;
    return 'color:$color';
  }

  String _normalizeIconKey(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return _looksLikeIconKey(value) ? value : 'inventory_2';
  }

  String? _normalizeColorHex(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    final match = _hexColorRegex.firstMatch(value)?.group(0);
    if (match == null || match.isEmpty) return null;
    return match.startsWith('#') ? match : '#$match';
  }

  List<String> _validateGroupPayload(
    Map<String, dynamic> data, {
    bool isUpdate = false,
  }) {
    final errors = <String>[];

    final codeError = InputValidators.validateString(
      data,
      'group_code',
      maxLen: 20,
      required: !isUpdate,
    );
    if (codeError != null) errors.add(codeError);

    final nameError = InputValidators.validateString(
      data,
      'group_name',
      maxLen: 200,
      required: !isUpdate,
    );
    if (nameError != null) errors.add(nameError);

    if (data.containsKey('mobile_color') &&
        data['mobile_color'] != null &&
        _normalizeColorHex(data['mobile_color']) == null) {
      errors.add('mobile_color ต้องเป็นค่าสีแบบ #RRGGBB');
    }

    return errors;
  }

  Future<Response> _checkDeleteGroupHandler(Request request, String id) async {
    try {
      final countRow = await db
          .customSelect(
            'SELECT COUNT(*) AS total FROM products WHERE group_id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      final total = countRow.read<int>('total');

      return Response.ok(
        jsonEncode({
          'success': true,
          'has_products': total > 0,
          'product_count': total,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createGroupHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final errors = _validateGroupPayload(data);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      final groupCode = (data['group_code'] as String).trim().toUpperCase();
      final groupName = (data['group_name'] as String).trim();
      final existing = await (db.select(
        db.productGroups,
      )..where((t) => t.groupCode.equals(groupCode))).getSingleOrNull();
      if (existing != null) {
        return InputValidators.badRequest(
          'รหัสหมวดสินค้า $groupCode มีอยู่แล้ว',
        );
      }

      final groupId =
          'GRP${DateTime.now().microsecondsSinceEpoch.toString().substring(6)}';
      await db
          .into(db.productGroups)
          .insert(
            ProductGroupsCompanion.insert(
              groupId: groupId,
              groupCode: groupCode,
              groupName: groupName,
              groupType: Value(
                _encodeGroupType(
                  iconKey: _normalizeIconKey(data['mobile_icon']),
                ),
              ),
              imageUrl: Value(
                _encodeGroupImage(
                  colorHex: _normalizeColorHex(data['mobile_color']),
                ),
              ),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างหมวดสินค้าสำเร็จ',
          'data': {'group_id': groupId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _updateGroupHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final errors = _validateGroupPayload(data, isUpdate: true);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      final existing = await (db.select(
        db.productGroups,
      )..where((t) => t.groupId.equals(id))).getSingleOrNull();
      if (existing == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบหมวดสินค้า'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final nextCode =
          (data['group_code'] as String?)?.trim().toUpperCase() ??
          existing.groupCode;
      final nextName =
          (data['group_name'] as String?)?.trim() ?? existing.groupName;

      final duplicate =
          await (db.select(db.productGroups)..where(
                (t) => t.groupCode.equals(nextCode) & t.groupId.isNotValue(id),
              ))
              .getSingleOrNull();
      if (duplicate != null) {
        return InputValidators.badRequest(
          'รหัสหมวดสินค้า $nextCode มีอยู่แล้ว',
        );
      }

      await (db.update(
        db.productGroups,
      )..where((t) => t.groupId.equals(id))).write(
        ProductGroupsCompanion(
          groupCode: Value(nextCode),
          groupName: Value(nextName),
          groupType: Value(
            _encodeGroupType(
              iconKey: _normalizeIconKey(
                data.containsKey('mobile_icon')
                    ? data['mobile_icon']
                    : _extractGroupIcon(existing),
              ),
            ),
          ),
          imageUrl: Value(
            _encodeGroupImage(
              colorHex: _normalizeColorHex(
                data.containsKey('mobile_color')
                    ? data['mobile_color']
                    : _extractGroupColor(existing),
              ),
            ),
          ),
        ),
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'อัปเดตหมวดสินค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteGroupHandler(Request request, String id) async {
    try {
      final countRow = await db
          .customSelect(
            'SELECT COUNT(*) AS total FROM products WHERE group_id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      final total = countRow.read<int>('total');
      if (total > 0) {
        return Response(
          409,
          body: jsonEncode({
            'success': false,
            'message': 'หมวดสินค้านี้ยังถูกใช้อยู่ในสินค้า $total รายการ',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final deleted = await (db.delete(
        db.productGroups,
      )..where((t) => t.groupId.equals(id))).go();
      if (deleted == 0) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบหมวดสินค้า'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'ลบหมวดสินค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

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

      final where = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';

      // ── COUNT query ──
      final countResult = await db
          .customSelect(
            'SELECT COUNT(*) as total FROM products $where',
            variables: variables,
          )
          .getSingle();
      final total = countResult.read<int>('total');

      // ── Data query with LIMIT/OFFSET ──
      variables.addAll([Variable.withInt(limit), Variable.withInt(offset)]);

      final rows = await db.customSelect('''
            SELECT
              product_id, product_code, product_name, barcode, group_id,
              base_unit, price_level1, price_level2, price_level3,
              price_level4, price_level5, standard_cost,
              is_stock_control, allow_negative_stock, is_active,
              image_path
            FROM products
            $where
            ORDER BY product_code ASC
            LIMIT ? OFFSET ?
            ''', variables: variables).get();

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
              'image_path': row.readNullable<String>('image_path'),
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
      final product = await (db.select(
        db.products,
      )..where((t) => t.productId.equals(id))).getSingleOrNull();

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
      final existing =
          await (db.select(db.products)..where(
                (t) => t.productCode.equals(data['product_code'] as String),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return InputValidators.badRequest(
          'รหัสสินค้า ${data['product_code']} มีอยู่ในระบบแล้ว',
        );
      }

      final productId = 'PRD${DateTime.now().millisecondsSinceEpoch}';

      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              productId: productId,
              productCode: data['product_code'] as String,
              productName: data['product_name'] as String,
              baseUnit: data['base_unit'] as String,
              barcode: Value(data['barcode'] as String?),
              groupId: Value(data['group_id'] as String?),
              // ✅ safe cast ผ่าน num? — ป้องกัน crash จาก int input
              priceLevel1: Value(
                (data['price_level1'] as num?)?.toDouble() ?? 0,
              ),
              priceLevel2: Value(
                (data['price_level2'] as num?)?.toDouble() ?? 0,
              ),
              priceLevel3: Value(
                (data['price_level3'] as num?)?.toDouble() ?? 0,
              ),
              priceLevel4: Value(
                (data['price_level4'] as num?)?.toDouble() ?? 0,
              ),
              priceLevel5: Value(
                (data['price_level5'] as num?)?.toDouble() ?? 0,
              ),
              standardCost: Value(
                (data['standard_cost'] as num?)?.toDouble() ?? 0,
              ),
              isStockControl: Value(data['is_stock_control'] as bool? ?? true),
              allowNegativeStock: Value(
                data['allow_negative_stock'] as bool? ?? false,
              ),
              imagePath: Value(data['image_path'] as String?),
              serviceMode: Value(
                (data['service_mode'] as String? ?? 'RETAIL').toUpperCase(),
              ),
              prepStation: Value(
                (data['prep_station'] as String?)?.toUpperCase(),
              ),
              requiresPreparation: Value(
                data['requires_preparation'] as bool? ?? false,
              ),
              dineInAvailable: Value(
                data['dine_in_available'] as bool? ?? false,
              ),
              takeawayAvailable: Value(
                data['takeaway_available'] as bool? ?? false,
              ),
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
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่',
        }),
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
        final dupe =
            await (db.select(db.products)..where(
                  (t) =>
                      t.productCode.equals(data['product_code'] as String) &
                      t.productId.isNotValue(id),
                ))
                .getSingleOrNull();
        if (dupe != null) {
          return InputValidators.badRequest(
            'รหัสสินค้า ${data['product_code']} มีอยู่ในระบบแล้ว',
          );
        }
      }

      await (db.update(
        db.products,
      )..where((t) => t.productId.equals(id))).write(
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
          allowNegativeStock: Value(
            data['allow_negative_stock'] as bool? ?? false,
          ),
          serviceMode: data.containsKey('service_mode')
              ? Value(
                  (data['service_mode'] as String? ?? 'RETAIL').toUpperCase(),
                )
              : const Value.absent(),
          prepStation: data.containsKey('prep_station')
              ? Value((data['prep_station'] as String?)?.toUpperCase())
              : const Value.absent(),
          requiresPreparation: data.containsKey('requires_preparation')
              ? Value(data['requires_preparation'] as bool? ?? false)
              : const Value.absent(),
          dineInAvailable: data.containsKey('dine_in_available')
              ? Value(data['dine_in_available'] as bool? ?? false)
              : const Value.absent(),
          takeawayAvailable: data.containsKey('takeaway_available')
              ? Value(data['takeaway_available'] as bool? ?? false)
              : const Value.absent(),
          imagePath: data.containsKey('image_path')
              ? Value(data['image_path'] as String?)
              : const Value.absent(),
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
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่',
        }),
      );
    }
  }

  // ─── GET /:id/check-delete ────────────────────────────────────────────────
  /// ตรวจก่อนลบ — คืนข้อมูลว่ามีประวัติการขาย/สต๊อกไหม ไม่มีผลต่อข้อมูล
  Future<Response> _checkDeleteProductHandler(
    Request request,
    String id,
  ) async {
    try {
      final salesRow = await db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM sales_order_items WHERE product_id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      final salesCount = (salesRow.data['cnt'] as int?) ?? 0;

      final movRow = await db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM stock_movements WHERE product_id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      final movCount = (movRow.data['cnt'] as int?) ?? 0;

      return Response.ok(
        jsonEncode({
          'success': true,
          'has_history': salesCount > 0 || movCount > 0,
          'has_sales': salesCount > 0,
          'sales_count': salesCount,
          'has_movements': movCount > 0,
          'movement_count': movCount,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /api/products/:id - ลบสินค้า (Soft Delete — ตรวจก่อนลบ)
  Future<Response> _deleteProductHandler(Request request, String id) async {
    try {
      // ── ตรวจสอบประวัติการใช้งาน ──────────────────────────────
      final hasSales =
          await (db.select(db.salesOrderItems)
                ..where((t) => t.productId.equals(id))
                ..limit(1))
              .getSingleOrNull() !=
          null;

      final hasMovements =
          await (db.select(db.stockMovements)
                ..where((t) => t.productId.equals(id))
                ..limit(1))
              .getSingleOrNull() !=
          null;

      final hasHistory = hasSales || hasMovements;

      if (hasHistory) {
        // ── Soft Delete — มีประวัติ → ปิดการใช้งานแทน ────────
        await (db.update(
          db.products,
        )..where((t) => t.productId.equals(id))).write(
          ProductsCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
        return Response.ok(
          jsonEncode({
            'success': true,
            'soft_delete': true,
            'message':
                'ปิดการใช้งานสินค้าสำเร็จ\n(มีประวัติการขาย จึงเก็บข้อมูลไว้)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        // ── Hard Delete — ไม่มีประวัติ ลบได้เลย ──────────────
        await (db.delete(
          db.products,
        )..where((t) => t.productId.equals(id))).go();
        return Response.ok(
          jsonEncode({
            'success': true,
            'soft_delete': false,
            'message': 'ลบสินค้าสำเร็จ',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// GET /api/products/barcode/:barcode - ค้นหาด้วย Barcode
  Future<Response> _getProductByBarcodeHandler(
    Request request,
    String barcode,
  ) async {
    try {
      final product = await (db.select(
        db.products,
      )..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

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
