import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import 'package:flutter/foundation.dart';

class TableRoutes {
  final AppDatabase db;
  TableRoutes(this.db);

  /// In-memory counter incremented every time table status changes.
  static int _tableVersion = 0;

  static void bumpVersion() => _tableVersion++;

  Router get router {
    final r = Router();

    r.get('/version', _getVersion);

    // Zones
    r.get('/zones', _listZones);
    r.post('/zones', _createZone);
    r.put('/zones/<id>', _updateZone);
    r.delete('/zones/<id>', _deleteZone);

    // Tables
    r.get('/', _listTables);
    r.post('/', _createTable);
    r.put('/<id>', _updateTable);
    r.delete('/<id>', _deleteTable);

    // Session actions
    r.post('/<id>/open', _openTable);
    r.post('/<id>/close', _closeTable);
    r.post('/<id>/transfer', _transferTable);
    r.get('/<id>/session', _getActiveSession);

    // Billing (R3)
    r.get('/<id>/bill', _getBill);
    r.post('/<id>/bill/service-charge', _setServiceCharge);
    r.post('/<id>/bill/split', _splitBill);
    r.post('/<id>/bill/split/apply', _applySplitBill);
    r.post('/merge', _mergeTables);

    // R4: Advanced Operations
    r.post('/<id>/assign-waiter', _assignWaiter);
    r.post('/<id>/update-guest-count', _updateGuestCount);
    r.post('/<id>/fire-course', _fireCourse);
    r.get('/<id>/timeline', _getTimeline);

    // Reservations
    r.get('/reservations', _listReservations);
    r.post('/reservations', _createReservation);
    r.put('/reservations/<rid>', _updateReservation);
    r.post('/reservations/<rid>/confirm', _confirmReservation);
    r.post('/reservations/<rid>/seat', _seatReservation);
    r.post('/reservations/<rid>/cancel', _cancelReservation);
    r.post('/reservations/<rid>/no-show', _noShowReservation);

    return r;
  }

  // ── Zones ──────────────────────────────────────────────────────────────────

  Future<Response> _listZones(Request req) async {
    try {
      final branchId = req.url.queryParameters['branch_id'];
      final query = db.select(db.zones)
        ..orderBy([(z) => OrderingTerm.asc(z.displayOrder)]);
      if (branchId != null) {
        query.where((z) => z.branchId.equals(branchId));
      }
      final zones = await query.get();
      return _ok(
        zones
            .map(
              (z) => {
                'zone_id': z.zoneId,
                'zone_name': z.zoneName,
                'branch_id': z.branchId,
                'display_order': z.displayOrder,
                'is_active': z.isActive,
              },
            )
            .toList(),
      );
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _createZone(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id = const Uuid().v4();
      await db
          .into(db.zones)
          .insert(
            ZonesCompanion(
              zoneId: Value(id),
              zoneName: Value(body['zone_name'] as String),
              branchId: Value(body['branch_id'] as String),
              displayOrder: Value(body['display_order'] as int? ?? 0),
              isActive: Value(body['is_active'] as bool? ?? true),
            ),
          );
      return _ok({'zone_id': id}, statusCode: 201);
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _updateZone(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(db.zones)..where((z) => z.zoneId.equals(id))).write(
        ZonesCompanion(
          zoneName: body.containsKey('zone_name')
              ? Value(body['zone_name'] as String)
              : const Value.absent(),
          displayOrder: body.containsKey('display_order')
              ? Value(body['display_order'] as int)
              : const Value.absent(),
          isActive: body.containsKey('is_active')
              ? Value(body['is_active'] as bool)
              : const Value.absent(),
        ),
      );
      return _ok({'zone_id': id});
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _deleteZone(Request req, String id) async {
    try {
      await (db.delete(db.zones)..where((z) => z.zoneId.equals(id))).go();
      return _ok({'deleted': id});
    } catch (e) {
      return _err(e);
    }
  }

  // ── Tables ─────────────────────────────────────────────────────────────────

  Future<Response> _listTables(Request req) async {
    try {
      final branchId = req.url.queryParameters['branch_id'];
      final zoneId = req.url.queryParameters['zone_id'];

      // โหลด zones ทั้งหมดเป็น map
      final allZones = await db.select(db.zones).get();
      final zoneMap = {for (final z in allZones) z.zoneId: z.zoneName};

      // โหลด active sessions (status = OPEN)
      final activeSessions = await (db.select(
        db.tableSessions,
      )..where((s) => s.status.equals('OPEN'))).get();
      final sessionByTable = {for (final s in activeSessions) s.tableId: s};

      // query tables
      final query = db.select(db.diningTables)
        ..orderBy([(t) => OrderingTerm.asc(t.tableNo)]);

      if (zoneId != null) {
        query.where((t) => t.zoneId.equals(zoneId));
      }

      final tables = await query.get();

      // filter by branchId ผ่าน zone
      final branchZoneIds = branchId != null
          ? allZones
                .where((z) => z.branchId == branchId)
                .map((z) => z.zoneId)
                .toSet()
          : null;

      final result = tables
          .where((t) {
            if (branchZoneIds != null && !branchZoneIds.contains(t.zoneId)) {
              return false;
            }
            return true;
          })
          .map((t) {
            final session = sessionByTable[t.tableId];
            return {
              'table_id': t.tableId,
              'table_no': t.tableNo,
              'table_display_name': t.tableDisplayName,
              'zone_id': t.zoneId,
              'zone_name': zoneMap[t.zoneId],
              'capacity': t.capacity,
              'status': t.status,
              'current_order_id': t.currentOrderId,
              'last_occupied_at': t.lastOccupiedAt?.toIso8601String(),
              'active_session_id': session?.sessionId,
              'active_guest_count': session?.guestCount,
              'session_opened_at': session?.openedAt.toIso8601String(),
              'waiter_name': session?.waiterName,
            };
          })
          .toList();

      return _ok(result);
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _createTable(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id = const Uuid().v4();
      await db
          .into(db.diningTables)
          .insert(
            DiningTablesCompanion(
              tableId: Value(id),
              tableNo: Value(body['table_no'] as String),
              tableDisplayName: body.containsKey('table_display_name')
                  ? Value(body['table_display_name'] as String?)
                  : const Value.absent(),
              zoneId: Value(body['zone_id'] as String),
              capacity: Value(body['capacity'] as int? ?? 4),
              status: const Value('AVAILABLE'),
            ),
          );
      return _ok({'table_id': id}, statusCode: 201);
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _updateTable(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).write(
        DiningTablesCompanion(
          tableNo: body.containsKey('table_no')
              ? Value(body['table_no'] as String)
              : const Value.absent(),
          tableDisplayName: body.containsKey('table_display_name')
              ? Value(body['table_display_name'] as String?)
              : const Value.absent(),
          zoneId: body.containsKey('zone_id')
              ? Value(body['zone_id'] as String)
              : const Value.absent(),
          capacity: body.containsKey('capacity')
              ? Value(body['capacity'] as int)
              : const Value.absent(),
          status: body.containsKey('status')
              ? Value(body['status'] as String)
              : const Value.absent(),
        ),
      );
      return _ok({'table_id': id});
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _deleteTable(Request req, String id) async {
    try {
      await (db.delete(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).go();
      return _ok({'deleted': id});
    } catch (e) {
      return _err(e);
    }
  }

  // ── Session actions ────────────────────────────────────────────────────────

  Future<Response> _openTable(Request req, String id) async {
    try {
      // ตรวจสอบว่าโต๊ะมีอยู่
      final table = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).getSingleOrNull();

      if (table == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Table not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (table.status == 'OCCUPIED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Table is already occupied',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final guestCount = body['guest_count'] as int? ?? 1;
      final openedBy = body['opened_by'] as String?;
      final branchId = body['branch_id'] as String? ?? '';

      final sessionId = const Uuid().v4();
      final openedAt = DateTime.now();

      // สร้าง session
      await db
          .into(db.tableSessions)
          .insert(
            TableSessionsCompanion(
              sessionId: Value(sessionId),
              tableId: Value(id),
              branchId: Value(branchId),
              openedAt: Value(openedAt),
              guestCount: Value(guestCount),
              status: const Value('OPEN'),
              openedBy: Value(openedBy),
            ),
          );

      // อัปเดตสถานะโต๊ะ
      await (db.update(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).write(
        DiningTablesCompanion(
          status: const Value('OCCUPIED'),
          lastOccupiedAt: Value(openedAt),
        ),
      );
      await _logTableSessionEvent(
        sessionId: sessionId,
        tableId: id,
        eventType: 'opened',
        eventAt: openedAt,
        description:
            'เปิดโต๊ะ ${table.tableDisplayName ?? table.tableNo}${guestCount > 0 ? ' ($guestCount คน)' : ''}',
        payload: {'guest_count': guestCount, 'opened_by': openedBy},
      );

      if (kDebugMode) {
        debugPrint('✅ Opened table $id session=$sessionId guests=$guestCount');
      }
      TableRoutes.bumpVersion();

      return _ok({
        'session_id': sessionId,
        'table_id': id,
        'branch_id': branchId,
        'opened_at': openedAt.toIso8601String(),
        'closed_at': null,
        'guest_count': guestCount,
        'status': 'OPEN',
        'opened_by': openedBy,
        'note': null,
      }, statusCode: 201);
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _closeTable(Request req, String id) async {
    try {
      // ปิด active session ของโต๊ะนี้
      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();

      if (session == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'No active session for this table',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final openOrders =
          await (db.select(db.salesOrders)..where(
                (o) =>
                    o.sessionId.equals(session.sessionId) &
                    o.status.equals('OPEN'),
              ))
              .get();
      if (openOrders.isNotEmpty) {
        return Response(
          409,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่สามารถปิดโต๊ะได้ เนื่องจากยังมี order ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final closedAt = DateTime.now();
      await (db.update(
        db.tableSessions,
      )..where((s) => s.sessionId.equals(session.sessionId))).write(
        TableSessionsCompanion(
          status: const Value('CLOSED'),
          closedAt: Value(closedAt),
        ),
      );

      // อัปเดตสถานะโต๊ะกลับเป็น AVAILABLE
      await (db.update(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).write(
        const DiningTablesCompanion(
          status: Value('CLEANING'),
          currentOrderId: Value(null),
        ),
      );
      await _logTableSessionEvent(
        sessionId: session.sessionId,
        tableId: id,
        eventType: 'closed',
        eventAt: closedAt,
        description: 'ปิด session ของโต๊ะนี้แล้ว',
        payload: {'status': 'CLOSED'},
      );

      if (kDebugMode) {
        debugPrint('✅ Closed table $id session=${session.sessionId}');
      }
      TableRoutes.bumpVersion();

      return _ok({
        'session_id': session.sessionId,
        'table_id': id,
        'branch_id': session.branchId,
        'opened_at': session.openedAt.toIso8601String(),
        'closed_at': closedAt.toIso8601String(),
        'guest_count': session.guestCount,
        'status': 'CLOSED',
        'opened_by': session.openedBy,
        'note': session.note,
      });
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _transferTable(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final targetTableId = body['target_table_id'] as String?;
      if (targetTableId == null || targetTableId.trim().isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'กรุณาระบุ target_table_id',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มี session ที่กำลังเปิดสำหรับโต๊ะนี้',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final targetTable = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals(targetTableId))).getSingleOrNull();
      if (targetTable == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบโต๊ะปลายทาง'}),
          headers: {'content-type': 'application/json'},
        );
      }
      if (targetTable.status != 'AVAILABLE') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'โต๊ะปลายทางต้องอยู่ในสถานะว่างเท่านั้น',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      await db.transaction(() async {
        final sourceTable = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals(id))).getSingleOrNull();

        await (db.update(db.tableSessions)
              ..where((s) => s.sessionId.equals(session.sessionId)))
            .write(TableSessionsCompanion(tableId: Value(targetTableId)));

        await (db.update(db.salesOrders)..where(
              (o) =>
                  o.sessionId.equals(session.sessionId) &
                  o.status.equals('OPEN'),
            ))
            .write(SalesOrdersCompanion(tableId: Value(targetTableId)));

        await (db.update(
          db.diningTables,
        )..where((t) => t.tableId.equals(id))).write(
          const DiningTablesCompanion(
            status: Value('CLEANING'),
            currentOrderId: Value(null),
          ),
        );

        final targetOrders =
            await (db.select(db.salesOrders)
                  ..where(
                    (o) =>
                        o.sessionId.equals(session.sessionId) &
                        o.tableId.equals(targetTableId) &
                        o.status.equals('OPEN'),
                  )
                  ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
                .get();
        await (db.update(
          db.diningTables,
        )..where((t) => t.tableId.equals(targetTableId))).write(
          DiningTablesCompanion(
            status: const Value('OCCUPIED'),
            lastOccupiedAt: Value(DateTime.now()),
            currentOrderId: Value(
              targetOrders.isNotEmpty
                  ? targetOrders.first.orderId
                  : sourceTable?.currentOrderId,
            ),
          ),
        );
      });
      TableRoutes.bumpVersion();

      return _ok({
        'session_id': session.sessionId,
        'table_id': targetTableId,
        'branch_id': session.branchId,
        'opened_at': session.openedAt.toIso8601String(),
        'closed_at': session.closedAt?.toIso8601String(),
        'guest_count': session.guestCount,
        'status': session.status,
        'opened_by': session.openedBy,
        'note': session.note,
      });
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getActiveSession(Request req, String id) async {
    try {
      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();

      if (session == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'No active session'}),
          headers: {'content-type': 'application/json'},
        );
      }

      return _ok({
        'session_id': session.sessionId,
        'table_id': session.tableId,
        'branch_id': session.branchId,
        'opened_at': session.openedAt.toIso8601String(),
        'closed_at': session.closedAt?.toIso8601String(),
        'guest_count': session.guestCount,
        'status': session.status,
        'opened_by': session.openedBy,
        'note': session.note,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // ── Billing (R3) ──────────────────────────────────────────────────────────

  /// GET /api/tables/:id/bill
  /// รวมรายการทั้งหมดจาก OPEN orders ของ session ปัจจุบัน
  Future<Response> _getBill(Request req, String id) async {
    try {
      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มีโต๊ะที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final orders =
          await (db.select(db.salesOrders)..where(
                (o) =>
                    o.sessionId.equals(session.sessionId) &
                    o.status.equals('OPEN'),
              ))
              .get();

      if (orders.isEmpty) return _ok(_emptyBill(session.sessionId, id));

      final orderIds = orders.map((o) => o.orderId).toList();
      final items =
          await (db.select(db.salesOrderItems)..where(
                (i) =>
                    i.orderId.isIn(orderIds) &
                    i.kitchenStatus.isNotIn(['CANCELLED']),
              ))
              .get();
      final itemIds = items.map((i) => i.itemId).toList();
      final modifiers = itemIds.isNotEmpty
          ? await (db.select(
              db.orderItemModifiers,
            )..where((m) => m.orderItemId.isIn(itemIds))).get()
          : <OrderItemModifier>[];
      final modifiersByItem = <String, List<OrderItemModifier>>{};
      for (final modifier in modifiers) {
        modifiersByItem
            .putIfAbsent(modifier.orderItemId, () => [])
            .add(modifier);
      }

      // รวมยอดทุก order
      double subtotal = 0;
      double discountAmount = 0;
      double serviceChargeRate = 0;
      double serviceChargeAmount = 0;

      for (final o in orders) {
        subtotal += o.subtotal;
        discountAmount += o.discountAmount;
        serviceChargeRate = o.serviceChargeRate; // ใช้ค่าล่าสุด
        serviceChargeAmount += o.serviceChargeAmount;
      }

      final grandTotal = subtotal - discountAmount + serviceChargeAmount;
      final nonWalkInCustomers = orders
          .where(
            (o) =>
                o.customerId != null &&
                o.customerId!.isNotEmpty &&
                o.customerId != 'WALK_IN',
          )
          .map((o) => (id: o.customerId!, name: o.customerName))
          .toList();
      final uniqueCustomerIds = nonWalkInCustomers
          .map((customer) => customer.id)
          .toSet();
      final billCustomer = uniqueCustomerIds.length == 1
          ? nonWalkInCustomers.first
          : null;

      return _ok({
        'session_id': session.sessionId,
        'table_id': id,
        'guest_count': session.guestCount,
        'opened_at': session.openedAt.toIso8601String(),
        'customer_id': billCustomer?.id,
        'customer_name': billCustomer?.name,
        'order_ids': orderIds,
        'items': items
            .map(
              (i) => {
                'item_id': i.itemId,
                'order_id': i.orderId,
                'line_no': i.lineNo,
                'product_id': i.productId,
                'product_name': i.productName,
                'quantity': i.quantity,
                'unit': i.unit,
                'unit_price': i.unitPrice,
                'discount_amount': i.discountAmount,
                'amount': i.amount,
                'kitchen_status': i.kitchenStatus,
                'course_no': i.courseNo,
                'special_instructions': i.specialInstructions,
                'modifiers':
                    (modifiersByItem[i.itemId] ?? const <OrderItemModifier>[])
                        .map(
                          (m) => {
                            'modifier_id': m.modifierId,
                            'modifier_name': m.modifierName,
                            'price_adjustment': m.priceAdjustment,
                          },
                        )
                        .toList(),
              },
            )
            .toList(),
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'service_charge_rate': serviceChargeRate,
        'service_charge_amount': serviceChargeAmount,
        'grand_total': grandTotal,
        'preview_token': _billToken(items),
      });
    } catch (e) {
      return _err(e);
    }
  }

  Map<String, dynamic> _emptyBill(String sessionId, String tableId) => {
    'session_id': sessionId,
    'table_id': tableId,
    'guest_count': 0,
    'opened_at': null,
    'customer_id': null,
    'customer_name': null,
    'order_ids': <String>[],
    'items': <dynamic>[],
    'subtotal': 0.0,
    'discount_amount': 0.0,
    'service_charge_rate': 0.0,
    'service_charge_amount': 0.0,
    'grand_total': 0.0,
  };

  /// POST /api/tables/:id/bill/service-charge
  /// body: { "rate": 10 }  (เปอร์เซ็นต์)
  Future<Response> _setServiceCharge(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final rate = (body['rate'] as num).toDouble();

      final orders = await (db.select(
        db.salesOrders,
      )..where((o) => o.tableId.equals(id) & o.status.equals('OPEN'))).get();

      if (orders.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มี order ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      await _recalculateServiceChargeForOrders(orders, rate);

      return _ok({'rate': rate, 'updated': orders.length});
    } catch (e) {
      return _err(e);
    }
  }

  /// POST /api/tables/:id/bill/split
  /// body: { "count": 3 }  — แบ่งเท่ากัน N คน
  /// หรือ { "splits": [{"label":"คน 1","item_ids":["...",...]}, ...] }
  Future<Response> _splitBill(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มี session ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final orders =
          await (db.select(db.salesOrders)..where(
                (o) =>
                    o.sessionId.equals(session.sessionId) &
                    o.status.equals('OPEN'),
              ))
              .get();
      final orderIds = orders.map((o) => o.orderId).toList();
      final allItems =
          await (db.select(db.salesOrderItems)..where(
                (i) =>
                    i.orderId.isIn(orderIds) &
                    i.kitchenStatus.isNotIn(['CANCELLED']),
              ))
              .get();

      final totalSubtotal = orders.fold<double>(0, (s, o) => s + o.subtotal);
      final totalDiscount = orders.fold<double>(
        0,
        (s, o) => s + o.discountAmount,
      );
      final totalSC = orders.fold<double>(
        0,
        (s, o) => s + o.serviceChargeAmount,
      );
      final grandTotal = totalSubtotal - totalDiscount + totalSC;
      final previewToken = _billToken(allItems);

      // ── Equal split by count ──
      if (body.containsKey('count')) {
        final count = body['count'] as int;
        if (count < 1) {
          return Response(
            400,
            body: jsonEncode({
              'success': false,
              'message': 'count ต้องมากกว่า 0',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
        final perPerson = grandTotal / count;
        return _ok({
          'mode': 'equal',
          'preview_token': previewToken,
          'count': count,
          'grand_total': grandTotal,
          'per_person': perPerson,
          'splits': List.generate(
            count,
            (i) => {
              'label': 'คน ${i + 1}',
              'amount': perPerson,
              'items': <dynamic>[],
            },
          ),
        });
      }

      // ── Item-level split ──
      if (body.containsKey('splits')) {
        final splitsRaw = body['splits'] as List;
        final result = splitsRaw.map((s) {
          final split = s as Map<String, dynamic>;
          final label = split['label'] as String? ?? '';
          final itemIds = (split['item_ids'] as List)
              .map((e) => e as String)
              .toSet();
          final splitItems = allItems.where((i) => itemIds.contains(i.itemId));
          final splitTotal = splitItems.fold<double>(
            0,
            (sum, i) => sum + i.amount,
          );
          // proportional service charge
          final scShare = grandTotal > 0
              ? splitTotal / (totalSubtotal - totalDiscount) * totalSC
              : 0.0;
          return {
            'label': label,
            'items': splitItems
                .map(
                  (i) => {
                    'item_id': i.itemId,
                    'product_name': i.productName,
                    'quantity': i.quantity,
                    'amount': i.amount,
                  },
                )
                .toList(),
            'subtotal': splitTotal,
            'service_charge': scShare,
            'total': splitTotal + scShare,
          };
        }).toList();

        return _ok({
          'mode': 'by_item',
          'preview_token': previewToken,
          'splits': result,
        });
      }

      return Response(
        400,
        body: jsonEncode({
          'success': false,
          'message': 'ต้องระบุ count หรือ splits',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _err(e);
    }
  }

  /// POST /api/tables/:id/bill/split/apply
  /// body:
  /// {
  ///   "splits": [
  ///     {
  ///       "label": "คน 1",
  ///       "items": [{"item_id": "...", "quantity": 1}]
  ///     }
  ///   ]
  /// }
  Future<Response> _applySplitBill(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final splitsRaw = body['splits'] as List?;
      if (splitsRaw == null || splitsRaw.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ต้องระบุ splits อย่างน้อย 1 รายการ',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มี session ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final openOrders =
          await (db.select(db.salesOrders)..where(
                (o) =>
                    o.sessionId.equals(session.sessionId) &
                    o.status.equals('OPEN'),
              ))
              .get();
      if (openOrders.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มี order ที่เปิดอยู่สำหรับโต๊ะนี้',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final orderIds = openOrders.map((o) => o.orderId).toList();
      final sourceItems =
          await (db.select(db.salesOrderItems)..where(
                (i) =>
                    i.orderId.isIn(orderIds) &
                    i.kitchenStatus.isNotIn(['CANCELLED']),
              ))
              .get();
      if (sourceItems.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มีรายการสำหรับแยกบิล',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Optimistic lock: reject if bill changed since preview
      final submittedToken = body['preview_token'] as String?;
      if (submittedToken != null) {
        final currentToken = _billToken(sourceItems);
        if (submittedToken != currentToken) {
          return Response(
            409,
            body: jsonEncode({
              'success': false,
              'message':
                  'รายการบิลเปลี่ยนแปลงหลังจากดูตัวอย่าง กรุณาตรวจสอบและลองใหม่',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      }

      final itemById = {for (final item in sourceItems) item.itemId: item};
      final modifierRows = await (db.select(
        db.orderItemModifiers,
      )..where((m) => m.orderItemId.isIn(itemById.keys))).get();
      final modifiersByItem = <String, List<OrderItemModifier>>{};
      for (final modifier in modifierRows) {
        modifiersByItem
            .putIfAbsent(modifier.orderItemId, () => [])
            .add(modifier);
      }

      final requestedByItem = <String, double>{};
      final normalizedSplits = <Map<String, dynamic>>[];

      for (final rawSplit in splitsRaw) {
        final split = Map<String, dynamic>.from(rawSplit as Map);
        final label = split['label'] as String? ?? 'บิลแยก';
        final rawItems = split['items'] as List?;
        final rawItemIds = split['item_ids'] as List?;

        final normalizedItems = <Map<String, dynamic>>[];
        if (rawItems != null && rawItems.isNotEmpty) {
          for (final rawItem in rawItems) {
            final itemMap = Map<String, dynamic>.from(rawItem as Map);
            final itemId = itemMap['item_id'] as String?;
            final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0;
            if (itemId == null || itemId.isEmpty || quantity <= 0) {
              throw Exception('ข้อมูล split item ไม่ถูกต้อง');
            }
            normalizedItems.add({'item_id': itemId, 'quantity': quantity});
          }
        } else if (rawItemIds != null && rawItemIds.isNotEmpty) {
          for (final rawItemId in rawItemIds) {
            final itemId = rawItemId.toString();
            final source = itemById[itemId];
            if (source == null) {
              throw Exception('ไม่พบรายการ $itemId');
            }
            normalizedItems.add({
              'item_id': itemId,
              'quantity': source.quantity,
            });
          }
        } else {
          throw Exception('split แต่ละส่วนต้องมี items หรือ item_ids');
        }

        for (final item in normalizedItems) {
          final itemId = item['item_id'] as String;
          final quantity = item['quantity'] as double;
          final source = itemById[itemId];
          if (source == null) {
            throw Exception('ไม่พบรายการ $itemId');
          }
          final currentRequested = requestedByItem[itemId] ?? 0;
          if (currentRequested + quantity > source.quantity + 0.0001) {
            throw Exception(
              'จำนวนที่แยกของรายการ ${source.productName} เกินจำนวนเดิม',
            );
          }
          requestedByItem[itemId] = currentRequested + quantity;
        }

        normalizedSplits.add({'label': label, 'items': normalizedItems});
      }

      final serviceChargeRate = openOrders.isNotEmpty
          ? openOrders.first.serviceChargeRate
          : 0.0;
      final createdSplits = <Map<String, dynamic>>[];
      final touchedOrderIds = <String>{};
      final now = DateTime.now();
      final ts = now.millisecondsSinceEpoch;

      await db.transaction(() async {
        for (
          var splitIndex = 0;
          splitIndex < normalizedSplits.length;
          splitIndex++
        ) {
          final split = normalizedSplits[splitIndex];
          final splitItems = split['items'] as List<Map<String, dynamic>>;
          if (splitItems.isEmpty) continue;

          final firstSourceItem =
              itemById[splitItems.first['item_id'] as String]!;
          final templateOrder = openOrders.firstWhere(
            (order) => order.orderId == firstSourceItem.orderId,
            orElse: () => openOrders.first,
          );

          final splitOrderId = const Uuid().v4();
          final splitOrderNo =
              'SO-SPLIT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$ts-$splitIndex';

          await db
              .into(db.salesOrders)
              .insert(
                SalesOrdersCompanion(
                  orderId: Value(splitOrderId),
                  orderNo: Value(splitOrderNo),
                  orderDate: Value(now),
                  orderType: const Value('SALE'),
                  customerId: Value(templateOrder.customerId),
                  customerName: Value(templateOrder.customerName),
                  branchId: Value(templateOrder.branchId),
                  warehouseId: Value(templateOrder.warehouseId),
                  userId: Value(templateOrder.userId),
                  tableId: Value(templateOrder.tableId),
                  sessionId: Value(templateOrder.sessionId),
                  partySize: Value(templateOrder.partySize),
                  serviceType: Value(templateOrder.serviceType),
                  subtotal: const Value(0),
                  discountAmount: const Value(0),
                  couponDiscount: const Value(0),
                  couponCodes: const Value(null),
                  promotionIds: const Value(null),
                  pointsUsed: const Value(0),
                  amountBeforeVat: const Value(0),
                  vatAmount: Value(templateOrder.vatAmount),
                  serviceChargeRate: Value(serviceChargeRate),
                  serviceChargeAmount: const Value(0),
                  totalAmount: const Value(0),
                  paymentType: Value(templateOrder.paymentType),
                  paidAmount: const Value(0),
                  changeAmount: const Value(0),
                  status: const Value('OPEN'),
                ),
              );

          final createdItems = <Map<String, dynamic>>[];

          for (var lineIndex = 0; lineIndex < splitItems.length; lineIndex++) {
            final splitItem = splitItems[lineIndex];
            final sourceItem = itemById[splitItem['item_id'] as String]!;
            final quantity = splitItem['quantity'] as double;
            final ratio = sourceItem.quantity == 0
                ? 0
                : quantity / sourceItem.quantity;
            final newItemId = '${splitOrderId}_${lineIndex + 1}';

            final newDiscountAmount = sourceItem.discountAmount * ratio;
            final newAmount = sourceItem.amount * ratio;
            final newCost = sourceItem.cost * ratio;

            await db
                .into(db.salesOrderItems)
                .insert(
                  SalesOrderItemsCompanion(
                    itemId: Value(newItemId),
                    orderId: Value(splitOrderId),
                    lineNo: Value(lineIndex + 1),
                    productId: Value(sourceItem.productId),
                    productCode: Value(sourceItem.productCode),
                    productName: Value(sourceItem.productName),
                    unit: Value(sourceItem.unit),
                    quantity: Value(quantity),
                    unitPrice: Value(sourceItem.unitPrice),
                    discountPercent: Value(sourceItem.discountPercent),
                    discountAmount: Value(newDiscountAmount),
                    amount: Value(newAmount),
                    cost: Value(newCost),
                    warehouseId: Value(sourceItem.warehouseId),
                    kitchenStatus: Value(sourceItem.kitchenStatus),
                    preparedAt: Value(sourceItem.preparedAt),
                    specialInstructions: Value(sourceItem.specialInstructions),
                    isFreeItem: Value(sourceItem.isFreeItem),
                    promotionId: Value(sourceItem.promotionId),
                  ),
                );

            final sourceModifiers =
                modifiersByItem[sourceItem.itemId] ??
                const <OrderItemModifier>[];
            for (
              var modifierIndex = 0;
              modifierIndex < sourceModifiers.length;
              modifierIndex++
            ) {
              final modifier = sourceModifiers[modifierIndex];
              await db
                  .into(db.orderItemModifiers)
                  .insert(
                    OrderItemModifiersCompanion(
                      itemModifierId: Value(const Uuid().v4()),
                      orderItemId: Value(newItemId),
                      modifierId: Value(modifier.modifierId),
                      modifierName: Value(modifier.modifierName),
                      priceAdjustment: Value(modifier.priceAdjustment),
                    ),
                  );
            }

            final remainingQuantity = sourceItem.quantity - quantity;
            if (remainingQuantity <= 0.0001) {
              await (db.delete(
                db.salesOrderItems,
              )..where((t) => t.itemId.equals(sourceItem.itemId))).go();
            } else {
              final remainingRatio = remainingQuantity / sourceItem.quantity;
              await (db.update(
                db.salesOrderItems,
              )..where((t) => t.itemId.equals(sourceItem.itemId))).write(
                SalesOrderItemsCompanion(
                  quantity: Value(remainingQuantity),
                  discountAmount: Value(
                    sourceItem.discountAmount * remainingRatio,
                  ),
                  amount: Value(sourceItem.amount * remainingRatio),
                  cost: Value(sourceItem.cost * remainingRatio),
                ),
              );
            }

            touchedOrderIds.add(sourceItem.orderId);
            createdItems.add({
              'item_id': newItemId,
              'product_id': sourceItem.productId,
              'product_code': sourceItem.productCode,
              'product_name': sourceItem.productName,
              'unit': sourceItem.unit,
              'quantity': quantity,
              'amount': newAmount,
              'unit_price': sourceItem.unitPrice,
              'special_instructions': sourceItem.specialInstructions,
              'modifiers': sourceModifiers
                  .map(
                    (m) => {
                      'modifier_id': m.modifierId,
                      'modifier_name': m.modifierName,
                      'price_adjustment': m.priceAdjustment,
                    },
                  )
                  .toList(),
            });
          }

          await _recalculateOrderTotals(
            splitOrderId,
            serviceChargeRate: serviceChargeRate,
          );

          final splitOrder = await (db.select(
            db.salesOrders,
          )..where((o) => o.orderId.equals(splitOrderId))).getSingle();
          createdSplits.add({
            'label': split['label'],
            'order_ids': [splitOrderId],
            'subtotal': splitOrder.subtotal,
            'discount_amount': splitOrder.discountAmount,
            'service_charge': splitOrder.serviceChargeAmount,
            'total': splitOrder.totalAmount,
            'items': createdItems,
          });
        }

        for (final orderId in touchedOrderIds) {
          final remainingItems = await (db.select(
            db.salesOrderItems,
          )..where((i) => i.orderId.equals(orderId))).get();
          if (remainingItems.isEmpty) {
            await (db.update(
              db.salesOrders,
            )..where((o) => o.orderId.equals(orderId))).write(
              SalesOrdersCompanion(
                status: const Value('CANCELLED'),
                updatedAt: Value(DateTime.now()),
              ),
            );
          } else {
            await _recalculateOrderTotals(
              orderId,
              serviceChargeRate: serviceChargeRate,
            );
          }
        }

        await _recalculateOpenOrdersForTable(
          id,
          serviceChargeRate: serviceChargeRate,
        );

        final remainingOpenOrders = await (db.select(
          db.salesOrders,
        )..where((o) => o.tableId.equals(id) & o.status.equals('OPEN'))).get();
        await (db.update(
          db.diningTables,
        )..where((t) => t.tableId.equals(id))).write(
          DiningTablesCompanion(
            currentOrderId: Value(
              remainingOpenOrders.isNotEmpty
                  ? remainingOpenOrders.first.orderId
                  : null,
            ),
          ),
        );
      });

      final total = createdSplits.fold<double>(
        0,
        (sum, split) => sum + ((split['total'] as num?)?.toDouble() ?? 0),
      );

      return _ok({
        'mode': 'applied',
        'count': createdSplits.length,
        'grand_total': total,
        'splits': createdSplits,
      });
    } catch (e) {
      return _err(e);
    }
  }

  /// POST /api/tables/merge
  /// body: { "source_table_id": "...", "target_table_id": "..." }
  /// ย้าย items ทั้งหมดจาก source ไปรวมที่ order ปัจจุบันของ target
  Future<Response> _mergeTables(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final sourceId = body['source_table_id'] as String?;
      final targetId = body['target_table_id'] as String?;

      if (sourceId == null || targetId == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ต้องระบุ source_table_id และ target_table_id',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final sourceSession =
          await (db.select(db.tableSessions)..where(
                (s) => s.tableId.equals(sourceId) & s.status.equals('OPEN'),
              ))
              .getSingleOrNull();
      final targetSession =
          await (db.select(db.tableSessions)..where(
                (s) => s.tableId.equals(targetId) & s.status.equals('OPEN'),
              ))
              .getSingleOrNull();

      if (sourceSession == null || targetSession == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ทั้งสองโต๊ะต้องเปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      await db.transaction(() async {
        await _logTableSessionEvent(
          sessionId: sourceSession.sessionId,
          tableId: sourceId,
          eventType: 'merge_out',
          description: 'รวมโต๊ะไปยัง $targetId',
          payload: {
            'source_table_id': sourceId,
            'target_table_id': targetId,
            'source_session_id': sourceSession.sessionId,
            'target_session_id': targetSession.sessionId,
          },
        );
        await _logTableSessionEvent(
          sessionId: targetSession.sessionId,
          tableId: targetId,
          eventType: 'merge_in',
          description: 'รับรวมโต๊ะจาก $sourceId',
          payload: {
            'source_table_id': sourceId,
            'target_table_id': targetId,
            'source_session_id': sourceSession.sessionId,
            'target_session_id': targetSession.sessionId,
          },
        );

        // ย้าย orders ของ source ให้ชี้มาที่ targetSession
        await (db.update(db.salesOrders)..where(
              (o) =>
                  o.sessionId.equals(sourceSession.sessionId) &
                  o.status.equals('OPEN'),
            ))
            .write(
              SalesOrdersCompanion(
                tableId: Value(targetId),
                sessionId: Value(targetSession.sessionId),
              ),
            );

        // ปิด source session
        await (db.update(
          db.tableSessions,
        )..where((s) => s.sessionId.equals(sourceSession.sessionId))).write(
          TableSessionsCompanion(
            status: const Value('CLOSED'),
            closedAt: Value(DateTime.now()),
            note: const Value('ย้ายรวมโต๊ะ'),
          ),
        );

        // source table → CLEANING
        await (db.update(
          db.diningTables,
        )..where((t) => t.tableId.equals(sourceId))).write(
          const DiningTablesCompanion(
            status: Value('CLEANING'),
            currentOrderId: Value(null),
          ),
        );

        final targetOrders =
            await (db.select(db.salesOrders)
                  ..where(
                    (o) =>
                        o.tableId.equals(targetId) &
                        o.sessionId.equals(targetSession.sessionId) &
                        o.status.equals('OPEN'),
                  )
                  ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
                .get();
        await (db.update(
          db.diningTables,
        )..where((t) => t.tableId.equals(targetId))).write(
          DiningTablesCompanion(
            currentOrderId: Value(
              targetOrders.isNotEmpty ? targetOrders.first.orderId : null,
            ),
          ),
        );
      });

      TableRoutes.bumpVersion();
      return _ok({
        'merged': true,
        'source_table_id': sourceId,
        'target_table_id': targetId,
        'target_session_id': targetSession.sessionId,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // ── Version endpoint ─────────────────────────────────────────────────────

  Future<Response> _getVersion(Request req) async => _ok({
    'version': _tableVersion,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Deterministic hash of the current open-bill items for optimistic locking.
  String _billToken(List<SalesOrderItem> items) {
    final sorted = [...items]..sort((a, b) => a.itemId.compareTo(b.itemId));
    final payload = sorted
        .map((i) => '${i.itemId}:${i.quantity}:${i.amount}')
        .join(',');
    return sha256.convert(utf8.encode(payload)).toString().substring(0, 16);
  }

  Response _ok(dynamic data, {int statusCode = 200}) => Response(
    statusCode,
    body: jsonEncode({'success': true, 'data': data}),
    headers: {'content-type': 'application/json'},
  );

  Future<void> _logTableSessionEvent({
    required String sessionId,
    required String tableId,
    required String eventType,
    required String description,
    Map<String, dynamic>? payload,
    DateTime? eventAt,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO table_session_events (
        event_id,
        session_id,
        table_id,
        event_type,
        event_at,
        description,
        payload_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        const Uuid().v4(),
        sessionId,
        tableId,
        eventType,
        (eventAt ?? DateTime.now()).toIso8601String(),
        description,
        payload == null ? null : jsonEncode(payload),
      ],
    );
  }

  Future<void> _recalculateServiceChargeForOrders(
    List<SalesOrder> orders,
    double rate,
  ) async {
    for (final order in orders) {
      await _recalculateOrderTotals(order.orderId, serviceChargeRate: rate);
    }
  }

  Future<void> _recalculateOpenOrdersForTable(
    String tableId, {
    required double serviceChargeRate,
  }) async {
    final openOrders = await (db.select(
      db.salesOrders,
    )..where((o) => o.tableId.equals(tableId) & o.status.equals('OPEN'))).get();
    for (final order in openOrders) {
      await _recalculateOrderTotals(
        order.orderId,
        serviceChargeRate: serviceChargeRate,
      );
    }
  }

  Future<void> _recalculateOrderTotals(
    String orderId, {
    double? serviceChargeRate,
  }) async {
    final order = await (db.select(
      db.salesOrders,
    )..where((o) => o.orderId.equals(orderId))).getSingleOrNull();
    if (order == null) return;

    final items = await (db.select(
      db.salesOrderItems,
    )..where((i) => i.orderId.equals(orderId))).get();

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.amount + item.discountAmount,
    );
    final discountAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.discountAmount,
    );
    final netAmount = (subtotal - discountAmount).clamp(0.0, double.infinity);
    final rate = serviceChargeRate ?? order.serviceChargeRate;
    final serviceChargeAmount = netAmount * rate / 100;
    final totalAmount = netAmount + order.vatAmount + serviceChargeAmount;

    await (db.update(
      db.salesOrders,
    )..where((o) => o.orderId.equals(orderId))).write(
      SalesOrdersCompanion(
        subtotal: Value(subtotal),
        discountAmount: Value(discountAmount),
        amountBeforeVat: Value(netAmount),
        serviceChargeRate: Value(rate),
        serviceChargeAmount: Value(serviceChargeAmount),
        totalAmount: Value(totalAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── R4: Waiter Assignment ─────────────────────────────────────────────────

  // POST /api/tables/:id/assign-waiter
  /// body: { "waiter_id": "...", "waiter_name": "..." }
  Future<Response> _assignWaiter(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final waiterId = body['waiter_id'] as String?;
      final waiterName = body['waiter_name'] as String?;

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่พบ session ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      await (db.update(
        db.tableSessions,
      )..where((s) => s.sessionId.equals(session.sessionId))).write(
        TableSessionsCompanion(
          waiterId: Value(waiterId),
          waiterName: Value(waiterName),
        ),
      );
      await _logTableSessionEvent(
        sessionId: session.sessionId,
        tableId: id,
        eventType: 'waiter',
        description: 'พนักงานเสิร์ฟ: ${waiterName ?? waiterId ?? '-'}',
        payload: {'waiter_id': waiterId, 'waiter_name': waiterName},
      );

      TableRoutes.bumpVersion();
      return _ok({
        'session_id': session.sessionId,
        'waiter_id': waiterId,
        'waiter_name': waiterName,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // POST /api/tables/:id/update-guest-count
  // body: { "guest_count": 3 }
  Future<Response> _updateGuestCount(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final guestCount = body['guest_count'] as int? ?? 1;

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่พบ session ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      await (db.update(db.tableSessions)
            ..where((s) => s.sessionId.equals(session.sessionId)))
          .write(TableSessionsCompanion(guestCount: Value(guestCount)));

      TableRoutes.bumpVersion();
      return _ok({'session_id': session.sessionId, 'guest_count': guestCount});
    } catch (e) {
      return _err(e);
    }
  }

  // ── R4: Course / Fire Order ───────────────────────────────────────────────

  // POST /api/tables/:id/fire-course
  /// body: { "course_no": 2 }
  /// Sets kitchen_status to 'PENDING' for all items in that course that are 'HELD'
  Future<Response> _fireCourse(Request req, String id) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final courseNo = body['course_no'] as int? ?? 1;

      final session =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id) & s.status.equals('OPEN')))
              .getSingleOrNull();
      if (session == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่พบ session ที่เปิดอยู่',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final orders =
          await (db.select(db.salesOrders)..where(
                (o) =>
                    o.sessionId.equals(session.sessionId) &
                    o.status.equals('OPEN'),
              ))
              .get();
      final orderIds = orders.map((o) => o.orderId).toList();

      int firedCount = 0;
      for (final orderId in orderIds) {
        final items =
            await (db.select(db.salesOrderItems)..where(
                  (i) =>
                      i.orderId.equals(orderId) &
                      i.courseNo.equals(courseNo) &
                      i.kitchenStatus.equals('HELD'),
                ))
                .get();
        for (final item in items) {
          await (db.update(
            db.salesOrderItems,
          )..where((i) => i.itemId.equals(item.itemId))).write(
            const SalesOrderItemsCompanion(kitchenStatus: Value('PENDING')),
          );
          firedCount++;
        }
      }
      if (firedCount > 0) {
        await _logTableSessionEvent(
          sessionId: session.sessionId,
          tableId: id,
          eventType: 'fire_course',
          description: 'ยิงคอร์ส $courseNo เข้าครัว ($firedCount รายการ)',
          payload: {'course_no': courseNo, 'fired_count': firedCount},
        );
      }

      return _ok({'fired': firedCount, 'course_no': courseNo, 'table_id': id});
    } catch (e) {
      return _err(e);
    }
  }

  // ── R4: Table Timeline ────────────────────────────────────────────────────

  // GET /api/tables/:id/timeline
  Future<Response> _getTimeline(Request req, String id) async {
    try {
      final sessions =
          await (db.select(db.tableSessions)
                ..where((s) => s.tableId.equals(id))
                ..orderBy([
                  (s) => OrderingTerm(
                    expression: s.openedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      if (sessions.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่พบ timeline ของโต๊ะนี้',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      final session = sessions.firstWhere(
        (s) => s.status == 'OPEN',
        orElse: () => sessions.first,
      );

      final table = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals(id))).getSingleOrNull();

      final orders =
          await (db.select(db.salesOrders)
                ..where((o) => o.sessionId.equals(session.sessionId))
                ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
              .get();

      final events = <Map<String, dynamic>>[];
      final sessionEventRows = await db
          .customSelect(
            '''
        SELECT event_type, event_at, description, payload_json
        FROM table_session_events
        WHERE session_id = ?
        ORDER BY event_at ASC, created_at ASC
        ''',
            variables: [Variable.withString(session.sessionId)],
          )
          .get();
      for (final row in sessionEventRows) {
        final payloadJson = row.read<String?>('payload_json');
        events.add({
          'type': row.read<String>('event_type'),
          'timestamp': row.read<String>('event_at'),
          'description': row.read<String>('description'),
          'data': payloadJson != null && payloadJson.isNotEmpty
              ? jsonDecode(payloadJson) as Map<String, dynamic>
              : <String, dynamic>{},
        });
      }
      final hasOpenedEvent = events.any((event) => event['type'] == 'opened');
      if (!hasOpenedEvent) {
        events.add({
          'type': 'opened',
          'timestamp': session.openedAt.toIso8601String(),
          'description':
              'เปิดโต๊ะ ${table?.tableDisplayName ?? id}'
              '${session.guestCount > 0 ? ' (${session.guestCount} คน)' : ''}',
          'data': {
            'guest_count': session.guestCount,
            'opened_by': session.openedBy,
          },
        });
      }

      for (final order in orders) {
        final items =
            await (db.select(db.salesOrderItems)
                  ..where((i) => i.orderId.equals(order.orderId))
                  ..orderBy([(i) => OrderingTerm.asc(i.lineNo)]))
                .get();

        events.add({
          'type': 'order',
          'timestamp': order.createdAt.toIso8601String(),
          'description': 'สั่งอาหาร ${items.length} รายการ (${order.orderNo})',
          'data': {
            'order_id': order.orderId,
            'order_no': order.orderNo,
            'item_count': items.length,
            'total': order.totalAmount,
            'items': items
                .map(
                  (i) => {
                    'name': i.productName,
                    'qty': i.quantity,
                    'course_no': i.courseNo,
                    'kitchen_status': i.kitchenStatus,
                  },
                )
                .toList(),
          },
        });

        for (final item in items) {
          if (item.preparedAt != null) {
            final statusLabel = switch (item.kitchenStatus) {
              'READY' => 'พร้อมเสิร์ฟ',
              'SERVED' => 'เสิร์ฟแล้ว',
              'CANCELLED' => 'ยกเลิกรายการ',
              _ => item.kitchenStatus,
            };
            events.add({
              'type': 'item_status',
              'timestamp': item.preparedAt!.toIso8601String(),
              'description': '${item.productName} — $statusLabel',
              'data': {
                'item_id': item.itemId,
                'product_name': item.productName,
                'status': item.kitchenStatus,
              },
            });
          }
        }
      }

      events.sort(
        (a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String),
      );

      return _ok({
        'session_id': session.sessionId,
        'table_id': id,
        'table_name': table?.tableDisplayName,
        'opened_at': session.openedAt.toIso8601String(),
        'closed_at': session.closedAt?.toIso8601String(),
        'status': session.status,
        'guest_count': session.guestCount,
        'waiter_id': session.waiterId,
        'waiter_name': session.waiterName,
        'events': events,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // ── R4: Reservations ──────────────────────────────────────────────────────

  Map<String, dynamic> _reservationToJson(
    TableReservation r, {
    String? tableName,
  }) => {
    'reservation_id': r.reservationId,
    'table_id': r.tableId,
    'table_name': tableName,
    'branch_id': r.branchId,
    'customer_name': r.customerName,
    'customer_phone': r.customerPhone,
    'reservation_time': r.reservationTime.toIso8601String(),
    'party_size': r.partySize,
    'notes': r.notes,
    'status': r.status,
    'session_id': r.sessionId,
    'created_at': r.createdAt.toIso8601String(),
  };

  /// GET /api/tables/reservations?branch_id=&date=YYYY-MM-DD&from=&to=&status=
  Future<Response> _listReservations(Request req) async {
    try {
      final params = req.url.queryParameters;
      final branchId = params['branch_id'];
      final dateStr = params['date'];
      final fromStr = params['from'];
      final toStr = params['to'];
      final status = params['status'];
      final searchQuery = (params['query'] ?? '').trim().toLowerCase();

      var query = db.select(db.tableReservations);
      query.where((r) {
        Expression<bool> cond = const Constant(true);
        if (branchId != null) cond = cond & r.branchId.equals(branchId);
        if (status != null) cond = cond & r.status.equals(status);
        return cond;
      });
      query.orderBy([(r) => OrderingTerm.asc(r.reservationTime)]);

      var reservations = await query.get();

      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          reservations = reservations.where((r) {
            final rt = r.reservationTime;
            return rt.year == date.year &&
                rt.month == date.month &&
                rt.day == date.day;
          }).toList();
        }
      } else if (fromStr != null || toStr != null) {
        final from = fromStr != null ? DateTime.tryParse(fromStr) : null;
        final to = toStr != null ? DateTime.tryParse(toStr) : null;
        reservations = reservations.where((r) {
          final rt = r.reservationTime;
          final day = DateTime(rt.year, rt.month, rt.day);
          if (from != null && day.isBefore(from)) return false;
          if (to != null && day.isAfter(to)) return false;
          return true;
        }).toList();
      }

      if (searchQuery.isNotEmpty) {
        reservations = reservations.where((r) {
          final customerName = r.customerName.toLowerCase();
          final customerPhone = (r.customerPhone ?? '').toLowerCase();
          return customerName.contains(searchQuery) ||
              customerPhone.contains(searchQuery);
        }).toList();
      }

      final tableIds = reservations
          .map((r) => r.tableId)
          .whereType<String>()
          .toSet();
      final tableMap = <String, String>{};
      for (final tid in tableIds) {
        final t = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals(tid))).getSingleOrNull();
        if (t != null) tableMap[tid] = t.tableDisplayName ?? t.tableNo;
      }

      return _ok(
        reservations
            .map(
              (r) => _reservationToJson(
                r,
                tableName: r.tableId != null ? tableMap[r.tableId] : null,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return _err(e);
    }
  }

  /// POST /api/tables/reservations
  Future<Response> _createReservation(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id = const Uuid().v4();
      final reservationTime = DateTime.parse(
        body['reservation_time'] as String,
      );

      await db
          .into(db.tableReservations)
          .insert(
            TableReservationsCompanion(
              reservationId: Value(id),
              tableId: Value(body['table_id'] as String?),
              branchId: Value(body['branch_id'] as String),
              customerName: Value(body['customer_name'] as String),
              customerPhone: Value(body['customer_phone'] as String?),
              reservationTime: Value(reservationTime),
              partySize: Value(body['party_size'] as int? ?? 2),
              notes: Value(body['notes'] as String?),
              status: const Value('PENDING'),
            ),
          );

      final created = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(id))).getSingle();
      return _ok(_reservationToJson(created), statusCode: 201);
    } catch (e) {
      return _err(e);
    }
  }

  // PUT /api/tables/reservations/:rid
  Future<Response> _updateReservation(Request req, String rid) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final companion = TableReservationsCompanion(
        tableId: body.containsKey('table_id')
            ? Value(body['table_id'] as String?)
            : const Value.absent(),
        customerName: body.containsKey('customer_name')
            ? Value(body['customer_name'] as String)
            : const Value.absent(),
        customerPhone: body.containsKey('customer_phone')
            ? Value(body['customer_phone'] as String?)
            : const Value.absent(),
        reservationTime: body.containsKey('reservation_time')
            ? Value(DateTime.parse(body['reservation_time'] as String))
            : const Value.absent(),
        partySize: body.containsKey('party_size')
            ? Value(body['party_size'] as int)
            : const Value.absent(),
        notes: body.containsKey('notes')
            ? Value(body['notes'] as String?)
            : const Value.absent(),
      );
      await (db.update(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).write(companion);
      final updated = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingle();
      return _ok(_reservationToJson(updated));
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _setReservationStatus(String rid, String newStatus) async {
    await (db.update(db.tableReservations)
          ..where((r) => r.reservationId.equals(rid)))
        .write(TableReservationsCompanion(status: Value(newStatus)));
    final updated = await (db.select(
      db.tableReservations,
    )..where((r) => r.reservationId.equals(rid))).getSingle();
    return _ok(_reservationToJson(updated));
  }

  // POST /api/tables/reservations/:rid/confirm
  Future<Response> _confirmReservation(Request req, String rid) async {
    try {
      return await _setReservationStatus(rid, 'CONFIRMED');
    } catch (e) {
      return _err(e);
    }
  }

  // POST /api/tables/reservations/:rid/cancel
  Future<Response> _cancelReservation(Request req, String rid) async {
    try {
      final reservation = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingleOrNull();

      await (db.update(db.tableReservations)
            ..where((r) => r.reservationId.equals(rid)))
          .write(const TableReservationsCompanion(status: Value('CANCELLED')));

      // คืนสถานะโต๊ะเป็น AVAILABLE ถ้าโต๊ะยังอยู่ใน RESERVED
      if (reservation?.tableId != null) {
        final table =
            await (db.select(db.diningTables)
                  ..where((t) => t.tableId.equals(reservation!.tableId!)))
                .getSingleOrNull();
        if (table != null && table.status == 'RESERVED') {
          await (db.update(db.diningTables)
                ..where((t) => t.tableId.equals(table.tableId)))
              .write(const DiningTablesCompanion(status: Value('AVAILABLE')));
        }
      }

      final updated = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingle();
      return _ok(_reservationToJson(updated));
    } catch (e) {
      return _err(e);
    }
  }

  // POST /api/tables/reservations/:rid/no-show
  Future<Response> _noShowReservation(Request req, String rid) async {
    try {
      final reservation = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingleOrNull();

      await (db.update(db.tableReservations)
            ..where((r) => r.reservationId.equals(rid)))
          .write(const TableReservationsCompanion(status: Value('NO_SHOW')));

      // ถ้าการจองผูกกับโต๊ะและโต๊ะยังอยู่ในสถานะ RESERVED → เปลี่ยนกลับเป็น AVAILABLE
      if (reservation?.tableId != null) {
        final table =
            await (db.select(db.diningTables)
                  ..where((t) => t.tableId.equals(reservation!.tableId!)))
                .getSingleOrNull();
        if (table != null && table.status == 'RESERVED') {
          await (db.update(db.diningTables)
                ..where((t) => t.tableId.equals(table.tableId)))
              .write(const DiningTablesCompanion(status: Value('AVAILABLE')));
        }
      }

      final updated = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingle();
      return _ok(_reservationToJson(updated));
    } catch (e) {
      return _err(e);
    }
  }

  // POST /api/tables/reservations/:rid/seat
  /// Opens the reserved table (or creates session) and links reservation
  Future<Response> _seatReservation(Request req, String rid) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

      final reservation = await (db.select(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).getSingleOrNull();
      if (reservation == null) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'ไม่พบการจอง'}),
          headers: {'content-type': 'application/json'},
        );
      }
      if (reservation.status == 'CANCELLED' ||
          reservation.status == 'NO_SHOW') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message':
                'การจองนี้ไม่สามารถนำเข้านั่งได้แล้ว (${reservation.status})',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      if (reservation.status == 'SEATED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'การจองนี้ถูกนำเข้านั่งแล้ว',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final tableId = body['table_id'] as String? ?? reservation.tableId;
      if (tableId == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'ต้องระบุ table_id'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final table = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
      if (table == null) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'ไม่พบโต๊ะที่เลือก'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final zone = await (db.select(
        db.zones,
      )..where((z) => z.zoneId.equals(table.zoneId))).getSingleOrNull();
      final existing =
          await (db.select(db.tableSessions)..where(
                (s) => s.tableId.equals(tableId) & s.status.equals('OPEN'),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return Response(
          409,
          body: jsonEncode({
            'success': false,
            'message': 'โต๊ะนี้มี session ที่เปิดอยู่แล้ว',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final sessionId = const Uuid().v4();
      final branchId =
          zone?.branchId ??
          body['branch_id'] as String? ??
          reservation.branchId;
      await db
          .into(db.tableSessions)
          .insert(
            TableSessionsCompanion(
              sessionId: Value(sessionId),
              tableId: Value(tableId),
              branchId: Value(branchId),
              guestCount: Value(reservation.partySize),
              status: const Value('OPEN'),
              openedBy: Value(body['opened_by'] as String?),
              note: Value('มาจาก reservation ${reservation.reservationId}'),
            ),
          );
      await (db.update(
        db.diningTables,
      )..where((t) => t.tableId.equals(tableId))).write(
        DiningTablesCompanion(
          status: const Value('OCCUPIED'),
          lastOccupiedAt: Value(DateTime.now()),
        ),
      );
      await _logTableSessionEvent(
        sessionId: sessionId,
        tableId: tableId,
        eventType: 'opened',
        description:
            'เปิดโต๊ะจาก reservation ${reservation.customerName} (${reservation.partySize} คน)',
        payload: {
          'guest_count': reservation.partySize,
          'reservation_id': reservation.reservationId,
          'opened_by': body['opened_by'] as String?,
        },
      );
      await _logTableSessionEvent(
        sessionId: sessionId,
        tableId: tableId,
        eventType: 'reservation_seated',
        description: 'นำลูกค้าจากการจองเข้านั่งแล้ว',
        payload: {
          'reservation_id': reservation.reservationId,
          'customer_name': reservation.customerName,
        },
      );

      await (db.update(
        db.tableReservations,
      )..where((r) => r.reservationId.equals(rid))).write(
        TableReservationsCompanion(
          status: const Value('SEATED'),
          sessionId: Value(sessionId),
          tableId: Value(tableId),
        ),
      );

      return _ok({
        'reservation_id': rid,
        'session_id': sessionId,
        'table_id': tableId,
      });
    } catch (e) {
      return _err(e);
    }
  }

  Response _err(dynamic e) {
    if (kDebugMode) {
      debugPrint('❌ TableRoutes error: $e');
    }
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'message': e.toString()}),
      headers: {'content-type': 'application/json'},
    );
  }
}
