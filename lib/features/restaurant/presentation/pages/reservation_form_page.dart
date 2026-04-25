import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../data/models/reservation_model.dart';
import '../providers/reservation_provider.dart';
import '../providers/table_provider.dart';

class ReservationFormPage extends ConsumerStatefulWidget {
  final ReservationModel? existing;
  const ReservationFormPage({super.key, this.existing});

  @override
  ConsumerState<ReservationFormPage> createState() =>
      _ReservationFormPageState();
}

class _ReservationFormPageState extends ConsumerState<ReservationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _partySizeCtrl;

  DateTime _reservationDate = DateTime.now();
  TimeOfDay _reservationTime = TimeOfDay.now();
  String? _tableId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _nameCtrl = TextEditingController(text: r?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: r?.customerPhone ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _partySizeCtrl = TextEditingController(
      text: r != null ? '${r.partySize}' : '2',
    );

    if (r != null) {
      _reservationDate = r.reservationTime;
      _reservationTime = TimeOfDay(
        hour: r.reservationTime.hour,
        minute: r.reservationTime.minute,
      );
      _tableId = r.tableId;
    } else {
      final now = DateTime.now().add(const Duration(hours: 1));
      _reservationDate = now;
      _reservationTime = TimeOfDay(hour: now.hour, minute: 0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _partySizeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final tablesAsync = ref.watch(tableListProvider);
    final tables = tablesAsync.asData?.value ?? [];
    final reservationDateText = DateFormat(
      'd MMM yyyy',
      'th',
    ).format(_reservationDate);
    final reservationTimeText =
        '${_reservationTime.hour.toString().padLeft(2, '0')}:'
        '${_reservationTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขการจอง' : 'เพิ่มการจอง'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final customerSection = _SectionCard(
                      title: 'ข้อมูลลูกค้า',
                      icon: Icons.person_outline,
                      color: AppTheme.primaryColor,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _inputDecoration(
                            context,
                            label: 'ชื่อลูกค้า *',
                            icon: Icons.person,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'กรุณากรอกชื่อ'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: _inputDecoration(
                            context,
                            label: 'เบอร์โทรศัพท์',
                            icon: Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                    );

                    final reservationSection = _SectionCard(
                      title: 'รายละเอียดการจอง',
                      icon: Icons.event_available_outlined,
                      color: AppTheme.infoColor,
                      children: [
                        if (isWide)
                          Row(
                            children: [
                              Expanded(
                                child: _PickerField(
                                  label: 'วันที่',
                                  icon: Icons.calendar_today,
                                  value: reservationDateText,
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerField(
                                  label: 'เวลา',
                                  icon: Icons.access_time,
                                  value: reservationTimeText,
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _PickerField(
                            label: 'วันที่',
                            icon: Icons.calendar_today,
                            value: reservationDateText,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          _PickerField(
                            label: 'เวลา',
                            icon: Icons.access_time,
                            value: reservationTimeText,
                            onTap: _pickTime,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _partySizeCtrl,
                          decoration: _inputDecoration(
                            context,
                            label: 'จำนวนคน *',
                            icon: Icons.group,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) {
                              return 'กรุณาระบุจำนวนคน';
                            }
                            return null;
                          },
                        ),
                      ],
                    );

                    final tableSection = _SectionCard(
                      title: 'โต๊ะ',
                      icon: Icons.table_restaurant_outlined,
                      color: AppTheme.successColor,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _tableId,
                          decoration: _inputDecoration(
                            context,
                            label: 'เลือกโต๊ะล่วงหน้า',
                            icon: Icons.table_restaurant,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('ยังไม่ระบุโต๊ะ'),
                            ),
                            ...tables.map(
                              (t) => DropdownMenuItem(
                                value: t.tableId,
                                child: Text(
                                  '${t.displayName}${t.zoneName != null ? ' (${t.zoneName})' : ''}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _tableId = v),
                        ),
                      ],
                    );

                    final notesSection = _SectionCard(
                      title: 'หมายเหตุ',
                      icon: Icons.sticky_note_2_outlined,
                      color: AppTheme.warningColor,
                      children: [
                        TextFormField(
                          controller: _notesCtrl,
                          decoration: _inputDecoration(
                            context,
                            hint: 'เช่น มีอาหารแพ้, วันเกิด, ต้องการเค้ก...',
                            icon: Icons.note,
                          ),
                          maxLines: 4,
                        ),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReservationFormHeader(
                          isEdit: isEdit,
                          dateText: reservationDateText,
                          timeText: reservationTimeText,
                          partySizeText: _partySizeCtrl.text,
                        ),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: customerSection),
                              const SizedBox(width: 16),
                              Expanded(child: reservationSection),
                            ],
                          )
                        else ...[
                          customerSection,
                          const SizedBox(height: 16),
                          reservationSection,
                        ],
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: tableSection),
                              const SizedBox(width: 16),
                              Expanded(child: notesSection),
                            ],
                          )
                        else ...[
                          tableSection,
                          const SizedBox(height: 16),
                          notesSection,
                        ],
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
            _FormActionBar(
              isSaving: _saving,
              isEdit: isEdit,
              onCancel: () => Navigator.pop(context),
              onSave: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    String? label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppTheme.surface3Of(context),
      border: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reservationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _reservationDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reservationTime,
    );
    if (picked != null) setState(() => _reservationTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final dt = DateTime(
      _reservationDate.year,
      _reservationDate.month,
      _reservationDate.day,
      _reservationTime.hour,
      _reservationTime.minute,
    );

    final body = {
      'customer_name': _nameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      'reservation_time': dt.toIso8601String(),
      'party_size': int.parse(_partySizeCtrl.text),
      'table_id': _tableId,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final notifier = ref.read(reservationsProvider.notifier);
      if (widget.existing != null) {
        await notifier.edit(widget.existing!.reservationId, body);
      } else {
        await notifier.create(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ReservationFormHeader extends StatelessWidget {
  const _ReservationFormHeader({
    required this.isEdit,
    required this.dateText,
    required this.timeText,
    required this.partySizeText,
  });

  final bool isEdit;
  final String dateText;
  final String timeText;
  final String partySizeText;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final partySize = int.tryParse(partySizeText) ?? 0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 7 : 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  isEdit ? Icons.edit_calendar : Icons.event_available,
                  color: AppTheme.primaryColor,
                  size: isMobile ? 16 : 18,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'แก้ไขรายละเอียดการจอง' : 'สร้างการจองใหม่',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'จัดเก็บข้อมูลลูกค้า เวลา จำนวนคน และโต๊ะล่วงหน้า',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.subtextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HeaderChip(
                  label: 'วันที่',
                  value: dateText,
                  icon: Icons.calendar_today_outlined,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _HeaderChip(
                  label: 'เวลา',
                  value: timeText,
                  icon: Icons.access_time,
                  color: AppTheme.infoColor,
                ),
                const SizedBox(width: 8),
                _HeaderChip(
                  label: 'จำนวนคน',
                  value: partySize > 0 ? '$partySize' : '-',
                  icon: Icons.group_outlined,
                  color: AppTheme.successColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: AppTheme.surface3Of(context),
          border: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: AppTheme.inputBorderOf(context)),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: AppTheme.textColorOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FormActionBar extends StatelessWidget {
  const _FormActionBar({
    required this.isSaving,
    required this.isEdit,
    required this.onCancel,
    required this.onSave,
  });

  final bool isSaving;
  final bool isEdit;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        border: Border(top: BorderSide(color: AppTheme.borderColorOf(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : onCancel,
              icon: const Icon(Icons.close),
              label: const Text('ยกเลิก'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มการจอง'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
