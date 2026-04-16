// ignore_for_file: avoid_print
// report_routes.dart — Week 6: Full Reporting
// Sales / Purchase / Inventory / Financial Reports

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:intl/intl.dart';
import '../../database/app_database.dart';

class ReportRoutes {
  final AppDatabase db;

  ReportRoutes(this.db);

  Router get router {
    final router = Router();

    // ── Sales Reports ────────────────────────────────────────────
    router.get('/sales-summary', _getSalesSummaryHandler);
    router.get('/sales-daily', _getSalesDailyHandler);
    router.get('/top-products', _getTopProductsHandler);
    router.get('/top-customers', _getTopCustomersHandler);
    router.get('/sales-by-customer', _getSalesByCustomerHandler);
    router.get('/customer-dividend-summary', _getCustomerDividendSummaryHandler);
    router.get('/sales-by-payment', _getSalesByPaymentHandler);
    router.get('/sales-by-category', _getSalesByCategoryHandler);
    router.get('/sales-by-period', _getSalesByPeriodHandler);

    // ── Purchase Reports ─────────────────────────────────────────
    router.get('/purchase-summary', _getPurchaseSummaryHandler); // 🆕
    router.get('/purchase-by-supplier', _getPurchaseBySupplierHandler); // 🆕
    router.get('/purchase-by-category', _getPurchaseByCategoryHandler); // 🆕

    // ── Inventory Reports ────────────────────────────────────────
    router.get('/stock-movement', _getStockMovementHandler); // 🆕
    router.get('/low-stock', _getLowStockHandler); // 🆕
    router.get('/stock-aging', _getStockAgingHandler); // 🆕

    // ── Financial Reports ────────────────────────────────────────
    router.get('/profit-loss', _getProfitLossHandler); // 🆕
    router.get('/ar-aging', _getArAgingHandler); // 🆕
    router.get('/ap-aging', _getApAgingHandler); // 🆕
    router.get('/cash-flow', _getCashFlowHandler); // 🆕

    return router;
  }

  // ═══════════════════════════════════════════════════════════════
  // SALES REPORTS
  // ═══════════════════════════════════════════════════════════════

  Future<Response> _getSalesSummaryHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];

      String where = '';
      List<Variable> vars = [];
      if (startDate != null && endDate != null) {
        where = "WHERE DATE(order_date) BETWEEN ? AND ?";
        vars = [Variable.withString(startDate), Variable.withString(endDate)];
      }

      final result = await db.customSelect('''
        SELECT
          COUNT(*) as total_orders,
          COALESCE(SUM(total_amount), 0) as total_sales,
          COALESCE(AVG(total_amount), 0) as avg_order_value,
          COALESCE(SUM(discount_amount), 0) as total_discount
        FROM sales_orders $where
      ''', variables: vars).getSingle();

      return _ok({
        'total_orders': result.read<int>('total_orders'),
        'total_sales': result.read<double>('total_sales'),
        'avg_order_value': result.read<double>('avg_order_value'),
        'total_discount': result.read<double>('total_discount'),
      });
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getSalesDailyHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDateParam = p['start_date'];
      final endDateParam = p['end_date'];
      final days = int.tryParse(p['days'] ?? '30') ?? 30;

      final now = DateTime.now();
      final startDate = startDateParam != null
          ? DateTime.parse(startDateParam)
          : DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: days - 1));
      final endDate = endDateParam != null
          ? DateTime.parse(endDateParam)
          : DateTime(now.year, now.month, now.day);
      final endExclusive = DateTime(
        endDate.year,
        endDate.month,
        endDate.day + 1,
      );

      final orders =
          await (db.select(db.salesOrders)..where(
                (t) =>
                    t.orderDate.isBiggerOrEqualValue(startDate) &
                    t.orderDate.isSmallerThanValue(endExclusive),
              ))
              .get();

      final grouped = <String, Map<String, dynamic>>{};
      for (final order in orders) {
        final key = DateFormat('yyyy-MM-dd').format(order.orderDate);
        final bucket = grouped.putIfAbsent(
          key,
          () => {'date': key, 'orders': 0, 'sales': 0.0, 'discount': 0.0},
        );
        bucket['orders'] = (bucket['orders'] as int) + 1;
        bucket['sales'] = (bucket['sales'] as double) + order.totalAmount;
        bucket['discount'] =
            (bucket['discount'] as double) + order.discountAmount;
      }

      final results = grouped.values.toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      return _okList(results.cast<Map<String, dynamic>>());
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getTopProductsHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final limit = int.tryParse(p['limit'] ?? '10') ?? 10;
      final startDate = p['start_date'];
      final endDate = p['end_date'];

      String where = '';
      List<Variable> vars = [];
      if (startDate != null && endDate != null) {
        where = "WHERE DATE(so.order_date) BETWEEN ? AND ?";
        vars = [Variable.withString(startDate), Variable.withString(endDate)];
      }

      final results = await db.customSelect('''
        SELECT
          soi.product_id,
          soi.product_code,
          soi.product_name,
          SUM(soi.quantity) as total_quantity,
          SUM(soi.amount) as total_sales,
          COUNT(DISTINCT so.order_id) as order_count
        FROM sales_order_items soi
        JOIN sales_orders so ON soi.order_id = so.order_id
        $where
        GROUP BY soi.product_id
        ORDER BY total_sales DESC
        LIMIT $limit
      ''', variables: vars).get();

      return _okList(
        results.map(
          (r) => {
            'product_id': r.read<String>('product_id'),
            'product_code': r.read<String>('product_code'),
            'product_name': r.read<String>('product_name'),
            'total_quantity': r.read<double>('total_quantity'),
            'total_sales': r.read<double>('total_sales'),
            'order_count': r.read<int>('order_count'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getTopCustomersHandler(Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;
      final results = await db.customSelect('''
        SELECT
          customer_id,
          customer_name,
          COUNT(*) as order_count,
          SUM(total_amount) as total_sales
        FROM sales_orders
        WHERE customer_id IS NOT NULL AND customer_id != 'WALK_IN'
        GROUP BY customer_id
        ORDER BY total_sales DESC
        LIMIT $limit
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'customer_id': r.read<String>('customer_id'),
            'customer_name': r.read<String>('customer_name'),
            'order_count': r.read<int>('order_count'),
            'total_sales': r.read<double>('total_sales'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getSalesByCustomerHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];
      // ใช้ alias so. เพื่อกันชนกับ subquery ar_invoices
      final dateFilter = _dateBetweenClause(
        column: 'so.order_date',
        startDate: startDate,
        endDate: endDate,
      );

      // กรอง COMPLETED เท่านั้น — ตัด CANCELLED และ OPEN ออกจากรายงาน
      // กรอง COMPLETED เท่านั้น — ตัด CANCELLED และ OPEN ออกจากรายงาน
      const statusFilter =
          "so.status = 'COMPLETED' AND so.customer_id IS NOT NULL AND so.customer_id != 'WALK_IN'";
      final whereBase = dateFilter.clause.isEmpty
          ? "WHERE $statusFilter"
          : "${dateFilter.clause} AND $statusFilter";

      // paid_amount  = (1) ยอดขายสด (non-CREDIT, COMPLETED) ในช่วงเวลา
      //               + (2) ยอดที่รับกลับมาแล้วผ่าน AR Invoice (paid_amount)
      //   → รวม case ที่ลูกค้าซื้อเชื่อแล้วจ่ายกลับจนหมด — ไม่หายไป
      // credit_amount = ยอดคงค้างใน AR Invoices ที่ยังไม่ PAID/CANCELLED (ทุก order)
      // กรอง status = 'COMPLETED' เท่านั้น — ตัด CANCELLED และ OPEN ออก
      final results = await db.customSelect('''
        SELECT
          so.customer_id,
          MAX(so.customer_name)  AS customer_name,
          COUNT(*)               AS order_count,
          COALESCE(SUM(so.total_amount), 0) AS total_amount,
          COALESCE(SUM(CASE WHEN so.payment_type != 'CREDIT'
                            THEN so.total_amount ELSE 0 END), 0)
            + COALESCE(ar.ar_received, 0)  AS paid_amount,
          COALESCE(ar.outstanding_amount, 0) AS credit_amount,
          MAX(so.order_date)     AS last_order_date
        FROM sales_orders so
        LEFT JOIN (
          -- ar_received    = ยอดที่ลูกค้าจ่ายกลับมาแล้วทั้งหมด (จาก AR Invoice paid_amount)
          -- outstanding    = ยอดที่ยังค้างอยู่ (total - paid, เฉพาะ UNPAID/PARTIAL)
          SELECT customer_id,
                 SUM(COALESCE(paid_amount, 0))                        AS ar_received,
                 SUM(CASE WHEN status NOT IN ('PAID','CANCELLED')
                          THEN total_amount - COALESCE(paid_amount, 0)
                          ELSE 0 END)                                  AS outstanding_amount
          FROM   ar_invoices
          WHERE  status != 'CANCELLED'
          GROUP  BY customer_id
        ) ar ON ar.customer_id = so.customer_id
        $whereBase
        GROUP BY so.customer_id
        ORDER BY paid_amount DESC
      ''', variables: dateFilter.variables).get();

      return _okList(
        results.map((r) => {
          'customer_id': r.read<String>('customer_id'),
          'customer_name': r.read<String>('customer_name'),
          'order_count': r.read<int>('order_count'),
          'total_amount': r.read<double>('total_amount'),
          'paid_amount': r.read<double>('paid_amount'),
          'credit_amount': r.read<double>('credit_amount'),
          'last_order_date':
              r.readNullable<DateTime>('last_order_date')?.toIso8601String(),
        }),
      );
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getCustomerDividendSummaryHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];
      final rawPercent = double.tryParse(p['dividend_percent'] ?? '') ?? 0;
      final dividendPercent = rawPercent < 0 ? 0.0 : rawPercent;
      final dateFilter = _dateBetweenClause(
        column: 'so.order_date',
        startDate: startDate,
        endDate: endDate,
      );

      const statusFilter =
          "so.status = 'COMPLETED' AND so.customer_id IS NOT NULL AND so.customer_id != 'WALK_IN'";
      final whereBase = dateFilter.clause.isEmpty
          ? "WHERE $statusFilter"
          : "${dateFilter.clause} AND $statusFilter";

      final results = await db.customSelect('''
        SELECT
          so.customer_id,
          MAX(so.customer_name)  AS customer_name,
          COUNT(*)               AS order_count,
          COALESCE(SUM(so.total_amount), 0) AS total_amount,
          COALESCE(SUM(CASE WHEN so.payment_type != 'CREDIT'
                            THEN so.total_amount ELSE 0 END), 0)
            + COALESCE(ar.ar_received, 0)  AS paid_amount,
          COALESCE(ar.outstanding_amount, 0) AS credit_amount,
          MAX(so.order_date)     AS last_order_date
        FROM sales_orders so
        LEFT JOIN (
          SELECT customer_id,
                 SUM(COALESCE(paid_amount, 0))                        AS ar_received,
                 SUM(CASE WHEN status NOT IN ('PAID','CANCELLED')
                          THEN total_amount - COALESCE(paid_amount, 0)
                          ELSE 0 END)                                  AS outstanding_amount
          FROM   ar_invoices
          WHERE  status != 'CANCELLED'
          GROUP  BY customer_id
        ) ar ON ar.customer_id = so.customer_id
        $whereBase
        GROUP BY so.customer_id
        ORDER BY paid_amount DESC
      ''', variables: dateFilter.variables).get();

      String? periodStartIso;
      String? periodEndIso;
      if (startDate != null && startDate.isNotEmpty) {
        periodStartIso = DateTime.parse(startDate).toIso8601String();
      }
      if (endDate != null && endDate.isNotEmpty) {
        final end = DateTime.parse(endDate);
        periodEndIso = DateTime(end.year, end.month, end.day).toIso8601String();
      }

      final savedRows = await db.customSelect(
        '''
        SELECT
          i.customer_id,
          r.run_id,
          r.run_no
        FROM customer_dividend_run_items i
        INNER JOIN customer_dividend_runs r ON r.run_id = i.run_id
        WHERE r.status != 'CANCELLED'
          AND ABS(COALESCE(r.dividend_percent, 0) - ?) < 0.0001
          AND (? = '' OR r.period_start IS NULL OR r.period_start <= ?)
          AND (? = '' OR r.period_end IS NULL OR r.period_end >= ?)
        ORDER BY COALESCE(r.updated_at, r.created_at) DESC
        ''',
        variables: [
          Variable.withReal(dividendPercent),
          Variable.withString(periodEndIso ?? ''),
          Variable.withString(periodEndIso ?? ''),
          Variable.withString(periodStartIso ?? ''),
          Variable.withString(periodStartIso ?? ''),
        ],
      ).get();

      final savedMap = <String, Map<String, String?>>{};
      for (final row in savedRows) {
        final customerId = row.read<String>('customer_id');
        savedMap.putIfAbsent(customerId, () {
          return {
            'run_id': row.read<String>('run_id'),
            'run_no': row.read<String>('run_no'),
          };
        });
      }

      return _okList(
        results.map((r) {
          final paidAmount = r.read<double>('paid_amount');
          final dividendBase = paidAmount;
          final dividendAmount = dividendBase * dividendPercent / 100;
          final customerId = r.read<String>('customer_id');
          final saved = savedMap[customerId];
          return {
            'customer_id': customerId,
            'customer_name': r.read<String>('customer_name'),
            'order_count': r.read<int>('order_count'),
            'total_amount': r.read<double>('total_amount'),
            'paid_amount': paidAmount,
            'credit_amount': r.read<double>('credit_amount'),
            'dividend_percent': dividendPercent,
            'dividend_base': dividendBase,
            'dividend_amount': dividendAmount,
            'last_order_date':
                r.readNullable<DateTime>('last_order_date')?.toIso8601String(),
            'saved_run_id': saved?['run_id'],
            'saved_run_no': saved?['run_no'],
          };
        }),
      );
    } catch (e) {
      return _err(e);
    }
  }


  Future<Response> _getSalesByPaymentHandler(Request request) async {
    try {
      final results = await db.customSelect('''
        SELECT
          payment_type,
          COUNT(*) as count,
          SUM(total_amount) as total
        FROM sales_orders
        GROUP BY payment_type
        ORDER BY total DESC
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'payment_type': r.read<String>('payment_type'),
            'count': r.read<int>('count'),
            'total': r.read<double>('total'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 ยอดขายตามหมวดหมู่สินค้า
  Future<Response> _getSalesByCategoryHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];

      String where = '';
      List<Variable> vars = [];
      if (startDate != null && endDate != null) {
        where = "WHERE DATE(so.order_date) BETWEEN ? AND ?";
        vars = [Variable.withString(startDate), Variable.withString(endDate)];
      }

      final results = await db.customSelect('''
        SELECT
          COALESCE(pr.group_id, 'ไม่มีหมวดหมู่') as category,
          COUNT(DISTINCT so.order_id) as order_count,
          SUM(soi.quantity) as total_qty,
          SUM(soi.amount) as total_sales
        FROM sales_order_items soi
        JOIN sales_orders so ON soi.order_id = so.order_id
        LEFT JOIN products pr ON soi.product_id = pr.product_id
        $where
        GROUP BY pr.group_id
        ORDER BY total_sales DESC
      ''', variables: vars).get();

      return _okList(
        results.map(
          (r) => {
            'category': r.read<String>('category'),
            'order_count': r.read<int>('order_count'),
            'total_qty': r.read<double>('total_qty'),
            'total_sales': r.read<double>('total_sales'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 ยอดขายตามช่วงเวลา (รายสัปดาห์ / รายเดือน)
  Future<Response> _getSalesByPeriodHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      // period: week | month | year
      final period = p['period'] ?? 'month';
      final year = p['year'] ?? DateTime.now().year.toString();

      String groupBy;
      String selectDate;
      switch (period) {
        case 'week':
          groupBy = "strftime('%Y-W%W', order_date)";
          selectDate = groupBy;
          break;
        case 'year':
          groupBy = "strftime('%Y', order_date)";
          selectDate = groupBy;
          break;
        default: // month
          groupBy = "strftime('%Y-%m', order_date)";
          selectDate = groupBy;
      }

      final results = await db.customSelect('''
        SELECT
          $selectDate as period,
          COUNT(*) as orders,
          COALESCE(SUM(total_amount), 0) as sales,
          COALESCE(SUM(discount_amount), 0) as discount
        FROM sales_orders
        WHERE strftime('%Y', order_date) = '$year'
        GROUP BY $groupBy
        ORDER BY period ASC
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'period': r.read<String>('period'),
            'orders': r.read<int>('orders'),
            'sales': r.read<double>('sales'),
            'discount': r.read<double>('discount'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PURCHASE REPORTS
  // ═══════════════════════════════════════════════════════════════

  // 🆕 สรุปการซื้อ
  Future<Response> _getPurchaseSummaryHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];

      String where = '';
      String invoiceWhere = '';
      List<Variable> vars = [];
      if (startDate != null && endDate != null) {
        where = "WHERE DATE(order_date) BETWEEN ? AND ?";
        invoiceWhere = "WHERE DATE(invoice_date) BETWEEN ? AND ?";
        vars = [Variable.withString(startDate), Variable.withString(endDate)];
      }

      final poResult = await db.customSelect('''
        SELECT
          COUNT(*) as total_po,
          COALESCE(SUM(total_amount), 0) as total_amount
        FROM purchase_orders $where
      ''', variables: vars).getSingle();

      final grResult = await db.customSelect('''
        SELECT COUNT(*) as total_gr
        FROM goods_receipts
        ${where.isNotEmpty ? where.replaceAll('order_date', 'receipt_date') : ''}
      ''', variables: vars).getSingle();

      final apResult = await db.customSelect('''
        SELECT
          COALESCE(
            SUM(
              CASE
                WHEN status != 'CANCELLED' THEN COALESCE(paid_amount, 0)
                ELSE 0
              END
            ),
            0
          ) as total_paid,
          COALESCE(
            SUM(
              CASE
                WHEN status != 'CANCELLED'
                THEN COALESCE(total_amount, 0) - COALESCE(paid_amount, 0)
                ELSE 0
              END
            ),
            0
          ) as total_outstanding
        FROM ap_invoices
        $invoiceWhere
      ''', variables: vars).getSingle();

      return _ok({
        'total_po': poResult.read<int>('total_po'),
        'total_po_amount': poResult.read<double>('total_amount'),
        'total_gr': grResult.read<int>('total_gr'),
        'total_paid': apResult.read<double>('total_paid'),
        'total_outstanding': apResult.read<double>('total_outstanding'),
      });
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 ยอดซื้อตามซัพพลายเออร์
  Future<Response> _getPurchaseBySupplierHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final limit = int.tryParse(p['limit'] ?? '10') ?? 10;

      final results = await db.customSelect('''
        SELECT
          supplier_id,
          supplier_name,
          COUNT(*) as po_count,
          SUM(total_amount) as total_amount
        FROM purchase_orders
        GROUP BY supplier_id
        ORDER BY total_amount DESC
        LIMIT $limit
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'supplier_id': r.read<String>('supplier_id'),
            'supplier_name': r.read<String>('supplier_name'),
            'po_count': r.read<int>('po_count'),
            'total_amount': r.read<double>('total_amount'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 ยอดซื้อตามหมวดหมู่
  Future<Response> _getPurchaseByCategoryHandler(Request request) async {
    try {
      final results = await db.customSelect('''
        SELECT
          COALESCE(pr.group_id, 'ไม่มีหมวดหมู่') as category,
          SUM(poi.quantity) as total_qty,
          SUM(poi.amount) as total_amount
        FROM purchase_order_items poi
        LEFT JOIN products pr ON poi.product_id = pr.product_id
        GROUP BY pr.group_id
        ORDER BY total_amount DESC
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'category': r.read<String>('category'),
            'total_qty': r.read<double>('total_qty'),
            'total_amount': r.read<double>('total_amount'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // INVENTORY REPORTS
  // ═══════════════════════════════════════════════════════════════

  // 🆕 รายงานความเคลื่อนไหวสต๊อก
  Future<Response> _getStockMovementHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final productId = p['product_id'];
      final days = int.tryParse(p['days'] ?? '30') ?? 30;

      String where = "WHERE sm.created_at >= DATE('now', '-$days days')";
      List<Variable> vars = [];
      if (productId != null) {
        where += ' AND sm.product_id = ?';
        vars.add(Variable.withString(productId));
      }

      final results = await db.customSelect('''
        SELECT
          sm.product_id,
          sm.product_name,
          sm.movement_type,
          sm.quantity,
          sm.balance_after,
          sm.reference_type,
          sm.reference_id,
          sm.remark,
          sm.created_at
        FROM stock_movements sm
        $where
        ORDER BY sm.created_at DESC
        LIMIT 200
      ''', variables: vars).get();

      return _okList(
        results.map(
          (r) => {
            'product_id': r.read<String>('product_id'),
            'product_name': r.read<String>('product_name'),
            'movement_type': r.read<String>('movement_type'),
            'quantity': r.read<double>('quantity'),
            'balance_after': r.read<double>('balance_after'),
            'reference_type': r.readNullable<String>('reference_type'),
            'reference_id': r.readNullable<String>('reference_id'),
            'remark': r.readNullable<String>('remark'),
            'created_at': r.read<DateTime>('created_at').toIso8601String(),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 สินค้าใกล้หมด (Low Stock Alert)
  Future<Response> _getLowStockHandler(Request request) async {
    try {
      final threshold =
          double.tryParse(request.url.queryParameters['threshold'] ?? '10') ??
          10;

      final results = await db.customSelect('''
        SELECT
          pr.product_id,
          pr.product_code,
          pr.product_name,
          pr.base_unit,
          COALESCE(SUM(sm.quantity), 0) as current_stock,
          COALESCE(pr.price_level1, 0) as unit_price
        FROM products pr
        LEFT JOIN stock_movements sm ON sm.product_id = pr.product_id
        WHERE pr.is_stock_control = 1
          AND pr.is_active = 1
        GROUP BY pr.product_id
        HAVING current_stock <= $threshold
        ORDER BY current_stock ASC
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'product_id': r.read<String>('product_id'),
            'product_code': r.read<String>('product_code'),
            'product_name': r.read<String>('product_name'),
            'base_unit': r.read<String>('base_unit'),
            'current_stock': r.read<double>('current_stock'),
            'unit_price': r.read<double>('unit_price'),
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 Stock Aging (สินค้าค้างสต๊อก)
  Future<Response> _getStockAgingHandler(Request request) async {
    try {
      // ดู stock ที่ไม่มีการเคลื่อนไหวมากกว่า N วัน
      final days =
          int.tryParse(request.url.queryParameters['days'] ?? '90') ?? 90;

      final results = await db.customSelect('''
        SELECT
          sb.product_id,
          pr.product_code,
          pr.product_name,
          pr.base_unit,
          sb.quantity,
          MAX(sm.created_at) as last_movement,
          CAST(julianday('now') - julianday(MAX(sm.created_at)) AS INTEGER) as days_since_last_movement
        FROM stock_balances sb
        JOIN products pr ON sb.product_id = pr.product_id
        LEFT JOIN stock_movements sm ON sb.product_id = sm.product_id
        WHERE sb.quantity > 0 AND pr.is_active = 1
        GROUP BY sb.product_id
        HAVING days_since_last_movement >= $days OR last_movement IS NULL
        ORDER BY days_since_last_movement DESC
      ''').get();

      return _okList(
        results.map(
          (r) => {
            'product_id': r.read<String>('product_id'),
            'product_code': r.read<String>('product_code'),
            'product_name': r.read<String>('product_name'),
            'base_unit': r.read<String>('base_unit'),
            'quantity': r.read<double>('quantity'),
            'last_movement': r
                .readNullable<DateTime>('last_movement')
                ?.toIso8601String(),
            'days_no_movement':
                r.readNullable<int>('days_since_last_movement') ?? 999,
          },
        ),
      );
    } catch (e) {
      return _err(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // FINANCIAL REPORTS
  // ═══════════════════════════════════════════════════════════════

  // 🆕 Profit & Loss
  Future<Response> _getProfitLossHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];
      final salesDateFilter = _dateBetweenClause(
        column: 'order_date',
        startDate: startDate,
        endDate: endDate,
      );
      final apDateFilter = _dateBetweenClause(
        column: 'payment_date',
        startDate: startDate,
        endDate: endDate,
      );

      // Revenue (ยอดขาย)
      final revenueResult = await db.customSelect('''
        SELECT COALESCE(SUM(total_amount), 0) as revenue,
               COALESCE(SUM(discount_amount), 0) as discount
        FROM sales_orders
        ${salesDateFilter.clause}
      ''', variables: salesDateFilter.variables).getSingle();

      // COGS (ต้นทุนขาย = ปริมาณขาย × standard_cost)
      final cogsResult = await db.customSelect(
        '''
        SELECT COALESCE(SUM(soi.quantity * pr.standard_cost), 0) as cogs
        FROM sales_order_items soi
        JOIN sales_orders so ON soi.order_id = so.order_id
        JOIN products pr ON soi.product_id = pr.product_id
        ${_dateBetweenClause(column: 'so.order_date', startDate: startDate, endDate: endDate).clause}
      ''',
        variables: _dateBetweenClause(
          column: 'so.order_date',
          startDate: startDate,
          endDate: endDate,
        ).variables,
      ).getSingle();

      // AP (ค่าใช้จ่าย — จากการจ่ายเงิน AP)
      final apResult = await db.customSelect('''
        SELECT COALESCE(SUM(total_amount), 0) as total_ap
        FROM ap_payments
        ${apDateFilter.clause}
      ''', variables: apDateFilter.variables).getSingle();

      final revenue = revenueResult.read<double>('revenue');
      final discount = revenueResult.read<double>('discount');
      final cogs = cogsResult.read<double>('cogs');
      final netRevenue = revenue - discount;
      final grossProfit = netRevenue - cogs;
      final totalApPaid = apResult.read<double>('total_ap');

      return _ok({
        'period': {'start': startDate, 'end': endDate},
        'revenue': revenue,
        'discount': discount,
        'net_revenue': netRevenue,
        'cogs': cogs,
        'gross_profit': grossProfit,
        'gross_margin_pct': netRevenue > 0
            ? (grossProfit / netRevenue * 100)
            : 0,
        'total_ap_paid': totalApPaid,
        'net_profit': grossProfit - totalApPaid,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 AR Aging (ลูกหนี้คงค้าง)
  Future<Response> _getArAgingHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final invoiceDateFilter = _dateBetweenClause(
        column: 'ai.invoice_date',
        startDate: p['start_date'],
        endDate: p['end_date'],
      );
      final results = await db.customSelect('''
        SELECT
          ai.invoice_id,
          ai.invoice_no,
          ai.customer_id,
          ai.customer_name,
          ai.invoice_date,
          ai.due_date,
          ai.total_amount,
          COALESCE(ai.paid_amount, 0) as paid_amount,
          (COALESCE(ai.total_amount, 0) - COALESCE(ai.paid_amount, 0)) as outstanding,
          CAST(
            julianday('now') - julianday(COALESCE(ai.due_date, ai.invoice_date))
            AS INTEGER
          ) as overdue_days
        FROM ar_invoices ai
        ${invoiceDateFilter.clause.isEmpty ? 'WHERE' : '${invoiceDateFilter.clause} AND'}
          ai.status != 'CANCELLED'
          AND (COALESCE(ai.total_amount, 0) - COALESCE(ai.paid_amount, 0)) > 0.009
        ORDER BY overdue_days DESC
      ''', variables: invoiceDateFilter.variables).get();

      // จัดกลุ่ม Aging
      final data = results.map((r) {
        final overdueDays = r.readNullable<int>('overdue_days') ?? 0;
        String agingBucket;
        if (overdueDays <= 0) {
          agingBucket = 'ยังไม่ถึงกำหนด';
        } else if (overdueDays <= 30) {
          agingBucket = '1-30 วัน';
        } else if (overdueDays <= 60) {
          agingBucket = '31-60 วัน';
        } else if (overdueDays <= 90) {
          agingBucket = '61-90 วัน';
        } else {
          agingBucket = 'เกิน 90 วัน';
        }

        return {
          'invoice_id': r.read<String>('invoice_id'),
          'invoice_no': r.read<String>('invoice_no'),
          'customer_id': r.read<String>('customer_id'),
          'customer_name': r.read<String>('customer_name'),
          'invoice_date': r.read<DateTime>('invoice_date').toIso8601String(),
          'due_date': r.readNullable<DateTime>('due_date')?.toIso8601String(),
          'total_amount': r.read<double>('total_amount'),
          'paid_amount': r.read<double>('paid_amount'),
          'outstanding': r.read<double>('outstanding'),
          'overdue_days': overdueDays,
          'aging_bucket': agingBucket,
        };
      }).toList();

      return _okList(data);
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 AP Aging (เจ้าหนี้คงค้าง)
  Future<Response> _getApAgingHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final invoiceDateFilter = _dateBetweenClause(
        column: 'ai.invoice_date',
        startDate: p['start_date'],
        endDate: p['end_date'],
      );
      final results = await db.customSelect('''
        SELECT
          ai.invoice_id,
          ai.invoice_no,
          ai.supplier_id,
          ai.supplier_name,
          ai.invoice_date,
          ai.due_date,
          ai.total_amount,
          COALESCE(ai.paid_amount, 0) as paid_amount,
          (COALESCE(ai.total_amount, 0) - COALESCE(ai.paid_amount, 0)) as outstanding,
          CAST(
            julianday('now') - julianday(COALESCE(ai.due_date, ai.invoice_date))
            AS INTEGER
          ) as overdue_days
        FROM ap_invoices ai
        ${invoiceDateFilter.clause.isEmpty ? 'WHERE' : '${invoiceDateFilter.clause} AND'}
          ai.status != 'CANCELLED'
          AND (COALESCE(ai.total_amount, 0) - COALESCE(ai.paid_amount, 0)) > 0.009
        ORDER BY overdue_days DESC
      ''', variables: invoiceDateFilter.variables).get();

      final data = results.map((r) {
        final overdueDays = r.readNullable<int>('overdue_days') ?? 0;
        String agingBucket;
        if (overdueDays <= 0) {
          agingBucket = 'ยังไม่ถึงกำหนด';
        } else if (overdueDays <= 30) {
          agingBucket = '1-30 วัน';
        } else if (overdueDays <= 60) {
          agingBucket = '31-60 วัน';
        } else if (overdueDays <= 90) {
          agingBucket = '61-90 วัน';
        } else {
          agingBucket = 'เกิน 90 วัน';
        }

        return {
          'invoice_id': r.read<String>('invoice_id'),
          'invoice_no': r.read<String>('invoice_no'),
          'supplier_id': r.read<String>('supplier_id'),
          'supplier_name': r.read<String>('supplier_name'),
          'invoice_date': r.read<DateTime>('invoice_date').toIso8601String(),
          'due_date': r.readNullable<DateTime>('due_date')?.toIso8601String(),
          'total_amount': r.read<double>('total_amount'),
          'paid_amount': r.read<double>('paid_amount'),
          'outstanding': r.read<double>('outstanding'),
          'overdue_days': overdueDays,
          'aging_bucket': agingBucket,
        };
      }).toList();

      return _okList(data);
    } catch (e) {
      return _err(e);
    }
  }

  // 🆕 Cash Flow (กระแสเงินสด)
  Future<Response> _getCashFlowHandler(Request request) async {
    try {
      final p = request.url.queryParameters;
      final startDate = p['start_date'];
      final endDate = p['end_date'];
      final receiptDateFilter = _dateBetweenClause(
        column: 'receipt_date',
        startDate: startDate,
        endDate: endDate,
      );
      final salesDateFilter = _dateBetweenClause(
        column: 'order_date',
        startDate: startDate,
        endDate: endDate,
      );
      final paymentDateFilter = _dateBetweenClause(
        column: 'payment_date',
        startDate: startDate,
        endDate: endDate,
      );

      // Inflow: AR Receipts + POS Sales (cash)
      final arResult = await db.customSelect('''
        SELECT COALESCE(SUM(total_amount), 0) as total
        FROM ar_receipts
        ${receiptDateFilter.clause}
      ''', variables: receiptDateFilter.variables).getSingle();

      final posResult = await db.customSelect('''
        SELECT COALESCE(SUM(total_amount), 0) as total
        FROM sales_orders
        ${salesDateFilter.clause}
      ''', variables: salesDateFilter.variables).getSingle();

      // Outflow: AP Payments
      final apResult = await db.customSelect('''
        SELECT COALESCE(SUM(total_amount), 0) as total
        FROM ap_payments
        ${paymentDateFilter.clause}
      ''', variables: paymentDateFilter.variables).getSingle();

      final inflow =
          posResult.read<double>('total') + arResult.read<double>('total');
      final outflow = apResult.read<double>('total');

      return _ok({
        'period': {'start': startDate, 'end': endDate},
        'inflow': {
          'pos_sales': posResult.read<double>('total'),
          'ar_receipts': arResult.read<double>('total'),
          'total': inflow,
        },
        'outflow': {'ap_payments': outflow, 'total': outflow},
        'net_cash_flow': inflow - outflow,
      });
    } catch (e) {
      return _err(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  Response _ok(Map<String, dynamic> data) => Response.ok(
    jsonEncode({'success': true, 'data': data}),
    headers: {'Content-Type': 'application/json'},
  );

  Response _okList(Iterable<Map<String, dynamic>> data) => Response.ok(
    jsonEncode({'success': true, 'data': data.toList()}),
    headers: {'Content-Type': 'application/json'},
  );

  ({String clause, List<Variable> variables}) _dateBetweenClause({
    required String column,
    required String? startDate,
    required String? endDate,
  }) {
    DateTime? parseStart(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      final date = DateTime.tryParse(value);
      if (date == null) {
        return null;
      }
      return DateTime(date.year, date.month, date.day);
    }

    DateTime? parseEndExclusive(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      final date = DateTime.tryParse(value);
      if (date == null) {
        return null;
      }
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(const Duration(days: 1));
    }

    final start = parseStart(startDate);
    final endExclusive = parseEndExclusive(endDate);

    if (start != null && endExclusive != null) {
      return (
        clause: 'WHERE $column >= ? AND $column < ?',
        variables: [
          Variable.withDateTime(start),
          Variable.withDateTime(endExclusive),
        ],
      );
    }
    if (start != null) {
      return (
        clause: 'WHERE $column >= ?',
        variables: [Variable.withDateTime(start)],
      );
    }
    if (endExclusive != null) {
      return (
        clause: 'WHERE $column < ?',
        variables: [Variable.withDateTime(endExclusive)],
      );
    }
    return (clause: '', variables: <Variable>[]);
  }

  Response _err(Object e) => Response.internalServerError(
    body: jsonEncode({'success': false, 'message': '$e'}),
    headers: {'Content-Type': 'application/json'},
  );
}
