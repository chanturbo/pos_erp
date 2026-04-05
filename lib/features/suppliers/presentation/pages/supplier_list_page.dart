import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
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
  String _searchQuery  = '';
  bool   _isTableView  = true;
  bool   _activeOnly   = false;
  bool   _userResized  = false;

  // ── Sort ────────────────────────────────────────────────────────
  String _sortColumn = 'name';
  bool   _sortAsc    = true;

  // ── Pagination ──────────────────────────────────────────────────
  int _currentPage = 1;

  // ── Column widths [ชื่อ, รหัส, โทร, ผู้ติดต่อ, เครดิต, วงเงิน, สถานะ, จัดการ]
  final List<double> _colWidths = [200, 100, 120, 140, 80, 110, 80, 100];
  static const List<double> _colMinW  = [120, 70, 80, 80, 60, 80, 70, 100];
  static const List<double> _colMaxW  = [400, 200, 220, 260, 120, 200, 120, 100];

  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFFE8622A), Color(0xFF4CAF50), Color(0xFF2196F3),
      Color(0xFF9C27B0), Color(0xFFFF5722), Color(0xFF009688),
      Color(0xFF3F51B5), Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ───────────────────────────────────────────
          _SupplierListTopBar(
            searchController: _searchController,
            searchQuery:  _searchQuery,
            activeOnly:   _activeOnly,
            isTableView:  _isTableView,
            onSearchChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
            onSearchCleared: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _currentPage = 1; });
            },
            onToggleActive: () =>
                setState(() { _activeOnly = !_activeOnly; _currentPage = 1; }),
            onToggleView: () => setState(() => _isTableView = !_isTableView),
            onRefresh: () => ref.read(supplierListProvider.notifier).refresh(),
            onAdd: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierFormPage()),
              );
              if (context.mounted) {
                ref.read(supplierListProvider.notifier).refresh();
              }
            },
          ),
          const Divider(height: 1, color: AppTheme.border),

          // ── Content ──────────────────────────────────────────
          Expanded(
            child: supplierAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => _buildError(e),
              data: (suppliers) {
                final filtered = suppliers.where((s) {
                  if (_activeOnly && !s.isActive) return false;
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return s.supplierName.toLowerCase().contains(q) ||
                      s.supplierCode.toLowerCase().contains(q) ||
                      (s.phone?.toLowerCase().contains(q) ?? false) ||
                      (s.contactPerson?.toLowerCase().contains(q) ?? false);
                }).toList();

                // ── Sort ──────────────────────────────────────
                filtered.sort((a, b) {
                  int cmp;
                  switch (_sortColumn) {
                    case 'name':    cmp = a.supplierName.compareTo(b.supplierName);
                    case 'code':    cmp = a.supplierCode.compareTo(b.supplierCode);
                    case 'phone':   cmp = (a.phone ?? '').compareTo(b.phone ?? '');
                    case 'contact': cmp = (a.contactPerson ?? '').compareTo(b.contactPerson ?? '');
                    case 'credit':  cmp = a.creditTerm.compareTo(b.creditTerm);
                    case 'limit':   cmp = a.creditLimit.compareTo(b.creditLimit);
                    case 'status':  cmp = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
                    default: cmp = 0;
                  }
                  return _sortAsc ? cmp : -cmp;
                });

                if (filtered.isEmpty) return _buildEmpty();

                // Pagination
                final totalPages = (filtered.length / pageSize).ceil();
                final safePage   = _currentPage.clamp(1, totalPages);
                final start = (safePage - 1) * pageSize;
                final end   = (start + pageSize).clamp(0, filtered.length);
                final pageItems = filtered.sublist(start, end);

                // ── Card View ────────────────────────────────
                if (!_isTableView) {
                  return Column(
                    children: [
                      Expanded(child: _buildCardView(pageItems)),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems:  filtered.length,
                        pageSize:    pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลซัพพลายเออร์',
                          title:    'รายงานซัพพลายเออร์',
                          filename: () => PdfFilename.generate('supplier_report'),
                          buildPdf: () => SupplierPdfBuilder.build(
                              List<SupplierModel>.from(filtered)),
                          hasData:  filtered.isNotEmpty,
                        ),
                      ),
                    ],
                  );
                }

                // ── Table View ───────────────────────────────
                final screenW = MediaQuery.of(context).size.width - 32;
                if (!_userResized) _autoFitColWidths(filtered, screenW);

                final totalW = 40.0 + 16.0 +
                    _colWidths.fold(0.0, (s, w) => s + w) +
                    28.0 + 32.0;
                final tableW = totalW > screenW ? totalW : screenW;

                return Stack(children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
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
                                      colMinW:   _colMinW,
                                      colMaxW:   _colMaxW,
                                      sortColumn: _sortColumn,
                                      sortAsc:    _sortAsc,
                                      onSort: (col) => setState(() {
                                        if (_sortColumn == col) {
                                          _sortAsc = !_sortAsc;
                                        } else {
                                          _sortColumn = col;
                                          _sortAsc    = true;
                                        }
                                        _currentPage = 1;
                                      }),
                                      onResize: (i, w) => setState(() {
                                        _colWidths[i] = w;
                                        _userResized  = true;
                                      }),
                                      onReset: () => setState(() {
                                        _colWidths.setAll(0,
                                            [200, 100, 120, 140, 80, 110, 80, 100]);
                                        _userResized = false;
                                      }),
                                    ),
                                    const Divider(height: 1, color: AppTheme.border),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: pageItems.length,
                                        separatorBuilder: (_, _) => const Divider(
                                            height: 1, color: AppTheme.border),
                                        itemBuilder: (_, i) {
                                          final s = pageItems[i];
                                          return _SupplierRow(
                                            supplier: s,
                                            colWidths: _colWidths,
                                            avatarColor: _avatarColor(s.supplierName),
                                            onEdit: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SupplierFormPage(supplier: s),
                                                ),
                                              );
                                              if (context.mounted) {
                                                ref.read(supplierListProvider
                                                    .notifier).refresh();
                                              }
                                            },
                                            onDelete: () => _confirmDelete(s),
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
                          totalItems:  filtered.length,
                          pageSize:    pageSize,
                          onPageChanged: (p) => setState(() => _currentPage = p),
                          trailing: PdfReportButton(
                            emptyMessage: 'ไม่มีข้อมูลซัพพลายเออร์',
                            title:    'รายงานซัพพลายเออร์',
                            filename: () => PdfFilename.generate('supplier_report'),
                            buildPdf: () => SupplierPdfBuilder.build(
                                List<SupplierModel>.from(filtered)),
                            hasData:  filtered.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Card View ──────────────────────────────────────────────────
  Widget _buildCardView(List<SupplierModel> suppliers) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s       = suppliers[i];
        final initial = s.supplierName.isNotEmpty
            ? s.supplierName.substring(0, 1).toUpperCase()
            : '?';
        final color = _avatarColor(s.supplierName);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.border),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppTheme.primaryLight.withValues(alpha: 0.6),
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.isActive
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5, height: 5,
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
                          Text('รหัส: ${s.supplierCode}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSub)),
                          if (s.phone != null)
                            Row(children: [
                              const Icon(Icons.phone_outlined,
                                  size: 11, color: AppTheme.textSub),
                              const SizedBox(width: 3),
                              Text(s.phone!,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textSub)),
                            ]),
                          if (s.contactPerson != null)
                            Row(children: [
                              const Icon(Icons.person_outline,
                                  size: 11, color: AppTheme.textSub),
                              const SizedBox(width: 3),
                              Text(s.contactPerson!,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textSub),
                                  overflow: TextOverflow.ellipsis),
                            ]),
                          if (s.creditLimit > 0)
                            Text(
                              'เครดิต ${s.creditTerm} วัน  ·  วงเงิน ฿${s.creditLimit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF1565C0)),
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
                                  builder: (_) => SupplierFormPage(supplier: s)),
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
  void _autoFitColWidths(List<SupplierModel> rows, double screenW) {
    const hPad     = 16.0;
    const sortIcon = 16.0;
    const hCharW   = 7.5;
    final labels  = ['ชื่อซัพพลายเออร์', 'รหัส', 'โทรศัพท์', 'ผู้ติดต่อ',
                     'เครดิต(วัน)', 'วงเงิน', 'สถานะ', 'จัดการ'];
    final hasSort = [true, true, true, true, true, true, true, false];

    final headerMinW = List<double>.generate(labels.length, (i) {
      final lw = labels[i].length * hCharW + hPad;
      return hasSort[i] ? lw + sortIcon : lw;
    });

    final maxW = List<double>.from(headerMinW);
    const charW  = 7.2;
    const cPad   = 24.0;

    for (final s in rows) {
      final nameW = s.supplierName.length * charW + 46 + cPad;
      if (nameW > maxW[0]) maxW[0] = nameW.clamp(_colMinW[0], _colMaxW[0]);
      final codeW = s.supplierCode.length * charW + cPad;
      if (codeW > maxW[1]) maxW[1] = codeW.clamp(_colMinW[1], _colMaxW[1]);
      final phoneW = (s.phone?.length ?? 1) * charW + cPad;
      if (phoneW > maxW[2]) maxW[2] = phoneW.clamp(_colMinW[2], _colMaxW[2]);
      final contactW = (s.contactPerson?.length ?? 1) * charW + cPad;
      if (contactW > maxW[3]) maxW[3] = contactW.clamp(_colMinW[3], _colMaxW[3]);
    }

    for (int i = 0; i < maxW.length; i++) {
      maxW[i] = maxW[i].clamp(_colMinW[i], _colMaxW[i]);
    }
    maxW[7] = 100.0;

    const totalFixed = 116.0;
    final totalCols  = maxW.fold(0.0, (s, w) => s + w);
    final available  = screenW - totalFixed;
    if (totalCols < available) {
      maxW[0] = (maxW[0] + (available - totalCols))
          .clamp(_colMinW[0], _colMaxW[0]);
    }
    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  // ── Detail dialog ──────────────────────────────────────────────
  void _showSupplierDetails(SupplierModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _avatarColor(s.supplierName),
            child: Text(
              s.supplierName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s.supplierName,
              style: const TextStyle(fontSize: 16))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('รหัส',           s.supplierCode),
              _DetailRow('ผู้ติดต่อ',      s.contactPerson ?? '-'),
              _DetailRow('โทรศัพท์',       s.phone         ?? '-'),
              _DetailRow('อีเมล',          s.email         ?? '-'),
              _DetailRow('Line ID',        s.lineId        ?? '-'),
              _DetailRow('ที่อยู่',         s.address       ?? '-'),
              _DetailRow('เลขผู้เสียภาษี', s.taxId         ?? '-'),
              _DetailRow('เครดิต',         '${s.creditTerm} วัน'),
              _DetailRow('วงเงินเครดิต',   '฿${s.creditLimit.toStringAsFixed(0)}'),
              _DetailRow('สถานะ',          s.isActive ? 'ใช้งาน' : 'ระงับ'),
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
                    builder: (_) => SupplierFormPage(supplier: s)),
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

    final details = orderCount > 0 ? 'ประวัติการสั่งซื้อ $orderCount รายการ' : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(
            hasHistory ? Icons.archive_outlined : Icons.delete_outline,
            color: hasHistory ? AppTheme.warningColor : AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(hasHistory ? 'ปิดการใช้งานซัพพลายเออร์' : 'ลบซัพพลายเออร์ถาวร'),
        ]),
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
              backgroundColor:
                  hasHistory ? AppTheme.warningColor : AppTheme.error,
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? message : 'ดำเนินการไม่สำเร็จ'),
      backgroundColor: success ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'ยังไม่มีซัพพลายเออร์' : 'ไม่พบซัพพลายเออร์ที่ค้นหา',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SupplierFormPage()));
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
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Text('เกิดข้อผิดพลาด: $e'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(supplierListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
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
          child: Text('$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
  final TextEditingController searchController;
  final String  searchQuery;
  final bool    activeOnly;
  final bool    isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _SupplierListTopBar({
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

  static const _kBreak = 720.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop)
          : _buildDoubleRow(context, canPop),
    );
  }

  Widget _buildSingleRow(BuildContext context, bool canPop) => Row(
    children: [
      if (canPop) ...[
        _BackBtn(onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 10),
      ],
      _SupplierPageIcon(),
      const SizedBox(width: 10),
      const Text('ซัพพลายเออร์',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A))),
      const Spacer(),
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
      Tooltip(
        message: isTableView ? 'Card View' : 'Table View',
        child: InkWell(
          onTap: onToggleView,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(
              isTableView ? Icons.view_agenda_outlined : Icons.table_rows_outlined,
              size: 17, color: AppTheme.textSub,
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      _RefreshBtn(onTap: onRefresh),
      const SizedBox(width: 6),
      _AddBtn(onTap: onAdd),
    ],
  );

  Widget _buildDoubleRow(BuildContext context, bool canPop) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        if (canPop) ...[
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
        ],
        _SupplierPageIcon(),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('ซัพพลายเออร์',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
              overflow: TextOverflow.ellipsis),
        ),
        _ActiveToggle(active: activeOnly, onTap: onToggleActive),
        const SizedBox(width: 4),
        Tooltip(
          message: isTableView ? 'Card View' : 'Table View',
          child: InkWell(
            onTap: onToggleView,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(
                isTableView ? Icons.view_agenda_outlined : Icons.table_rows_outlined,
                size: 17, color: AppTheme.textSub,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _RefreshBtn(onTap: onRefresh),
        const SizedBox(width: 4),
        _AddBtn(onTap: onAdd, compact: true),
      ]),
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

// ─────────────────────────────────────────────────────────────────
// Table Header
// ─────────────────────────────────────────────────────────────────
class _SupplierTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool   sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  static const _cols = [
    ('ชื่อซัพพลายเออร์', 'name'),
    ('รหัส',             'code'),
    ('โทรศัพท์',         'phone'),
    ('ผู้ติดต่อ',         'contact'),
    ('เครดิต(วัน)',      'credit'),
    ('วงเงิน',           'limit'),
    ('สถานะ',            'status'),
    ('จัดการ',           ''),
  ];

  const _SupplierTableHeader({
    required this.colWidths, required this.colMinW, required this.colMaxW,
    required this.sortColumn, required this.sortAsc,
    required this.onSort, required this.onResize, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          const SizedBox(width: 40, height: 40,
            child: Center(child: Text('รหัส',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.white70)))),
          const SizedBox(width: 16),
          ...List.generate(_cols.length, (i) {
            final (label, sortKey) = _cols[i];
            final isActive = sortKey.isNotEmpty && sortColumn == sortKey;
            return _ResizableCell(
              label: label, sortKey: sortKey,
              width: colWidths[i], minWidth: colMinW[i], maxWidth: colMaxW[i],
              isActive: isActive, sortAsc: sortAsc,
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
                child: Icon(Icons.settings_backup_restore,
                    size: 14, color: Colors.white54),
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
    required this.label, required this.sortKey,
    required this.width, required this.minWidth, required this.maxWidth,
    required this.isActive, required this.sortAsc, required this.isLast,
    required this.onSort, required this.onResize,
  });

  @override
  State<_ResizableCell> createState() => _ResizableCellState();
}

class _ResizableCellState extends State<_ResizableCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const activeColor   = Color(0xFFFF9D45);
    const inactiveColor = Colors.white70;
    final labelColor    = widget.isActive ? activeColor : inactiveColor;
    final canSort       = widget.onSort != null;

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
                          vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(widget.label,
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: labelColor),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            widget.isActive
                                ? (widget.sortAsc
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded)
                                : Icons.unfold_more_rounded,
                            size: 13,
                            color: widget.isActive ? activeColor : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(widget.label,
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: inactiveColor),
                        overflow: TextOverflow.ellipsis),
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
                  width: 8, height: 28,
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
  final List<double>  colWidths;
  final Color         avatarColor;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;

  const _SupplierRow({
    required this.supplier, required this.colWidths,
    required this.avatarColor, required this.onEdit, required this.onDelete,
  });

  @override
  State<_SupplierRow> createState() => _SupplierRowState();
}

class _SupplierRowState extends State<_SupplierRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s       = widget.supplier;
    final w       = widget.colWidths;
    final initial = s.supplierName.isNotEmpty
        ? s.supplierName.substring(0, 1).toUpperCase()
        : '?';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppTheme.primaryLight : Colors.white,
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
                style: const TextStyle(fontSize: 11, color: AppTheme.textSub),
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
                    child: Text(initial,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.supplierName,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500, color: Colors.black87),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

            // รหัส — w[1]
            SizedBox(
              width: w[1],
              child: Text(s.supplierCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
            ),

            // โทรศัพท์ — w[2]
            SizedBox(
              width: w[2],
              child: Text(s.phone ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
            ),

            // ผู้ติดต่อ — w[3]
            SizedBox(
              width: w[3],
              child: Text(s.contactPerson ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
            ),

            // เครดิต — w[4]
            SizedBox(
              width: w[4],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                          : AppTheme.textSub,
                    ),
                  ),
                ),
              ),
            ),

            // วงเงิน — w[5]
            SizedBox(
              width: w[5],
              child: s.creditLimit > 0
                  ? Text('฿${s.creditLimit.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13,
                          color: Color(0xFF1565C0)))
                  : const Text('-',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
            ),

            // สถานะ — w[6]
            SizedBox(
              width: w[6],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                        width: 6, height: 6,
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
                          fontSize: 11, fontWeight: FontWeight.w600,
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
class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border)),
      child: const Icon(Icons.arrow_back_ios_new, size: 15, color: AppTheme.textSub),
    ),
  );
}

class _SupplierPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.successColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.business, color: AppTheme.successColor, size: 18),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  const _SearchField({required this.controller, required this.query,
      required this.onChanged, required this.onCleared});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'ค้นหาซัพพลายเออร์...',
        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSub),
        prefixIcon: const Icon(Icons.search, size: 17, color: AppTheme.textSub),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 15), onPressed: onCleared)
            : null,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: onChanged,
    ),
  );
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
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF4CAF50) : AppTheme.border,
          ),
        ),
        child: Icon(Icons.verified_outlined, size: 17,
            color: active ? const Color(0xFF2E7D32) : AppTheme.textSub),
      ),
    ),
  );
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'รีเฟรช',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border)),
        child: const Icon(Icons.refresh, size: 17, color: AppTheme.textSub),
      ),
    ),
  );
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
        : const Text('เพิ่มซัพพลายเออร์',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18, vertical: 13),
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
  const _ActionIcon({required this.icon, required this.color,
      required this.tooltip, required this.onTap});

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
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}
