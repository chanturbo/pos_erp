import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/sales_summary_model.dart';

const _kBorder = PdfColor.fromInt(0xFFCCCCCC);
const _kHeaderBg = PdfColor.fromInt(0xFFF0F0F0);
const _kAltBg = PdfColor.fromInt(0xFFFAFAFA);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF666666);

class ReportsPdfBuilder {
  static final _money = NumberFormat('#,##0.00', 'th_TH');
  static final _qty = NumberFormat('#,##0.##', 'th_TH');
  static final _date = DateFormat('dd/MM/yyyy', 'th_TH');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  static Future<pw.Document> buildSales({
    required SalesSummaryModel summary,
    required List<TopProductModel> topProducts,
    required List<TopCustomerModel> topCustomers,
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    return _buildDocument(
      title: 'รายงานภาพรวมการขาย',
      companyName: effectiveCompanyName,
      pages: (ttf, regular) => [
        [
          _summaryGrid(
            [
              ('ยอดขายรวม', '฿${_money.format(summary.totalSales)}'),
              ('จำนวนออเดอร์', '${summary.totalOrders}'),
              ('เฉลี่ย/ออเดอร์', '฿${_money.format(summary.avgOrderValue)}'),
              ('ส่วนลดรวม', '฿${_money.format(summary.totalDiscount)}'),
            ],
            regular,
            ttf,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'สินค้าขายดี',
            headers: ['#', 'สินค้า', 'จำนวน', 'ออเดอร์', 'ยอดขาย'],
            rows: topProducts.asMap().entries.map((entry) {
              final p = entry.value;
              return [
                '${entry.key + 1}',
                p.productName,
                _qty.format(p.totalQuantity),
                '${p.orderCount}',
                _money.format(p.totalSales),
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'ลูกค้าซื้อบ่อย',
            headers: ['#', 'ลูกค้า', 'ออเดอร์', 'ยอดขาย'],
            rows: topCustomers.asMap().entries.map((entry) {
              final c = entry.value;
              return [
                '${entry.key + 1}',
                c.customerName,
                '${c.orderCount}',
                _money.format(c.totalSales),
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
      ],
    );
  }

  static Future<pw.Document> buildPurchase({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> topSuppliers,
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    return _buildDocument(
      title: 'รายงานภาพรวมการซื้อ',
      companyName: effectiveCompanyName,
      pages: (ttf, regular) => [
        [
          _summaryGrid(
            [
              ('ใบสั่งซื้อทั้งหมด', '${summary['total_po'] ?? 0}'),
              (
                'มูลค่าสั่งซื้อรวม',
                '฿${_money.format((summary['total_po_amount'] ?? 0) as num)}',
              ),
              (
                'ชำระแล้ว',
                '฿${_money.format((summary['total_paid'] ?? 0) as num)}',
              ),
              (
                'คงค้าง',
                '฿${_money.format((summary['total_outstanding'] ?? 0) as num)}',
              ),
              ('ใบรับสินค้า', '${summary['total_gr'] ?? 0}'),
            ],
            regular,
            ttf,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'ซัพพลายเออร์สูงสุด',
            headers: ['#', 'ซัพพลายเออร์', 'จำนวน PO', 'มูลค่า'],
            rows: topSuppliers.asMap().entries.map((entry) {
              final s = entry.value;
              return [
                '${entry.key + 1}',
                '${s['supplier_name'] ?? '-'}',
                '${s['po_count'] ?? 0}',
                _money.format((s['total_amount'] ?? 0) as num),
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
      ],
    );
  }

  static Future<pw.Document> buildInventory({
    required List<Map<String, dynamic>> lowStock,
    required List<Map<String, dynamic>> stockAging,
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    return _buildDocument(
      title: 'รายงานภาพรวมสต๊อก',
      companyName: effectiveCompanyName,
      pages: (ttf, regular) => [
        [
          _tableSection(
            title: 'สินค้าใกล้หมด',
            headers: ['#', 'สินค้า', 'รหัส', 'คงเหลือ', 'หน่วย'],
            rows: lowStock.asMap().entries.map((entry) {
              final item = entry.value;
              return [
                '${entry.key + 1}',
                '${item['product_name'] ?? '-'}',
                '${item['product_code'] ?? '-'}',
                _qty.format((item['current_stock'] ?? 0) as num),
                '${item['base_unit'] ?? '-'}',
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'สินค้าค้างสต๊อก',
            headers: [
              '#',
              'สินค้า',
              'คงเหลือ',
              'หน่วย',
              'ไม่เคลื่อนไหว',
              'ล่าสุด',
            ],
            rows: stockAging.asMap().entries.map((entry) {
              final item = entry.value;
              final lastMovement = item['last_movement'] as String?;
              return [
                '${entry.key + 1}',
                '${item['product_name'] ?? '-'}',
                _qty.format((item['quantity'] ?? 0) as num),
                '${item['base_unit'] ?? '-'}',
                '${item['days_no_movement'] ?? 0} วัน',
                lastMovement == null
                    ? '-'
                    : _date.format(DateTime.parse(lastMovement)),
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
      ],
    );
  }

  static Future<pw.Document> buildFinancial({
    required Map<String, dynamic> profitLoss,
    required Map<String, dynamic> cashFlow,
    required List<Map<String, dynamic>> arAging,
    required List<Map<String, dynamic>> apAging,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    String periodText = 'ทั้งหมด';
    if (dateFrom != null && dateTo != null) {
      periodText = '${_date.format(dateFrom)} - ${_date.format(dateTo)}';
    } else if (dateFrom != null) {
      periodText = 'ตั้งแต่ ${_date.format(dateFrom)}';
    } else if (dateTo != null) {
      periodText = 'ถึง ${_date.format(dateTo)}';
    }

    return _buildDocument(
      title: 'รายงานภาพรวมการเงิน',
      companyName: effectiveCompanyName,
      subtitle: 'ช่วงเวลา: $periodText',
      pages: (ttf, regular) => [
        [
          _summaryGrid(
            [
              (
                'รายได้สุทธิ',
                '฿${_money.format((profitLoss['net_revenue'] ?? 0) as num)}',
              ),
              (
                'กำไรขั้นต้น',
                '฿${_money.format((profitLoss['gross_profit'] ?? 0) as num)}',
              ),
              (
                'กำไรสุทธิ',
                '฿${_money.format((profitLoss['net_profit'] ?? 0) as num)}',
              ),
              (
                'กระแสเงินสดสุทธิ',
                '฿${_money.format((cashFlow['net_cash_flow'] ?? 0) as num)}',
              ),
            ],
            regular,
            ttf,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'กำไร - ขาดทุน',
            headers: ['รายการ', 'มูลค่า'],
            rows: [
              ['รายได้รวม', _money.format((profitLoss['revenue'] ?? 0) as num)],
              ['ส่วนลด', _money.format((profitLoss['discount'] ?? 0) as num)],
              [
                'รายได้สุทธิ',
                _money.format((profitLoss['net_revenue'] ?? 0) as num),
              ],
              ['ต้นทุนขาย', _money.format((profitLoss['cogs'] ?? 0) as num)],
              [
                'จ่าย AP',
                _money.format((profitLoss['total_ap_paid'] ?? 0) as num),
              ],
              [
                'กำไรสุทธิ',
                _money.format((profitLoss['net_profit'] ?? 0) as num),
              ],
            ],
            ttf: ttf,
            regular: regular,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'กระแสเงินสด',
            headers: ['รายการ', 'มูลค่า'],
            rows: [
              [
                'ยอดขาย POS',
                _money.format(
                  (((cashFlow['inflow'] ?? {}) as Map)['pos_sales'] ?? 0)
                      as num,
                ),
              ],
              [
                'รับชำระ AR',
                _money.format(
                  (((cashFlow['inflow'] ?? {}) as Map)['ar_receipts'] ?? 0)
                      as num,
                ),
              ],
              [
                'จ่ายชำระ AP',
                _money.format(
                  (((cashFlow['outflow'] ?? {}) as Map)['ap_payments'] ?? 0)
                      as num,
                ),
              ],
              [
                'กระแสเงินสดสุทธิ',
                _money.format((cashFlow['net_cash_flow'] ?? 0) as num),
              ],
            ],
            ttf: ttf,
            regular: regular,
          ),
        ],
        [
          _tableSection(
            title: 'ลูกหนี้คงค้าง',
            headers: ['เลขที่', 'ลูกค้า', 'คงค้าง', 'Bucket'],
            rows: arAging.take(30).map((item) {
              return [
                '${item['invoice_no'] ?? '-'}',
                '${item['customer_name'] ?? '-'}',
                _money.format((item['outstanding'] ?? 0) as num),
                '${item['aging_bucket'] ?? '-'}',
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
        [
          _tableSection(
            title: 'เจ้าหนี้คงค้าง',
            headers: ['เลขที่', 'ซัพพลายเออร์', 'คงค้าง', 'Bucket'],
            rows: apAging.take(30).map((item) {
              return [
                '${item['invoice_no'] ?? '-'}',
                '${item['supplier_name'] ?? '-'}',
                _money.format((item['outstanding'] ?? 0) as num),
                '${item['aging_bucket'] ?? '-'}',
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
      ],
    );
  }

  static Future<pw.Document> buildSalesChart({
    required List<DailySalesModel> dailySales,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();

    String periodText = 'ทั้งหมด';
    if (dateFrom != null && dateTo != null) {
      periodText = '${_date.format(dateFrom)} - ${_date.format(dateTo)}';
    } else if (dateFrom != null) {
      periodText = 'ตั้งแต่ ${_date.format(dateFrom)}';
    } else if (dateTo != null) {
      periodText = 'ถึง ${_date.format(dateTo)}';
    }

    final sorted = [...dailySales]..sort((a, b) => a.date.compareTo(b.date));
    final totalSales = sorted.fold<double>(0, (sum, item) => sum + item.sales);
    final totalOrders = sorted.fold<int>(0, (sum, item) => sum + item.orders);
    final avgSales = sorted.isEmpty ? 0.0 : totalSales / sorted.length;

    return _buildDocument(
      title: 'รายงานกราฟยอดขาย',
      companyName: effectiveCompanyName,
      subtitle: 'ช่วงเวลา: $periodText',
      pages: (ttf, regular) => [
        [
          _summaryGrid(
            [
              ('จำนวนวัน', '${sorted.length}'),
              ('ยอดขายรวม', '฿${_money.format(totalSales)}'),
              ('ออเดอร์รวม', '$totalOrders'),
              ('เฉลี่ยต่อวัน', '฿${_money.format(avgSales)}'),
            ],
            regular,
            ttf,
          ),
          pw.SizedBox(height: 12),
          _tableSection(
            title: 'ยอดขายรายวัน',
            headers: ['#', 'วันที่', 'ออเดอร์', 'ยอดขาย'],
            rows: sorted.asMap().entries.map((entry) {
              final item = entry.value;
              final date = DateTime.tryParse(item.date);
              return [
                '${entry.key + 1}',
                date == null ? item.date : _date.format(date),
                '${item.orders}',
                _money.format(item.sales),
              ];
            }).toList(),
            ttf: ttf,
            regular: regular,
          ),
        ],
      ],
    );
  }

  static Future<pw.Document> _buildDocument({
    required String title,
    required String companyName,
    String? subtitle,
    required List<List<pw.Widget>> Function(pw.Font ttf, pw.Font regular) pages,
  }) async {
    final doc = pw.Document(title: title, author: companyName);
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTime.format(DateTime.now());
    final pageWidgets = pages(ttf, regular);

    for (var i = 0; i < pageWidgets.length; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(
                companyName: companyName,
                title: title,
                subtitle: subtitle,
                printedAt: printedAt,
                page: i + 1,
                totalPages: pageWidgets.length,
                ttf: ttf,
                regular: regular,
              ),
              ...pageWidgets[i],
            ],
          ),
        ),
      );
    }

    if (pageWidgets.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(
                companyName: companyName,
                title: title,
                subtitle: subtitle,
                printedAt: printedAt,
                page: 1,
                totalPages: 1,
                ttf: ttf,
                regular: regular,
              ),
              _emptyBlock(regular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  static pw.Widget _header({
    required String companyName,
    required String title,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font regular,
    String? subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'หน้า $page / $totalPages',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _summaryGrid(
    List<(String, String)> items,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => pw.Container(
              width: 245,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBorder),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.$1,
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: _kSub,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    item.$2,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 12,
                      color: _kText,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _tableSection({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: ttf, fontSize: 11)),
        pw.SizedBox(height: 6),
        rows.isEmpty
            ? _emptyBlock(regular)
            : pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerDecoration: const pw.BoxDecoration(color: _kHeaderBg),
                headerStyle: pw.TextStyle(font: ttf, fontSize: 8),
                cellStyle: pw.TextStyle(font: regular, fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(color: _kAltBg),
                border: pw.TableBorder.all(color: _kBorder, width: 0.5),
              ),
      ],
    );
  }

  static pw.Widget _emptyBlock(pw.Font regular) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _kBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'ไม่มีข้อมูล',
        style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
      ),
    );
  }
}
