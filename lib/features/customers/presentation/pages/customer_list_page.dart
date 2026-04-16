import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/features/customers/data/models/customer_model.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';

import '../providers/customer_provider.dart';
import 'customer_detail_page.dart';
import 'customer_form_page.dart';
import 'customer_pdf_report.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();
  final _hScroll = ScrollController();
  final _currencyFmt = NumberFormat('#,##0');

  String _searchQuery = '';
  bool _showMembersOnly = false;
  bool _isTableView = true;
  bool _userResized = false;

  String _sortColumn = 'name';
  bool _sortAsc = true;

  int _currentPage = 1;

  final List<double> _colWidths = [220, 120, 130, 140, 90, 120, 90, 138];
  static const List<double> _colMinW = [140, 90, 90, 100, 80, 90, 80, 138];
  static const List<double> _colMaxW = [400, 220, 220, 220, 150, 190, 130, 138];

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFFE8622A),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF00897B),
      const Color(0xFFEF6C00),
      const Color(0xFF6A1B9A),
      const Color(0xFF3949AB),
      const Color(0xFFD81B60),
    ];
    if (name.isEmpty) return colors.first;
    return colors[name.codeUnitAt(0) % colors.length];
  }

  List<CustomerModel> _applyFilter(List<CustomerModel> customers) {
    return customers.where((c) {
      final isMember = c.memberNo != null && c.memberNo!.trim().isNotEmpty;
      if (_showMembersOnly && !isMember) return false;
      if (_searchQuery.isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      return c.customerName.toLowerCase().contains(q) ||
          c.customerCode.toLowerCase().contains(q) ||
          (c.phone?.toLowerCase().contains(q) ?? false) ||
          (c.memberNo?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CustomerModel> _applySort(List<CustomerModel> customers) {
    customers.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'name':
          cmp = a.customerName.compareTo(b.customerName);
        case 'code':
          cmp = a.customerCode.compareTo(b.customerCode);
        case 'phone':
          cmp = (a.phone ?? '').compareTo(b.phone ?? '');
        case 'memberNo':
          cmp = (a.memberNo ?? '').compareTo(b.memberNo ?? '');
        case 'points':
          cmp = a.points.compareTo(b.points);
        case 'creditLimit':
          cmp = a.creditLimit.compareTo(b.creditLimit);
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return customers;
  }

  Map<String, dynamic> _calcSummary(List<CustomerModel> customers) {
    final members = customers
        .where((c) => c.memberNo != null && c.memberNo!.trim().isNotEmpty)
        .length;
    final active = customers.where((c) => c.isActive).length;
    final creditLimit = customers.fold<double>(
      0,
      (sum, c) => sum + c.creditLimit,
    );

    return {
      'count': customers.length,
      'memberCount': members,
      'activeCount': active,
      'creditLimit': creditLimit,
    };
  }

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

  void _autoFitColWidths(List<CustomerModel> rows) {
    // Column definitions: (label, isSortable) — ตรงกับ _CustomerTableHeader._cols
    const headers = [
      ('ชื่อ-นามสกุล', true),
      ('รหัสลูกค้า', true),
      ('โทรศัพท์', true),
      ('เลขสมาชิก', true),
      ('คะแนน', true),
      ('วงเงินเครดิต', true),
      ('สถานะ', true),
      ('จัดการ', false),
    ];
    final headerStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = TextStyle(
      fontSize: 13,
      color: _CustomerListColors.of(context).subtext,
    );
    final emphasisStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _CustomerListColors.of(context).amountText,
    );
    final badgeStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    // ใช้ formula เดียวกับ product_list_page:
    //   colWidth = labelW + basePadding(16) + sortChrome(20 if sortable)
    //            + resizeHandle(14 if not last) + buffer(10)
    const basePadding = 16.0;
    const sortChrome = 20.0; // gap(4) + icon(12) + 4px buffer
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

    for (final c in rows) {
      // ชื่อ-นามสกุล: มี CircleAvatar (radius 18 → diameter 36) + gap 10 + text + buffer 10
      final nameW =
          _measureTextWidth(context, c.customerName, style: cellStyle) + 56;
      if (nameW > maxW[0]) maxW[0] = nameW;

      final codeW =
          _measureTextWidth(context, c.customerCode, style: cellStyle) + 20;
      if (codeW > maxW[1]) maxW[1] = codeW;

      final phoneW =
          _measureTextWidth(context, c.phone ?? '-', style: cellStyle) + 20;
      if (phoneW > maxW[2]) maxW[2] = phoneW;

      // เลขสมาชิก: ถ้ามี badge = icon(14)+gap(4)+text+badge-padding(24) = +42
      final isMember = c.memberNo != null && c.memberNo!.trim().isNotEmpty;
      final memberW =
          _measureTextWidth(
            context,
            c.memberNo ?? '-',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.warningColor,
            ),
          ) +
          (isMember ? 42 : 20);
      if (memberW > maxW[3]) maxW[3] = memberW;

      // คะแนน: ถ้ามี badge = text + 39
      final pointW =
          _measureTextWidth(
            context,
            isMember ? '${c.points} pt' : '-',
            style: isMember
                ? badgeStyle.copyWith(color: const Color(0xFFE65100))
                : cellStyle,
          ) +
          (isMember ? 39 : 20);
      if (pointW > maxW[4]) maxW[4] = pointW;

      final creditW =
          _measureTextWidth(
            context,
            c.creditLimit > 0 ? '฿${_currencyFmt.format(c.creditLimit)}' : '-',
            style: c.creditLimit > 0 ? emphasisStyle : cellStyle,
          ) +
          20;
      if (creditW > maxW[5]) maxW[5] = creditW;

      // สถานะ badge: dot(8)+gap(4)+text+horizontal-padding(22) = +34
      final statusLabel = c.isActive ? 'ใช้งาน' : 'ปิดใช้';
      final statusW =
          _measureTextWidth(context, statusLabel, style: badgeStyle) + 34;
      if (statusW > maxW[6]) maxW[6] = statusW;

      maxW[7] = 138; // จัดการ — fixed
    }

    for (int i = 0; i < maxW.length; i++) {
      maxW[i] = maxW[i].clamp(_colMinW[i], _colMaxW[i]);
    }

    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  Future<void> _openCreateForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerFormPage()),
    );
    if (!mounted) return;
    ref.read(customerListProvider.notifier).refresh();
  }

  Future<void> _openEditForm(CustomerModel customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormPage(customer: customer)),
    );
    if (!mounted) return;
    ref.read(customerListProvider.notifier).refresh();
  }

  void _openDetail(CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: customer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final colors = _CustomerListColors.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    final inlineFilters = isDesktop
        ? _ToggleChip(
            icon: Icons.card_membership,
            label: _showMembersOnly ? 'เฉพาะสมาชิก' : 'ลูกค้าทั้งหมด',
            active: _showMembersOnly,
            onTap: () => setState(() {
              _showMembersOnly = !_showMembersOnly;
              _currentPage = 1;
            }),
          )
        : null;

    return EscapePopScope(
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: Column(
          children: [
            _CustomerListTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
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
              onToggleView: () => setState(() => _isTableView = !_isTableView),
              onRefresh: () =>
                  ref.read(customerListProvider.notifier).refresh(),
              onAdd: _openCreateForm,
            ),
            if (!isDesktop)
              _CustomerFilterBar(
                searchController: _searchController,
                searchQuery: _searchQuery,
                showMembersOnly: _showMembersOnly,
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
                onToggleMember: () => setState(() {
                  _showMembersOnly = !_showMembersOnly;
                  _currentPage = 1;
                }),
                onToggleView: () =>
                    setState(() => _isTableView = !_isTableView),
              ),
            Expanded(
              child: customerAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => _buildError(e),
                data: (customers) {
                  final filtered = _applySort(_applyFilter(customers));
                  final summary = _calcSummary(filtered);

                  if (filtered.isEmpty) return _buildEmpty(customers.isEmpty);

                  final totalPages = (filtered.length / pageSize).ceil();
                  final safePage = _currentPage.clamp(1, totalPages);
                  final pageStart = (safePage - 1) * pageSize;
                  final pageEnd = (pageStart + pageSize).clamp(
                    0,
                    filtered.length,
                  );
                  final pageItems = filtered.sublist(pageStart, pageEnd);

                  final screenWidth = MediaQuery.of(context).size.width - 32;
                  if (_isTableView && !_userResized) {
                    _autoFitColWidths(filtered);
                  }

                  final totalW =
                      40.0 +
                      16.0 +
                      _colWidths.fold(0.0, (sum, w) => sum + w) +
                      28.0 +
                      32.0;
                  final tableW = totalW > screenWidth ? totalW : screenWidth;

                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                      boxShadow: [
                        if (!colors.isDark)
                          BoxShadow(
                            color: AppTheme.navy.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _CustomerSummaryBar(
                          summary: summary,
                          fmt: _currencyFmt,
                          inlineFilters: inlineFilters,
                        ),
                        Divider(height: 1, color: colors.border),
                        Expanded(
                          child: _isTableView
                              ? Scrollbar(
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
                                          _CustomerTableHeader(
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
                                                220,
                                                120,
                                                130,
                                                140,
                                                90,
                                                120,
                                                90,
                                                138,
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
                                              itemBuilder: (context, index) {
                                                final customer =
                                                    pageItems[index];
                                                return _CustomerRow(
                                                  customer: customer,
                                                  colWidths: _colWidths,
                                                  avatarColor:
                                                      customer.customerId ==
                                                          'WALK_IN'
                                                      ? const Color(0xFF546E7A)
                                                      : _avatarColor(
                                                          customer.customerName,
                                                        ),
                                                  onTap: () =>
                                                      _openDetail(customer),
                                                  onEdit:
                                                      customer.customerId ==
                                                          'WALK_IN'
                                                      ? null
                                                      : () => _openEditForm(
                                                          customer,
                                                        ),
                                                  onDelete:
                                                      customer.customerId ==
                                                          'WALK_IN'
                                                      ? null
                                                      : () => _confirmDelete(
                                                          customer.customerId,
                                                          customer.customerName,
                                                        ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : _buildCustomerCardView(pageItems),
                        ),
                        PaginationBar(
                          currentPage: safePage,
                          totalItems: filtered.length,
                          pageSize: pageSize,
                          onPageChanged: (p) =>
                              setState(() => _currentPage = p),
                          trailing: PdfReportButton(
                            emptyMessage: 'ไม่มีข้อมูลลูกค้า',
                            title: 'รายงานลูกค้า',
                            filename: () =>
                                PdfFilename.generate('customer_report'),
                            buildPdf: () => CustomerPdfBuilder.build(filtered),
                            hasData: filtered.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCardView(List<CustomerModel> customers) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: _CustomerListColors.of(context).border),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final isSystem = customer.customerId == 'WALK_IN';
        final isMember =
            customer.memberNo != null && customer.memberNo!.trim().isNotEmpty;
        final initial = customer.customerName.isNotEmpty
            ? customer.customerName.substring(0, 1).toUpperCase()
            : '?';

        final colors = _CustomerListColors.of(context);

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.border),
          ),
          color: colors.cardBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openDetail(customer),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isSystem
                            ? const Color(0xFF546E7A)
                            : _avatarColor(customer.customerName),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isMember)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.card_membership,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                customer.customerName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(isActive: customer.isActive),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'รหัส: ${customer.customerCode}',
                          style: TextStyle(fontSize: 11, color: colors.subtext),
                        ),
                        if (customer.phone != null &&
                            customer.phone!.trim().isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 11,
                                color: colors.subtext,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  customer.phone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.subtext,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isMember)
                              _MemberBadge(
                                memberNo: customer.memberNo!,
                                points: customer.points,
                              ),
                            if (customer.creditLimit > 0)
                              Text(
                                'วงเงิน ฿${_currencyFmt.format(customer.creditLimit)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.amountText,
                                ),
                              ),
                            if (!isMember)
                              Text(
                                'แต้ม ${customer.points} pt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.subtext,
                                ),
                              ),
                            if (isSystem)
                              Text(
                                'ลูกค้าระบบ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.subtext,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionPill(
                        icon: Icons.open_in_new,
                        tooltip: 'ดูรายละเอียด',
                        color: AppTheme.primary,
                        compact: true,
                        onTap: () => _openDetail(customer),
                      ),
                      if (!isSystem) ...[
                        const SizedBox(height: 4),
                        _ActionPill(
                          icon: Icons.edit_outlined,
                          tooltip: 'แก้ไข',
                          color: AppTheme.info,
                          compact: true,
                          onTap: () => _openEditForm(customer),
                        ),
                        const SizedBox(height: 4),
                        _ActionPill(
                          icon: Icons.delete_outline,
                          tooltip: 'ลบ',
                          color: AppTheme.error,
                          compact: true,
                          onTap: () => _confirmDelete(
                            customer.customerId,
                            customer.customerName,
                          ),
                        ),
                      ],
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

  Future<void> _confirmDelete(String id, String name) async {
    final check = await ref
        .read(customerListProvider.notifier)
        .checkDeleteCustomer(id);
    if (!mounted) return;

    final hasHistory = check['has_history'] == true;
    final orderCount = (check['order_count'] as int?) ?? 0;
    final hasPoints = check['has_points'] == true;

    final details = [
      if (orderCount > 0) 'ประวัติการซื้อ $orderCount รายการ',
      if (hasPoints) 'ประวัติสะสมแต้ม',
    ].join(' และ ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: hasHistory ? 'ปิดการใช้งานลูกค้า' : 'ลบลูกค้าถาวร',
          icon: hasHistory ? Icons.archive_outlined : Icons.delete_outline,
          iconColor: hasHistory ? AppTheme.warningColor : AppTheme.error,
        ),
        content: hasHistory
            ? Text(
                'ลูกค้า "$name" มี$details\n\nไม่สามารถลบได้ ระบบจะปิดการใช้งานแทนเพื่อเก็บประวัติไว้',
              )
            : Text('ต้องการลบลูกค้า "$name" ออกจากระบบอย่างถาวรใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(
              hasHistory ? Icons.pause_circle_outline : Icons.delete_forever,
              size: 16,
            ),
            label: Text(hasHistory ? 'ปิดการใช้งาน' : 'ลบถาวร'),
            style: FilledButton.styleFrom(
              backgroundColor: hasHistory
                  ? AppTheme.warningColor
                  : AppTheme.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final message = await ref
        .read(customerListProvider.notifier)
        .deleteCustomer(id);
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

  Widget _buildEmpty(bool noData) {
    final colors = _CustomerListColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.emptyIconBg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              _showMembersOnly ? Icons.card_membership : Icons.people_outline,
              size: 38,
              color: colors.emptyIcon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noData ? 'ยังไม่มีข้อมูลลูกค้า' : 'ไม่พบลูกค้าที่ตรงกับเงื่อนไข',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noData
                ? 'เมื่อลงทะเบียนลูกค้า รายการจะปรากฏที่หน้านี้'
                : 'ลองปรับคำค้นหา สลับมุมมอง หรือแสดงลูกค้าทั้งหมดอีกครั้ง',
            style: TextStyle(fontSize: 13, color: colors.subtext),
          ),
          const SizedBox(height: 12),
          if (_showMembersOnly)
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _showMembersOnly = false;
                _currentPage = 1;
              }),
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('แสดงลูกค้าทั้งหมด'),
            )
          else
            ElevatedButton.icon(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('เพิ่มลูกค้า'),
            ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    final colors = _CustomerListColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text(
            'เกิดข้อผิดพลาด: $error',
            style: TextStyle(color: colors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(customerListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

class _CustomerListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _CustomerListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  static const _kBreak = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();
    final colors = _CustomerListColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.topBarBg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildWide(context, canPop, colors.isDark)
          : _buildNarrow(context, canPop, colors.isDark),
    );
  }

  Widget _buildWide(BuildContext context, bool canPop, bool isDark) {
    return Row(
      children: [
        _TopBarLeading(canPop: canPop, isDark: isDark),
        const SizedBox(width: 10),
        const _TopBarPageIcon(),
        const SizedBox(width: 10),
        const Text(
          'รายการลูกค้า',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _TopSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ),
        const SizedBox(width: 8),
        _ViewModeChip(isTableView: isTableView, onTap: onToggleView),
        const SizedBox(width: 8),
        _TopBarRefreshButton(onTap: onRefresh),
        const SizedBox(width: 8),
        _TopBarAddButton(onTap: onAdd),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'Customer List',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context, bool canPop, bool isDark) {
    return Row(
      children: [
        _TopBarLeading(canPop: canPop, isDark: isDark),
        const SizedBox(width: 8),
        const _TopBarPageIcon(),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'รายการลูกค้า',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _ViewModeChip(isTableView: isTableView, onTap: onToggleView),
        const SizedBox(width: 6),
        _TopBarRefreshButton(onTap: onRefresh),
        const SizedBox(width: 6),
        _TopBarAddButton(onTap: onAdd, compact: true),
      ],
    );
  }
}

class _CustomerFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showMembersOnly;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleMember;
  final VoidCallback onToggleView;

  const _CustomerFilterBar({
    required this.searchController,
    required this.searchQuery,
    required this.showMembersOnly,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleMember,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.searchBarBg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          _TopSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
            fillColor: colors.inputFill,
            textColor: colors.text,
            hintColor: colors.subtext,
            iconColor: colors.subtext,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  icon: Icons.card_membership,
                  label: showMembersOnly ? 'เฉพาะสมาชิก' : 'ลูกค้าทั้งหมด',
                  active: showMembersOnly,
                  onTap: onToggleMember,
                ),
              ),
              const SizedBox(width: 8),
              _ViewModeChip(isTableView: isTableView, onTap: onToggleView),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSummaryBar extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat fmt;
  final Widget? inlineFilters;

  const _CustomerSummaryBar({
    required this.summary,
    required this.fmt,
    this.inlineFilters,
  });

  @override
  Widget build(BuildContext context) {
    final count = summary['count'] as int;
    final memberCount = summary['memberCount'] as int;
    final activeCount = summary['activeCount'] as int;
    final creditLimit = summary['creditLimit'] as double;

    final chips = [
      _SummaryChip(
        icon: Icons.people_outline,
        label: '$count รายการ',
        color: AppTheme.info,
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.card_membership,
        label: '$memberCount สมาชิก',
        color: AppTheme.success,
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.verified_user_outlined,
        label: '$activeCount ใช้งาน',
        color: AppTheme.primary,
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.account_balance_wallet_outlined,
        label: '฿${fmt.format(creditLimit)}',
        color: const Color(0xFF6A1B9A),
      ),
    ];

    final colors = _CustomerListColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: colors.summaryBg),
      child: inlineFilters != null
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: chips),
                      const SizedBox(width: 16),
                      inlineFilters!,
                    ],
                  ),
                ),
              ),
            )
          : Wrap(spacing: 12, runSpacing: 8, children: chips),
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
    final colors = _CustomerListColors.of(context);
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

class _CustomerTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  static const _cols = [
    ('ชื่อ-นามสกุล', 'name'),
    ('รหัสลูกค้า', 'code'),
    ('โทรศัพท์', 'phone'),
    ('เลขสมาชิก', 'memberNo'),
    ('คะแนน', 'points'),
    ('วงเงินเครดิต', 'creditLimit'),
    ('สถานะ', 'status'),
    ('จัดการ', ''),
  ];

  const _CustomerTableHeader({
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
    final colors = _CustomerListColors.of(context);
    return Container(
      decoration: BoxDecoration(color: colors.tableHeaderBg),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                '#',
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
            return _ResizableHeaderCell(
              label: label,
              width: colWidths[i],
              minWidth: colMinW[i],
              maxWidth: colMaxW[i],
              isActive: isActive,
              sortAsc: sortAsc,
              rightAligned: sortKey == 'creditLimit',
              isLast: i == _cols.length - 1,
              onSort: sortKey.isNotEmpty ? () => onSort(sortKey) : null,
              onResize: (delta) {
                final newW = (colWidths[i] + delta).clamp(
                  colMinW[i],
                  colMaxW[i],
                );
                onResize(i, newW);
              },
            );
          }),
          Tooltip(
            message: 'รีเซตความกว้างคอลัมน์',
            waitDuration: const Duration(milliseconds: 600),
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

class _ResizableHeaderCell extends StatefulWidget {
  final String label;
  final double width;
  final double minWidth;
  final double maxWidth;
  final bool isActive;
  final bool sortAsc;
  final bool rightAligned;
  final bool isLast;
  final VoidCallback? onSort;
  final void Function(double delta) onResize;

  const _ResizableHeaderCell({
    required this.label,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.isActive,
    required this.sortAsc,
    this.rightAligned = false,
    required this.isLast,
    required this.onSort,
    required this.onResize,
  });

  @override
  State<_ResizableHeaderCell> createState() => _ResizableHeaderCellState();
}

class _ResizableHeaderCellState extends State<_ResizableHeaderCell> {
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
                        children: [
                          Expanded(
                            child: Align(
                              alignment: widget.rightAligned
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
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
                    child: Align(
                      alignment: widget.rightAligned
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
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

class _CustomerRow extends StatefulWidget {
  final CustomerModel customer;
  final List<double> colWidths;
  final Color avatarColor;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CustomerRow({
    required this.customer,
    required this.colWidths,
    required this.avatarColor,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    final customer = widget.customer;
    final isMember =
        customer.memberNo != null && customer.memberNo!.trim().isNotEmpty;
    final isSystem = customer.customerId == 'WALK_IN';
    final initial = customer.customerName.isNotEmpty
        ? customer.customerName.substring(0, 1).toUpperCase()
        : '?';
    final w = widget.colWidths;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: _hovered ? colors.rowHoverBg : colors.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    customer.customerCode.length > 6
                        ? customer.customerCode.substring(
                            customer.customerCode.length - 4,
                          )
                        : customer.customerCode,
                    style: TextStyle(fontSize: 11, color: colors.subtext),
                  ),
                ),
                const SizedBox(width: 16),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          customer.customerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: w[1],
                  child: Text(
                    customer.customerCode,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.subtext),
                  ),
                ),
                SizedBox(
                  width: w[2],
                  child: Text(
                    customer.phone ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.subtext),
                  ),
                ),
                SizedBox(
                  width: w[3],
                  child: isMember
                      ? _MemberInlineBadge(memberNo: customer.memberNo!)
                      : Text(
                          '-',
                          style: TextStyle(fontSize: 13, color: colors.subtext),
                        ),
                ),
                SizedBox(
                  width: w[4],
                  child: isMember
                      ? _PointsBadge(points: customer.points)
                      : Text(
                          '-',
                          style: TextStyle(fontSize: 13, color: colors.subtext),
                        ),
                ),
                SizedBox(
                  width: w[5],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      customer.creditLimit > 0
                          ? '฿${NumberFormat('#,##0').format(customer.creditLimit)}'
                          : '-',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: customer.creditLimit > 0
                            ? colors.amountText
                            : colors.subtext,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: w[6],
                  child: Center(
                    child: _StatusBadge(isActive: customer.isActive),
                  ),
                ),
                SizedBox(
                  width: w[7],
                  child: isSystem
                      ? const Center(
                          child: _InfoChip(
                            icon: Icons.shield_outlined,
                            label: 'ระบบ',
                            color: AppTheme.textSub,
                            compact: true,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionPill(
                              icon: Icons.open_in_new,
                              tooltip: 'ดูรายละเอียด',
                              color: AppTheme.primary,
                              onTap: widget.onTap,
                              compact: true,
                            ),
                            const SizedBox(width: 6),
                            _ActionPill(
                              icon: Icons.edit_outlined,
                              tooltip: 'แก้ไข',
                              color: AppTheme.info,
                              onTap: widget.onEdit!,
                              compact: true,
                            ),
                            const SizedBox(width: 6),
                            _ActionPill(
                              icon: Icons.delete_outline,
                              tooltip: 'ลบ',
                              color: AppTheme.error,
                              onTap: widget.onDelete!,
                              compact: true,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarLeading extends StatelessWidget {
  final bool canPop;
  final bool isDark;

  const _TopBarLeading({required this.canPop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (canPop) {
      return _TopBarIconButton(
        icon: Icons.arrow_back,
        tooltip: 'ย้อนกลับ',
        onTap: () => Navigator.of(context).maybePop(),
      );
    }
    if (context.isMobile) {
      return buildMobileHomeCompactButton(context, isDark: isDark);
    }
    return const SizedBox.shrink();
  }
}

class _TopBarPageIcon extends StatelessWidget {
  const _TopBarPageIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.people_outline, color: Colors.white, size: 18),
    );
  }
}

class _TopSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? iconColor;

  const _TopSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: textColor ?? colors.text),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อ, รหัส, โทร, สมาชิก...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: hintColor ?? colors.subtext,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 17,
            color: iconColor ?? colors.subtext,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 15),
                  onPressed: onCleared,
                )
              : null,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          filled: true,
          fillColor: fillColor ?? colors.inputFill,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.08)
              : colors.neutralChipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppTheme.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.primary : colors.subtext,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? AppTheme.primary : colors.subtext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeChip extends StatelessWidget {
  final bool isTableView;
  final VoidCallback onTap;

  const _ViewModeChip({required this.isTableView, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TopBarIconButton(
      icon: isTableView
          ? Icons.view_agenda_outlined
          : Icons.table_rows_outlined,
      tooltip: isTableView ? 'Card View' : 'Table View',
      onTap: onTap,
      lightScheme: false,
    );
  }
}

class _TopBarRefreshButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TopBarRefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TopBarIconButton(
      icon: Icons.refresh,
      tooltip: 'รีเฟรช',
      onTap: onTap,
    );
  }
}

class _TopBarAddButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _TopBarAddButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: compact
          ? const SizedBox.shrink()
          : const Text(
              'เพิ่มลูกค้า',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
      style: ElevatedButton.styleFrom(
        backgroundColor: compact ? colors.navButtonBg : AppTheme.primary,
        foregroundColor: compact ? Colors.white70 : Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 13,
        ),
        minimumSize: Size.zero,
        elevation: 0,
        side: compact ? BorderSide(color: colors.navButtonBorder) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool lightScheme;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.lightScheme = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: lightScheme ? colors.navButtonBg : colors.neutralChipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: lightScheme ? colors.navButtonBorder : colors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: lightScheme ? Colors.white70 : colors.subtext,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.success : AppTheme.error;
    final bg = isActive ? AppTheme.successContainer : AppTheme.errorContainer;
    final label = isActive ? 'ใช้งาน' : 'ปิดใช้';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberInlineBadge extends StatelessWidget {
  final String memberNo;

  const _MemberInlineBadge({required this.memberNo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.card_membership,
          size: 13,
          color: AppTheme.warningColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            memberNo,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.warningColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final int points;

  const _PointsBadge({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warningLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars, size: 12, color: AppTheme.warningColor),
          const SizedBox(width: 3),
          Text(
            '$points pt',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final String memberNo;
  final int points;

  const _MemberBadge({required this.memberNo, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warningLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_membership,
            size: 13,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 5),
          Text(
            '$memberNo · $points pt',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.info,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _CustomerListColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ActionPill({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _CustomerListColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color searchBarBg;
  final Color tableHeaderBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color rowHoverBg;
  final Color emptyIconBg;
  final Color emptyIcon;
  final Color neutralChipBg;
  final Color navButtonBg;
  final Color navButtonBorder;
  final Color amountText;

  const _CustomerListColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.searchBarBg,
    required this.tableHeaderBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.rowHoverBg,
    required this.emptyIconBg,
    required this.emptyIcon,
    required this.neutralChipBg,
    required this.navButtonBg,
    required this.navButtonBorder,
    required this.amountText,
  });

  factory _CustomerListColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CustomerListColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      searchBarBg: isDark ? AppTheme.darkTopBar : Colors.white,
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : Colors.grey,
      neutralChipBg: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
      amountText: isDark ? AppTheme.primaryLight : AppTheme.info,
    );
  }
}
