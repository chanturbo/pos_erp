import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_provider.dart';
import 'customer_form_page.dart';
import 'customer_pdf_report.dart'; // ✅ PDF report

// ─────────────────────────────────────────────────────────────────
// สีหลัก (ตามภาพ: orange theme)
// ─────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFFE8622A);
const _kPrimaryLight = Color(0xFFFFF3EE);
const _kBorder = Color(0xFFE8E8E8);
const _kHeaderBg = Color(0xFFF9F9F9);
const _kTextSub = Color(0xFF8A8A8A);

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showMembersOnly = false;
  bool _isTableView     = true;  // ✅ user เลือก Table/Card ได้

  // ✅ ความกว้างคอลัมน์ (pixel) — ลากขยาย/ย่อได้
  // ลำดับ: [ชื่อ, รหัส, โทร, สมาชิก, คะแนน, เครดิต, สถานะ, จัดการ]
  final List<double> _colWidths = [220, 130, 130, 130, 100, 120, 90, 100];
  static const List<double> _colMinW = [120, 80, 80, 80, 70, 80, 70, 100];
  static const List<double> _colMaxW = [400, 250, 220, 220, 160, 200, 120, 100];

  // ✅ ScrollControllers สำหรับแสดง scrollbar
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // ── Avatar color จาก initial ──────────────────────────────────
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFFE8622A),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFFF5722),
      const Color(0xFF009688),
      const Color(0xFF3F51B5),
      const Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar (Responsive) ───────────────────────────────
          _CustomerListTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            showMembersOnly: _showMembersOnly,
            isTableView: _isTableView,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onSearchCleared: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            onToggleMember: () =>
                setState(() => _showMembersOnly = !_showMembersOnly),
            onToggleView: () =>
                setState(() => _isTableView = !_isTableView),
            onRefresh: () =>
                ref.read(customerListProvider.notifier).refresh(),
            onAdd: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CustomerFormPage()));
            },
          ),

          // ── Table ──────────────────────────────────────────────
          Expanded(
            child: customerAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
              error: (e, _) => _buildError(e),
              data: (customers) {
                final filtered = customers.where((c) {
                  if (_showMembersOnly && (c.memberNo == null || c.memberNo!.isEmpty)) {
                    return false;
                  }
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return c.customerName.toLowerCase().contains(q) ||
                      c.customerCode.toLowerCase().contains(q) ||
                      (c.phone?.toLowerCase().contains(q) ?? false) ||
                      (c.memberNo?.toLowerCase().contains(q) ?? false);
                }).toList();

                if (filtered.isEmpty) return _buildEmpty();

                // ✅ Card View เมื่อ user เลือก
                if (!_isTableView) {
                  return _buildCustomerCardView(context, filtered);
                }

                // ✅ ปรับ colWidths ตามขนาดหน้าจอจริง
                final screenW = MediaQuery.of(context).size.width - 32;
                _adjustColWidths(screenW);

                final totalW = 40.0 + 16.0 +
                    _colWidths.fold(0.0, (s, w) => s + w) +
                    28.0 + 32.0;
                final tableW = totalW > screenW ? totalW : screenW;

                return Stack(
                  children: [
                    Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  // ✅ แนวตั้ง scroll ด้านนอก, แนวนอน scroll ด้านใน
                  child: Column(
                    children: [
                      // ── Header + Rows scroll แนวนอนพร้อมกัน ──────
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
                                // Header (resizable)
                                _ResizableTableHeader(
                                  colWidths: _colWidths,
                                  colMinW: _colMinW,
                                  colMaxW: _colMaxW,
                                  onResize: (i, w) =>
                                      setState(() => _colWidths[i] = w),
                                  onReset: () => setState(() {
                                    _colWidths.setAll(
                                        0, [220, 130, 130, 130, 100, 120, 90, 100]);
                                  }),
                                ),
                                const Divider(height: 1, color: _kBorder),
                                // Rows — ใช้ shrinkWrap ภายใน Column ที่รู้ขนาดแล้ว
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1, color: _kBorder),
                                    itemBuilder: (context, i) {
                                      final c = filtered[i];
                                      final isMember = c.memberNo != null &&
                                          c.memberNo!.isNotEmpty;
                                      final isSystem = c.customerId == 'WALK_IN';
                                      return _CustomerRow(
                                        customer: c,
                                        isMember: isMember,
                                        isSystem: isSystem,
                                        colWidths: _colWidths,
                                        avatarColor: isSystem
                                            ? const Color(0xFF546E7A)
                                            : _avatarColor(c.customerName),
                                        onEdit: isSystem
                                            ? null
                                            : () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CustomerFormPage(customer: c),
                                                  ),
                                                );
                                              },
                                        onDelete: isSystem
                                            ? null
                                            : () => _confirmDelete(
                                                c.customerId, c.customerName),
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
                      // ── Footer (ไม่ scroll แนวนอน) ───────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: _kHeaderBg,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'ทั้งหมด ${filtered.length} รายการ',
                              style: const TextStyle(
                                  fontSize: 12, color: _kTextSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), // Container
                    // ✅ ปุ่ม PDF ลอยมุมขวาล่าง
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: CustomerReportButton(
                        customers: filtered,
                      ),
                    ),
                  ],
                ); // Stack
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Card View — แสดงเมื่อ user เลือก Card mode
  // ─────────────────────────────────────────────────────────────
  Widget _buildCustomerCardView(BuildContext context, List<dynamic> customers) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = customers[i];
        final isMember = c.memberNo != null && c.memberNo!.isNotEmpty;
        final isSystem = c.customerId == 'WALK_IN';
        final color = _avatarColor(c.customerName);
        final initial = c.customerName.isNotEmpty
            ? c.customerName.substring(0, 1).toUpperCase()
            : '?';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _kBorder),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSystem
                          ? const Color(0xFF546E7A)
                          : (isMember ? const Color(0xFFFFB300) : color),
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (isMember)
                      Positioned(
                        right: -2, bottom: -2,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.star, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
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
                            child: Text(c.customerName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A)),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.isActive
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
                                    color: c.isActive
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFF44336),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.isActive ? 'ใช้งาน' : 'ปิดใช้',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: c.isActive
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
                      Text('รหัส: \${c.customerCode}',
                          style: const TextStyle(
                              fontSize: 11, color: _kTextSub)),
                      if (c.phone != null)
                        Text('โทร: \${c.phone}',
                            style: const TextStyle(
                                fontSize: 11, color: _kTextSub)),
                      if (isMember)
                        Row(
                          children: [
                            Icon(Icons.card_membership,
                                size: 11, color: Colors.amber[700]),
                            const SizedBox(width: 3),
                            Text('\${c.memberNo}  ·  \${c.points} pt',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      if (c.creditLimit > 0)
                        Text('วงเงิน: ฿\${c.creditLimit.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1565C0))),
                    ],
                  ),
                ),

                // Actions
                if (isSystem)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ระบบ',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF546E7A),
                            fontWeight: FontWeight.w600)),
                  )
                else
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
                              builder: (_) => CustomerFormPage(customer: c),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFC62828),
                        tooltip: 'ลบ',
                        onTap: () =>
                            _confirmDelete(c.customerId, c.customerName),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

    // ─────────────────────────────────────────────────────────────
  // ปรับ colWidths อัตโนมัติตามความกว้างหน้าจอ
  // ─────────────────────────────────────────────────────────────
  void _adjustColWidths(double screenW) {
    // รวม fixed: ลำดับ(40+16) + reset(28) + padding(32) = 116
    const fixed = 116.0;
    // ratio ของแต่ละคอลัมน์ [ชื่อ, รหัส, โทร, สมาชิก, คะแนน, เครดิต, สถานะ, จัดการ]
    const ratios = [3.0, 2.0, 2.0, 2.0, 1.5, 1.5, 1.2, 1.3];
    final available = screenW - fixed;
    final totalRatio = ratios.fold(0.0, (s, r) => s + r);
    for (int i = 0; i < _colWidths.length; i++) {
      final computed = (available * ratios[i] / totalRatio);
      _colWidths[i] = computed.clamp(_colMinW[i], _colMaxW[i]);
    }
  }

    Future<void> _confirmDelete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบลูกค้า $name ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success =
          await ref.read(customerListProvider.notifier).deleteCustomer(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'ลบลูกค้าสำเร็จ' : 'ลบลูกค้าไม่สำเร็จ'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_showMembersOnly ? Icons.card_membership : Icons.people_outline,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? (_showMembersOnly ? 'ยังไม่มีสมาชิก' : 'ยังไม่มีลูกค้า')
                : 'ไม่พบลูกค้าที่ค้นหา',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CustomerFormPage()));
            },
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มลูกค้า'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
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
            onPressed: () => ref.read(customerListProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ResizableTableHeader — header ที่ลากขยาย/ย่อคอลัมน์ได้
// ─────────────────────────────────────────────────────────────────
class _ResizableTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final void Function(int index, double width) onResize;
  final VoidCallback onReset;

  static const _labels = [
    'ชื่อ-นามสกุล', 'รหัสลูกค้า', 'โทรศัพท์',
    'เลขสมาชิก', 'คะแนน', 'วงเงินเครดิต', 'สถานะ', 'จัดการ',
  ];

  const _ResizableTableHeader({
    required this.colWidths,
    required this.colMinW,
    required this.colMaxW,
    required this.onResize,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _kTextSub,
    );

    return Container(
      color: _kHeaderBg,
      // padding จะถูกนับใน tableW แล้ว — ใส่แค่ vertical
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ลำดับ (fixed, ไม่ resize)
          const SizedBox(
            width: 40,
            child: Text('รหัส', style: labelStyle),
          ),
          const SizedBox(width: 16),

          // คอลัมน์ที่ resize ได้ (0–7)
          ...List.generate(_labels.length, (i) {
            return _ResizableCell(
              label: _labels[i],
              width: colWidths[i],
              minWidth: colMinW[i],
              maxWidth: colMaxW[i],
              labelStyle: labelStyle,
              isLast: i == _labels.length - 1,
              onResize: (delta) {
                final newW = (colWidths[i] + delta)
                    .clamp(colMinW[i], colMaxW[i]);
                onResize(i, newW);
              },
            );
          }),

          // ปุ่ม reset ความกว้าง
          Tooltip(
            message: 'รีเซตความกว้างคอลัมน์',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.settings_backup_restore,
                    size: 14, color: _kTextSub),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ResizableCell — เซลล์ header พร้อม drag handle ด้านขวา
// ─────────────────────────────────────────────────────────────────
class _ResizableCell extends StatefulWidget {
  final String label;
  final double width;
  final double minWidth;
  final double maxWidth;
  final TextStyle labelStyle;
  final bool isLast;
  final void Function(double delta) onResize;

  const _ResizableCell({
    required this.label,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.labelStyle,
    required this.isLast,
    required this.onResize,
  });

  @override
  State<_ResizableCell> createState() => _ResizableCellState();
}

class _ResizableCellState extends State<_ResizableCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Row(
        children: [
          // Label
          Expanded(
            child: Text(
              widget.label,
              style: widget.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Drag handle (ซ่อนใน isLast)
          if (!widget.isLast)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    widget.onResize(d.delta.dx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 8,
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: _hovering ? 20 : 12,
                    decoration: BoxDecoration(
                      color: _hovering
                          ? _kPrimary
                          : _kBorder,
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
// Customer Row
// ─────────────────────────────────────────────────────────────────
class _CustomerRow extends StatefulWidget {
  final dynamic customer;
  final bool isMember;
  final bool isSystem;
  final List<double> colWidths;  // ✅ รับความกว้างจาก parent
  final Color avatarColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CustomerRow({
    required this.customer,
    required this.isMember,
    required this.isSystem,
    required this.colWidths,
    required this.avatarColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final initial = c.customerName.isNotEmpty
        ? c.customerName.substring(0, 1).toUpperCase()
        : '?';

    final w = widget.colWidths;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kPrimaryLight : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // ลำดับ (fixed)
            SizedBox(
              width: 40,
              child: Text(
                c.customerCode.length > 6
                    ? c.customerCode.substring(c.customerCode.length - 4)
                    : c.customerCode,
                style: const TextStyle(fontSize: 11, color: _kTextSub),
              ),
            ),
            const SizedBox(width: 16),

            // ชื่อ + Avatar — w[0]
            SizedBox(
              width: w[0],
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: widget.avatarColor,
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (widget.isMember)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.star,
                                size: 8, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.customerName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // รหัส — w[1]
            SizedBox(
              width: w[1],
              child: Text(c.customerCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kTextSub)),
            ),

            // โทร — w[2]
            SizedBox(
              width: w[2],
              child: Text(c.phone ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kTextSub)),
            ),

            // เลขสมาชิก — w[3]
            SizedBox(
              width: w[3],
              child: widget.isMember
                  ? Row(
                      children: [
                        const Icon(Icons.card_membership,
                            size: 13, color: Color(0xFFFFB300)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            c.memberNo ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFFB300),
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : const Text('-',
                      style: TextStyle(fontSize: 13, color: _kTextSub)),
            ),

            // คะแนน — w[4]
            SizedBox(
              width: w[4],
              child: widget.isMember
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars,
                              size: 12, color: Color(0xFFFFB300)),
                          const SizedBox(width: 3),
                          Text('${c.points} pt',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE65100))),
                        ],
                      ),
                    )
                  : const Text('-',
                      style: TextStyle(fontSize: 13, color: _kTextSub)),
            ),

            // วงเงินเครดิต — w[5]
            SizedBox(
              width: w[5],
              child: c.creditLimit > 0
                  ? Text(
                      '฿${c.creditLimit.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1565C0)),
                    )
                  : const Text('-',
                      style: TextStyle(fontSize: 13, color: _kTextSub)),
            ),

            // สถานะ — w[6]
            SizedBox(
              width: w[6],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.isActive
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
                          color: c.isActive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        c.isActive ? 'ใช้งาน' : 'ปิดใช้',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.isActive
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
              child: widget.isSystem
                  // ✅ ลูกค้าระบบ — แสดง badge แทนปุ่ม
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB0BEC5)),
                        ),
                        child: const Text(
                          'ระบบ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF546E7A),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionIcon(
                          icon: Icons.edit_outlined,
                          color: const Color(0xFF1565C0),
                          tooltip: 'แก้ไข',
                          onTap: widget.onEdit!,
                        ),
                        const SizedBox(width: 6),
                        _ActionIcon(
                          icon: Icons.delete_outline,
                          color: const Color(0xFFC62828),
                          tooltip: 'ลบ',
                          onTap: widget.onDelete!,
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
// ─────────────────────────────────────────────────────────────────
// Responsive Top Bar — 1 แถวบน desktop, 2 แถวบน tablet/mobile
// ─────────────────────────────────────────────────────────────────
class _CustomerListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showMembersOnly;
  final bool isTableView;       // ✅ เพิ่ม
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleMember;
  final VoidCallback onToggleView;  // ✅ เพิ่ม
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _CustomerListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.showMembersOnly,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleMember,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  // breakpoint: จอกว้าง >= 720 → 1 แถว, < 720 → 2 แถว
  static const _kBreak = 720.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop)
          : _buildDoubleRow(context, canPop),
    );
  }

  // ── Desktop / Wide: ทุกอย่างอยู่แถวเดียว ──────────────────────
  Widget _buildSingleRow(BuildContext context, bool canPop) {
    return Row(
      children: [
        if (canPop) ...[
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
        ],
        _PageIcon(),
        const SizedBox(width: 10),
        const Text(
          'รายการลูกค้า',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A)),
        ),
        const Spacer(),
        // Search — ยืดหยุ่นแต่มี max width
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
        _MemberToggle(active: showMembersOnly, onTap: onToggleMember),
        const SizedBox(width: 6),
        // ✅ ปุ่ม Table/Card toggle
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
                border: Border.all(color: _kBorder),
              ),
              child: Icon(
                isTableView ? Icons.view_agenda_outlined : Icons.table_rows_outlined,
                size: 17, color: _kTextSub,
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
  }

  // ── Mobile / Tablet: แถว 1 = title+ปุ่ม, แถว 2 = search ──────
  Widget _buildDoubleRow(BuildContext context, bool canPop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // แถวบน: back + title + action buttons
        Row(
          children: [
            if (canPop) ...[
              _BackBtn(onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
            ],
            _PageIcon(),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'รายการลูกค้า',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _MemberToggle(active: showMembersOnly, onTap: onToggleMember),
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
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(
                    isTableView ? Icons.view_agenda_outlined : Icons.table_rows_outlined,
                    size: 17, color: _kTextSub,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _RefreshBtn(onTap: onRefresh),
            const SizedBox(width: 4),
            _AddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        // แถวล่าง: search เต็มความกว้าง
        _SearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child:
              const Icon(Icons.arrow_back_ios_new, size: 15, color: _kTextSub),
        ),
      );
}

class _PageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _kPrimaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.people, color: _kPrimary, size: 18),
      );
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
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ค้นหาลูกค้า...',
            hintStyle: const TextStyle(fontSize: 13, color: _kTextSub),
            prefixIcon:
                const Icon(Icons.search, size: 17, color: _kTextSub),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: onCleared,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: onChanged,
        ),
      );
}

class _MemberToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _MemberToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: active ? 'แสดงทั้งหมด' : 'แสดงเฉพาะสมาชิก',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? const Color(0xFFFFE082)
                      : _kBorder),
            ),
            child: Icon(Icons.card_membership,
                size: 17,
                color: active
                    ? const Color(0xFFFFB300)
                    : _kTextSub),
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
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.refresh, size: 17, color: _kTextSub),
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
            : const Text('เพิ่มลูกค้า',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          // ✅ เพิ่มความสูง: vertical 9 → 13
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18, vertical: 13),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = _kPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? activeColor : _kBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? activeColor : _kTextSub),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? activeColor : _kTextSub,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          // ✅ ลด padding เพื่อให้ 2 ปุ่มพอดีกับ 100px
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
}