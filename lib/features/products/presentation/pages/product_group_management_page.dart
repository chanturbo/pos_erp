import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';

import '../../../../shared/theme/app_theme.dart';
import '../providers/product_provider.dart';

class ProductGroupManagementPage extends ConsumerStatefulWidget {
  const ProductGroupManagementPage({super.key});

  @override
  ConsumerState<ProductGroupManagementPage> createState() =>
      _ProductGroupManagementPageState();
}

class _ProductGroupManagementPageState
    extends ConsumerState<ProductGroupManagementPage> {
  static const _colorOptions = <_ColorChoice>[
    _ColorChoice('ส้ม', '#EF6C00'),
    _ColorChoice('น้ำเงิน', '#1565C0'),
    _ColorChoice('เขียว', '#2E7D32'),
    _ColorChoice('แดง', '#C62828'),
    _ColorChoice('ชมพู', '#D81B60'),
    _ColorChoice('ม่วง', '#6A1B9A'),
    _ColorChoice('ฟ้า', '#0288D1'),
    _ColorChoice('ทีล', '#00838F'),
    _ColorChoice('น้ำตาล', '#6D4C41'),
    _ColorChoice('เทา', '#546E7A'),
  ];

  static const _iconOptions = <_IconChoice>[
    _IconChoice('สินค้า', 'inventory_2', Icons.inventory_2_outlined),
    _IconChoice('ขาย', 'sell', Icons.sell_outlined),
    _IconChoice('ตะกร้า', 'shopping_basket', Icons.shopping_basket_outlined),
    _IconChoice('เครื่องดื่ม', 'local_drink', Icons.local_drink_outlined),
    _IconChoice('อาหาร', 'fastfood', Icons.fastfood_outlined),
    _IconChoice('ของหวาน', 'icecream', Icons.icecream_outlined),
    _IconChoice('กาแฟ', 'local_cafe', Icons.local_cafe_outlined),
    _IconChoice('เบเกอรี', 'bakery_dining', Icons.bakery_dining_outlined),
    _IconChoice('ร้านค้า', 'storefront', Icons.storefront_outlined),
    _IconChoice(
      'ทำความสะอาด',
      'cleaning_services',
      Icons.cleaning_services_outlined,
    ),
  ];

  Future<void> _openGroupForm([ProductGroupModel? group]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductGroupFormSheet(
        group: group,
        colorOptions: _colorOptions,
        iconOptions: _iconOptions,
      ),
    );
  }

  Future<void> _confirmDelete(ProductGroupModel group) async {
    final repo = ref.read(productGroupRepositoryProvider);
    final check = await repo.checkDeleteGroup(group.groupId);
    if (!mounted) return;

    final productCount = (check['product_count'] as num?)?.toInt() ?? 0;
    final hasProducts = check['has_products'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'ลบหมวดสินค้า',
          icon: Icons.delete_outline,
          iconColor: AppTheme.errorColor,
        ),
        content: Text(
          hasProducts
              ? 'หมวด "${group.groupName}" ยังถูกใช้อยู่ในสินค้า $productCount รายการ จึงยังลบไม่ได้'
              : 'ต้องการลบหมวด "${group.groupName}" ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ปิด'),
          ),
          if (!hasProducts)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('ลบ'),
            ),
        ],
      ),
    );

    if (confirmed != true) return;
    final message = await repo.deleteGroup(group.groupId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'ลบหมวดสินค้าไม่สำเร็จ'),
        backgroundColor: message != null
            ? AppTheme.successColor
            : AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(productGroupsProvider);
    final colors = _GroupPageColors.of(context);
    final groups = groupsAsync.value ?? const <ProductGroupModel>[];

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Column(
        children: [
          _GroupTopBar(
            colors: colors,
            totalGroups: groups.length,
            onRefresh: () => ref.invalidate(productGroupsProvider),
            onAdd: _openGroupForm,
          ),
          _GroupSummaryBar(
            colors: colors,
            totalGroups: groups.length,
            iconCount: groups
                .where((g) => (g.mobileIcon ?? '').trim().isNotEmpty)
                .length,
            colorCount: groups
                .where((g) => (g.mobileColor ?? '').trim().isNotEmpty)
                .length,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(14),
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
                child: groupsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'เกิดข้อผิดพลาด: $e',
                      style: TextStyle(color: colors.subtext),
                    ),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return _GroupEmptyState(
                        colors: colors,
                        onAdd: _openGroupForm,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _GroupListTile(
                        group: groups[index],
                        colors: colors,
                        onEdit: () => _openGroupForm(groups[index]),
                        onDelete: () => _confirmDelete(groups[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: colors.cardBg,
            border: Border(top: BorderSide(color: colors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(productGroupsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('รีเฟรช'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _openGroupForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มหมวด'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTopBar extends StatelessWidget {
  final _GroupPageColors colors;
  final int totalGroups;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _GroupTopBar({
    required this.colors,
    required this.totalGroups,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Container(
      color: colors.topBarBg,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: isWide
          ? Row(
              children: [
                if (canPop) ...[
                  _GroupTopNavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                ],
                _GroupTopPageIcon(),
                const SizedBox(width: 12),
                const Expanded(child: _GroupTopBarText()),
                _GroupTopStatPill(label: 'หมวด', value: '$totalGroups'),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('รีเฟรช'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มหมวด'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (canPop) ...[
                      _GroupTopNavButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _GroupTopPageIcon(),
                    const SizedBox(width: 12),
                    const Expanded(child: _GroupTopBarText()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _GroupTopStatPill(label: 'หมวด', value: '$totalGroups'),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('เพิ่มหมวด'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GroupTopBarText extends StatelessWidget {
  const _GroupTopBarText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'จัดการหมวดสินค้า',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'กำหนดรหัส ชื่อ สี และไอคอนของหมวดสินค้าให้พร้อมใช้งานในระบบ',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

class _GroupTopNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GroupTopNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _GroupTopPageIcon extends StatelessWidget {
  const _GroupTopPageIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Icon(Icons.category_outlined, color: Colors.white),
    );
  }
}

class _GroupTopStatPill extends StatelessWidget {
  final String label;
  final String value;

  const _GroupTopStatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSummaryBar extends StatelessWidget {
  final _GroupPageColors colors;
  final int totalGroups;
  final int iconCount;
  final int colorCount;

  const _GroupSummaryBar({
    required this.colors,
    required this.totalGroups,
    required this.iconCount,
    required this.colorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.summaryBg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _GroupSummaryChip(
            label: 'หมวดทั้งหมด',
            value: '$totalGroups',
            color: AppTheme.info,
          ),
          _GroupSummaryChip(
            label: 'มีไอคอน',
            value: '$iconCount',
            color: AppTheme.primary,
          ),
          _GroupSummaryChip(
            label: 'มีสี',
            value: '$colorCount',
            color: AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _GroupSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GroupSummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupEmptyState extends StatelessWidget {
  final _GroupPageColors colors;
  final VoidCallback onAdd;

  const _GroupEmptyState({required this.colors, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: colors.summaryBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category_outlined,
                size: 42,
                color: colors.emptyIcon,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'ยังไม่มีหมวดสินค้า',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'เริ่มสร้างหมวดสินค้าแรกเพื่อจัดระเบียบรายการสินค้าในระบบ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.subtext),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหมวดแรก'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupListTile extends StatelessWidget {
  final ProductGroupModel group;
  final _GroupPageColors colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupListTile({
    required this.group,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group.mobileColor) ?? AppTheme.primaryColor;
    final icon = _iconForKey(group.mobileIcon);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(icon: Icons.tag, label: group.groupCode),
                      _MetaChip(
                        icon: Icons.palette_outlined,
                        label: group.mobileColor ?? '-',
                      ),
                      _MetaChip(icon: icon, label: group.mobileIcon ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                PopupMenuItem(value: 'delete', child: Text('ลบ')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGroupFormSheet extends ConsumerStatefulWidget {
  final ProductGroupModel? group;
  final List<_ColorChoice> colorOptions;
  final List<_IconChoice> iconOptions;

  const _ProductGroupFormSheet({
    required this.group,
    required this.colorOptions,
    required this.iconOptions,
  });

  @override
  ConsumerState<_ProductGroupFormSheet> createState() =>
      _ProductGroupFormSheetState();
}

class _ProductGroupFormSheetState
    extends ConsumerState<_ProductGroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late String _selectedColor;
  late String _selectedIcon;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.group?.groupCode ?? '',
    );
    _nameController = TextEditingController(
      text: widget.group?.groupName ?? '',
    );
    _selectedColor = widget.group?.mobileColor ?? widget.colorOptions.first.hex;
    _selectedIcon = widget.group?.mobileIcon ?? widget.iconOptions.first.key;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    final payload = {
      'group_code': _codeController.text.trim().toUpperCase(),
      'group_name': _nameController.text.trim(),
      'mobile_color': _selectedColor,
      'mobile_icon': _selectedIcon,
    };

    final repo = ref.read(productGroupRepositoryProvider);
    final ok = widget.group == null
        ? await repo.createGroup(payload)
        : await repo.updateGroup(widget.group!.groupId, payload);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.group == null
                ? 'เพิ่มหมวดสินค้าสำเร็จ'
                : 'แก้ไขหมวดสินค้าสำเร็จ',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('บันทึกหมวดสินค้าไม่สำเร็จ'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewColor = _parseColor(_selectedColor) ?? AppTheme.primaryColor;
    final previewIcon = _iconForKey(_selectedIcon);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.group == null ? 'เพิ่มหมวดสินค้า' : 'แก้ไขหมวดสินค้า',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: previewColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(previewIcon, color: previewColor, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'รหัสหมวด',
                    hintText: 'เช่น DRINK / SNACK',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'กรุณากรอกรหัสหมวด'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อหมวดสินค้า',
                    hintText: 'เช่น เครื่องดื่ม / ของใช้ประจำวัน',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'กรุณากรอกชื่อหมวด'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text(
                  'เลือกสีหมวด',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in widget.colorOptions)
                      _ChoiceTile(
                        selected: _selectedColor == option.hex,
                        onTap: () =>
                            setState(() => _selectedColor = option.hex),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _parseColor(option.hex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(option.label),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'เลือกไอคอนหมวด',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in widget.iconOptions)
                      _ChoiceTile(
                        selected: _selectedIcon == option.key,
                        onTap: () => setState(() => _selectedIcon = option.key),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(option.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(option.label),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      widget.group == null
                          ? 'เพิ่มหมวดสินค้า'
                          : 'บันทึกการแก้ไข',
                    ),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ChoiceTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.10)
              : Colors.grey.withValues(alpha: 0.08),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : Colors.grey.withValues(alpha: 0.22),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _GroupPageColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color summaryBg;
  final Color emptyIcon;

  const _GroupPageColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.summaryBg,
    required this.emptyIcon,
  });

  factory _GroupPageColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GroupPageColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : Colors.grey,
    );
  }
}

class _ColorChoice {
  final String label;
  final String hex;

  const _ColorChoice(this.label, this.hex);
}

class _IconChoice {
  final String label;
  final String key;
  final IconData icon;

  const _IconChoice(this.label, this.key, this.icon);
}

Color? _parseColor(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (!value.startsWith('#')) return null;
  final hex = value.substring(1);
  if (hex.length != 6 && hex.length != 8) return null;
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

IconData _iconForKey(String? key) {
  switch (key) {
    case 'sell':
      return Icons.sell_outlined;
    case 'shopping_basket':
      return Icons.shopping_basket_outlined;
    case 'local_drink':
      return Icons.local_drink_outlined;
    case 'fastfood':
      return Icons.fastfood_outlined;
    case 'icecream':
      return Icons.icecream_outlined;
    case 'local_cafe':
      return Icons.local_cafe_outlined;
    case 'bakery_dining':
      return Icons.bakery_dining_outlined;
    case 'storefront':
      return Icons.storefront_outlined;
    case 'cleaning_services':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}
