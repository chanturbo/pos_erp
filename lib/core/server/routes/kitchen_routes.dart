
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../../utils/crypto_utils.dart';
import 'package:flutter/foundation.dart';

class KitchenRoutes {
  final AppDatabase db;
  KitchenRoutes(this.db);

  Router get router {
    final r = Router();

    // GET /api/kitchen/queue?station=kitchen&branch_id=...&status=PENDING,PREPARING
    r.get('/queue', _getQueue);

    // GET /api/kitchen/summary?branch_id=...
    r.get('/summary', _getSummary);

    // PUT /api/kitchen/items/:itemId/status  body: { "status": "PREPARING" }
    r.put('/items/<itemId>/status', _updateItemStatus);

    // PUT /api/kitchen/items/:itemId/serve  (shortcut → SERVED)
    r.put('/items/<itemId>/serve', _serveItem);

    // R4: Kitchen analytics
    r.get('/analytics', _getAnalytics);

    return r;
  }

  // ── Queue ──────────────────────────────────────────────────────────────────

  Future<Response> _getQueue(Request req) async {
    try {
      final params = req.url.queryParameters;
      final station = params['station']; // kitchen | bar | dessert | null=all
      final branchId = params['branch_id'];
      final statusFilter = params['status']; // e.g. "PENDING,PREPARING"

      final statuses = statusFilter != null
          ? statusFilter.split(',').map((s) => s.trim().toUpperCase()).toList()
          : ['PENDING', 'PREPARING', 'READY', 'HELD'];

      // โหลด open orders ที่ผูกกับ table (dine-in) หรือ order ทั่วไป
      final openOrders = await (db.select(
        db.salesOrders,
      )..where((o) => o.status.equals('OPEN'))).get();

      // filter by branchId ถ้ามี
      final filteredOrders = branchId != null
          ? openOrders.where((o) => o.branchId == branchId).toList()
          : openOrders;

      if (filteredOrders.isEmpty) return _ok([]);

      final orderIds = filteredOrders.map((o) => o.orderId).toList();

      // โหลด order items
      final itemsQuery = db.select(db.salesOrderItems)
        ..where(
          (i) => i.orderId.isIn(orderIds) & i.kitchenStatus.isIn(statuses),
        );
      final items = await itemsQuery.get();

      if (items.isEmpty) return _ok([]);

      // โหลด products เพื่อได้ prepStation
      final productIds = items.map((i) => i.productId).toSet().toList();
      final products = await (db.select(
        db.products,
      )..where((p) => p.productId.isIn(productIds))).get();
      final productMap = {for (final p in products) p.productId: p};

      // โหลด tables เพื่อได้ table name
      final tableIds = filteredOrders
          .where((o) => o.tableId != null)
          .map((o) => o.tableId!)
          .toSet()
          .toList();
      final tables = tableIds.isNotEmpty
          ? await (db.select(
              db.diningTables,
            )..where((t) => t.tableId.isIn(tableIds))).get()
          : <DiningTable>[];
      final tableMap = {
        for (final t in tables) t.tableId: t.tableDisplayName ?? t.tableNo,
      };

      // map order lookup
      final orderMap = {for (final o in filteredOrders) o.orderId: o};

      // filter by station + requiresPreparation
      final result = items
          .where((i) {
            final product = productMap[i.productId];
            // แสดงเฉพาะ items ที่ต้องเตรียมในครัว
            final needsPrep =
                (product?.requiresPreparation ?? false) ||
                product?.prepStation != null;
            if (!needsPrep) return false;
            if (station == null) return true;
            final ps = product?.prepStation?.toLowerCase();
            return ps == station.toLowerCase();
          })
          .map((i) {
            final order = orderMap[i.orderId];
            final product = productMap[i.productId];
            return {
              'item_id': i.itemId,
              'order_id': i.orderId,
              'order_no': order?.orderNo ?? '',
              'table_id': order?.tableId,
              'table_name': order?.tableId != null
                  ? tableMap[order!.tableId]
                  : null,
              'session_id': order?.sessionId,
              'line_no': i.lineNo,
              'product_id': i.productId,
              'product_name': i.productName,
              'quantity': i.quantity,
              'unit': i.unit,
              'kitchen_status': i.kitchenStatus,
              'course_no': i.courseNo,
              'prep_station': product?.prepStation,
              'special_instructions': i.specialInstructions,
              'created_at': i.createdAt.toIso8601String(),
              'prepared_at': i.preparedAt?.toIso8601String(),
            };
          })
          .toList();

      // เรียงตาม createdAt (เก่าสุดก่อน)
      result.sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );

      return _ok(result);
    } catch (e) {
      return _err(e);
    }
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Future<Response> _getSummary(Request req) async {
    try {
      final branchId = req.url.queryParameters['branch_id'];

      final openOrders = await (db.select(
        db.salesOrders,
      )..where((o) => o.status.equals('OPEN'))).get();

      final filteredOrderIds =
          (branchId != null
                  ? openOrders.where((o) => o.branchId == branchId)
                  : openOrders)
              .map((o) => o.orderId)
              .toList();

      if (filteredOrderIds.isEmpty) {
        return _ok(<Map<String, dynamic>>[]);
      }

      final items =
          await (db.select(db.salesOrderItems)..where(
                (i) =>
                    i.orderId.isIn(filteredOrderIds) &
                    i.kitchenStatus.isNotIn(['SERVED', 'CANCELLED']),
              ))
              .get();

      final productIds = items.map((i) => i.productId).toSet().toList();
      final products = productIds.isNotEmpty
          ? await (db.select(
              db.products,
            )..where((p) => p.productId.isIn(productIds))).get()
          : <Product>[];
      final productMap = {for (final p in products) p.productId: p};

      // count by station + status
      final summary = <String, Map<String, int>>{};
      for (final item in items) {
        final station =
            productMap[item.productId]?.prepStation?.toLowerCase() ?? 'kitchen';
        summary.putIfAbsent(
          station,
          () => {'pending': 0, 'preparing': 0, 'ready': 0},
        );
        switch (item.kitchenStatus) {
          case 'PENDING':
            summary[station]!['pending'] = (summary[station]!['pending']! + 1);
            break;
          case 'PREPARING':
            summary[station]!['preparing'] =
                (summary[station]!['preparing']! + 1);
            break;
          case 'READY':
            summary[station]!['ready'] = (summary[station]!['ready']! + 1);
            break;
        }
      }

      final result = summary.entries
          .map(
            (e) => {
              'station': e.key,
              'pending_count': e.value['pending'],
              'preparing_count': e.value['preparing'],
              'ready_count': e.value['ready'],
            },
          )
          .toList();

      return _ok(result);
    } catch (e) {
      return _err(e);
    }
  }

  // ── Item status update ─────────────────────────────────────────────────────

  Future<Response> _updateItemStatus(Request req, String itemId) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final newStatus = (body['status'] as String).toUpperCase();

      final validStatuses = [
        'PENDING',
        'PREPARING',
        'READY',
        'SERVED',
        'CANCELLED',
      ];
      if (!validStatuses.contains(newStatus)) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'invalid status: $newStatus',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final item = await (db.select(
        db.salesOrderItems,
      )..where((i) => i.itemId.equals(itemId))).getSingleOrNull();
      if (item == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบรายการอาหาร'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (!_canTransition(item.kitchenStatus, newStatus)) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message':
                'เปลี่ยนสถานะจาก ${item.kitchenStatus} เป็น $newStatus ไม่ได้',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      if (newStatus == 'CANCELLED') {
        final reason = (body['reason'] as String?)?.trim() ?? '';
        if (reason.isEmpty) {
          return Response(
            400,
            body: jsonEncode({
              'success': false,
              'message': 'กรุณาระบุเหตุผลในการยกเลิกรายการ',
            }),
            headers: {'content-type': 'application/json'},
          );
        }

        final prefs = await SharedPreferences.getInstance();
        final storedPin = (prefs.getString('manager_pin') ?? '').trim();
        final submittedPin = (body['manager_pin'] as String?)?.trim() ?? '';
        if (storedPin.isNotEmpty) {
          final isHashed = storedPin.length == 64;
          final valid = isHashed
              ? CryptoUtils.verifyPassword(submittedPin, storedPin)
              : submittedPin == storedPin;
          if (!valid || submittedPin.isEmpty) {
            return Response(
              403,
              body: jsonEncode({
                'success': false,
                'message': 'Manager PIN ไม่ถูกต้อง',
              }),
              headers: {'content-type': 'application/json'},
            );
          }
        }

        final order = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(item.orderId))).getSingleOrNull();
        if (order != null &&
            order.sessionId != null &&
            order.tableId != null &&
            order.sessionId!.trim().isNotEmpty &&
            order.tableId!.trim().isNotEmpty) {
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
              order.sessionId,
              order.tableId,
              'item_cancelled',
              DateTime.now().toIso8601String(),
              'ยกเลิกรายการ ${item.productName}',
              jsonEncode({
                'item_id': item.itemId,
                'product_name': item.productName,
                'reason': reason,
              }),
            ],
          );
        }
      }

      final preparedAt = (newStatus == 'READY' || newStatus == 'SERVED')
          ? Value(DateTime.now())
          : const Value<DateTime?>.absent();

      await (db.update(
        db.salesOrderItems,
      )..where((i) => i.itemId.equals(itemId))).write(
        SalesOrderItemsCompanion(
          kitchenStatus: Value(newStatus),
          preparedAt: preparedAt,
        ),
      );

      if (kDebugMode) {
        debugPrint('✅ Kitchen: item $itemId → $newStatus');
      }
      return _ok({
        'item_id': itemId,
        'status': newStatus,
        if (newStatus == 'CANCELLED') 'reason': body['reason'],
      });
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _serveItem(Request req, String itemId) async {
    try {
      await (db.update(
        db.salesOrderItems,
      )..where((i) => i.itemId.equals(itemId))).write(
        SalesOrderItemsCompanion(
          kitchenStatus: const Value('SERVED'),
          preparedAt: Value(DateTime.now()),
        ),
      );
      return _ok({'item_id': itemId, 'status': 'SERVED'});
    } catch (e) {
      return _err(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Response _ok(dynamic data, {int statusCode = 200}) => Response(
    statusCode,
    body: jsonEncode({'success': true, 'data': data}),
    headers: {'content-type': 'application/json'},
  );

  Response _err(dynamic e) {
    if (kDebugMode) {
      debugPrint('❌ KitchenRoutes error: $e');
    }
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'message': e.toString()}),
      headers: {'content-type': 'application/json'},
    );
  }

  // ── R4: Analytics ──────────────────────────────────────────────────────────

  /// GET /api/kitchen/analytics?branch_id=&date=YYYY-MM-DD
  Future<Response> _getAnalytics(Request req) async {
    try {
      final params = req.url.queryParameters;
      final branchId = params['branch_id'];
      final dateStr = params['date'];

      final targetDate = dateStr != null
          ? DateTime.tryParse(dateStr)
          : DateTime.now();
      final dayStart = DateTime(
        targetDate!.year,
        targetDate.month,
        targetDate.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));

      final orders =
          await (db.select(db.salesOrders)..where((o) {
                Expression<bool> cond =
                    o.orderDate.isBiggerOrEqualValue(dayStart) &
                    o.orderDate.isSmallerThanValue(dayEnd);
                if (branchId != null) cond = cond & o.branchId.equals(branchId);
                return cond;
              }))
              .get();
      final restaurantOrders = orders
          .where(
            (o) =>
                (o.tableId != null && o.tableId!.trim().isNotEmpty) ||
                (o.sessionId != null && o.sessionId!.trim().isNotEmpty) ||
                (o.serviceType != null &&
                    const {
                      'DINE_IN',
                      'TAKEAWAY',
                      'DELIVERY',
                    }.contains(o.serviceType!.trim().toUpperCase())),
          )
          .toList();

      final orderIds = restaurantOrders.map((o) => o.orderId).toList();

      if (orderIds.isEmpty) {
        return _ok({
          'period': dayStart.toIso8601String().substring(0, 10),
          'total_orders': 0,
          'total_items': 0,
          'avg_prep_time_minutes': 0,
          'avg_order_time_minutes': 0,
          'items_by_station': <String, int>{},
          'avg_prep_by_station': <String, double>{},
          'top_items': <Map<String, dynamic>>[],
        });
      }

      final allItems = await (db.select(
        db.salesOrderItems,
      )..where((i) => i.orderId.isIn(orderIds))).get();

      final productIds = allItems.map((i) => i.productId).toSet().toList();
      final products = productIds.isEmpty
          ? <Product>[]
          : await (db.select(
              db.products,
            )..where((p) => p.productId.isIn(productIds))).get();
      final productMap = {
        for (final product in products) product.productId: product,
      };

      // Prep time: items that were prepared (have preparedAt)
      final preparedItems = allItems
          .where((i) => i.preparedAt != null)
          .toList();
      double totalPrepMins = 0;
      for (final item in preparedItems) {
        final order = restaurantOrders.firstWhere(
          (o) => o.orderId == item.orderId,
        );
        final prepTime =
            item.preparedAt!.difference(order.createdAt).inSeconds / 60.0;
        if (prepTime > 0) totalPrepMins += prepTime;
      }
      final avgPrepMins = preparedItems.isNotEmpty
          ? totalPrepMins / preparedItems.length
          : 0.0;

      // Order time: from first item created to last item SERVED
      double totalOrderMins = 0;
      int ordersWithTime = 0;
      for (final order in restaurantOrders) {
        final items = allItems
            .where((i) => i.orderId == order.orderId)
            .toList();
        final servedItems = items.where(
          (i) => i.kitchenStatus == 'SERVED' && i.preparedAt != null,
        );
        if (servedItems.isNotEmpty) {
          final lastServed = servedItems
              .map((i) => i.preparedAt!)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final orderTime =
              lastServed.difference(order.createdAt).inSeconds / 60.0;
          if (orderTime > 0) {
            totalOrderMins += orderTime;
            ordersWithTime++;
          }
        }
      }
      final avgOrderMins = ordersWithTime > 0
          ? totalOrderMins / ordersWithTime
          : 0.0;

      // Items by station — join with products
      final itemsByStation = <String, int>{};
      final prepTimeByStation = <String, List<double>>{};
      final itemCounts = <String, int>{};

      for (final item in allItems) {
        final product = productMap[item.productId];
        final station = product?.prepStation ?? 'kitchen';

        itemsByStation[station] = (itemsByStation[station] ?? 0) + 1;
        itemCounts[item.productName] = (itemCounts[item.productName] ?? 0) + 1;

        if (item.preparedAt != null) {
          final order = restaurantOrders.firstWhere(
            (o) => o.orderId == item.orderId,
          );
          final mins =
              item.preparedAt!.difference(order.createdAt).inSeconds / 60.0;
          if (mins > 0) {
            prepTimeByStation.putIfAbsent(station, () => []).add(mins);
          }
        }
      }

      final avgPrepByStation = prepTimeByStation.map(
        (station, times) =>
            MapEntry(station, times.reduce((a, b) => a + b) / times.length),
      );

      final topItems =
          (itemCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(10)
              .map((e) => {'product_name': e.key, 'count': e.value})
              .toList();

      return _ok({
        'period': dayStart.toIso8601String().substring(0, 10),
        'total_orders': restaurantOrders.length,
        'total_items': allItems.length,
        'avg_prep_time_minutes': double.parse(avgPrepMins.toStringAsFixed(1)),
        'avg_order_time_minutes': double.parse(avgOrderMins.toStringAsFixed(1)),
        'items_by_station': itemsByStation,
        'avg_prep_by_station': avgPrepByStation.map(
          (k, v) => MapEntry(k, double.parse(v.toStringAsFixed(1))),
        ),
        'top_items': topItems,
      });
    } catch (e) {
      return _err(e);
    }
  }

  bool _canTransition(String currentStatus, String nextStatus) {
    if (currentStatus == nextStatus) return true;

    const allowedTransitions = <String, Set<String>>{
      'HELD': {'PENDING', 'CANCELLED'},
      'PENDING': {'PREPARING', 'CANCELLED'},
      'PREPARING': {'PENDING', 'READY', 'CANCELLED'},
      'READY': {'SERVED', 'CANCELLED'},
      'SERVED': {},
      'CANCELLED': {},
    };

    return allowedTransitions[currentStatus]?.contains(nextStatus) ?? false;
  }
}
