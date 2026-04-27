import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/routes/app_router.dart';
import 'package:pos_erp/main.dart' show applyRestoreInPlace;
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';
import 'package:pos_erp/features/products/presentation/providers/product_provider.dart';
import 'package:pos_erp/features/products/presentation/pages/product_list_page.dart';
import 'package:pos_erp/features/products/data/models/product_model.dart';
import 'package:pos_erp/features/users/presentation/providers/user_provider.dart';
import 'package:pos_erp/features/users/presentation/pages/user_list_page.dart';
import 'package:pos_erp/features/users/data/models/user_management_model.dart';
import 'package:pos_erp/features/home/presentation/pages/home_page.dart';
import 'package:pos_erp/features/branches/presentation/providers/branch_provider.dart';
import 'package:pos_erp/features/branches/presentation/pages/branch_list_page.dart';
import 'package:pos_erp/features/branches/presentation/pages/sync_status_page.dart';
import 'package:pos_erp/features/branches/data/models/branch_model.dart';
import 'package:pos_erp/core/services/backup/backup_service.dart';
import 'package:pos_erp/core/services/backup/models/backup_result.dart';
import 'package:pos_erp/core/services/backup/google_drive_backup_service.dart';
import 'package:pos_erp/core/client/api_client.dart';
import '../../shared/setup_storage.dart';

class _SetupReadiness {
  final String companyName;
  final String? selectedBranchId;
  final String? selectedWarehouseId;
  final int totalBranches;
  final int activeBranches;
  final int totalWarehouses;
  final int activeWarehouses;
  final int validWarehousesOnActiveBranches;
  final int totalProducts;
  final int activeProducts;
  final int stockProducts;
  final int totalUsers;
  final int activeUsers;
  final int staffUsers;
  final bool hasSelectedActiveBranch;
  final bool hasSelectedActiveWarehouse;
  final bool selectedWarehouseMatchesBranch;

  const _SetupReadiness({
    required this.companyName,
    required this.selectedBranchId,
    required this.selectedWarehouseId,
    required this.totalBranches,
    required this.activeBranches,
    required this.totalWarehouses,
    required this.activeWarehouses,
    required this.validWarehousesOnActiveBranches,
    required this.totalProducts,
    required this.activeProducts,
    required this.stockProducts,
    required this.totalUsers,
    required this.activeUsers,
    required this.staffUsers,
    required this.hasSelectedActiveBranch,
    required this.hasSelectedActiveWarehouse,
    required this.selectedWarehouseMatchesBranch,
  });

  bool get hasStoreInfo => companyName.trim().isNotEmpty;
  bool get hasActiveBranches => activeBranches > 0;
  bool get hasActiveWarehouses => activeWarehouses > 0;
  bool get hasWarehousesOnActiveBranches => validWarehousesOnActiveBranches > 0;
  bool get posContextReady =>
      hasSelectedActiveBranch &&
      hasSelectedActiveWarehouse &&
      selectedWarehouseMatchesBranch;
  bool get branchReady =>
      hasActiveBranches && hasWarehousesOnActiveBranches && posContextReady;
  bool get hasActiveProducts => activeProducts > 0;
  bool get hasStockControlledProducts => stockProducts > 0;
  bool get productReady => hasActiveProducts && hasStockControlledProducts;
  bool get staffReady => staffUsers > 0;
  bool get isFullyReady =>
      hasStoreInfo && branchReady && productReady && staffReady;

  int get nextStep {
    if (!hasStoreInfo) return 0;
    if (!branchReady) return 1;
    if (!productReady) return 2;
    if (!staffReady) return 3;
    return 3;
  }

  List<String> get missingItems {
    final items = <String>[];
    if (!hasStoreInfo) items.add('ตั้งชื่อร้าน');
    if (!hasActiveBranches) items.add('เพิ่มสาขาอย่างน้อย 1 สาขา');
    if (!hasWarehousesOnActiveBranches) {
      items.add('เพิ่มคลัง active ที่ผูกกับสาขา active');
    }
    if (!hasSelectedActiveBranch) {
      items.add('เลือกสาขา active ที่เครื่อง POS นี้จะใช้งาน');
    }
    if (!hasSelectedActiveWarehouse) {
      items.add('เลือกคลัง active ที่เครื่อง POS นี้จะใช้งาน');
    }
    if (!selectedWarehouseMatchesBranch &&
        hasSelectedActiveBranch &&
        hasSelectedActiveWarehouse) {
      items.add('ให้คลังที่เลือกอยู่ภายใต้สาขาที่เลือก');
    }
    if (!hasActiveProducts) items.add('เพิ่มสินค้า active');
    if (!hasStockControlledProducts) {
      items.add('เพิ่มสินค้าที่ควบคุมสต๊อกอย่างน้อย 1 รายการ');
    }
    if (!staffReady) items.add('เพิ่มพนักงานจริง');
    return items;
  }

  int get completedCriteriaCount =>
      readinessItems.where((item) => item.passed).length;

  int get totalCriteriaCount => readinessItems.length;

  List<_ReadinessStatus> get readinessItems => [
        _ReadinessStatus(label: 'ข้อมูลร้าน', passed: hasStoreInfo),
        _ReadinessStatus(label: 'สาขา active', passed: hasActiveBranches),
        _ReadinessStatus(
          label: 'คลัง active ที่ผูกกับสาขา active',
          passed: hasWarehousesOnActiveBranches,
        ),
        _ReadinessStatus(
          label: 'เลือกสาขาสำหรับ POS แล้ว',
          passed: hasSelectedActiveBranch,
        ),
        _ReadinessStatus(
          label: 'เลือกคลังสำหรับ POS แล้ว',
          passed: hasSelectedActiveWarehouse,
        ),
        _ReadinessStatus(
          label: 'คลังที่เลือกตรงกับสาขาที่เลือก',
          passed: selectedWarehouseMatchesBranch,
        ),
        _ReadinessStatus(label: 'สินค้า active', passed: hasActiveProducts),
        _ReadinessStatus(
          label: 'สินค้าควบคุมสต๊อก',
          passed: hasStockControlledProducts,
        ),
        _ReadinessStatus(label: 'พนักงานจริง', passed: staffReady),
      ];
}

class _SetupGateDecision {
  final bool isReady;
  final _SetupReadiness? readiness;
  final bool usedFallback;

  const _SetupGateDecision({
    required this.isReady,
    this.readiness,
    this.usedFallback = false,
  });
}

_SetupReadiness _buildReadiness({
  required String companyName,
  required String? selectedBranchId,
  required String? selectedWarehouseId,
  required List<BranchModel> branches,
  required List<WarehouseModel> warehouses,
  required List<ProductModel> products,
  required List<UserManagementModel> users,
}) {
  final activeBranchIds = branches
      .where((b) => b.isActive)
      .map((b) => b.branchId)
      .toSet();
  final activeBranches = activeBranchIds.length;
  final activeWarehouses = warehouses.where((w) => w.isActive).length;
  final validWarehousesOnActiveBranches = warehouses
      .where((w) => w.isActive && activeBranchIds.contains(w.branchId))
      .length;
  final activeProducts = products.where((p) => p.isActive).length;
  final stockProducts = products
      .where((p) => p.isActive && p.isStockControl)
      .length;
  final activeUsers = users.where((u) => u.isActive).length;
  final staffUsers = users
      .where((u) => u.isActive && (u.roleId?.toUpperCase() ?? '') != 'ADMIN')
      .length;
  final selectedBranch = selectedBranchId == null
      ? null
      : branches
            .cast<BranchModel?>()
            .firstWhere(
              (branch) => branch?.branchId == selectedBranchId,
              orElse: () => null,
            );
  final selectedWarehouse = selectedWarehouseId == null
      ? null
      : warehouses
            .cast<WarehouseModel?>()
            .firstWhere(
              (warehouse) => warehouse?.warehouseId == selectedWarehouseId,
              orElse: () => null,
            );
  final hasSelectedActiveBranch =
      selectedBranch != null && selectedBranch.isActive;
  final hasSelectedActiveWarehouse = selectedWarehouse != null &&
      selectedWarehouse.isActive &&
      activeBranchIds.contains(selectedWarehouse.branchId);
  final selectedWarehouseMatchesBranch =
      hasSelectedActiveBranch &&
      hasSelectedActiveWarehouse &&
      selectedWarehouse.branchId == selectedBranch.branchId;

  return _SetupReadiness(
    companyName: companyName,
    selectedBranchId: selectedBranchId,
    selectedWarehouseId: selectedWarehouseId,
    totalBranches: branches.length,
    activeBranches: activeBranches,
    totalWarehouses: warehouses.length,
    activeWarehouses: activeWarehouses,
    validWarehousesOnActiveBranches: validWarehousesOnActiveBranches,
    totalProducts: products.length,
    activeProducts: activeProducts,
    stockProducts: stockProducts,
    totalUsers: users.length,
    activeUsers: activeUsers,
    staffUsers: staffUsers,
    hasSelectedActiveBranch: hasSelectedActiveBranch,
    hasSelectedActiveWarehouse: hasSelectedActiveWarehouse,
    selectedWarehouseMatchesBranch: selectedWarehouseMatchesBranch,
  );
}

class SetupGatePage extends ConsumerStatefulWidget {
  const SetupGatePage({super.key});

  @override
  ConsumerState<SetupGatePage> createState() => _SetupGatePageState();
}

class _SetupGatePageState extends ConsumerState<SetupGatePage> {
  late final Future<_SetupGateDecision> _future = _resolveSetupStatus();

  Future<_SetupGateDecision> _resolveSetupStatus() async {
    final explicitCompleted = await SetupStorage.isCompleted();
    final companyName = await SetupStorage.getStoredCompanyName();
    final posContext = await SetupStorage.getPosContextSnapshot();

    try {
      final branches = await ref.read(branchListProvider.future);
      final warehouses = await ref.read(warehouseListProvider.future);
      final products = await ref.read(productListProvider.future);
      final users = await ref.read(userListProvider.future);
      final readiness = _buildReadiness(
        companyName: companyName,
        selectedBranchId: posContext.branchId,
        selectedWarehouseId: posContext.warehouseId,
        branches: branches,
        warehouses: warehouses,
        products: products,
        users: users,
      );
      await SetupStorage.markCompleted(readiness.isFullyReady);
      return _SetupGateDecision(
        isReady: readiness.isFullyReady,
        readiness: readiness,
      );
    } catch (_) {
      return _SetupGateDecision(
        isReady: explicitCompleted,
        usedFallback: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SetupGateDecision>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _SetupLoadingScaffold();
        }
        final decision = snapshot.data!;
        if (decision.isReady) {
          return const HomePage();
        }
        return SetupOnboardingPage(
          gateMessage: _buildGateMessage(decision),
        );
      },
    );
  }

  String? _buildGateMessage(_SetupGateDecision decision) {
    if (decision.usedFallback || decision.readiness == null) {
      return 'ระบบยังยืนยันความพร้อมของข้อมูลตั้งต้นไม่ได้ จึงพาเข้าหน้าตั้งค่าเพื่อป้องกันการเปิดขายด้วยข้อมูลไม่ครบ';
    }

    final missing = decision.readiness!.missingItems;
    if (missing.isEmpty) return null;

    return 'ระบบยังไม่ให้เข้าใช้งานตรง ๆ เพราะข้อมูลตั้งต้นบางส่วนมีผลต่อการขาย การตัดสต๊อก และการอ้างอิงเอกสาร หากยังไม่ครบอาจทำให้ยอดขายลงผิดสาขา สต๊อกตัดไม่ถูกคลัง หรือไม่สามารถมอบหมายงานให้พนักงานได้ ตอนนี้ยังขาด: ${missing.join(' • ')}';
  }
}

class SetupOnboardingPage extends ConsumerStatefulWidget {
  final String? gateMessage;

  const SetupOnboardingPage({super.key, this.gateMessage});

  @override
  ConsumerState<SetupOnboardingPage> createState() =>
      _SetupOnboardingPageState();
}

class _SetupOnboardingPageState extends ConsumerState<SetupOnboardingPage> {
  final _companyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');
  final _scrollController = ScrollController();
  final _stepSectionKey = GlobalKey();

  int _currentStep = 0;
  bool _saving = false;
  bool _productsVisited = false;
  bool _usersVisited = false;
  bool _isRestoringBackup = false;
  bool _isUpdatingRestoreChoice = false;
  bool _autoCompleting = false;
  String? _persistedSelectedBranchId;
  String? _persistedSelectedWarehouseId;

  // Demo data selection state
  bool _demoChoicePending = false;
  bool _demoSeeding = false;
  String? _selectedDemoMode;
  SetupRestoreSnapshot _restoreSnapshot = const SetupRestoreSnapshot(
    status: SetupRestoreStatus.undecided,
  );
  _SetupReadiness _readiness = const _SetupReadiness(
    companyName: '',
    selectedBranchId: null,
    selectedWarehouseId: null,
    totalBranches: 0,
    activeBranches: 0,
    totalWarehouses: 0,
    activeWarehouses: 0,
    validWarehousesOnActiveBranches: 0,
    totalProducts: 0,
    activeProducts: 0,
    stockProducts: 0,
    totalUsers: 0,
    activeUsers: 0,
    staffUsers: 0,
    hasSelectedActiveBranch: false,
    hasSelectedActiveWarehouse: false,
    selectedWarehouseMatchesBranch: false,
  );

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _companyNameController.text = settings.companyName;
    _phoneController.text = settings.phone;
    _addressController.text = settings.address;
    Future.microtask(_loadRestoreSnapshot);
    Future.microtask(_loadPersistedPosContext);
    Future.microtask(_checkDemoChoice);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).updateCompanyInfo(
            companyName: _companyNameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _currentStep = 1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishSetup({bool allowEmptyCompany = false}) async {
    final companyName = _companyNameController.text.trim();
    if (!allowEmptyCompany && companyName.isEmpty) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อร้านก่อนเริ่มใช้งาน')),
      );
      return;
    }
    if (companyName.isNotEmpty) {
      await ref.read(settingsProvider.notifier).updateCompanyInfo(
            companyName: companyName,
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
    }
    await SetupStorage.markCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.home);
  }

  Future<void> _loadRestoreSnapshot() async {
    final snapshot = await SetupStorage.getRestoreSnapshot();
    if (!mounted) return;
    setState(() => _restoreSnapshot = snapshot);
  }

  Future<void> _loadPersistedPosContext() async {
    final snapshot = await SetupStorage.getPosContextSnapshot();
    if (!mounted) return;
    setState(() {
      _persistedSelectedBranchId = snapshot.branchId;
      _persistedSelectedWarehouseId = snapshot.warehouseId;
    });
  }

  Future<void> _checkDemoChoice() async {
    final mode = await SetupStorage.getDemoMode();
    if (!mounted) return;
    setState(() {
      _demoChoicePending = mode == null;
      _selectedDemoMode = mode;
    });
  }

  Future<void> _applyDemoMode(String mode) async {
    if (_demoSeeding) return;
    setState(() => _demoSeeding = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/setup/seed-demo', data: {'mode': mode});
      await SetupStorage.setDemoMode(mode);
      // Refresh providers so the seeded data appears immediately
      ref.invalidate(productListProvider);
      ref.invalidate(branchListProvider);
      ref.invalidate(warehouseListProvider);
      if (!mounted) return;
      setState(() {
        _demoChoicePending = false;
        _demoSeeding = false;
        _selectedDemoMode = mode;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _demoSeeding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  ({IconData icon, String label, Color color}) _demoModeInfo(String mode) =>
      switch (mode) {
        'pos' => (
            icon: Icons.point_of_sale,
            label: 'POS ร้านค้า',
            color: Colors.green,
          ),
        'restaurant' => (
            icon: Icons.restaurant,
            label: 'ร้านอาหาร',
            color: Colors.orange,
          ),
        'both' => (
            icon: Icons.store,
            label: 'ทั้งสองระบบ',
            color: Colors.purple,
          ),
        _ => (
            icon: Icons.do_not_disturb_alt_outlined,
            label: 'ไม่ต้องการ',
            color: Colors.grey,
          ),
      };

  Widget _demoDataCard() {
    if (!_demoChoicePending && _selectedDemoMode == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.dataset_outlined, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ข้อมูลตัวอย่าง',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ระบบใหม่',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Body: pending หรือ selected ──────────────────────────
            if (_demoChoicePending) ...[
              Text(
                'เลือกประเภทข้อมูลตัวอย่างที่ต้องการสร้างสำหรับการใช้งานครั้งแรก',
                style: TextStyle(fontSize: 13, color: AppTheme.subtextColorOf(context)),
              ),
              const SizedBox(height: 14),
              if (_demoSeeding)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('กำลังสร้างข้อมูลตัวอย่าง...'),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _demoOptionButton(
                      icon: Icons.point_of_sale,
                      label: 'POS ร้านค้า',
                      description: 'สินค้าขายปลีก + สต๊อก',
                      color: Colors.green,
                      onTap: () => _applyDemoMode('pos'),
                    ),
                    _demoOptionButton(
                      icon: Icons.restaurant,
                      label: 'ร้านอาหาร',
                      description: 'เมนูอาหาร + โต๊ะ + KDS',
                      color: Colors.orange,
                      onTap: () => _applyDemoMode('restaurant'),
                    ),
                    _demoOptionButton(
                      icon: Icons.store,
                      label: 'ทั้งสองระบบ',
                      description: 'POS + ร้านอาหาร',
                      color: Colors.purple,
                      onTap: () => _applyDemoMode('both'),
                    ),
                    _demoOptionButton(
                      icon: Icons.close,
                      label: 'ไม่ต้องการ',
                      description: 'เริ่มจากข้อมูลเปล่า',
                      color: Colors.grey,
                      onTap: () => _applyDemoMode('none'),
                    ),
                  ],
                ),
            ] else if (_selectedDemoMode != null) ...[
              // ── แสดงสถานะที่เลือกแล้ว ─────────────────────────────
              const SizedBox(height: 4),
              Builder(builder: (context) {
                final info = _demoModeInfo(_selectedDemoMode!);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: info.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(info.icon, color: info.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลือกไว้: ${info.label}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: info.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ข้อมูลตัวอย่างถูกสร้างแล้ว',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtextColorOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('เปลี่ยนประเภทข้อมูลตัวอย่าง?'),
                              content: const Text(
                                'ข้อมูลตัวอย่างเดิม (สินค้า, หมวดหมู่, โต๊ะ, สต๊อก) จะถูกลบออก\nแล้วสร้างใหม่ตามประเภทที่เลือก',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('ยกเลิก'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                  child: const Text('ลบและเปลี่ยน'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            setState(() => _demoChoicePending = true);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: info.color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text('เปลี่ยน'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _demoOptionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: AppTheme.subtextColorOf(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRestorePassphrase() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('ใส่รหัสเข้ารหัสไฟล์สำรองข้อมูล'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'รหัสเข้ารหัส',
                  suffixIcon: IconButton(
                    onPressed: () => setLocalState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ใส่รหัสที่ใช้ตอนสร้างไฟล์สำรองข้อมูล',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtextColorOf(context),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.length >= 8) {
                  Navigator.of(context).pop(text);
                }
              },
              child: const Text('ถัดไป'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _restoreTableLabel(String table) {
    switch (table) {
      case 'companies':
        return 'บริษัท';
      case 'branches':
        return 'สาขา';
      case 'warehouses':
        return 'คลัง';
      case 'products':
        return 'สินค้า';
      case 'customers':
        return 'ลูกค้า';
      case 'sales_orders':
        return 'ออเดอร์ขาย';
      case 'users':
        return 'ผู้ใช้';
      default:
        return table;
    }
  }

  Widget _restoreInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.subtextColorOf(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRestore(RestorePreparationResult result) async {
    final createdAt = DateTime.tryParse(result.manifest.createdAt)?.toLocal();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('ตรวจสอบ Backup ก่อนกู้คืน'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _restoreInfoRow(
                  'ชุดข้อมูล',
                  result.manifest.companyName.isNotEmpty
                      ? result.manifest.companyName
                      : '-',
                ),
                _restoreInfoRow(
                  'สร้างเมื่อ',
                  createdAt != null
                      ? _dateTimeFmt.format(createdAt)
                      : result.manifest.createdAt,
                ),
                _restoreInfoRow(
                  'ไฟล์ในชุดสำรอง',
                  '${result.manifest.fileCount} ไฟล์',
                ),
                _restoreInfoRow(
                  'รูปสินค้า',
                  '${result.inspection.productImageCount} ไฟล์',
                ),
                const SizedBox(height: 8),
                Text(
                  'จำนวนข้อมูลในฐานข้อมูลสำรอง',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...BackupService.trackedInspectionTables.map((table) {
                  final count = result.inspection.tableCounts[table] ?? 0;
                  return _restoreInfoRow(
                    _restoreTableLabel(table),
                    NumberFormat.decimalPattern().format(count),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.settings_backup_restore_outlined),
            label: const Text('กู้คืนข้อมูล'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _restoreFromLocalBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final restorePath = await backupService.pickBackupRestorePath();
    if (restorePath == null || restorePath.isEmpty || !mounted) return;

    final passphrase = await _promptRestorePassphrase();
    if (passphrase == null || !mounted) return;

    setState(() => _isRestoringBackup = true);
    try {
      final result = await backupService.prepareRestore(
        encryptedBackupFile: File(restorePath),
        passphrase: passphrase,
      );
      if (!mounted) return;
      final confirmed = await _confirmRestore(result);
      if (!confirmed || !mounted) return;

      await _applyRestoreResult(result, source: 'local');
    } on BackupException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กู้คืนข้อมูลไม่สำเร็จ: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoringBackup = false);
    }
  }

  Future<void> _restoreFromGoogleDrive() async {
    final googleDrive = ref.read(googleDriveBackupServiceProvider);
    setState(() => _isRestoringBackup = true);

    try {
      await googleDrive.signIn();
      if (!mounted) return;
      final items = await googleDrive.listBackups();
      if (!mounted) return;

      final selectedItem = await showDialog<DriveBackupItem>(
        context: context,
        builder: (context) => _DriveBackupListDialog(
          items: items,
          dateTimeFmt: _dateTimeFmt,
        ),
      );
      if (selectedItem == null || !mounted) return;

      final passphrase = await _promptRestorePassphrase();
      if (passphrase == null || !mounted) return;

      final tempFile = await googleDrive.downloadBackup(
        fileId: selectedItem.fileId,
        fileName: selectedItem.fileName,
      );
      try {
        final backupService = ref.read(backupServiceProvider);
        final result = await backupService.prepareRestore(
          encryptedBackupFile: tempFile,
          passphrase: passphrase,
        );
        if (!mounted) return;
        final confirmed = await _confirmRestore(result);
        if (!confirmed || !mounted) return;
        await _applyRestoreResult(result, source: 'google_drive');
      } finally {
        if (tempFile.existsSync()) await tempFile.delete();
      }
    } on GoogleDriveBackupException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    } on BackupException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กู้คืนข้อมูลจาก Google Drive ไม่สำเร็จ: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoringBackup = false);
    }
  }

  Future<void> _applyRestoreResult(
    RestorePreparationResult result, {
    required String source,
  }) async {
    await ref.read(settingsProvider.notifier).updateCompanyInfo(
          companyName: result.manifest.companyName,
        );
    await SetupStorage.markRestoreCompleted(source: source);
    await SetupStorage.markCompleted(true);
    await applyRestoreInPlace();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กู้คืนข้อมูลสำเร็จแล้ว'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _markRestoreSkipped() async {
    setState(() => _isUpdatingRestoreChoice = true);
    try {
      await SetupStorage.markRestoreSkipped();
      await _loadRestoreSnapshot();
    } finally {
      if (mounted) setState(() => _isUpdatingRestoreChoice = false);
    }
  }

  Future<void> _openProducts() async {
    setState(() => _productsVisited = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductListPage()),
    );
    ref.invalidate(productListProvider);
  }

  Future<void> _openUsers() async {
    setState(() => _usersVisited = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserListPage()),
    );
    ref.invalidate(userListProvider);
  }

  Future<void> _openBranches() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BranchListPage()),
    );
    ref.invalidate(branchListProvider);
    ref.invalidate(warehouseListProvider);
  }

  Future<void> _openPosContextSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncStatusPage()),
    );
    await _loadPersistedPosContext();
    ref.invalidate(branchListProvider);
    ref.invalidate(warehouseListProvider);
  }

  void _jumpToStep(int step) {
    if (!mounted) return;
    setState(() => _currentStep = step.clamp(0, 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _stepSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(posContextBootstrapProvider);
    final branchesAsync = ref.watch(branchListProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final productsAsync = ref.watch(productListProvider);
    final usersAsync = ref.watch(userListProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final branches = branchesAsync.asData?.value ?? <BranchModel>[];
    final warehouses = warehousesAsync.asData?.value ?? <WarehouseModel>[];
    final products = productsAsync.asData?.value ?? <ProductModel>[];
    final users = usersAsync.asData?.value ?? <UserManagementModel>[];
    final resolvedSelectedBranch = selectedBranch ??
        branches.cast<BranchModel?>().firstWhere(
              (branch) => branch?.branchId == _persistedSelectedBranchId,
              orElse: () => null,
            );
    final resolvedSelectedWarehouse = selectedWarehouse ??
        warehouses.cast<WarehouseModel?>().firstWhere(
              (warehouse) =>
                  warehouse?.warehouseId == _persistedSelectedWarehouseId,
              orElse: () => null,
            );
    _readiness = _buildReadiness(
      companyName: _companyNameController.text.trim(),
      selectedBranchId:
          resolvedSelectedBranch?.branchId ?? _persistedSelectedBranchId,
      selectedWarehouseId:
          resolvedSelectedWarehouse?.warehouseId ??
          _persistedSelectedWarehouseId,
      branches: branches,
      warehouses: warehouses,
      products: products,
      users: users,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAutomaticProgress(
        readiness: _readiness,
      );
    });

    final steps = [
      _SetupStepMeta(
        title: 'ตั้งค่าร้าน',
        description: 'กรอกชื่อร้านและข้อมูลติดต่อก่อนเริ่มใช้งาน',
        icon: Icons.storefront_outlined,
        color: Colors.orange,
      ),
      _SetupStepMeta(
        title: 'สาขา/คลัง',
        description: 'ต้องมีคลังที่ผูกกับสาขา active และเลือก POS context ให้พร้อม',
        icon: Icons.store_outlined,
        color: Colors.deepOrange,
      ),
      _SetupStepMeta(
        title: 'เพิ่มสินค้า',
        description: 'เข้าไปเพิ่มรายการสินค้าและตรวจสอบความพร้อมของสต๊อก',
        icon: Icons.inventory_2_outlined,
        color: Colors.green,
      ),
      _SetupStepMeta(
        title: 'เพิ่มพนักงาน',
        description: 'สร้างผู้ใช้และกำหนดสิทธิ์ให้ทีมงานก่อนเปิดใช้งานจริง',
        icon: Icons.people_alt_outlined,
        color: Colors.blue,
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101826) : const Color(0xFFF6F2EA),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroCard(steps),
                  const SizedBox(height: 16),
                  if (widget.gateMessage != null) ...[
                    _gateReasonCard(widget.gateMessage!),
                    const SizedBox(height: 16),
                  ],
                  _progressStrip(steps),
                  const SizedBox(height: 16),
                  _readinessSummaryCard(),
                  const SizedBox(height: 16),
                  _restoreChoiceCard(),
                  const SizedBox(height: 16),
                  _demoDataCard(),
                  SizedBox(key: _stepSectionKey, width: double.infinity),
                  if (_currentStep == 0) _storeInfoStep(),
                  if (_currentStep == 1)
                    _branchWarehouseStep(
                      totalBranches: _readiness.totalBranches,
                      activeBranches: _readiness.activeBranches,
                      totalWarehouses: _readiness.totalWarehouses,
                      activeWarehouses: _readiness.activeWarehouses,
                      validWarehousesOnActiveBranches:
                          _readiness.validWarehousesOnActiveBranches,
                      selectedBranch: resolvedSelectedBranch,
                      selectedWarehouse: resolvedSelectedWarehouse,
                    ),
                  if (_currentStep == 2)
                    _productStep(
                      totalProducts: _readiness.totalProducts,
                      activeProducts: _readiness.activeProducts,
                      stockProducts: _readiness.stockProducts,
                    ),
                  if (_currentStep == 3)
                    _userStep(
                      totalUsers: _readiness.totalUsers,
                      activeUsers: _readiness.activeUsers,
                      staffUsers: _readiness.staffUsers,
                    ),
                  const SizedBox(height: 16),
                  _footerActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncAutomaticProgress({
    required _SetupReadiness readiness,
  }) async {
    if (!mounted || _saving || _isRestoringBackup || _autoCompleting) return;

    final targetStep = readiness.isFullyReady ? null : readiness.nextStep;

    if (targetStep != null && targetStep != _currentStep) {
      setState(() => _currentStep = targetStep);
      return;
    }

    if (targetStep == null) {
      _autoCompleting = true;
      try {
        await SetupStorage.markCompleted(true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ข้อมูลพร้อมแล้ว ระบบข้าม onboarding ให้โดยอัตโนมัติ'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      } finally {
        _autoCompleting = false;
      }
    }
  }

  Widget _heroCard(List<_SetupStepMeta> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16324F), Color(0xFF1E5A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ตั้งค่าระบบครั้งแรก',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'เริ่มจากข้อมูลร้าน แล้วพาไปเปิดหน้าสินค้าและผู้ใช้งานที่มีอยู่จริงในระบบ เพื่อให้พร้อมใช้งานเร็วที่สุด',
            style: TextStyle(color: Color(0xFFD9E9F3), height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (step) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(step.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          step.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _gateReasonCard(String message) {
    final completed = _readiness.completedCriteriaCount;
    final total = _readiness.totalCriteriaCount;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.warningColor.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'พร้อมแล้ว $completed จาก $total ข้อ',
                      style: const TextStyle(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'เหตุผลที่ระบบยังไม่เปิดให้ใช้งานตรง ๆ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      color: AppTheme.subtextColorOf(context),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressStrip(List<_SetupStepMeta> steps) {
    return Row(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final active = index == _currentStep;
        final done = index < _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: done
                  ? step.color.withValues(alpha: 0.12)
                  : active
                      ? Theme.of(context).cardColor
                      : Theme.of(context).cardColor.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done || active
                    ? step.color.withValues(alpha: 0.45)
                    : AppTheme.borderColorOf(context),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: done ? step.color : step.color.withValues(alpha: 0.14),
                  child: Icon(
                    done ? Icons.check : step.icon,
                    size: 14,
                    color: done ? Colors.white : step.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtextColorOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _storeInfoStep() {
    return _stepCard(
      title: 'ข้อมูลร้าน',
      subtitle:
          'ข้อมูลชุดนี้จะถูกใช้กับใบเสร็จ รายงาน และข้อมูลสำรองของกิจการ',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อร้าน / ชื่อบริษัท',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'กรุณากรอกชื่อร้าน';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ที่อยู่ร้าน',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchWarehouseStep({
    required int totalBranches,
    required int activeBranches,
    required int totalWarehouses,
    required int activeWarehouses,
    required int validWarehousesOnActiveBranches,
    required BranchModel? selectedBranch,
    required WarehouseModel? selectedWarehouse,
  }) {
    return _stepCard(
      title: 'สาขาและคลัง',
      subtitle:
          'ระบบขายจะยึดสาขาและคลังที่เครื่องนี้เลือกไว้จริง จึงต้องมีคลัง active ที่ผูกกับสาขา active และตั้งค่า POS context ให้พร้อมก่อนเริ่มใช้งาน',
      child: Column(
        children: [
          _statTile(
            icon: Icons.store_outlined,
            color: Colors.deepOrange,
            title: 'สาขาทั้งหมดในระบบ',
            value: '$totalBranches สาขา',
          ),
          const SizedBox(height: 8),
          _statTile(
            icon: Icons.warehouse_outlined,
            color: Colors.brown,
            title: 'คลังทั้งหมดในระบบ',
            value: '$totalWarehouses คลัง',
          ),
          const SizedBox(height: 8),
          _checkRow(
            label: 'มีสาขา active อย่างน้อย 1 สาขา',
            passed: _readiness.hasActiveBranches,
            detail: activeBranches > 0
                ? 'พร้อมใช้งาน $activeBranches สาขา'
                : 'ยังไม่มีสาขาที่พร้อมใช้งาน',
          ),
          _checkRow(
            label: 'มีคลัง active อย่างน้อย 1 คลัง',
            passed: _readiness.hasActiveWarehouses,
            detail: activeWarehouses > 0
                ? 'พบคลัง active $activeWarehouses คลัง'
                : 'ยังไม่มีคลังที่พร้อมใช้งาน',
          ),
          _checkRow(
            label: 'มีคลัง active ที่ผูกกับสาขา active',
            passed: _readiness.hasWarehousesOnActiveBranches,
            detail: validWarehousesOnActiveBranches > 0
                ? 'พร้อมใช้งาน $validWarehousesOnActiveBranches คลัง'
                : 'ยังไม่มีคลังที่ผูกกับสาขา active จึงยังตัดสต๊อกตามสาขาไม่ได้',
          ),
          _checkRow(
            label: 'เลือกสาขาสำหรับ POS แล้ว',
            passed: _readiness.hasSelectedActiveBranch,
            detail: selectedBranch != null && _readiness.hasSelectedActiveBranch
                ? 'กำลังใช้ ${selectedBranch.branchName}'
                : 'ยังไม่ได้เลือกสาขา active สำหรับเครื่องนี้',
          ),
          _checkRow(
            label: 'เลือกคลังสำหรับ POS แล้ว',
            passed: _readiness.hasSelectedActiveWarehouse,
            detail: selectedWarehouse != null &&
                    _readiness.hasSelectedActiveWarehouse
                ? 'กำลังใช้ ${selectedWarehouse.warehouseName}'
                : 'ยังไม่ได้เลือกคลัง active สำหรับเครื่องนี้',
          ),
          _checkRow(
            label: 'คลังที่เลือกอยู่ภายใต้สาขาที่เลือก',
            passed: _readiness.selectedWarehouseMatchesBranch,
            detail: _readiness.selectedWarehouseMatchesBranch
                ? 'POS context พร้อมขายและตัดสต๊อกแล้ว'
                : 'เลือกสาขาและคลังให้สัมพันธ์กันก่อนเปิดขายจริง',
          ),
          const SizedBox(height: 12),
          _ctaTile(
            icon: Icons.add_business_outlined,
            color: Colors.deepOrange,
            title: 'เปิดหน้าจัดการสาขาและคลัง',
            subtitle:
                'เพิ่มสาขาใหม่ และสร้างคลังอย่างน้อย 1 คลังให้พร้อมสำหรับขายและตัดสต๊อก',
            onTap: _openBranches,
          ),
          const SizedBox(height: 8),
          _ctaTile(
            icon: Icons.point_of_sale_outlined,
            color: Colors.brown,
            title: 'เลือกสาขา/คลังที่เครื่อง POS จะใช้งาน',
            subtitle:
                'เปิดหน้าการเชื่อมต่อ/ซิงก์เพื่อกำหนด selected branch และ selected warehouse ของเครื่องนี้',
            onTap: _openPosContextSetup,
          ),
        ],
      ),
    );
  }

  Widget _productStep({
    required int totalProducts,
    required int activeProducts,
    required int stockProducts,
  }) {
    return _stepCard(
      title: 'ตั้งต้นสินค้าและสต๊อก',
      subtitle: 'เปิดไปหน้าสินค้าเพื่อเพิ่มข้อมูลจริง หรือเช็กสต๊อกเริ่มต้นก่อนเปิดขาย',
      child: Column(
        children: [
          _statTile(
            icon: Icons.inventory_2_outlined,
            color: Colors.green,
            title: 'สินค้าทั้งหมดในระบบ',
            value: '$totalProducts รายการ',
          ),
          const SizedBox(height: 8),
          _checkRow(
            label: 'มีสินค้าอย่างน้อย 1 รายการ',
            passed: totalProducts > 0,
            detail: totalProducts > 0 ? 'พบ $totalProducts รายการ' : 'ยังไม่พบสินค้า',
          ),
          _checkRow(
            label: 'สินค้าที่เปิดใช้งาน',
            passed: _readiness.hasActiveProducts,
            detail: activeProducts > 0
                ? 'พร้อมขาย $activeProducts รายการ'
                : 'ยังไม่มีสินค้า active',
          ),
          _checkRow(
            label: 'สินค้าที่ควบคุมสต๊อก',
            passed: _readiness.hasStockControlledProducts,
            detail: stockProducts > 0
                ? 'มี $stockProducts รายการ เกณฑ์ readiness ส่วนสินค้าผ่านแล้ว'
                : 'ยังไม่มีสินค้าที่ผูกสต๊อก จึงยังไม่ถือว่าพร้อมใช้งานจริง',
          ),
          const SizedBox(height: 12),
          _ctaTile(
            icon: Icons.add_box_outlined,
            color: Colors.green,
            title: 'เปิดหน้าจัดการสินค้า',
            subtitle: 'เพิ่ม แก้ไข หรือ import สินค้าจริงเข้าระบบ',
            onTap: _openProducts,
          ),
          const SizedBox(height: 8),
          _hintLine(
            _productsVisited
                ? 'เปิดหน้าสินค้าแล้ว คุณกลับมาทำขั้นต่อไปได้ทันที'
                : 'แนะนำให้เพิ่มสินค้าอย่างน้อย 1 รายการก่อนเริ่มขาย',
          ),
        ],
      ),
    );
  }

  Widget _userStep({
    required int totalUsers,
    required int activeUsers,
    required int staffUsers,
  }) {
    return _stepCard(
      title: 'ตั้งทีมงานและสิทธิ์',
      subtitle: 'เข้าไปสร้างผู้ใช้สำหรับแคชเชียร์หรือผู้จัดการ และกำหนดสิทธิ์จากหน้าจัดการผู้ใช้',
      child: Column(
        children: [
          _statTile(
            icon: Icons.people_alt_outlined,
            color: Colors.blue,
            title: 'ผู้ใช้ทั้งหมดในระบบ',
            value: '$totalUsers คน',
          ),
          const SizedBox(height: 8),
          _checkRow(
            label: 'มีผู้ใช้ active',
            passed: activeUsers > 0,
            detail: activeUsers > 0 ? '$activeUsers คน' : 'ยังไม่มีผู้ใช้ที่ใช้งานได้',
          ),
          _checkRow(
            label: 'มีพนักงานนอกเหนือจาก admin',
            passed: staffUsers > 0,
            detail: staffUsers > 0
                ? 'พบ $staffUsers คน ระบบจะข้ามขั้นนี้อัตโนมัติ'
                : 'ยังมีเฉพาะ admin หรือยังไม่เปิดใช้งานผู้ใช้',
          ),
          const SizedBox(height: 12),
          _ctaTile(
            icon: Icons.person_add_alt_1_outlined,
            color: Colors.blue,
            title: 'เปิดหน้าจัดการผู้ใช้งาน',
            subtitle: 'เพิ่มพนักงานใหม่และกำหนด role ก่อนใช้งานจริง',
            onTap: _openUsers,
          ),
          const SizedBox(height: 8),
          _hintLine(
            _usersVisited
                ? 'เปิดหน้าผู้ใช้งานแล้ว พร้อมปิด onboarding ได้เลย'
                : 'ถ้ายังมีแค่ admin เดียว คุณยังปิด wizard ได้และกลับมาเพิ่มภายหลัง',
          ),
        ],
      ),
    );
  }

  Widget _footerActions() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == 3;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving
                ? null
                : () {
                    if (isFirst) {
                      _finishSetup(allowEmptyCompany: true);
                    } else {
                      setState(() => _currentStep -= 1);
                    }
                  },
            child: Text(isFirst ? 'ข้ามไปก่อน' : 'ย้อนกลับ'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _saving
                ? null
                : () {
                    if (_currentStep == 0) {
                      _saveStoreInfo();
                    } else if (!isLast) {
                      setState(() => _currentStep += 1);
                    } else {
                      _finishSetup();
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _currentStep == 0
                        ? 'บันทึกและไปต่อ'
                        : isLast
                            ? 'เริ่มใช้งานระบบ'
                            : 'ไปขั้นถัดไป',
                  ),
          ),
        ),
      ],
    );
  }

  Widget _restoreChoiceCard() {
    final updatedAt = _restoreSnapshot.updatedAtIso == null
        ? null
        : DateTime.tryParse(_restoreSnapshot.updatedAtIso!)?.toLocal();
    final statusMeta = switch (_restoreSnapshot.status) {
      SetupRestoreStatus.restored => (
          'กู้คืนข้อมูลแล้ว',
          _restoreSnapshot.source == 'google_drive'
              ? 'กู้คืนจาก Google Drive'
              : 'กู้คืนจากไฟล์สำรองในเครื่อง',
          AppTheme.successColor,
          Icons.check_circle_outline,
        ),
      SetupRestoreStatus.skipped => (
          'ข้ามการกู้คืนไว้ก่อน',
          'คุณเลือกเริ่ม setup แบบไม่ restore ตอนนี้',
          AppTheme.warningColor,
          Icons.schedule_outlined,
        ),
      SetupRestoreStatus.undecided => (
          'ยังไม่ได้เลือก',
          'ถ้ามีข้อมูลเดิม แนะนำให้กู้คืนก่อนเริ่ม onboarding',
          const Color(0xFF4A6572),
          Icons.help_outline,
        ),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6572).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_backup_restore_outlined,
                    color: Color(0xFF4A6572),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'มีข้อมูลสำรองเดิมหรือไม่',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ถ้าคุณมีไฟล์สำรองจากเครื่องเก่า สามารถกู้คืนก่อนทำ onboarding ต่อได้ ระบบจะโหลดฐานข้อมูลกลับเข้ามาและข้ามขั้นตั้งต้นให้ทันที',
              style: TextStyle(
                color: AppTheme.subtextColorOf(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusMeta.$3.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusMeta.$3.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusMeta.$4, color: statusMeta.$3, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusMeta.$1,
                          style: TextStyle(
                            color: statusMeta.$3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusMeta.$2,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtextColorOf(context),
                          ),
                        ),
                        if (updatedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'อัปเดตเมื่อ ${_dateTimeFmt.format(updatedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.subtextColorOf(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _isRestoringBackup || _isUpdatingRestoreChoice
                      ? null
                      : _restoreFromLocalBackup,
                  icon: _isRestoringBackup
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open_outlined),
                  label: const Text('กู้คืนจากไฟล์สำรอง'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRestoringBackup || _isUpdatingRestoreChoice
                      ? null
                      : _restoreFromGoogleDrive,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('กู้คืนจาก Google Drive'),
                ),
                TextButton.icon(
                  onPressed: _isRestoringBackup || _isUpdatingRestoreChoice
                      ? null
                      : _markRestoreSkipped,
                  icon: _isUpdatingRestoreChoice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.skip_next_outlined),
                  label: const Text('ข้าม restore ไว้ก่อน'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _readinessSummaryCard() {
    final isReady = _readiness.isFullyReady;
    final missing = _readiness.missingItems;
    final accent = isReady ? AppTheme.successColor : AppTheme.warningColor;
    final title = isReady ? 'พร้อมใช้งานแล้ว' : 'ตอนนี้ยังขาดอะไรอีกบ้างก่อนพร้อมใช้งาน';
    final subtitle = isReady
        ? 'ข้อมูลร้าน โครงสร้างสาขา/คลัง POS context สินค้า active ที่ควบคุมสต๊อกอย่างน้อย 1 รายการ และพนักงานจริงครบแล้ว ระบบจะข้าม onboarding ให้โดยอัตโนมัติ'
        : missing.join(' • ');
    final passedItems = <_ReadinessItem>[
      _ReadinessItem(
        label: 'ข้อมูลร้าน',
        passed: _readiness.hasStoreInfo,
        onTap: () => _jumpToStep(0),
        actionLabel: 'ไปขั้นร้าน',
      ),
      _ReadinessItem(
        label: 'สาขา active',
        passed: _readiness.hasActiveBranches,
        onTap: _openBranches,
        actionLabel: 'เปิดหน้าสาขา',
      ),
      _ReadinessItem(
        label: 'คลัง active ที่ผูกกับสาขา active',
        passed: _readiness.hasWarehousesOnActiveBranches,
        onTap: _openBranches,
        actionLabel: 'เปิดหน้าสาขา',
      ),
      _ReadinessItem(
        label: 'เลือกสาขาสำหรับ POS แล้ว',
        passed: _readiness.hasSelectedActiveBranch,
        onTap: _openPosContextSetup,
        actionLabel: 'ตั้งค่า POS',
      ),
      _ReadinessItem(
        label: 'เลือกคลังสำหรับ POS แล้ว',
        passed: _readiness.hasSelectedActiveWarehouse,
        onTap: _openPosContextSetup,
        actionLabel: 'ตั้งค่า POS',
      ),
      _ReadinessItem(
        label: 'คลังที่เลือกตรงกับสาขาที่เลือก',
        passed: _readiness.selectedWarehouseMatchesBranch,
        onTap: _openPosContextSetup,
        actionLabel: 'ตั้งค่า POS',
      ),
      _ReadinessItem(
        label: 'สินค้า active',
        passed: _readiness.hasActiveProducts,
        onTap: () => _jumpToStep(2),
        actionLabel: 'ไปขั้นสินค้า',
      ),
      _ReadinessItem(
        label: 'สินค้าควบคุมสต๊อก',
        passed: _readiness.hasStockControlledProducts,
        onTap: () => _jumpToStep(2),
        actionLabel: 'ไปขั้นสินค้า',
      ),
      _ReadinessItem(
        label: 'พนักงานจริง',
        passed: _readiness.staffReady,
        onTap: () => _jumpToStep(3),
        actionLabel: 'ไปขั้นพนักงาน',
      ),
    ];
    final passedGroup = passedItems.where((item) => item.passed).toList();
    final missingGroup = passedItems.where((item) => !item.passed).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isReady
                        ? Icons.verified_outlined
                        : Icons.assignment_late_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.subtextColorOf(context),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _summarySection(
              title: 'สิ่งที่ผ่านแล้ว',
              icon: Icons.check_circle_outline,
              color: AppTheme.successColor,
              items: passedGroup,
              emptyLabel: 'ยังไม่มีรายการที่ผ่าน',
            ),
            const SizedBox(height: 12),
            _summarySection(
              title: 'สิ่งที่ยังขาด',
              icon: Icons.assignment_late_outlined,
              color: AppTheme.warningColor,
              items: missingGroup,
              emptyLabel: 'ไม่มีรายการค้างแล้ว',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summarySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_ReadinessItem> items,
    required String emptyLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtextColorOf(context),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _summaryStatusTile(item: item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryStatusTile({required _ReadinessItem item}) {
    final color = item.passed ? AppTheme.successColor : AppTheme.warningColor;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              item.passed
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              item.actionLabel ?? 'เปิดดู',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtextColorOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.subtextColorOf(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _ctaTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColorOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtextColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppTheme.subtextColorOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.subtextColorOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow({
    required String label,
    required bool passed,
    required String detail,
  }) {
    final color = passed ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtextColorOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupLoadingScaffold extends StatelessWidget {
  const _SetupLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _SetupStepMeta {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _SetupStepMeta({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _ReadinessStatus {
  final String label;
  final bool passed;

  const _ReadinessStatus({
    required this.label,
    required this.passed,
  });
}

class _ReadinessItem {
  final String label;
  final bool passed;
  final VoidCallback onTap;
  final String? actionLabel;

  const _ReadinessItem({
    required this.label,
    required this.passed,
    required this.onTap,
    this.actionLabel,
  });
}

class _DriveBackupListDialog extends StatelessWidget {
  final List<DriveBackupItem> items;
  final DateFormat dateTimeFmt;

  const _DriveBackupListDialog({
    required this.items,
    required this.dateTimeFmt,
  });

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final decimals = unitIndex == 0 ? 0 : 2;
    return '${size.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_outlined, color: Color(0xFF1A73E8), size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('ไฟล์สำรองบน Google Drive')),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 480,
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'ไม่พบไฟล์สำรองข้อมูลบน Google Drive',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final createdAt = item.createdAt == null
                      ? null
                      : DateTime.tryParse(item.createdAt!);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.backup_outlined,
                        color: Color(0xFF1A73E8),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.companyName?.isNotEmpty == true
                          ? item.companyName!
                          : item.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (createdAt != null)
                          Text(
                            dateTimeFmt.format(createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        Text(
                          '${item.fileName}  •  ${_formatBytes(item.fileSize)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).pop(item),
                      child: const Text('กู้คืน'),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}
