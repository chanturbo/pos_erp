import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../providers/supplier_provider.dart';
import '../../../suppliers/data/models/supplier_model.dart';
import 'supplier_form_page.dart';
import 'supplier_pdf_report.dart';

class SupplierListPage extends ConsumerStatefulWidget {
  const SupplierListPage({super.key});

  @override
  ConsumerState<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends ConsumerState<SupplierListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isTableView = true;
  bool _activeOnly = false;
  bool _userResized = false;

  // ── Sort ────────────────────────────────────────────────────────
  String _sortColumn = 'name';
  bool _sortAsc = true;

  // ── Pagination ──────────────────────────────────────────────────
  int _currentPage = 1;

  // ── Column widths [ชื่อ, รหัส, โทร, ผู้ติดต่อ, เครดิต, วงเงิน, สถานะ, จัดการ]
  final List<double> _colWidths = [200, 100, 120, 140, 80, 110, 80, 100];
  static const List<double> _colMinW = [120, 70, 80, 80, 60, 80, 70, 100];
  static const List<double> _colMaxW = [400, 200, 220, 260, 120, 200, 120, 100];

  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFFE8622A),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFFFF5722),
      Color(0xFF009688),
      Color(0xFF3F51B5),
      Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  Map<String, int> _calcSummary(List<SupplierModel> suppliers) {
    final active = suppliers.where((s) => s.isActive).length;
    final inactive = suppliers.length - active;
    final withCredit = suppliers
        .where((s) => s.creditLimit > 0 || s.creditTerm > 0)
        .length;
    final withContact = suppliers
        .where(
          (s) =>
              (s.contactPerson?.isNotEmpty ?? false) ||
              (s.phone?.isNotEmpty ?? false),
        )
        .length;
    return {
      'count': suppliers.length,
      'active': active,
      'inactive': inactive,
      'credit': withCredit,
      'contact': withContact,
    };
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final canPop = Navigator.of(context).canPop();
    final colors = _SupplierListColors.of(context);

    return EscapePopScope(
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: Column(
              children: [
                _SupplierListTopBar(
                  canPop: canPop,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  activeOnly: _activeOnly,
                  isTableView: _isTableView,
                  onSearchChanged: (v) => setState(() {
                    _searchQuery = v;
                    _currentPage = 1;
                  }),
                  onSearchCleared: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 1;
                    });
                  },
                  onToggleActive: () => setState(() {
                    _activeOnly = !_activeOnly;
                    _currentPage = 1;
                  }),
                  onToggleView: () =>
                      setState(() => _isTableView = !_isTableView),
                  onRefresh: () =>
                      ref.read(supplierListProvider.notifier).refresh(),
                  onAdd: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplierFormPage(),
                      ),
                    );
                    if (context.mounted) {
                      ref.read(supplierListProvider.notifier).refresh();
                    }
                  },
                ),
                // ── Content ──────────────────────────────────────────
                Expanded(
                  child: supplierAsync.when(
                    loading: () => Center(
                      child: Padding(
                        padding: context.pagePadding,
                        child: const CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    error: (e, _) => _buildError(e),
                    data: (suppliers) {
                      final filtered = suppliers.where((s) {
                        if (_activeOnly && !s.isActive) return false;
                        if (_searchQuery.isEmpty) return true;
                        final q = _searchQuery.toLowerCase();
                        return s.supplierName.toLowerCase().contains(q) ||
                            s.supplierCode.toLowerCase().contains(q) ||
                            (s.phone?.toLowerCase().contains(q) ?? false) ||
                            (s.contactPerson?.toLowerCase().contains(q) ??
                                false);
                      }).toList();
                      final summary = _calcSummary(filtered);

                      // ── Sort ──────────────────────────────────────
                      filtered.sort((a, b) {
                        int cmp;
                        switch (_sortColumn) {
                          case 'name':
                            cmp = a.supplierName.compareTo(b.supplierName);
                          case 'code':
                            cmp = a.supplierCode.compareTo(b.supplierCode);
                          case 'phone':
                            cmp = (a.phone ?? '').compareTo(b.phone ?? '');
                          case 'contact':
                            cmp = (a.contactPerson ?? '').compareTo(
                              b.contactPerson ?? '',
                            );
                          case 'credit':
                            cmp = a.creditTerm.compareTo(b.creditTerm);
                          case 'limit':
                            cmp = a.creditLimit.compareTo(b.creditLimit);
                          case 'status':
                            cmp = (b.isActive ? 1 : 0).compareTo(
                              a.isActive ? 1 : 0,
                            );
                          default:
                            cmp = 0;
                        }
                        return _sortAsc ? cmp : -cmp;
                      });

                      if (filtered.isEmpty) return _buildEmpty();

                      // Pagination
                      final totalPages = (filtered.length / pageSize).ceil();
                      final safePage = _currentPage.clamp(1, totalPages);
                      final start = (safePage - 1) * pageSize;
                      final end = (start + pageSize).clamp(0, filtered.length);
                      final pageItems = filtered.sublist(start, end);

                      // ── Card View ────────────────────────────────
                      if (!_isTableView) {
                        return Column(
                          children: [
                            _SupplierSummaryBar(summary: summary),
                            Expanded(child: _buildCardView(pageItems)),
                            PaginationBar(
                              currentPage: safePage,
                              totalItems: filtered.length,
                              pageSize: pageSize,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p),
                              trailing: PdfReportButton(
                                emptyMessage: 'ไม่มีข้อมูลซัพพลายเออร์',
                                title: 'รายงานซัพพลายเออร์',
                                filename: () =>
                                    PdfFilename.generate('supplier_report'),
                                buildPdf: () => SupplierPdfBuilder.build(
                                  List<SupplierModel>.from(filtered),
                                ),
                                hasData: filtered.isNotEmpty,
                              ),
                            ),
                          ],
                        );
                      }

                      // ── Table View ───────────────────────────────
                      final screenW = MediaQuery.of(context).size.width - 32;
                      if (!_userResized) _autoFitColWidths(filtered);

                      final totalW =
                          40.0 +
                          16.0 +
                          _colWidths.fold(0.0, (s, w) => s + w) +
                          28.0 +
                          32.0;
                      final tableW = totalW > screenW ? totalW : screenW;

                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                              boxShadow: [
                                if (!colors.isDark)
                                  BoxShadow(
                                    color: AppTheme.navy.withValues(
                                      alpha: 0.04,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _SupplierSummaryBar(summary: summary),
                                Divider(height: 1, color: colors.border),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _hScroll,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _hScroll,
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: tableW,
                                        child: Column(
                                          children: [
                                            _SupplierTableHeader(
                                              colWidths: _colWidths,
                                              colMinW: _colMinW,
                                              colMaxW: _colMaxW,
                                              sortColumn: _sortColumn,
                                              sortAsc: _sortAsc,
                                              onSort: (col) => setState(() {
                                                if (_sortColumn == col) {
                                                  _sortAsc = !_sortAsc;
                                                } else {
                                                  _sortColumn = col;
                                                  _sortAsc = true;
                                                }
                                                _currentPage = 1;
                                              }),
                                              onResize: (i, w) => setState(() {
                                                _colWidths[i] = w;
                                                _userResized = true;
                                              }),
                                              onReset: () => setState(() {
                                                _colWidths.setAll(0, [
                                                  200,
                                                  100,
                                                  120,
                                                  140,
                                                  80,
                                                  110,
                                                  80,
                                                  100,
                                                ]);
                                                _userResized = false;
                                              }),
                                            ),
                                            Divider(
                                              height: 1,
                                              color: colors.border,
                                            ),
                                            Expanded(
                                              child: ListView.separated(
                                                itemCount: pageItems.length,
                                                separatorBuilder: (_, _) =>
                                                    Divider(
                                                      height: 1,
                                                      color: colors.border,
                                                    ),
                                                itemBuilder: (_, i) {
                                                  final s = pageItems[i];
                                                  return _SupplierRow(
                                                    supplier: s,
                                                    colWidths: _colWidths,
                                                    avatarColor: _avatarColor(
                                                      s.supplierName,
                                                    ),
                                                    onEdit: () async {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SupplierFormPage(
                                                                supplier: s,
                                                              ),
                                                        ),
                                                      );
                                                      if (context.mounted) {
                                                        ref
                                                            .read(
                                                              supplierListProvider
                                                                  .notifier,
                                                            )
                                                            .refresh();
                                                      }
                                                    },
                                                    onDelete: () =>
                                                        _confirmDelete(s),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                PaginationBar(
                                  currentPage: safePage,
                                  totalItems: filtered.length,
                                  pageSize: pageSize,
                                  onPageChanged: (p) =>
                                      setState(() => _currentPage = p),
                                  trailing: PdfReportButton(
                                    emptyMessage: 'ไม่มีข้อมูลซัพพลายเออร์',
                                    title: 'รายงานซัพพลายเออร์',
                                    filename: () =>
                                        PdfFilename.generate('supplier_report'),
                                    buildPdf: () => SupplierPdfBuilder.build(
                                      List<SupplierModel>.from(filtered),
                                    ),
                                    hasData: filtered.isNotEmpty,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Card View ──────────────────────────────────────────────────
  Widget _buildCardView(List<SupplierModel> suppliers) {
    final colors = _SupplierListColors.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = suppliers[i];
        final initial = s.supplierName.isNotEmpty
            ? s.supplierName.substring(0, 1).toUpperCase()
            : '?';
        final color = _avatarColor(s.supplierName);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.border),
          ),
          color: colors.cardBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: colors.rowHoverBg,
            onTap: () => _showSupplierDetails(s),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.supplierName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: s.isActive
                                    ? AppTheme.successContainer
                                    : AppTheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      (s.isActive
                                              ? AppTheme.success
                                              : AppTheme.error)
                                          .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: s.isActive
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFF44336),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    s.isActive ? 'ใช้งาน' : 'ระงับ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: s.isActive
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'รหัส: ${s.supplierCode}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSub,
                          ),
                        ),
                        if (s.phone != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 11,
                                color: AppTheme.textSub,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                s.phone!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSub,
                                ),
                              ),
                            ],
                          ),
                        if (s.contactPerson != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 11,
                                color: AppTheme.textSub,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                s.contactPerson!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSub,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        if (s.creditLimit > 0)
                          Text(
                            'เครดิต ${s.creditTerm} วัน  ·  วงเงิน ฿${s.creditLimit.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.info,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF1565C0),
                        tooltip: 'แก้ไข',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierFormPage(supplier: s),
                            ),
                          );
                          if (context.mounted) {
                            ref.read(supplierListProvider.notifier).refresh();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFC62828),
                        tooltip: 'ลบ',
                        onTap: () => _confirmDelete(s),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Auto-fit columns ───────────────────────────────────────────
  double _measureTextWidth(
    BuildContext context,
    String text, {
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  void _autoFitColWidths(List<SupplierModel> rows) {
    const headers = [
      ('ชื่อซัพพลายเออร์', true),
      ('รหัส', true),
      ('โทรศัพท์', true),
      ('ผู้ติดต่อ', true),
      ('เครดิต(วัน)', true),
      ('วงเงิน', true),
      ('สถานะ', true),
      ('จัดการ', false),
    ];

    final headerStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    final colors = _SupplierListColors.of(context);
    final cellStyle = TextStyle(fontSize: 13, color: colors.subtext);
    final emphasisStyle = TextStyle(fontSize: 13, color: colors.amountText);
    final nameStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: colors.text,
    );
    const badgeStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    // colWidth = labelW + basePadding(16) + sortChrome(20 if sortable)
    //          + resizeHandle(14 if not last) + buffer(10)
    const basePadding = 16.0;
    const sortChrome = 20.0;
    const resizeHandle = 14.0;
    const headerBuffer = 10.0;

    final maxW = List<double>.generate(headers.length, (i) {
      final label = headers[i].$1;
      final isSortable = headers[i].$2;
      final isLast = i == headers.length - 1;
      final labelW = _measureTextWidth(context, label, style: headerStyle);
      return labelW +
          basePadding +
          (isSortable ? sortChrome : 0.0) +
          (isLast ? 0.0 : resizeHandle) +
          headerBuffer;
    });

    for (final s in rows) {
      // ชื่อ: CircleAvatar(radius 18 → 36px) + gap(10) + text + buffer(10) = +56
      final nameW =
          _measureTextWidth(context, s.supplierName, style: nameStyle) + 56;
      if (nameW > maxW[0]) maxW[0] = nameW;

      final codeW =
          _measureTextWidth(context, s.supplierCode, style: cellStyle) + 20;
      if (codeW > maxW[1]) maxW[1] = codeW;

      final phoneW =
          _measureTextWidth(context, s.phone ?? '-', style: cellStyle) + 20;
      if (phoneW > maxW[2]) maxW[2] = phoneW;

      final contactW =
          _measureTextWidth(
            context,
            s.contactPerson ?? '-',
            style: cellStyle,
          ) +
          20;
      if (contactW > maxW[3]) maxW[3] = contactW;

      // เครดิต(วัน): badge — horizontal padding 8×2=16 + center buffer = +32
      final creditLabel = s.creditTerm > 0 ? '${s.creditTerm} วัน' : '-';
      final creditW =
          _measureTextWidth(context, creditLabel, style: badgeStyle) + 32;
      if (creditW > maxW[4]) maxW[4] = creditW;

      // วงเงิน: text + 20
      final amtLabel =
          s.creditLimit > 0 ? '฿${s.creditLimit.toStringAsFixed(0)}' : '-';
      final amtW =
          _measureTextWidth(
            context,
            amtLabel,
            style: s.creditLimit > 0 ? emphasisStyle : cellStyle,
          ) +
          20;
      if (amtW > maxW[5]) maxW[5] = amtW;

      // สถานะ: badge = dot(6)+gap(5)+text + horizontal padding(10×2) + buffer = +41
      final statusLabel = s.isActive ? 'ใช้งาน' : 'ระงับ';
      final statusW =
          _measureTextWidth(context, statusLabel, style: badgeStyle) + 41;
      if (statusW > maxW[6]) maxW[6] = statusW;

      maxW[7] = 100.0; // จัดการ — fixed
    }

    for (int i = 0; i < maxW.length; i++) {
      maxW[i] = maxW[i].clamp(_colMinW[i], _colMaxW[i]);
    }

    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  // ── Detail dialog ──────────────────────────────────────────────
  void _showSupplierDetails(SupplierModel s) {
    showDialog(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: s.supplierName,
          icon: Icons.local_shipping_outlined,
          iconColor: AppTheme.primary,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('รหัส', s.supplierCode),
              _DetailRow('ผู้ติดต่อ', s.contactPerson ?? '-'),
              _DetailRow('โทรศัพท์', s.phone ?? '-'),
              _DetailRow('อีเมล', s.email ?? '-'),
              _DetailRow('Line ID', s.lineId ?? '-'),
              _DetailRow('ที่อยู่', s.address ?? '-'),
              _DetailRow('เลขผู้เสียภาษี', s.taxId ?? '-'),
              _DetailRow('เครดิต', '${s.creditTerm} วัน'),
              _DetailRow(
                'วงเงินเครดิต',
                '฿${s.creditLimit.toStringAsFixed(0)}',
              ),
              _DetailRow('สถานะ', s.isActive ? 'ใช้งาน' : 'ระงับ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('แก้ไข'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupplierFormPage(supplier: s),
                ),
              );
              if (context.mounted) {
                ref.read(supplierListProvider.notifier).refresh();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(SupplierModel s) async {
    // ── Pre-check ก่อนแสดง dialog ────────────────────────────────
    final check = await ref
        .read(supplierListProvider.notifier)
        .checkDeleteSupplier(s.supplierId);
    if (!mounted) return;

    final hasHistory = check['has_history'] == true;
    final orderCount = (check['order_count'] as int?) ?? 0;

    final details = orderCount > 0
        ? 'ประวัติการสั่งซื้อ $orderCount รายการ'
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: hasHistory ? 'ปิดการใช้งานซัพพลายเออร์' : 'ลบซัพพลายเออร์ถาวร',
          icon: hasHistory ? Icons.archive_outlined : Icons.delete_outline,
          iconColor: hasHistory ? AppTheme.warningColor : AppTheme.error,
        ),
        content: hasHistory
            ? Text(
                'ซัพพลายเออร์ "${s.supplierName}" มี$details\n\n'
                'ไม่สามารถลบได้ ระบบจะปิดการใช้งานแทนเพื่อเก็บประวัติไว้',
              )
            : Text(
                'ต้องการลบ "${s.supplierName}" '
                'ออกจากระบบอย่างถาวรใช่หรือไม่?',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: Icon(
              hasHistory ? Icons.pause_circle_outline : Icons.delete_forever,
              size: 16,
            ),
            label: Text(hasHistory ? 'ปิดการใช้งาน' : 'ลบถาวร'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasHistory
                  ? AppTheme.warningColor
                  : AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final message = await ref
        .read(supplierListProvider.notifier)
        .deleteSupplier(s.supplierId);
    if (!mounted) return;
    final success = message != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? message : 'ดำเนินการไม่สำเร็จ'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmpty() {
    final colors = _SupplierListColors.of(context);
    return Center(
      child: Padding(
        padding: context.pagePadding,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 72,
                  color: colors.emptyIcon,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'ยังไม่มีซัพพลายเออร์'
                      : 'ไม่พบซัพพลายเออร์ที่ค้นหา',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ลองเปลี่ยนคำค้นหา หรือเพิ่มซัพพลายเออร์ใหม่เพื่อเริ่มต้นใช้งาน',
                  style: TextStyle(color: colors.subtext, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplierFormPage(),
                      ),
                    );
                    if (context.mounted) {
                      ref.read(supplierListProvider.notifier).refresh();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มซัพพลายเออร์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    final colors = _SupplierListColors.of(context);
    return Center(
      child: Padding(
        padding: context.pagePadding,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: context.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('เกิดข้อผิดพลาด: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(supplierListProvider.notifier).refresh(),
                  child: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Detail Row helper
// ─────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────
class _SupplierListTopBar extends StatelessWidget {
  final bool canPop;
  final TextEditingController searchController;
  final String searchQuery;
  final bool activeOnly;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _SupplierListTopBar({
    required this.canPop,
    required this.searchController,
    required this.searchQuery,
    required this.activeOnly,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleActive,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  static const _kBreak = 980.0;

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return Container(
      color: colors.topBarBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _kBreak;
          return isWide
              ? _buildSingleRow(context, colors)
              : _buildDoubleRow(context, colors);
        },
      ),
    );
  }

  Widget _buildSingleRow(BuildContext context, _SupplierListColors colors) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop) ...[
            _TopNavBtn(
              icon: Icons.arrow_back,
              tooltip: 'ย้อนกลับ',
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
          ],
          _SupplierPageIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ซัพพลายเออร์',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ค้นหาซัพพลายเออร์ ดูเฉพาะที่ใช้งาน และสลับมุมมองรายการ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _SearchField(
              controller: searchController,
              query: searchQuery,
              onChanged: onSearchChanged,
              onCleared: onSearchCleared,
            ),
          ),
          const SizedBox(width: 8),
          _ActiveToggle(active: activeOnly, onTap: onToggleActive),
          const SizedBox(width: 6),
          _TopNavBtn(
            icon: isTableView
                ? Icons.view_agenda_outlined
                : Icons.table_rows_outlined,
            tooltip: isTableView ? 'Card View' : 'Table View',
            onTap: onToggleView,
          ),
          const SizedBox(width: 6),
          _RefreshBtn(onTap: onRefresh),
          const SizedBox(width: 6),
          _AddBtn(onTap: onAdd),
        ],
      );

  Widget _buildDoubleRow(BuildContext context, _SupplierListColors colors) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop) ...[
                _TopNavBtn(
                  icon: Icons.arrow_back,
                  tooltip: 'ย้อนกลับ',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
              ],
              _SupplierPageIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ซัพพลายเออร์',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ค้นหาซัพพลายเออร์ ดูเฉพาะที่ใช้งาน และสลับมุมมองรายการ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActiveToggle(active: activeOnly, onTap: onToggleActive),
              _TopNavBtn(
                icon: isTableView
                    ? Icons.view_agenda_outlined
                    : Icons.table_rows_outlined,
                tooltip: isTableView ? 'Card View' : 'Table View',
                onTap: onToggleView,
              ),
              _RefreshBtn(onTap: onRefresh),
              _AddBtn(onTap: onAdd, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          _SearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ],
      );
}

class _SupplierSummaryBar extends StatelessWidget {
  final Map<String, int> summary;

  const _SupplierSummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: colors.summaryBg),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _SummaryChip(
            icon: Icons.receipt_long,
            label: 'ทั้งหมด ${summary['count']}',
            color: AppTheme.info,
          ),
          _SummaryChip(
            icon: Icons.check_circle_outline,
            label: 'ใช้งาน ${summary['active']}',
            color: AppTheme.success,
          ),
          _SummaryChip(
            icon: Icons.pause_circle_outline,
            label: 'ระงับ ${summary['inactive']}',
            color: AppTheme.error,
          ),
          _SummaryChip(
            icon: Icons.credit_score_outlined,
            label: 'เครดิต ${summary['credit']}',
            color: AppTheme.primary,
          ),
          _SummaryChip(
            icon: Icons.perm_contact_calendar_outlined,
            label: 'มีผู้ติดต่อ ${summary['contact']}',
            color: AppTheme.info,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Table Header
// ─────────────────────────────────────────────────────────────────
class _SupplierTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  static const _cols = [
    ('ชื่อซัพพลายเออร์', 'name'),
    ('รหัส', 'code'),
    ('โทรศัพท์', 'phone'),
    ('ผู้ติดต่อ', 'contact'),
    ('เครดิต(วัน)', 'credit'),
    ('วงเงิน', 'limit'),
    ('สถานะ', 'status'),
    ('จัดการ', ''),
  ];

  const _SupplierTableHeader({
    required this.colWidths,
    required this.colMinW,
    required this.colMaxW,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
    required this.onResize,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return Container(
      color: colors.tableHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                'รหัส',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ...List.generate(_cols.length, (i) {
            final (label, sortKey) = _cols[i];
            final isActive = sortKey.isNotEmpty && sortColumn == sortKey;
            return _ResizableCell(
              label: label,
              sortKey: sortKey,
              width: colWidths[i],
              minWidth: colMinW[i],
              maxWidth: colMaxW[i],
              isActive: isActive,
              sortAsc: sortAsc,
              isLast: i == _cols.length - 1,
              onSort: sortKey.isNotEmpty ? () => onSort(sortKey) : null,
              onResize: (delta) {
                final nw = (colWidths[i] + delta).clamp(colMinW[i], colMaxW[i]);
                onResize(i, nw);
              },
            );
          }),
          Tooltip(
            message: 'รีเซตความกว้างคอลัมน์',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.settings_backup_restore,
                  size: 14,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Resizable Cell (reuse pattern จาก customer)
// ─────────────────────────────────────────────────────────────────
class _ResizableCell extends StatefulWidget {
  final String label;
  final String sortKey;
  final double width, minWidth, maxWidth;
  final bool isActive, sortAsc, isLast;
  final VoidCallback? onSort;
  final void Function(double) onResize;

  const _ResizableCell({
    required this.label,
    required this.sortKey,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.isActive,
    required this.sortAsc,
    required this.isLast,
    required this.onSort,
    required this.onResize,
  });

  @override
  State<_ResizableCell> createState() => _ResizableCellState();
}

class _ResizableCellState extends State<_ResizableCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFFF9D45);
    const inactiveColor = Colors.white70;
    final labelColor = widget.isActive ? activeColor : inactiveColor;
    final canSort = widget.onSort != null;

    return SizedBox(
      width: widget.width,
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: canSort
                ? InkWell(
                    onTap: widget.onSort,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            widget.isActive
                                ? (widget.sortAsc
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded)
                                : Icons.unfold_more_rounded,
                            size: 13,
                            color: widget.isActive
                                ? activeColor
                                : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: inactiveColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          if (!widget.isLast)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => widget.onResize(d.delta.dx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 8,
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: _hovering ? 22 : 12,
                    decoration: BoxDecoration(
                      color: _hovering
                          ? const Color(0xFFFF9D45)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Supplier Table Row (hover + AnimatedContainer)
// ─────────────────────────────────────────────────────────────────
class _SupplierRow extends StatefulWidget {
  final SupplierModel supplier;
  final List<double> colWidths;
  final Color avatarColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierRow({
    required this.supplier,
    required this.colWidths,
    required this.avatarColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SupplierRow> createState() => _SupplierRowState();
}

class _SupplierRowState extends State<_SupplierRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    final s = widget.supplier;
    final w = widget.colWidths;
    final initial = s.supplierName.isNotEmpty
        ? s.supplierName.substring(0, 1).toUpperCase()
        : '?';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? colors.rowHoverBg : colors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // ลำดับ (รหัสย่อ)
            SizedBox(
              width: 40,
              child: Text(
                s.supplierCode.length > 6
                    ? s.supplierCode.substring(s.supplierCode.length - 4)
                    : s.supplierCode,
                style: TextStyle(fontSize: 11, color: colors.rowIndexText),
              ),
            ),
            const SizedBox(width: 16),

            // ชื่อ + Avatar — w[0]
            SizedBox(
              width: w[0],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: widget.avatarColor,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.supplierName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // รหัส — w[1]
            SizedBox(
              width: w[1],
              child: Text(
                s.supplierCode,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.subtext),
              ),
            ),

            // โทรศัพท์ — w[2]
            SizedBox(
              width: w[2],
              child: Text(
                s.phone ?? '-',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.subtext),
              ),
            ),

            // ผู้ติดต่อ — w[3]
            SizedBox(
              width: w[3],
              child: Text(
                s.contactPerson ?? '-',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.subtext),
              ),
            ),

            // เครดิต — w[4]
            SizedBox(
              width: w[4],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: s.creditTerm > 0
                        ? const Color(0xFFE3F2FD)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.creditTerm > 0 ? '${s.creditTerm} วัน' : '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.creditTerm > 0
                          ? const Color(0xFF1565C0)
                          : colors.subtext,
                    ),
                  ),
                ),
              ),
            ),

            // วงเงิน — w[5]
            SizedBox(
              width: w[5],
              child: s.creditLimit > 0
                  ? Text(
                      '฿${s.creditLimit.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 13, color: colors.amountText),
                    )
                  : Text(
                      '-',
                      style: TextStyle(fontSize: 13, color: colors.subtext),
                    ),
            ),

            // สถานะ — w[6]
            SizedBox(
              width: w[6],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s.isActive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: s.isActive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.isActive ? 'ใช้งาน' : 'ระงับ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: s.isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // จัดการ — w[7]
            SizedBox(
              width: w[7],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF1565C0),
                    tooltip: 'แก้ไข',
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 6),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: const Color(0xFFC62828),
                    tooltip: 'ลบ',
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────
class _SupplierPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.local_shipping_outlined,
      color: AppTheme.primaryLight,
      size: 18,
    ),
  );
}

class _TopNavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopNavBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colors.navButtonBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.navButtonBorder),
          ),
          child: Icon(icon, size: 17, color: Colors.white70),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SupplierListColors.of(context);
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: colors.text),
        decoration: InputDecoration(
          hintText: 'ค้นหาซัพพลายเออร์...',
          hintStyle: TextStyle(fontSize: 13, color: colors.subtext),
          prefixIcon: Icon(Icons.search, size: 17, color: colors.subtext),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 15, color: colors.subtext),
                  onPressed: onCleared,
                )
              : null,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          filled: true,
          fillColor: colors.inputFill,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _ActiveToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: active ? 'แสดงทั้งหมด' : 'แสดงเฉพาะที่ใช้งาน',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.success.withValues(alpha: 0.10)
              : _SupplierListColors.of(context).navButtonBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppTheme.success.withValues(alpha: 0.30)
                : _SupplierListColors.of(context).navButtonBorder,
          ),
        ),
        child: Icon(
          Icons.verified_outlined,
          size: 17,
          color: active ? AppTheme.success : Colors.white70,
        ),
      ),
    ),
  );
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});

  @override
  Widget build(BuildContext context) =>
      _TopNavBtn(icon: Icons.refresh, tooltip: 'รีเฟรช', onTap: onTap);
}

class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AddBtn({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'เพิ่มซัพพลายเออร์',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: 13,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
  );
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

class _SupplierListColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color emptyIcon;
  final Color navButtonBg;
  final Color navButtonBorder;
  final Color rowHoverBg;
  final Color tableHeaderBg;
  final Color amountText;
  final Color rowIndexText;

  const _SupplierListColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.emptyIcon,
    required this.navButtonBg,
    required this.navButtonBorder,
    required this.rowHoverBg,
    required this.tableHeaderBg,
    required this.amountText,
    required this.rowIndexText,
  });

  factory _SupplierListColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SupplierListColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : Colors.grey,
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight.withValues(alpha: 0.60),
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      amountText: isDark ? AppTheme.primaryLight : AppTheme.info,
      rowIndexText: isDark ? const Color(0xFF8F8F8F) : const Color(0xFFBBBBBB),
    );
  }
}
