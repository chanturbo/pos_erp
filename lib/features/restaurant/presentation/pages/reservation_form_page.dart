import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
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
    _partySizeCtrl =
        TextEditingController(text: r != null ? '${r.partySize}' : '2');

    if (r != null) {
      _reservationDate = r.reservationTime;
      _reservationTime = TimeOfDay(
          hour: r.reservationTime.hour,
          minute: r.reservationTime.minute);
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

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขการจอง' : 'เพิ่มการจอง'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'ข้อมูลลูกค้า',
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อลูกค้า *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'เบอร์โทรศัพท์',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'รายละเอียดการจอง',
              children: [
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'วันที่',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('d MMM yyyy', 'th')
                              .format(_reservationDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'เวลา',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_reservationTime.hour.toString().padLeft(2, '0')}:'
                          '${_reservationTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _partySizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนคน *',
                    prefixIcon: Icon(Icons.group),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'กรุณาระบุจำนวนคน';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'โต๊ะ (ไม่บังคับ)',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tableId,
                  decoration: const InputDecoration(
                    labelText: 'เลือกโต๊ะล่วงหน้า',
                    prefixIcon: Icon(Icons.table_restaurant),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('ยังไม่ระบุโต๊ะ')),
                    ...tables.map((t) => DropdownMenuItem(
                          value: t.tableId,
                          child: Text(
                              '${t.displayName}${t.zoneName != null ? ' (${t.zoneName})' : ''}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _tableId = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'หมายเหตุ',
              children: [
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'เช่น มีอาหารแพ้, วันเกิด, ต้องการเค้ก...',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มการจอง'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
}
