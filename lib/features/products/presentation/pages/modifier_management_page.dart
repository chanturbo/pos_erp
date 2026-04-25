import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/models/modifier_model.dart';
import '../providers/modifier_provider.dart';

const _orange = AppTheme.primaryColor;
const _navy = AppTheme.navyColor;
const _success = AppTheme.successColor;

class ModifierManagementPage extends ConsumerWidget {
  const ModifierManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(modifierGroupsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        title: const Text('จัดการ Modifier Groups'),
        backgroundColor: AppTheme.cardColor(context),
        foregroundColor: AppTheme.textColorOf(context),
        elevation: 0,
        actions: [
          FilledButton.icon(
            onPressed: () => _showGroupDialog(context, ref, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('สร้าง Group'),
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: asyncGroups.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) => groups.isEmpty
            ? _EmptyState(
                onAdd: () => _showGroupDialog(context, ref, null))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(height: 12),
                itemBuilder: (_, i) => _GroupCard(
                  group: groups[i],
                  onEditGroup: () =>
                      _showGroupDialog(context, ref, groups[i]),
                  onDeleteGroup: () =>
                      _confirmDeleteGroup(context, ref, groups[i]),
                  onAddOption: () =>
                      _showOptionDialog(context, ref, groups[i].modifierGroupId, null),
                  onEditOption: (opt) =>
                      _showOptionDialog(context, ref, groups[i].modifierGroupId, opt),
                  onDeleteOption: (opt) =>
                      _confirmDeleteOption(context, ref, opt),
                ),
              ),
      ),
    );
  }

  Future<void> _showGroupDialog(
      BuildContext context, WidgetRef ref, ModifierGroupModel? existing) async {
    final nameCtrl = TextEditingController(text: existing?.groupName ?? '');
    String selType = existing?.selectionType ?? 'SINGLE';
    bool isRequired = existing?.isRequired ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.cardColor(context),
          title: Text(
            existing == null ? 'สร้าง Modifier Group' : 'แก้ไข Group',
            style: TextStyle(color: AppTheme.textColorOf(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: AppTheme.textColorOf(context)),
                decoration: InputDecoration(
                  labelText: 'ชื่อ Group',
                  hintText: 'เช่น ขนาด, ระดับความเผ็ด',
                  labelStyle: TextStyle(color: AppTheme.subtextColorOf(context)),
                ),
              ),
              const SizedBox(height: 16),
              Text('ประเภทการเลือก',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtextColorOf(context))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SINGLE', label: Text('เลือกได้ 1')),
                  ButtonSegment(
                      value: 'MULTIPLE', label: Text('เลือกได้หลาย')),
                ],
                selected: {selType},
                onSelectionChanged: (v) =>
                    setState(() => selType = v.first),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('บังคับเลือก'),
                value: isRequired,
                onChanged: (v) =>
                    setState(() => isRequired = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: _orange,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final notifier =
                    ref.read(modifierGroupsProvider.notifier);
                bool ok;
                if (existing == null) {
                  ok = await notifier.createGroup({
                    'group_name': name,
                    'selection_type': selType,
                    'is_required': isRequired,
                    'min_selection': 0,
                    'max_selection': selType == 'SINGLE' ? 1 : 10,
                  });
                } else {
                  ok = await notifier.updateGroup(
                      existing.modifierGroupId, {
                    'group_name': name,
                    'selection_type': selType,
                    'is_required': isRequired,
                    'max_selection': selType == 'SINGLE' ? 1 : 10,
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เกิดข้อผิดพลาด')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: _orange),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptionDialog(BuildContext context, WidgetRef ref,
      String groupId, ModifierOptionModel? existing) async {
    final nameCtrl =
        TextEditingController(text: existing?.modifierName ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.priceAdjustment == null
            ? '0'
            : existing!.priceAdjustment.toStringAsFixed(2));
    bool isDefault = existing?.isDefault ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.cardColor(context),
          title: Text(
            existing == null ? 'เพิ่ม Option' : 'แก้ไข Option',
            style: TextStyle(color: AppTheme.textColorOf(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: AppTheme.textColorOf(context)),
                decoration: const InputDecoration(
                  labelText: 'ชื่อ Option',
                  hintText: 'เช่น ธรรมดา, พิเศษ, ไม่เผ็ด',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^-?\d*\.?\d*'))
                ],
                style: TextStyle(color: AppTheme.textColorOf(context)),
                decoration: const InputDecoration(
                  labelText: 'ปรับราคา (฿)',
                  hintText: '0 = ราคาเดิม, +20 = บวก 20',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('ค่าเริ่มต้น'),
                value: isDefault,
                onChanged: (v) =>
                    setState(() => isDefault = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: _orange,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final adj =
                    double.tryParse(priceCtrl.text) ?? 0;
                final notifier =
                    ref.read(modifierGroupsProvider.notifier);
                bool ok;
                if (existing == null) {
                  ok = await notifier.createOption(groupId, {
                    'modifier_name': name,
                    'price_adjustment': adj,
                    'is_default': isDefault,
                  });
                } else {
                  ok = await notifier.updateOption(
                      existing.modifierId, {
                    'modifier_name': name,
                    'price_adjustment': adj,
                    'is_default': isDefault,
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เกิดข้อผิดพลาด')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: _orange),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context, WidgetRef ref, ModifierGroupModel group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        title: const Text('ลบ Group'),
        content: Text(
            'ลบ "${group.groupName}" และ options ทั้งหมด?\n'
            'สินค้าที่ผูกกับ group นี้จะถูก unlink ด้วย'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(modifierGroupsProvider.notifier)
          .deleteGroup(group.modifierGroupId);
    }
  }

  Future<void> _confirmDeleteOption(BuildContext context, WidgetRef ref,
      ModifierOptionModel option) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        title: const Text('ลบ Option'),
        content: Text('ลบ "${option.modifierName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(modifierGroupsProvider.notifier)
          .deleteOption(option.modifierId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final ModifierGroupModel group;
  final VoidCallback onEditGroup;
  final VoidCallback onDeleteGroup;
  final VoidCallback onAddOption;
  final void Function(ModifierOptionModel) onEditOption;
  final void Function(ModifierOptionModel) onDeleteOption;

  const _GroupCard({
    required this.group,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onAddOption,
    required this.onEditOption,
    required this.onDeleteOption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: AppRadius.sm,
                  ),
                  child:
                      const Icon(Icons.tune, size: 16, color: _orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.groupName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColorOf(context),
                        ),
                      ),
                      Row(
                        children: [
                          _Chip(
                              group.isSingle
                                  ? 'เลือกได้ 1'
                                  : 'เลือกได้หลาย',
                              _navy),
                          if (group.isRequired) ...[
                            const SizedBox(width: 4),
                            _Chip('บังคับเลือก', AppTheme.errorColor),
                          ],
                          const SizedBox(width: 4),
                          _Chip(
                              '${group.options.length} options',
                              AppTheme.infoColor),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEditGroup,
                  tooltip: 'แก้ไข Group',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.errorColor),
                  onPressed: onDeleteGroup,
                  tooltip: 'ลบ Group',
                ),
              ],
            ),
          ),

          if (group.options.isNotEmpty)
            const Divider(height: 1, indent: 16, endIndent: 16),

          // Options
          ...group.options.map(
            (opt) => ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20),
              leading: opt.isDefault
                  ? const Icon(Icons.star,
                      size: 14, color: _orange)
                  : const Icon(Icons.radio_button_unchecked,
                      size: 14, color: Colors.grey),
              title: Text(opt.modifierName,
                  style: const TextStyle(fontSize: 13)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PriceTag(opt.priceAdjustment),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => onEditOption(opt),
                    borderRadius: AppRadius.xs,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => onDeleteOption(opt),
                    borderRadius: AppRadius.xs,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 14, color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add option button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OutlinedButton.icon(
              onPressed: onAddOption,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('เพิ่ม Option',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: BorderSide(
                    color: _orange.withValues(alpha: 0.5)),
                foregroundColor: _orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.xs,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final double adj;
  const _PriceTag(this.adj);

  @override
  Widget build(BuildContext context) {
    if (adj == 0) {
      return const SizedBox.shrink();
    }
    final sign = adj > 0 ? '+' : '';
    final color = adj > 0 ? _success : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.xs,
      ),
      child: Text(
        '$sign฿${adj.toStringAsFixed(2)}',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tune,
              size: 64,
              color: AppTheme.iconSubtleOf(context)),
          const SizedBox(height: 16),
          Text('ยังไม่มี Modifier Groups',
              style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.subtextColorOf(context))),
          const SizedBox(height: 8),
          Text('เช่น ขนาด (ธรรมดา/พิเศษ), ระดับความเผ็ด',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.subtextColorOf(context))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('สร้าง Modifier Group'),
            style: FilledButton.styleFrom(backgroundColor: _orange),
          ),
        ],
      ),
    );
  }
}
