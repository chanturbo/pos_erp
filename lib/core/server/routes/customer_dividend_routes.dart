// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/app_database.dart';

class CustomerDividendRoutes {
  final AppDatabase db;

  CustomerDividendRoutes(this.db);

  Router get router {
    final router = Router();
    router.get('/', _getRunsHandler);
    router.get('/<id>', _getRunHandler);
    router.post('/', _createRunHandler);
    router.put('/<id>/status', _updateRunStatusHandler);
    router.put('/<id>/bulk-payment-status', _bulkUpdateItemStatusHandler);
    router.put('/<id>/items/<itemId>/payment-status', _updateItemStatusHandler);
    return router;
  }

  Future<Response> _getRunsHandler(Request request) async {
    try {
      final results = await db.customSelect('''
        SELECT
          r.run_id,
          r.run_no,
          r.period_start,
          r.period_end,
          r.dividend_percent,
          r.total_customers,
          r.total_dividend_base,
          r.total_dividend_amount,
          r.status,
          r.remark,
          r.created_by,
          r.created_at,
          r.updated_at,
          r.paid_at,
          COALESCE(SUM(COALESCE(i.paid_amount_actual, 0)), 0) AS actual_paid_total,
          COALESCE(SUM(CASE WHEN i.payment_status = 'PAID' THEN 1 ELSE 0 END), 0) AS paid_count,
          COALESCE(SUM(CASE WHEN i.payment_status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_count,
          COALESCE(SUM(CASE WHEN i.payment_status = 'SKIPPED' THEN 1 ELSE 0 END), 0) AS skipped_count
        FROM customer_dividend_runs r
        LEFT JOIN customer_dividend_run_items i ON i.run_id = r.run_id
        GROUP BY r.run_id
        ORDER BY COALESCE(r.period_end, r.created_at) DESC, r.created_at DESC
      ''').get();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': results.map((r) => _runRowToJson(r)).toList(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _getRunHandler(Request request, String id) async {
    try {
      final header = await db.customSelect('''
        SELECT
          r.run_id,
          r.run_no,
          r.period_start,
          r.period_end,
          r.dividend_percent,
          r.total_customers,
          r.total_dividend_base,
          r.total_dividend_amount,
          r.status,
          r.remark,
          r.created_by,
          r.created_at,
          r.updated_at,
          r.paid_at,
          COALESCE(SUM(COALESCE(i.paid_amount_actual, 0)), 0) AS actual_paid_total,
          COALESCE(SUM(CASE WHEN i.payment_status = 'PAID' THEN 1 ELSE 0 END), 0) AS paid_count,
          COALESCE(SUM(CASE WHEN i.payment_status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_count,
          COALESCE(SUM(CASE WHEN i.payment_status = 'SKIPPED' THEN 1 ELSE 0 END), 0) AS skipped_count
        FROM customer_dividend_runs r
        LEFT JOIN customer_dividend_run_items i ON i.run_id = r.run_id
        WHERE r.run_id = ?
        GROUP BY r.run_id
      ''', variables: [Variable.withString(id)]).getSingleOrNull();

      if (header == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Run not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final items = await db.customSelect('''
        SELECT
          item_id,
          run_id,
          customer_id,
          customer_name,
          order_count,
          paid_amount,
          credit_amount,
          dividend_base,
          dividend_percent,
          dividend_amount,
          payment_status,
          paid_amount_actual,
          paid_at,
          note,
          created_at,
          updated_at
        FROM customer_dividend_run_items
        WHERE run_id = ?
        ORDER BY dividend_amount DESC, customer_name ASC
      ''', variables: [Variable.withString(id)]).get();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            ..._runRowToJson(header),
            'items': items.map(_itemRowToJson).toList(),
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _createRunHandler(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final items = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (items.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'items ต้องมีอย่างน้อย 1 รายการ'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final runId = 'CDRUN${DateTime.now().millisecondsSinceEpoch}';
      final runNo = data['run_no'] as String? ?? 'CD-${DateTime.now().millisecondsSinceEpoch}';
      final periodStart = data['period_start'] as String?;
      final periodEnd = data['period_end'] as String?;
      final dividendPercent = (data['dividend_percent'] as num?)?.toDouble() ?? 0;
      final remark = data['remark'] as String?;
      final createdBy = data['created_by'] as String?;
      final totalCustomers = items.length;
      final totalDividendBase = items.fold<double>(
        0,
        (s, i) => s + ((i['dividend_base'] as num?)?.toDouble() ?? 0),
      );
      final totalDividendAmount = items.fold<double>(
        0,
        (s, i) => s + ((i['dividend_amount'] as num?)?.toDouble() ?? 0),
      );
      final now = DateTime.now().toIso8601String();
      final customerIds = items
          .map((item) => item['customer_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (customerIds.isNotEmpty) {
        final placeholders = List.filled(customerIds.length, '?').join(', ');
        final duplicated = await db.customSelect(
          '''
          SELECT DISTINCT i.customer_id, i.customer_name, r.run_no
          FROM customer_dividend_run_items i
          INNER JOIN customer_dividend_runs r ON r.run_id = i.run_id
          WHERE r.status != 'CANCELLED'
            AND COALESCE(r.period_start, '') = COALESCE(?, '')
            AND COALESCE(r.period_end, '') = COALESCE(?, '')
            AND ABS(COALESCE(r.dividend_percent, 0) - ?) < 0.0001
            AND i.customer_id IN ($placeholders)
          ''',
          variables: [
            Variable.withString(periodStart ?? ''),
            Variable.withString(periodEnd ?? ''),
            Variable.withReal(dividendPercent),
            ...customerIds.map(Variable.withString),
          ],
        ).get();

        if (duplicated.isNotEmpty) {
          final labels = duplicated
              .map((row) {
                final name = row.read<String>('customer_name');
                final runNo = row.read<String>('run_no');
                return '$name ($runNo)';
              })
              .join(', ');
          return Response(
            409,
            body: jsonEncode({
              'success': false,
              'message': 'มีลูกค้าบางรายการถูกบันทึกงวดแล้ว: $labels',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      await db.transaction(() async {
        await db.customStatement(
          '''
          INSERT INTO customer_dividend_runs (
            run_id, run_no, period_start, period_end, dividend_percent,
            total_customers, total_dividend_base, total_dividend_amount,
            status, remark, created_by, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', ?, ?, ?, ?)
          ''',
          [
            runId,
            runNo,
            periodStart,
            periodEnd,
            dividendPercent,
            totalCustomers,
            totalDividendBase,
            totalDividendAmount,
            remark,
            createdBy,
            now,
            now,
          ],
        );

        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          await db.customStatement(
            '''
            INSERT INTO customer_dividend_run_items (
              item_id, run_id, customer_id, customer_name, order_count,
              paid_amount, credit_amount, dividend_base, dividend_percent,
              dividend_amount, payment_status, paid_amount_actual, note,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', 0, ?, ?, ?)
            ''',
            [
              'CDITEM${DateTime.now().millisecondsSinceEpoch}$i',
              runId,
              item['customer_id'] as String? ?? '',
              item['customer_name'] as String? ?? '-',
              (item['order_count'] as num?)?.toInt() ?? 0,
              (item['paid_amount'] as num?)?.toDouble() ?? 0,
              (item['credit_amount'] as num?)?.toDouble() ?? 0,
              (item['dividend_base'] as num?)?.toDouble() ?? 0,
              (item['dividend_percent'] as num?)?.toDouble() ?? dividendPercent,
              (item['dividend_amount'] as num?)?.toDouble() ?? 0,
              item['note'] as String?,
              now,
              now,
            ],
          );
        }
      });

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Dividend run created',
          'data': {'run_id': runId, 'run_no': runNo},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _updateRunStatusHandler(Request request, String id) async {
    try {
      final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = (data['status'] as String? ?? 'DRAFT').toUpperCase();
      final now = DateTime.now().toIso8601String();
      final paidAt = status == 'PAID' ? now : null;

      await db.customStatement(
        '''
        UPDATE customer_dividend_runs
        SET status = ?, paid_at = COALESCE(?, paid_at), updated_at = ?
        WHERE run_id = ?
        ''',
        [status, paidAt, now, id],
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Run status updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _updateItemStatusHandler(
    Request request,
    String id,
    String itemId,
  ) async {
    try {
      final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final paymentStatus = (data['payment_status'] as String? ?? 'PENDING').toUpperCase();
      final paidAmountActual = (data['paid_amount_actual'] as num?)?.toDouble() ?? 0;
      final note = data['note'] as String?;
      final now = DateTime.now().toIso8601String();
      final paidAt = paymentStatus == 'PAID' ? now : null;

      await db.transaction(() async {
        await db.customStatement(
          '''
          UPDATE customer_dividend_run_items
          SET payment_status = ?,
              paid_amount_actual = ?,
              paid_at = ?,
              note = ?,
              updated_at = ?
          WHERE run_id = ? AND item_id = ?
          ''',
          [paymentStatus, paidAmountActual, paidAt, note, now, id, itemId],
        );

        await _refreshRunStatus(id, now);
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Item status updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _bulkUpdateItemStatusHandler(
    Request request,
    String id,
  ) async {
    try {
      final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final paymentStatus =
          (data['payment_status'] as String? ?? 'PENDING').toUpperCase();
      final now = DateTime.now().toIso8601String();

      await db.transaction(() async {
        if (paymentStatus == 'PAID') {
          await db.customStatement(
            '''
            UPDATE customer_dividend_run_items
            SET payment_status = 'PAID',
                paid_amount_actual = dividend_amount,
                paid_at = ?,
                updated_at = ?
            WHERE run_id = ?
            ''',
            [now, now, id],
          );
        } else {
          await db.customStatement(
            '''
            UPDATE customer_dividend_run_items
            SET payment_status = ?,
                paid_amount_actual = 0,
                paid_at = NULL,
                updated_at = ?
            WHERE run_id = ?
            ''',
            [paymentStatus, now, id],
          );
        }

        await _refreshRunStatus(id, now);
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Bulk status updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _error(e);
    }
  }

  Map<String, dynamic> _runRowToJson(QueryRow r) {
    final paidCount = r.read<int>('paid_count');
    final pendingCount = r.read<int>('pending_count');
    final skippedCount = r.read<int>('skipped_count');
    final storedStatus = r.read<String>('status');

    return {
      'run_id': r.read<String>('run_id'),
      'run_no': r.read<String>('run_no'),
      'period_start': r.readNullable<String>('period_start'),
      'period_end': r.readNullable<String>('period_end'),
      'dividend_percent': r.read<double>('dividend_percent'),
      'total_customers': r.read<int>('total_customers'),
      'total_dividend_base': r.read<double>('total_dividend_base'),
      'total_dividend_amount': r.read<double>('total_dividend_amount'),
      'status': _deriveRunStatus(
        storedStatus: storedStatus,
        paidCount: paidCount,
        pendingCount: pendingCount,
        skippedCount: skippedCount,
      ),
      'remark': r.readNullable<String>('remark'),
      'created_by': r.readNullable<String>('created_by'),
      'created_at': r.readNullable<String>('created_at'),
      'updated_at': r.readNullable<String>('updated_at'),
      'paid_at': r.readNullable<String>('paid_at'),
      'actual_paid_total': r.read<double>('actual_paid_total'),
      'paid_count': paidCount,
      'pending_count': pendingCount,
      'skipped_count': skippedCount,
    };
  }

  Map<String, dynamic> _itemRowToJson(QueryRow r) => {
        'item_id': r.read<String>('item_id'),
        'run_id': r.read<String>('run_id'),
        'customer_id': r.read<String>('customer_id'),
        'customer_name': r.read<String>('customer_name'),
        'order_count': r.read<int>('order_count'),
        'paid_amount': r.read<double>('paid_amount'),
        'credit_amount': r.read<double>('credit_amount'),
        'dividend_base': r.read<double>('dividend_base'),
        'dividend_percent': r.read<double>('dividend_percent'),
        'dividend_amount': r.read<double>('dividend_amount'),
        'payment_status': r.read<String>('payment_status'),
        'paid_amount_actual': r.read<double>('paid_amount_actual'),
        'paid_at': r.readNullable<String>('paid_at'),
        'note': r.readNullable<String>('note'),
        'created_at': r.readNullable<String>('created_at'),
        'updated_at': r.readNullable<String>('updated_at'),
      };

  String _deriveRunStatus({
    required String storedStatus,
    required int paidCount,
    required int pendingCount,
    required int skippedCount,
  }) {
    if (storedStatus.toUpperCase() == 'CANCELLED') {
      return 'CANCELLED';
    }
    if (paidCount > 0 && pendingCount == 0 && skippedCount == 0) {
      return 'PAID';
    }
    if (paidCount > 0 || skippedCount > 0) {
      return 'PARTIAL';
    }
    return 'DRAFT';
  }

  Future<void> _refreshRunStatus(String runId, String now) async {
    final statusRow = await db.customSelect('''
      SELECT
        COALESCE(SUM(CASE WHEN payment_status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE WHEN payment_status = 'PAID' THEN 1 ELSE 0 END), 0) AS paid_count,
        COALESCE(SUM(CASE WHEN payment_status = 'SKIPPED' THEN 1 ELSE 0 END), 0) AS skipped_count
      FROM customer_dividend_run_items
      WHERE run_id = ?
    ''', variables: [Variable.withString(runId)]).getSingle();

    final pendingCount = statusRow.read<int>('pending_count');
    final paidCount = statusRow.read<int>('paid_count');
    final skippedCount = statusRow.read<int>('skipped_count');
    String nextStatus = 'DRAFT';
    String? nextPaidAt;

    // PAID ต้องหมายถึงทุกรายการถูกจ่ายครบจริง ๆ เท่านั้น
    if (paidCount > 0 && pendingCount == 0 && skippedCount == 0) {
      nextStatus = 'PAID';
      nextPaidAt = now;
    } else if (paidCount > 0 || skippedCount > 0) {
      // มีการดำเนินการบางส่วนแล้ว ไม่ว่าจะเป็นจ่ายแล้วหรือข้ามจ่าย
      // แต่ยังไม่ใช่การจ่ายครบทั้งหมด ให้เป็น PARTIAL
      nextStatus = 'PARTIAL';
    }

    await db.customStatement(
      '''
      UPDATE customer_dividend_runs
      SET status = ?, paid_at = ?, updated_at = ?
      WHERE run_id = ?
      ''',
      [nextStatus, nextPaidAt, now, runId],
    );
  }

  Response _error(Object e) => Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
}
