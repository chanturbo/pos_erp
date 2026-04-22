// branch_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../restaurant/data/models/restaurant_enums.dart';
import '../providers/branch_provider.dart';
import '../../data/models/branch_model.dart';

class BranchFormPage extends ConsumerStatefulWidget {
  final BranchModel? branch;
  const BranchFormPage({super.key, this.branch});

  @override
  ConsumerState<BranchFormPage> createState() => _BranchFormPageState();
}

class _BranchFormPageState extends ConsumerState<BranchFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late TabController _tabCtrl;

  // Branch fields
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  bool _isActive = true;
  BusinessMode _businessMode = BusinessMode.retail;

  // Warehouse form
  final _whCodeCtrl = TextEditingController();
  final _whNameCtrl = TextEditingController();

  bool get isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final b = widget.branch;
    _codeCtrl = TextEditingController(text: b?.branchCode ?? '');
    _nameCtrl = TextEditingController(text: b?.branchName ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _isActive = b?.isActive ?? true;
    _businessMode = BusinessMode.fromString(b?.businessMode);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whCodeCtrl.dispose();
    _whNameCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _panelCard(BuildContext context, {required Widget child, Key? key}) =>
      Card(
        key: key,
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderColorOf(context)),
        ),
        child: child,
      );

  Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) =>
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );

  TextStyle _titleStyle(BuildContext context) => TextStyle(
        fontSize: context.isMobile ? 13 : 14,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  TextStyle _subtitleStyle(BuildContext context) => TextStyle(
        fontSize: context.isMobile ? 11 : 12,
        color: AppTheme.subtextColorOf(context),
        fontWeight: FontWeight.w500,
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? AppTheme.navyDark : AppTheme.navy;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Container(
              color: topBarBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (context.isMobile)
                    InkWell(
                      onTap: () => navigateToMobileHome(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.home_rounded,
                            color: Colors.white, size: 20),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.edit_outlined
                          : Icons.add_business_outlined,
                      color: AppTheme.primaryLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'แก้ไขสาขา' : 'เพิ่มสาขา',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined,
                          color: Colors.white, size: 18),
                      label: const Text('บันทึก',
                          style: TextStyle(color: Colors.white)),
                    ),
                  // Badge
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Branch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Tab bar ──────────────────────────────────────────────────
            Container(
              color: topBarBg,
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: AppTheme.primaryLight,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(icon: Icon(Icons.store_outlined), text: 'ข้อมูลสาขา'),
                  Tab(icon: Icon(Icons.warehouse_outlined), text: 'คลังสินค้า'),
                ],
              ),
            ),
            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildBranchTab(context),
                  _buildWarehouseTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Branch Info Tab ────────────────────────────────────────────────────────
  Widget _buildBranchTab(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ข้อมูลทั่วไป ─────────────────────────────────────────
              _panelCard(
                context,
                child: Padding(
                  padding: context.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, 'ข้อมูลทั่วไป',
                          Icons.info_outline_rounded, AppTheme.primary),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'รหัสสาขา *',
                                border: OutlineInputBorder(),
                                hintText: 'BKK01',
                                prefixIcon:
                                    Icon(Icons.qr_code_outlined),
                              ),
                              textCapitalization:
                                  TextCapitalization.characters,
                              validator: (v) =>
                                  v == null || v.isEmpty
                                      ? 'กรุณากรอกรหัส'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อสาขา *',
                                border: OutlineInputBorder(),
                                hintText: 'สาขากรุงเทพ',
                                prefixIcon:
                                    Icon(Icons.storefront_outlined),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty
                                      ? 'กรุณากรอกชื่อ'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'เบอร์โทรศัพท์',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ที่อยู่',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── การตั้งค่า ────────────────────────────────────────────
              _panelCard(
                context,
                child: Padding(
                  padding: context.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, 'การตั้งค่า',
                          Icons.tune_rounded, AppTheme.infoColor),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<BusinessMode>(
                        initialValue: _businessMode,
                        decoration: const InputDecoration(
                          labelText: 'โหมดธุรกิจ',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.storefront_outlined),
                        ),
                        items: BusinessMode.values
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _businessMode = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      // Business mode description
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.infoColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 15,
                                color: AppTheme.infoColor
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _businessModeDesc(_businessMode),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtextColorOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (_isActive
                                      ? AppTheme.successColor
                                      : Colors.grey)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isActive
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                              color: _isActive
                                  ? AppTheme.successColor
                                  : Colors.grey,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('สถานะสาขา',
                                    style: _titleStyle(context)),
                                Text(
                                  _isActive
                                      ? 'เปิดใช้งานอยู่'
                                      : 'ปิดใช้งาน',
                                  style: _subtitleStyle(context),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (v) =>
                                setState(() => _isActive = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _businessModeDesc(BusinessMode mode) => switch (mode) {
        BusinessMode.retail =>
          'ระบบขายปลีกทั่วไป — ใช้หน้า POS สำหรับบันทึกการขาย',
        BusinessMode.restaurant =>
          'ร้านอาหาร — ใช้ระบบโต๊ะ/ออเดอร์/KDS แทนหน้า POS',
        BusinessMode.hybrid =>
          'ผสม — มีทั้งหน้า POS และระบบร้านอาหารพร้อมกัน',
      };

  // ── Warehouse Tab ──────────────────────────────────────────────────────────
  Widget _buildWarehouseTab(BuildContext context) {
    if (!isEdit) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Padding(
            padding: context.pagePadding,
            child: _panelCard(
              context,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.warehouse_outlined,
                            color: AppTheme.infoColor, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text('บันทึกสาขาก่อน',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        'บันทึกข้อมูลสาขาก่อน จึงจะสามารถเพิ่มคลังสินค้าได้\n(ระบบจะสร้างคลังหลักให้อัตโนมัติ)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.subtextColorOf(context),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final warehousesAsync = ref.watch(warehouseListProvider);

    return warehousesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (warehouses) {
        final myWarehouses = warehouses
            .where((w) => w.branchId == widget.branch!.branchId)
            .toList();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: context.contentMaxWidth),
            child: SingleChildScrollView(
              padding: context.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Add warehouse form ───────────────────────────────
                  _panelCard(
                    context,
                    child: Padding(
                      padding: context.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            context,
                            'เพิ่มคลังสินค้า',
                            Icons.add_box_outlined,
                            AppTheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _whCodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'รหัสคลัง',
                                    border: OutlineInputBorder(),
                                    hintText: 'WH01',
                                    prefixIcon:
                                        Icon(Icons.qr_code_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _whNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'ชื่อคลัง',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(
                                        Icons.warehouse_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _addWarehouse,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('เพิ่ม'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Warehouse list ───────────────────────────────────
                  _panelCard(
                    context,
                    child: Padding(
                      padding: context.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            context,
                            'คลังสินค้าทั้งหมด (${myWarehouses.length})',
                            Icons.warehouse_outlined,
                            AppTheme.infoColor,
                          ),
                          const SizedBox(height: 12),
                          if (myWarehouses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24),
                              child: Center(
                                child: Text(
                                  'ยังไม่มีคลังสินค้า',
                                  style:
                                      _subtitleStyle(context),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (var i = 0;
                                    i < myWarehouses.length;
                                    i++) ...[
                                  _warehouseRow(
                                      context, myWarehouses[i]),
                                  if (i != myWarehouses.length - 1)
                                    Divider(
                                      height: 1,
                                      color: AppTheme.borderColorOf(
                                          context),
                                    ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _warehouseRow(BuildContext context, WarehouseModel wh) {
    final isActive = wh.isActive;
    final statusColor =
        isActive ? AppTheme.successColor : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warehouse_outlined,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wh.warehouseName, style: _titleStyle(context)),
                Text(wh.warehouseCode, style: _subtitleStyle(context)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addWarehouse() async {
    if (_whCodeCtrl.text.isEmpty || _whNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกรหัสและชื่อคลัง')));
      return;
    }

    final wh = WarehouseModel(
      warehouseId: 'WH${DateTime.now().millisecondsSinceEpoch}',
      warehouseCode: _whCodeCtrl.text.trim().toUpperCase(),
      warehouseName: _whNameCtrl.text.trim(),
      branchId: widget.branch!.branchId,
      createdAt: DateTime.now(),
    );

    final ok =
        await ref.read(warehouseListProvider.notifier).createWarehouse(wh);

    if (ok && mounted) {
      _whCodeCtrl.clear();
      _whNameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มคลังสินค้าแล้ว')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final branch = BranchModel(
      branchId: widget.branch?.branchId ?? 'BR${now.millisecondsSinceEpoch}',
      companyId: widget.branch?.companyId ?? 'COMP001',
      branchCode: _codeCtrl.text.trim().toUpperCase(),
      branchName: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim().isNotEmpty
          ? _addressCtrl.text.trim()
          : null,
      phone: _phoneCtrl.text.trim().isNotEmpty
          ? _phoneCtrl.text.trim()
          : null,
      isActive: _isActive,
      businessMode: _businessMode.value,
      createdAt: widget.branch?.createdAt ?? now,
      updatedAt: now,
    );

    bool ok;
    if (isEdit) {
      ok = await ref.read(branchListProvider.notifier).updateBranch(branch);
    } else {
      ok = await ref.read(branchListProvider.notifier).createBranch(branch);
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? 'อัพเดทสาขาแล้ว' : 'สร้างสาขาแล้ว')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')));
      }
    }
  }
}
