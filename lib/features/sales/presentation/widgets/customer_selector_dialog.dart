import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../customers/data/models/customer_model.dart';

const _kPrimary = Color(0xFFE8622A);
const _kPrimaryLight = Color(0xFFFFF3EE);
const _kBorder = Color(0xFFE0E0E0);
const _kTextSub = Color(0xFF8A8A8A);

class CustomerSelectorDialog extends ConsumerStatefulWidget {
  final CustomerModel? currentCustomer;

  const CustomerSelectorDialog({super.key, this.currentCustomer});

  @override
  ConsumerState<CustomerSelectorDialog> createState() =>
      _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState
    extends ConsumerState<CustomerSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showMembersOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    final colors = [
      _kPrimary,
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFF009688),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerListProvider);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 620,
        height: 720,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_outline,
                        color: _kPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'เลือกลูกค้า',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A)),
                  ),
                  const Spacer(),
                  // Toggle member
                  _HeaderChip(
                    icon: Icons.card_membership,
                    label: _showMembersOnly ? 'ทั้งหมด' : 'สมาชิก',
                    active: _showMembersOnly,
                    onTap: () =>
                        setState(() => _showMembersOnly = !_showMembersOnly),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: _kTextSub),
                    ),
                  ),
                ],
              ),
            ),

            // ── Walk-in Button ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: InkWell(
                onTap: () => Navigator.pop(
                  context,
                  CustomerModel(
                    customerId: 'WALK_IN',
                    customerCode: 'WALK-IN',
                    customerName: 'ลูกค้าทั่วไป',
                  ),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF1565C0),
                        child: Icon(Icons.person_outline,
                            color: Colors.white, size: 16),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ลูกค้าทั่วไป',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1565C0))),
                          Text('ขายแบบไม่ระบุลูกค้า',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF5B8DEF))),
                        ],
                      ),
                      Spacer(),
                      Icon(Icons.chevron_right,
                          color: Color(0xFF1565C0), size: 18),
                    ],
                  ),
                ),
              ),
            ),

            // ── Search ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ค้นหา (ชื่อ, รหัส, เบอร์โทร, เลขสมาชิก)',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: _kTextSub),
                  prefixIcon:
                      const Icon(Icons.search, size: 18, color: _kTextSub),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
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
                    borderSide:
                        const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9F9F9),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 8),

            const Divider(height: 1, color: _kBorder),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: customerAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _kPrimary),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('เกิดข้อผิดพลาด: $e',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(customerListProvider.notifier)
                            .refresh(),
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
                data: (customers) {
                  final filtered = customers.where((c) {
                    if (c.customerId == 'WALK_IN') return false;
                    if (_showMembersOnly &&
                        (c.memberNo == null || c.memberNo!.isEmpty)) {
                      return false;
                    }
                    if (_searchQuery.isEmpty) return true;
                    final q = _searchQuery.toLowerCase();
                    return c.customerName.toLowerCase().contains(q) ||
                        c.customerCode.toLowerCase().contains(q) ||
                        (c.phone?.toLowerCase().contains(q) ?? false) ||
                        (c.memberNo?.toLowerCase().contains(q) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showMembersOnly
                                ? Icons.card_membership
                                : Icons.search_off,
                            size: 52,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showMembersOnly
                                ? 'ไม่พบสมาชิก'
                                : 'ไม่พบลูกค้า',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      final isSelected = widget.currentCustomer
                              ?.customerId ==
                          c.customerId;
                      final isMember = c.memberNo != null &&
                          c.memberNo!.isNotEmpty;
                      final color = _avatarColor(c.customerName);
                      final initial = c.customerName.isNotEmpty
                          ? c.customerName.substring(0, 1).toUpperCase()
                          : '?';

                      return InkWell(
                        onTap: () => Navigator.pop(context, c),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _kPrimaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? _kPrimary.withValues(alpha: 0.4)
                                  : _kBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected
                                        ? _kPrimary
                                        : (isMember
                                            ? const Color(0xFFFFB300)
                                            : color),
                                    child: Text(initial,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (isMember)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB300),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white,
                                              width: 1.5),
                                        ),
                                        child: const Icon(Icons.star,
                                            size: 8,
                                            color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.customerName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: const Color(0xFF1A1A1A),
                                        )),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(c.customerCode,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: _kTextSub)),
                                        if (c.phone != null) ...[
                                          const Text(' · ',
                                              style: TextStyle(
                                                  color: _kTextSub)),
                                          Text(c.phone!,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: _kTextSub)),
                                        ],
                                      ],
                                    ),
                                    if (isMember)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 3),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.card_membership,
                                                size: 11,
                                                color: Color(0xFFFFB300)),
                                            const SizedBox(width: 3),
                                            Text(c.memberNo!,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFFFFB300),
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.stars,
                                                size: 11,
                                                color: Color(0xFFFFB300)),
                                            const SizedBox(width: 2),
                                            Text('${c.points} pt',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color:
                                                        Color(0xFFE65100))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Trailing
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: _kPrimary, size: 18)
                              else
                                const Icon(Icons.chevron_right,
                                    color: _kTextSub, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Footer ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ปิด',
                      style:
                          TextStyle(fontSize: 13, color: _kTextSub)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Header Chip
// ─────────────────────────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB300);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? amber : _kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? amber : _kTextSub),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? amber : _kTextSub,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}