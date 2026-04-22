import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/core/database/app_database.dart';
import 'package:pos_erp/core/server/routes/kitchen_routes.dart';
import 'package:pos_erp/core/server/routes/sales_routes.dart';
import 'package:pos_erp/core/server/routes/table_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';

void main() {
  group('Restaurant R4 routes', () {
    late AppDatabase db;
    late TableRoutes tableRoutes;
    late KitchenRoutes kitchenRoutes;
    late SalesRoutes salesRoutes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement('PRAGMA foreign_keys = ON');
      tableRoutes = TableRoutes(db);
      kitchenRoutes = KitchenRoutes(db);
      salesRoutes = SalesRoutes(db);
      await _seedBaseData(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'seat reservation rejects cancelled reservation and occupied table',
      () async {
        await db
            .into(db.tableReservations)
            .insert(
              TableReservationsCompanion.insert(
                reservationId: 'RES-CANCELLED',
                branchId: 'BR1',
                customerName: 'Cancelled Guest',
                reservationTime: DateTime.now(),
                status: const Value('CANCELLED'),
              ),
            );

        final cancelledRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/reservations/RES-CANCELLED/seat'),
            body: jsonEncode({'table_id': 'TB1', 'branch_id': 'BR1'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        final cancelledBody =
            jsonDecode(await cancelledRes.readAsString())
                as Map<String, dynamic>;
        expect(cancelledRes.statusCode, 400);
        expect(cancelledBody['success'], isFalse);

        await db
            .into(db.tableReservations)
            .insert(
              TableReservationsCompanion.insert(
                reservationId: 'RES-OCCUPIED',
                branchId: 'BR1',
                customerName: 'Occupied Guest',
                reservationTime: DateTime.now(),
                status: const Value('CONFIRMED'),
              ),
            );
        await db
            .into(db.tableSessions)
            .insert(
              TableSessionsCompanion.insert(
                sessionId: 'TS-OCCUPIED',
                tableId: 'TB1',
                branchId: 'BR1',
                guestCount: const Value(2),
                status: const Value('OPEN'),
              ),
            );

        final occupiedRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/reservations/RES-OCCUPIED/seat'),
            body: jsonEncode({'table_id': 'TB1', 'branch_id': 'BR1'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        final occupiedBody =
            jsonDecode(await occupiedRes.readAsString())
                as Map<String, dynamic>;
        expect(occupiedRes.statusCode, 409);
        expect(occupiedBody['success'], isFalse);
      },
    );

    test(
      'kitchen analytics counts restaurant orders only and respects branch filter',
      () async {
        final now = DateTime.now();

        await _insertSalesOrder(
          db,
          orderId: 'SO-REST-1',
          orderNo: 'SO-REST-1',
          branchId: 'BR1',
          warehouseId: 'WH1',
          userId: 'USR1',
          tableId: 'TB1',
          sessionId: 'TS-REST-1',
          serviceType: 'DINE_IN',
          status: 'COMPLETED',
          orderDate: now,
          itemId: 'ITEM-REST-1',
          productId: 'P1',
          productName: 'Pad Thai',
          kitchenStatus: 'SERVED',
          preparedAt: now.add(const Duration(minutes: 10)),
        );

        await _insertSalesOrder(
          db,
          orderId: 'SO-RTL-1',
          orderNo: 'SO-RTL-1',
          branchId: 'BR1',
          warehouseId: 'WH1',
          userId: 'USR1',
          status: 'COMPLETED',
          orderDate: now,
          itemId: 'ITEM-RTL-1',
          productId: 'P1',
          productName: 'Pad Thai',
          kitchenStatus: 'SERVED',
          preparedAt: now.add(const Duration(minutes: 3)),
        );

        await _insertSalesOrder(
          db,
          orderId: 'SO-REST-2',
          orderNo: 'SO-REST-2',
          branchId: 'BR2',
          warehouseId: 'WH2',
          userId: 'USR1',
          tableId: 'TB2',
          sessionId: 'TS-REST-2',
          serviceType: 'DINE_IN',
          status: 'COMPLETED',
          orderDate: now,
          itemId: 'ITEM-REST-2',
          productId: 'P2',
          productName: 'Tom Yum',
          kitchenStatus: 'SERVED',
          preparedAt: now.add(const Duration(minutes: 7)),
        );

        final date = _fmtDate(now);
        final res = await kitchenRoutes.router.call(
          Request(
            'GET',
            Uri.parse('http://localhost/analytics?branch_id=BR1&date=$date'),
          ),
        );
        final body =
            jsonDecode(await res.readAsString()) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;

        expect(res.statusCode, 200);
        expect(data['total_orders'], 1);
        expect(data['total_items'], 1);
        expect((data['top_items'] as List).length, 1);
        expect((data['top_items'] as List).first['product_name'], 'Pad Thai');
      },
    );

    test(
      'fire-course updates held items and timeline includes waiter and fire event',
      () async {
        final openedAt = DateTime.now().subtract(const Duration(minutes: 20));
        await db
            .into(db.tableSessions)
            .insert(
              TableSessionsCompanion.insert(
                sessionId: 'TS-FIRE',
                tableId: 'TB1',
                branchId: 'BR1',
                guestCount: const Value(2),
                status: const Value('OPEN'),
                openedAt: Value(openedAt),
              ),
            );
        await (db.update(db.diningTables)
              ..where((t) => t.tableId.equals('TB1')))
            .write(const DiningTablesCompanion(status: Value('OCCUPIED')));

        await db
            .into(db.salesOrders)
            .insert(
              SalesOrdersCompanion.insert(
                orderId: 'SO-FIRE',
                orderNo: 'SO-FIRE',
                orderDate: openedAt,
                branchId: 'BR1',
                warehouseId: 'WH1',
                userId: 'USR1',
                tableId: const Value('TB1'),
                sessionId: const Value('TS-FIRE'),
                serviceType: const Value('DINE_IN'),
                subtotal: const Value(120),
                totalAmount: const Value(120),
                status: const Value('OPEN'),
              ),
            );
        await db
            .into(db.salesOrderItems)
            .insert(
              SalesOrderItemsCompanion.insert(
                itemId: 'ITEM-FIRE',
                orderId: 'SO-FIRE',
                lineNo: 1,
                productId: 'P1',
                productCode: 'P1',
                productName: 'Pad Thai',
                unit: 'plate',
                quantity: 1,
                unitPrice: 120,
                amount: 120,
                warehouseId: 'WH1',
                kitchenStatus: const Value('HELD'),
                courseNo: const Value(2),
              ),
            );

        final waiterRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/assign-waiter'),
            body: jsonEncode({'waiter_id': 'W01', 'waiter_name': 'Alice'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        expect(waiterRes.statusCode, 200);

        final fireRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/fire-course'),
            body: jsonEncode({'course_no': 2}),
            headers: {'content-type': 'application/json'},
          ),
        );
        final fireBody =
            jsonDecode(await fireRes.readAsString()) as Map<String, dynamic>;
        expect(fireRes.statusCode, 200);
        expect(fireBody['data']['fired'], 1);

        final item = await (db.select(
          db.salesOrderItems,
        )..where((t) => t.itemId.equals('ITEM-FIRE'))).getSingle();
        expect(item.kitchenStatus, 'PENDING');

        final timelineRes = await tableRoutes.router.call(
          Request('GET', Uri.parse('http://localhost/TB1/timeline')),
        );
        final timelineBody =
            jsonDecode(await timelineRes.readAsString())
                as Map<String, dynamic>;
        final events = (timelineBody['data']['events'] as List)
            .cast<Map<String, dynamic>>();

        expect(
          events.any(
            (event) =>
                event['type'] == 'waiter' &&
                (event['data'] as Map<String, dynamic>)['waiter_name'] ==
                    'Alice',
          ),
          isTrue,
        );
        expect(
          events.any(
            (event) =>
                event['type'] == 'fire_course' &&
                (event['data'] as Map<String, dynamic>)['course_no'] == 2,
          ),
          isTrue,
        );
      },
    );

    test(
      'open table creates active session and marks table occupied',
      () async {
        final res = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/open'),
            body: jsonEncode({
              'guest_count': 3,
              'branch_id': 'BR1',
              'opened_by': 'USR1',
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final body =
            jsonDecode(await res.readAsString()) as Map<String, dynamic>;

        expect(res.statusCode, 201);
        expect(body['data']['guest_count'], 3);

        final session =
            await (db.select(db.tableSessions)..where(
                  (s) => s.tableId.equals('TB1') & s.status.equals('OPEN'),
                ))
                .getSingle();
        final table = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();

        expect(session.branchId, 'BR1');
        expect(session.guestCount, 3);
        expect(table.status, 'OCCUPIED');
      },
    );

    test(
      'create dine-in order reserves stock and holds later courses',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );

        final createRes = await salesRoutes.router.call(
          await _authedJsonRequest(
            db,
            'POST',
            'http://localhost/',
            body: {
              'status': 'OPEN',
              'table_id': 'TB1',
              'session_id': sessionId,
              'service_type': 'DINE_IN',
              'party_size': 2,
              'warehouse_id': 'WH1',
              'subtotal': 260,
              'discount_amount': 0,
              'amount_before_vat': 260,
              'total_amount': 260,
              'payment_type': 'CASH',
              'items': [
                {
                  'product_id': 'P1',
                  'product_code': 'P1',
                  'product_name': 'Pad Thai',
                  'unit': 'plate',
                  'quantity': 1,
                  'unit_price': 120,
                  'amount': 120,
                  'course_no': 1,
                },
                {
                  'product_id': 'P2',
                  'product_code': 'P2',
                  'product_name': 'Tom Yum',
                  'unit': 'bowl',
                  'quantity': 1,
                  'unit_price': 140,
                  'amount': 140,
                  'course_no': 2,
                },
              ],
            },
          ),
        );
        final createBody =
            jsonDecode(await createRes.readAsString()) as Map<String, dynamic>;
        final orderId = createBody['data']['order_id'] as String;

        expect(createRes.statusCode, 200);

        final order = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(orderId))).getSingle();
        final items =
            await (db.select(db.salesOrderItems)
                  ..where((i) => i.orderId.equals(orderId))
                  ..orderBy([(i) => OrderingTerm.asc(i.lineNo)]))
                .get();
        final table = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();
        final stockP1 =
            await (db.select(db.stockBalances)..where(
                  (s) => s.productId.equals('P1') & s.warehouseId.equals('WH1'),
                ))
                .getSingle();
        final stockP2 =
            await (db.select(db.stockBalances)..where(
                  (s) => s.productId.equals('P2') & s.warehouseId.equals('WH1'),
                ))
                .getSingle();

        expect(order.status, 'OPEN');
        expect(order.serviceType, 'DINE_IN');
        expect(order.tableId, 'TB1');
        expect(table.currentOrderId, orderId);
        expect(items.map((item) => item.kitchenStatus).toList(), [
          'PENDING',
          'HELD',
        ]);
        expect(stockP1.reservedQty, 1);
        expect(stockP2.reservedQty, 1);
      },
    );

    test('split, complete payment, and close table for dine-in flow', () async {
      final sessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      final orderId = await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sessionId,
        tableId: 'TB1',
      );

      final originalItems =
          await (db.select(db.salesOrderItems)
                ..where((i) => i.orderId.equals(orderId))
                ..orderBy([(i) => OrderingTerm.asc(i.lineNo)]))
              .get();

      final splitRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/bill/split/apply'),
          body: jsonEncode({
            'splits': [
              {
                'label': 'คน 1',
                'items': [
                  {
                    'item_id': originalItems.first.itemId,
                    'quantity': originalItems.first.quantity,
                  },
                ],
              },
            ],
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final splitBody =
          jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;
      final splitOrderId =
          (splitBody['data']['splits'] as List).first['order_ids'].first
              as String;

      expect(splitRes.statusCode, 200);

      final completeRes = await salesRoutes.router.call(
        await _authedJsonRequest(
          db,
          'POST',
          'http://localhost/$orderId/complete',
          body: {
            'additional_order_ids': [splitOrderId],
            'payment_type': 'CASH',
            'paid_amount': 260,
            'change_amount': 0,
          },
        ),
      );
      expect(completeRes.statusCode, 200);

      final completedOrders = await (db.select(
        db.salesOrders,
      )..where((o) => o.orderId.isIn([orderId, splitOrderId]))).get();
      final stockP1 =
          await (db.select(db.stockBalances)..where(
                (s) => s.productId.equals('P1') & s.warehouseId.equals('WH1'),
              ))
              .getSingle();
      final stockP2 =
          await (db.select(db.stockBalances)..where(
                (s) => s.productId.equals('P2') & s.warehouseId.equals('WH1'),
              ))
              .getSingle();

      expect(
        completedOrders.every((order) => order.status == 'COMPLETED'),
        isTrue,
      );
      expect(stockP1.reservedQty, 0);
      expect(stockP2.reservedQty, 0);

      final closeRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/close'),
          body: jsonEncode({}),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(closeRes.statusCode, 200);

      final session = await (db.select(
        db.tableSessions,
      )..where((s) => s.sessionId.equals(sessionId))).getSingle();
      final table = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals('TB1'))).getSingle();

      expect(session.status, 'CLOSED');
      expect(table.status, 'CLEANING');
      expect(table.currentOrderId, equals(null));
    });

    test(
      'transfer table updates open order table reference and current order',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final transferRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/transfer'),
            body: jsonEncode({'target_table_id': 'TB3'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        expect(transferRes.statusCode, 200);

        final movedOrder = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(orderId))).getSingle();
        final movedSession = await (db.select(
          db.tableSessions,
        )..where((s) => s.sessionId.equals(sessionId))).getSingle();
        final sourceTable = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();
        final targetTable = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB3'))).getSingle();

        expect(movedOrder.tableId, 'TB3');
        expect(movedSession.tableId, 'TB3');
        expect(sourceTable.currentOrderId, equals(null));
        expect(sourceTable.status, 'CLEANING');
        expect(targetTable.currentOrderId, orderId);
        expect(targetTable.status, 'OCCUPIED');
      },
    );

    test(
      'partial split payment keeps table current order pointing to remaining open order',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final originalOrderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final originalItems =
            await (db.select(db.salesOrderItems)
                  ..where((i) => i.orderId.equals(originalOrderId))
                  ..orderBy([(i) => OrderingTerm.asc(i.lineNo)]))
                .get();

        final splitRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split/apply'),
            body: jsonEncode({
              'splits': [
                {
                  'label': 'คน 1',
                  'items': [
                    {
                      'item_id': originalItems.first.itemId,
                      'quantity': originalItems.first.quantity,
                    },
                  ],
                },
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final splitBody =
            jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;
        final splitOrderId =
            (splitBody['data']['splits'] as List).first['order_ids'].first
                as String;
        expect(splitRes.statusCode, 200);

        final completeRes = await salesRoutes.router.call(
          await _authedJsonRequest(
            db,
            'POST',
            'http://localhost/$splitOrderId/complete',
            body: {
              'payment_type': 'CASH',
              'paid_amount': 120,
              'change_amount': 0,
            },
          ),
        );
        expect(completeRes.statusCode, 200);

        final originalOrder = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(originalOrderId))).getSingle();
        final splitOrder = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(splitOrderId))).getSingle();
        final table = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();

        expect(splitOrder.status, 'COMPLETED');
        expect(originalOrder.status, 'OPEN');
        expect(table.currentOrderId, originalOrderId);
      },
    );

    test(
      'partial quantity split prorates amounts and keeps remaining quantity',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final sourceItem =
            await (db.select(db.salesOrderItems)..where(
                  (i) => i.orderId.equals(orderId) & i.productId.equals('P1'),
                ))
                .getSingle();

        await (db.update(
          db.salesOrderItems,
        )..where((i) => i.itemId.equals(sourceItem.itemId))).write(
          SalesOrderItemsCompanion(
            quantity: const Value(2),
            amount: const Value(240),
            cost: Value(sourceItem.cost * 2),
          ),
        );

        final previewRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split'),
            body: jsonEncode({
              'splits': [
                {
                  'label': 'คน 1',
                  'item_ids': [sourceItem.itemId],
                },
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final previewBody =
            jsonDecode(await previewRes.readAsString()) as Map<String, dynamic>;
        final previewToken = previewBody['data']['preview_token'] as String;

        final splitRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split/apply'),
            body: jsonEncode({
              'preview_token': previewToken,
              'splits': [
                {
                  'label': 'คน 1',
                  'items': [
                    {'item_id': sourceItem.itemId, 'quantity': 1},
                  ],
                },
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final splitBody =
            jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;
        final splitData = splitBody['data'] as Map<String, dynamic>;
        final createdSplit =
            (splitData['splits'] as List).first as Map<String, dynamic>;
        final splitOrderId =
            (createdSplit['order_ids'] as List).first as String;

        expect(previewRes.statusCode, 200);
        expect(splitRes.statusCode, 200);
        expect(createdSplit['subtotal'], 120);
        expect((createdSplit['items'] as List).first['quantity'], 1.0);

        final remainingSourceItem = await (db.select(
          db.salesOrderItems,
        )..where((i) => i.itemId.equals(sourceItem.itemId))).getSingle();
        final splitItem = await (db.select(
          db.salesOrderItems,
        )..where((i) => i.orderId.equals(splitOrderId))).getSingle();

        expect(remainingSourceItem.quantity, 1);
        expect(remainingSourceItem.amount, 120);
        expect(splitItem.quantity, 1);
        expect(splitItem.amount, 120);
      },
    );

    test(
      'partial quantity split rejects quantity exceeding original item',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final sourceItem =
            await (db.select(db.salesOrderItems)..where(
                  (i) => i.orderId.equals(orderId) & i.productId.equals('P1'),
                ))
                .getSingle();

        final splitRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split/apply'),
            body: jsonEncode({
              'splits': [
                {
                  'label': 'คน 1',
                  'items': [
                    {
                      'item_id': sourceItem.itemId,
                      'quantity': sourceItem.quantity + 1,
                    },
                  ],
                },
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final splitBody =
            jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

        expect(splitRes.statusCode, 500);
        expect(splitBody['success'], isFalse);
        expect(splitBody['message'], contains('เกินจำนวนเดิม'));

        final unchangedItem = await (db.select(
          db.salesOrderItems,
        )..where((i) => i.itemId.equals(sourceItem.itemId))).getSingle();
        expect(unchangedItem.quantity, sourceItem.quantity);
        expect(unchangedItem.orderId, orderId);
      },
    );

    test('partial quantity split rejects stale preview token', () async {
      final sessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      final orderId = await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sessionId,
        tableId: 'TB1',
      );

      final sourceItem =
          await (db.select(db.salesOrderItems)..where(
                (i) => i.orderId.equals(orderId) & i.productId.equals('P1'),
              ))
              .getSingle();

      final splitRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/bill/split/apply'),
          body: jsonEncode({
            'preview_token': 'stale-preview-token',
            'splits': [
              {
                'label': 'คน 1',
                'items': [
                  {
                    'item_id': sourceItem.itemId,
                    'quantity': sourceItem.quantity,
                  },
                ],
              },
            ],
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final splitBody =
          jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

      expect(splitRes.statusCode, 409);
      expect(splitBody['success'], isFalse);
      expect(splitBody['message'], contains('รายการบิลเปลี่ยนแปลง'));

      final orders =
          await (db.select(db.salesOrders)..where(
                (o) => o.sessionId.equals(sessionId) & o.status.equals('OPEN'),
              ))
              .get();
      expect(orders, hasLength(1));
      expect(orders.single.orderId, orderId);
    });

    test('partial quantity split rejects zero quantity input', () async {
      final sessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      final orderId = await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sessionId,
        tableId: 'TB1',
      );

      final sourceItem =
          await (db.select(db.salesOrderItems)..where(
                (i) => i.orderId.equals(orderId) & i.productId.equals('P1'),
              ))
              .getSingle();

      final splitRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/bill/split/apply'),
          body: jsonEncode({
            'splits': [
              {
                'label': 'คน 1',
                'items': [
                  {'item_id': sourceItem.itemId, 'quantity': 0},
                ],
              },
            ],
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final splitBody =
          jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

      expect(splitRes.statusCode, 500);
      expect(splitBody['success'], isFalse);
      expect(splitBody['message'], contains('ข้อมูล split item ไม่ถูกต้อง'));

      final openOrders =
          await (db.select(db.salesOrders)..where(
                (o) => o.sessionId.equals(sessionId) & o.status.equals('OPEN'),
              ))
              .get();
      expect(openOrders, hasLength(1));
      expect(openOrders.single.orderId, orderId);
    });

    test('partial quantity split rejects blank item id input', () async {
      final sessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      final orderId = await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sessionId,
        tableId: 'TB1',
      );

      final splitRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/bill/split/apply'),
          body: jsonEncode({
            'splits': [
              {
                'label': 'คน 1',
                'items': [
                  {'item_id': '', 'quantity': 1},
                ],
              },
            ],
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final splitBody =
          jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

      expect(splitRes.statusCode, 500);
      expect(splitBody['success'], isFalse);
      expect(splitBody['message'], contains('ข้อมูล split item ไม่ถูกต้อง'));

      final openOrders =
          await (db.select(db.salesOrders)..where(
                (o) => o.sessionId.equals(sessionId) & o.status.equals('OPEN'),
              ))
              .get();
      expect(openOrders, hasLength(1));
      expect(openOrders.single.orderId, orderId);
    });

    test(
      'partial quantity split rejects split block without items or item_ids',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final splitRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split/apply'),
            body: jsonEncode({
              'splits': [
                {'label': 'คน 1'},
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final splitBody =
            jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

        expect(splitRes.statusCode, 500);
        expect(splitBody['success'], isFalse);
        expect(
          splitBody['message'],
          contains('split แต่ละส่วนต้องมี items หรือ item_ids'),
        );

        final openOrders =
            await (db.select(db.salesOrders)..where(
                  (o) =>
                      o.sessionId.equals(sessionId) & o.status.equals('OPEN'),
                ))
                .get();
        expect(openOrders, hasLength(1));
        expect(openOrders.single.orderId, orderId);
      },
    );

    test(
      'partial quantity split rejects oversubscribe across multiple splits in one request',
      () async {
        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );

        final sourceItem =
            await (db.select(db.salesOrderItems)..where(
                  (i) => i.orderId.equals(orderId) & i.productId.equals('P1'),
                ))
                .getSingle();

        final splitRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/TB1/bill/split/apply'),
            body: jsonEncode({
              'splits': [
                {
                  'label': 'คน 1',
                  'items': [
                    {
                      'item_id': sourceItem.itemId,
                      'quantity': sourceItem.quantity,
                    },
                  ],
                },
                {
                  'label': 'คน 2',
                  'items': [
                    {'item_id': sourceItem.itemId, 'quantity': 1},
                  ],
                },
              ],
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final splitBody =
            jsonDecode(await splitRes.readAsString()) as Map<String, dynamic>;

        expect(splitRes.statusCode, 500);
        expect(splitBody['success'], isFalse);
        expect(splitBody['message'], contains('เกินจำนวนเดิม'));

        final openOrders =
            await (db.select(db.salesOrders)..where(
                  (o) =>
                      o.sessionId.equals(sessionId) & o.status.equals('OPEN'),
                ))
                .get();
        final currentItem = await (db.select(
          db.salesOrderItems,
        )..where((i) => i.itemId.equals(sourceItem.itemId))).getSingle();

        expect(openOrders, hasLength(1));
        expect(openOrders.single.orderId, orderId);
        expect(currentItem.quantity, sourceItem.quantity);
      },
    );

    test('close table is rejected while open orders still exist', () async {
      final sessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sessionId,
        tableId: 'TB1',
      );

      final closeRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/TB1/close'),
          body: jsonEncode({}),
          headers: {'content-type': 'application/json'},
        ),
      );
      final closeBody =
          jsonDecode(await closeRes.readAsString()) as Map<String, dynamic>;

      expect(closeRes.statusCode, 409);
      expect(closeBody['success'], isFalse);

      final session = await (db.select(
        db.tableSessions,
      )..where((s) => s.sessionId.equals(sessionId))).getSingle();
      final table = await (db.select(
        db.diningTables,
      )..where((t) => t.tableId.equals('TB1'))).getSingle();

      expect(session.status, 'OPEN');
      expect(table.status, 'OCCUPIED');
    });

    test(
      'seat reservation creates session and updates reservation/table state',
      () async {
        await db
            .into(db.tableReservations)
            .insert(
              TableReservationsCompanion.insert(
                reservationId: 'RES-SEATED',
                branchId: 'BR1',
                customerName: 'Walk-in Reserved',
                reservationTime: DateTime.now(),
                partySize: const Value(4),
                status: const Value('CONFIRMED'),
              ),
            );

        final seatRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/reservations/RES-SEATED/seat'),
            body: jsonEncode({'table_id': 'TB1', 'branch_id': 'BR1'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        final seatBody =
            jsonDecode(await seatRes.readAsString()) as Map<String, dynamic>;

        expect(seatRes.statusCode, 200);
        expect(seatBody['data']['table_id'], 'TB1');

        final reservation = await (db.select(
          db.tableReservations,
        )..where((r) => r.reservationId.equals('RES-SEATED'))).getSingle();
        final session =
            await (db.select(db.tableSessions)
                  ..where((s) => s.sessionId.equals(reservation.sessionId!)))
                .getSingle();
        final table = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();

        expect(reservation.status, 'SEATED');
        expect(session.guestCount, 4);
        expect(table.status, 'OCCUPIED');
      },
    );

    test(
      'void item requires reason and valid manager pin, including held items',
      () async {
        SharedPreferences.setMockInitialValues({'manager_pin': '1234'});

        final sessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        final orderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sessionId,
          tableId: 'TB1',
        );
        final heldItem =
            await (db.select(db.salesOrderItems)..where(
                  (i) => i.orderId.equals(orderId) & i.courseNo.equals(2),
                ))
                .getSingle();

        final missingReasonRes = await kitchenRoutes.router.call(
          Request(
            'PUT',
            Uri.parse('http://localhost/items/${heldItem.itemId}/status'),
            body: jsonEncode({'status': 'CANCELLED', 'manager_pin': '1234'}),
            headers: {'content-type': 'application/json'},
          ),
        );
        expect(missingReasonRes.statusCode, 400);

        final wrongPinRes = await kitchenRoutes.router.call(
          Request(
            'PUT',
            Uri.parse('http://localhost/items/${heldItem.itemId}/status'),
            body: jsonEncode({
              'status': 'CANCELLED',
              'reason': 'ลูกค้าเปลี่ยนใจ',
              'manager_pin': '9999',
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        expect(wrongPinRes.statusCode, 403);

        final okRes = await kitchenRoutes.router.call(
          Request(
            'PUT',
            Uri.parse('http://localhost/items/${heldItem.itemId}/status'),
            body: jsonEncode({
              'status': 'CANCELLED',
              'reason': 'ลูกค้าเปลี่ยนใจ',
              'manager_pin': '1234',
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        final okBody =
            jsonDecode(await okRes.readAsString()) as Map<String, dynamic>;
        expect(okRes.statusCode, 200);
        expect(okBody['data']['reason'], 'ลูกค้าเปลี่ยนใจ');

        final updatedItem = await (db.select(
          db.salesOrderItems,
        )..where((i) => i.itemId.equals(heldItem.itemId))).getSingle();
        expect(updatedItem.kitchenStatus, 'CANCELLED');

        final timelineRes = await tableRoutes.router.call(
          Request('GET', Uri.parse('http://localhost/TB1/timeline')),
        );
        final timelineBody =
            jsonDecode(await timelineRes.readAsString())
                as Map<String, dynamic>;
        final events = (timelineBody['data']['events'] as List)
            .cast<Map<String, dynamic>>();
        expect(
          events.any(
            (event) =>
                event['type'] == 'item_cancelled' &&
                (event['data'] as Map<String, dynamic>)['reason'] ==
                    'ลูกค้าเปลี่ยนใจ',
          ),
          isTrue,
        );
      },
    );

    test('merge table logs merge events to both table timelines', () async {
      final sourceSessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB1',
      );
      final targetSessionId = await _openTableForTest(
        db,
        tableRoutes,
        tableId: 'TB2',
      );
      await _createOpenDineInOrder(
        db,
        salesRoutes,
        sessionId: sourceSessionId,
        tableId: 'TB1',
      );

      final mergeRes = await tableRoutes.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/merge'),
          body: jsonEncode({
            'source_table_id': 'TB1',
            'target_table_id': 'TB2',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(mergeRes.statusCode, 200);

      final sourceTimelineRes = await tableRoutes.router.call(
        Request('GET', Uri.parse('http://localhost/TB1/timeline')),
      );
      final sourceTimelineBody =
          jsonDecode(await sourceTimelineRes.readAsString())
              as Map<String, dynamic>;
      final sourceEvents = (sourceTimelineBody['data']['events'] as List)
          .cast<Map<String, dynamic>>();

      final targetTimelineRes = await tableRoutes.router.call(
        Request('GET', Uri.parse('http://localhost/TB2/timeline')),
      );
      final targetTimelineBody =
          jsonDecode(await targetTimelineRes.readAsString())
              as Map<String, dynamic>;
      final targetEvents = (targetTimelineBody['data']['events'] as List)
          .cast<Map<String, dynamic>>();

      expect(
        sourceEvents.any(
          (event) =>
              event['type'] == 'merge_out' &&
              (event['data'] as Map<String, dynamic>)['target_table_id'] ==
                  'TB2',
        ),
        isTrue,
      );
      expect(
        targetEvents.any(
          (event) =>
              event['type'] == 'merge_in' &&
              (event['data'] as Map<String, dynamic>)['source_table_id'] ==
                  'TB1',
        ),
        isTrue,
      );
      expect(targetTimelineBody['data']['session_id'], equals(targetSessionId));
    });

    test(
      'merge sets target current order when target session had no order yet',
      () async {
        final sourceSessionId = await _openTableForTest(
          db,
          tableRoutes,
          tableId: 'TB1',
        );
        await _openTableForTest(db, tableRoutes, tableId: 'TB3');
        final sourceOrderId = await _createOpenDineInOrder(
          db,
          salesRoutes,
          sessionId: sourceSessionId,
          tableId: 'TB1',
        );

        final mergeRes = await tableRoutes.router.call(
          Request(
            'POST',
            Uri.parse('http://localhost/merge'),
            body: jsonEncode({
              'source_table_id': 'TB1',
              'target_table_id': 'TB3',
            }),
            headers: {'content-type': 'application/json'},
          ),
        );
        expect(mergeRes.statusCode, 200);

        final movedOrder = await (db.select(
          db.salesOrders,
        )..where((o) => o.orderId.equals(sourceOrderId))).getSingle();
        final sourceTable = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB1'))).getSingle();
        final targetTable = await (db.select(
          db.diningTables,
        )..where((t) => t.tableId.equals('TB3'))).getSingle();

        expect(movedOrder.tableId, 'TB3');
        expect(sourceTable.currentOrderId, equals(null));
        expect(targetTable.currentOrderId, sourceOrderId);
      },
    );

    test('reservation list filters by customer name or phone query', () async {
      final now = DateTime.now();
      await db
          .into(db.tableReservations)
          .insert(
            TableReservationsCompanion.insert(
              reservationId: 'RES-SEARCH-1',
              branchId: 'BR1',
              customerName: 'Alice Wonder',
              customerPhone: const Value('0811111111'),
              reservationTime: now,
            ),
          );
      await db
          .into(db.tableReservations)
          .insert(
            TableReservationsCompanion.insert(
              reservationId: 'RES-SEARCH-2',
              branchId: 'BR1',
              customerName: 'Bob Stone',
              customerPhone: const Value('0899999999'),
              reservationTime: now,
            ),
          );

      final byNameRes = await tableRoutes.router.call(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/reservations?branch_id=BR1&date=${_fmtDate(now)}&query=alice',
          ),
        ),
      );
      final byNameBody =
          jsonDecode(await byNameRes.readAsString()) as Map<String, dynamic>;
      final byNameData = (byNameBody['data'] as List)
          .cast<Map<String, dynamic>>();

      final byPhoneRes = await tableRoutes.router.call(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/reservations?branch_id=BR1&date=${_fmtDate(now)}&query=9999',
          ),
        ),
      );
      final byPhoneBody =
          jsonDecode(await byPhoneRes.readAsString()) as Map<String, dynamic>;
      final byPhoneData = (byPhoneBody['data'] as List)
          .cast<Map<String, dynamic>>();

      expect(byNameRes.statusCode, 200);
      expect(byNameData, hasLength(1));
      expect(byNameData.first['customer_name'], 'Alice Wonder');

      expect(byPhoneRes.statusCode, 200);
      expect(byPhoneData, hasLength(1));
      expect(byPhoneData.first['customer_name'], 'Bob Stone');
    });
  });
}

Future<void> _seedBaseData(AppDatabase db) async {
  await db
      .into(db.companies)
      .insert(
        CompaniesCompanion.insert(companyId: 'COMP1', companyName: 'Test Co'),
      );
  await db.batch((batch) {
    batch.insertAll(db.branches, [
      BranchesCompanion.insert(
        branchId: 'BR1',
        companyId: 'COMP1',
        branchCode: 'B01',
        branchName: 'Restaurant 1',
        businessMode: const Value('RESTAURANT'),
      ),
      BranchesCompanion.insert(
        branchId: 'BR2',
        companyId: 'COMP1',
        branchCode: 'B02',
        branchName: 'Restaurant 2',
        businessMode: const Value('RESTAURANT'),
      ),
    ]);
    batch.insertAll(db.warehouses, [
      WarehousesCompanion.insert(
        warehouseId: 'WH1',
        warehouseCode: 'WH1',
        warehouseName: 'Warehouse 1',
        branchId: 'BR1',
      ),
      WarehousesCompanion.insert(
        warehouseId: 'WH2',
        warehouseCode: 'WH2',
        warehouseName: 'Warehouse 2',
        branchId: 'BR2',
      ),
    ]);
  });
  await db
      .into(db.roles)
      .insert(
        RolesCompanion.insert(
          roleId: 'ROLE1',
          roleName: 'Admin',
          permissions: const {'restaurant': true},
        ),
      );
  await db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          userId: 'USR1',
          username: 'admin',
          passwordHash: 'hash',
          fullName: 'Admin',
          roleId: const Value('ROLE1'),
          branchId: const Value('BR1'),
        ),
      );
  await db
      .into(db.productGroups)
      .insert(
        ProductGroupsCompanion.insert(
          groupId: 'PG1',
          groupCode: 'FOOD',
          groupName: 'Food',
        ),
      );
  await db.batch((batch) {
    batch.insertAll(db.products, [
      ProductsCompanion.insert(
        productId: 'P1',
        productCode: 'P1',
        productName: 'Pad Thai',
        baseUnit: 'plate',
        groupId: const Value('PG1'),
        priceLevel1: const Value(120),
        prepStation: const Value('kitchen'),
        requiresPreparation: const Value(true),
        serviceMode: const Value('RESTAURANT'),
        dineInAvailable: const Value(true),
      ),
      ProductsCompanion.insert(
        productId: 'P2',
        productCode: 'P2',
        productName: 'Tom Yum',
        baseUnit: 'bowl',
        groupId: const Value('PG1'),
        priceLevel1: const Value(140),
        prepStation: const Value('kitchen'),
        requiresPreparation: const Value(true),
        serviceMode: const Value('RESTAURANT'),
        dineInAvailable: const Value(true),
      ),
    ]);
    batch.insertAll(db.zones, [
      ZonesCompanion.insert(zoneId: 'ZN1', zoneName: 'Zone 1', branchId: 'BR1'),
      ZonesCompanion.insert(zoneId: 'ZN2', zoneName: 'Zone 2', branchId: 'BR2'),
    ]);
    batch.insertAll(db.diningTables, [
      DiningTablesCompanion.insert(
        tableId: 'TB1',
        tableNo: 'A1',
        zoneId: 'ZN1',
        tableDisplayName: const Value('Table A1'),
      ),
      DiningTablesCompanion.insert(
        tableId: 'TB2',
        tableNo: 'B1',
        zoneId: 'ZN2',
        tableDisplayName: const Value('Table B1'),
      ),
      DiningTablesCompanion.insert(
        tableId: 'TB3',
        tableNo: 'A2',
        zoneId: 'ZN1',
        tableDisplayName: const Value('Table A2'),
      ),
    ]);
    batch.insertAll(db.stockBalances, [
      StockBalancesCompanion.insert(
        stockId: 'SB_P1_WH1',
        productId: 'P1',
        warehouseId: 'WH1',
        quantity: const Value(20),
        avgCost: const Value(60),
        lastCost: const Value(60),
      ),
      StockBalancesCompanion.insert(
        stockId: 'SB_P2_WH1',
        productId: 'P2',
        warehouseId: 'WH1',
        quantity: const Value(20),
        avgCost: const Value(70),
        lastCost: const Value(70),
      ),
    ]);
    batch.insertAll(db.stockMovements, [
      StockMovementsCompanion.insert(
        movementId: 'SM-P1-OPEN',
        movementNo: 'SM-P1-OPEN',
        movementDate: DateTime.now().subtract(const Duration(days: 1)),
        movementType: 'OPENING',
        productId: 'P1',
        warehouseId: 'WH1',
        quantity: 20,
        unitCost: const Value(60),
        userId: 'USR1',
      ),
      StockMovementsCompanion.insert(
        movementId: 'SM-P2-OPEN',
        movementNo: 'SM-P2-OPEN',
        movementDate: DateTime.now().subtract(const Duration(days: 1)),
        movementType: 'OPENING',
        productId: 'P2',
        warehouseId: 'WH1',
        quantity: 20,
        unitCost: const Value(70),
        userId: 'USR1',
      ),
    ]);
  });
}

Future<void> _insertSalesOrder(
  AppDatabase db, {
  required String orderId,
  required String orderNo,
  required String branchId,
  required String warehouseId,
  required String userId,
  String? tableId,
  String? sessionId,
  String? serviceType,
  required String status,
  required DateTime orderDate,
  required String itemId,
  required String productId,
  required String productName,
  required String kitchenStatus,
  DateTime? preparedAt,
}) async {
  await db
      .into(db.salesOrders)
      .insert(
        SalesOrdersCompanion.insert(
          orderId: orderId,
          orderNo: orderNo,
          orderDate: orderDate,
          branchId: branchId,
          warehouseId: warehouseId,
          userId: userId,
          tableId: Value(tableId),
          sessionId: Value(sessionId),
          serviceType: Value(serviceType),
          subtotal: const Value(120),
          totalAmount: const Value(120),
          status: Value(status),
        ),
      );
  await db
      .into(db.salesOrderItems)
      .insert(
        SalesOrderItemsCompanion.insert(
          itemId: itemId,
          orderId: orderId,
          lineNo: 1,
          productId: productId,
          productCode: productId,
          productName: productName,
          unit: 'unit',
          quantity: 1,
          unitPrice: 120,
          amount: 120,
          warehouseId: warehouseId,
          kitchenStatus: Value(kitchenStatus),
          preparedAt: Value(preparedAt),
        ),
      );
}

String _fmtDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Future<Request> _authedJsonRequest(
  AppDatabase db,
  String method,
  String url, {
  Map<String, dynamic>? body,
}) async {
  final user = await (db.select(
    db.users,
  )..where((u) => u.userId.equals('USR1'))).getSingle();
  return Request(
    method,
    Uri.parse(url),
    body: body == null ? '' : jsonEncode(body),
    headers: body == null
        ? const {}
        : const {'content-type': 'application/json'},
    context: {'user': user},
  );
}

Future<String> _openTableForTest(
  AppDatabase db,
  TableRoutes tableRoutes, {
  required String tableId,
}) async {
  final res = await tableRoutes.router.call(
    Request(
      'POST',
      Uri.parse('http://localhost/$tableId/open'),
      body: jsonEncode({
        'guest_count': 2,
        'branch_id': 'BR1',
        'opened_by': 'USR1',
      }),
      headers: {'content-type': 'application/json'},
    ),
  );
  final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  return body['data']['session_id'] as String;
}

Future<String> _createOpenDineInOrder(
  AppDatabase db,
  SalesRoutes salesRoutes, {
  required String sessionId,
  required String tableId,
}) async {
  final res = await salesRoutes.router.call(
    await _authedJsonRequest(
      db,
      'POST',
      'http://localhost/',
      body: {
        'status': 'OPEN',
        'table_id': tableId,
        'session_id': sessionId,
        'service_type': 'DINE_IN',
        'party_size': 2,
        'warehouse_id': 'WH1',
        'subtotal': 260,
        'discount_amount': 0,
        'amount_before_vat': 260,
        'total_amount': 260,
        'payment_type': 'CASH',
        'items': [
          {
            'product_id': 'P1',
            'product_code': 'P1',
            'product_name': 'Pad Thai',
            'unit': 'plate',
            'quantity': 1,
            'unit_price': 120,
            'amount': 120,
            'course_no': 1,
          },
          {
            'product_id': 'P2',
            'product_code': 'P2',
            'product_name': 'Tom Yum',
            'unit': 'bowl',
            'quantity': 1,
            'unit_price': 140,
            'amount': 140,
            'course_no': 2,
          },
        ],
      },
    ),
  );
  final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  return body['data']['order_id'] as String;
}
