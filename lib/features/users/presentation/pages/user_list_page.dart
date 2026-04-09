// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/permissions/app_permissions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/branches/presentation/providers/branch_provider.dart';
import '../../data/models/user_management_model.dart';
import '../providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────
// UserListPage
// ─────────────────────────────────────────────────────────────────
class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterRoleId;      // null = แสดงทั้งหมด
  bool _filterActiveOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserManagementModel> _filter(List<UserManagementModel> all) {
    var list = all;
    if (_filterActiveOnly) list = list.where((u) => u.isActive).toList();
    if (_filterRoleId != null) {
      list = list.where((u) => u.roleId == _filterRoleId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q) ||
        (u.email?.toLowerCase().contains(q) ?? false),
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final currentUser = ref.watch(authProvider).user;
    final roleUpper = currentUser?.roleId?.toUpperCase() ?? '';
    final isAdmin = roleUpper == 'ADMIN';
    final canCreate = isAdmin || roleUpper == 'MANAGER';

    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: const Text('จัดการผู้ใช้งาน'),
        actions: [
          if (canCreate)
            FilledButton.icon(
              onPressed: () => _showUserForm(context, null),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('เพิ่มผู้ใช้'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(context, e),
              data: (users) {
                final filtered = _filter(users);
                if (filtered.isEmpty) return _buildEmpty(users.isEmpty);
                return RefreshIndicator(
                  onRefresh: () => ref.read(userListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _UserCard(
                      user: filtered[i],
                      currentUserId: currentUser?.userId ?? '',
                      isAdmin: isAdmin,
                      onEdit: () => _showUserForm(context, filtered[i]),
                      onChangePassword: () =>
                          _showChangePassword(context, filtered[i]),
                      onToggle: () => _toggleActive(context, filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ────────────────────────────────────────────────
  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkTopBar
            : Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColorOf(context))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search
          SizedBox(
            height: 40,
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ / username / อีเมล',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Role filter
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColorOf(context)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String?>(
                  value: _filterRoleId,
                  hint: const Text('ทุก Role', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ทุก Role', style: TextStyle(fontSize: 13))),
                    ...appRoles.map((r) => DropdownMenuItem(
                      value: r.roleId,
                      child: Text(r.label, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) => setState(() => _filterRoleId = v),
                ),
              ),
            ),
          ),
          // Active only toggle
          FilterChip(
            label: const Text('เฉพาะที่ใช้งานอยู่'),
            selected: _filterActiveOnly,
            onSelected: (v) => setState(() => _filterActiveOnly = v),
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            checkmarkColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              fontSize: 12,
              color: _filterActiveOnly ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noData) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          noData ? 'ยังไม่มีผู้ใช้งาน' : 'ไม่พบผู้ใช้ที่ตรงกับเงื่อนไข',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  Widget _buildError(BuildContext context, Object e) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
        const SizedBox(height: 12),
        Text('เกิดข้อผิดพลาด: $e'),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => ref.read(userListProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  // ── Actions ───────────────────────────────────────────────────
  Future<void> _showUserForm(BuildContext context, UserManagementModel? user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _UserFormPage(user: user)),
    );
  }

  Future<void> _showChangePassword(BuildContext context, UserManagementModel user) async {
    final currentUser = ref.read(authProvider).user;
    final isSelf = currentUser?.userId == user.userId;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePasswordDialog(user: user, isSelf: isSelf),
    );
  }

  Future<void> _toggleActive(BuildContext context, UserManagementModel user) async {
    final action = user.isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน';
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: '$action "${user.fullName}"?',
          icon: user.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1,
          iconColor: user.isActive ? AppTheme.errorColor : AppTheme.successColor,
        ),
        content: Text(user.isActive
            ? 'ผู้ใช้จะไม่สามารถเข้าสู่ระบบได้จนกว่าจะเปิดใช้งานอีกครั้ง'
            : 'ผู้ใช้จะสามารถเข้าสู่ระบบได้อีกครั้ง'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive ? AppTheme.errorColor : AppTheme.successColor,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(userListProvider.notifier).toggleActive(user.userId);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('$action "${user.fullName}" สำเร็จ'),
          backgroundColor: user.isActive ? AppTheme.errorColor : AppTheme.successColor,
          behavior: SnackBarBehavior.floating, width: 320,
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating, width: 320,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// _UserCard
// ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final UserManagementModel user;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onChangePassword;
  final VoidCallback onToggle;

  const _UserCard({
    required this.user,
    required this.currentUserId,
    required this.isAdmin,
    required this.onEdit,
    required this.onChangePassword,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = user.userId == currentUserId;
    final roleColor = _roleColor(user.roleId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: user.isActive
                    ? roleColor.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: user.isActive ? roleColor : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: user.isActive ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('คุณ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${user.username}',
                    style: TextStyle(fontSize: 12, color: AppTheme.subtextColorOf(context)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Role badge
                      if (user.roleName != null)
                        _Chip(label: user.roleName!, color: roleColor),
                      // Branch badge
                      if (user.branchName != null)
                        _Chip(
                          label: user.branchName!,
                          color: Colors.grey,
                          icon: Icons.store_rounded,
                        ),
                      // Inactive badge
                      if (!user.isActive)
                        _Chip(label: 'ปิดใช้งาน', color: AppTheme.errorColor),
                    ],
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email!,
                      style: TextStyle(fontSize: 11, color: AppTheme.subtextColorOf(context)),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'password') onChangePassword();
                if (v == 'toggle') onToggle();
              },
              itemBuilder: (_) => [
                if (isAdmin) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16),
                      SizedBox(width: 10),
                      Text('แก้ไขข้อมูล'),
                    ]),
                  ),
                ],
                const PopupMenuItem(
                  value: 'password',
                  child: Row(children: [
                    Icon(Icons.lock_reset_rounded, size: 16),
                    SizedBox(width: 10),
                    Text('เปลี่ยนรหัสผ่าน'),
                  ]),
                ),
                if (isAdmin && !isSelf)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        user.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: user.isActive ? AppTheme.errorColor : AppTheme.successColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user.isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                        style: TextStyle(
                          color: user.isActive ? AppTheme.errorColor : AppTheme.successColor,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String? roleId) => switch (roleId?.toUpperCase()) {
    'ADMIN'      => const Color(0xFF6C5CE7),
    'MANAGER'    => AppTheme.primaryColor,
    'CASHIER'    => AppTheme.successColor,
    'WAREHOUSE'  => const Color(0xFF0984E3),
    'ACCOUNTANT' => const Color(0xFF00B894),
    _            => Colors.grey,
  };
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _UserFormPage — เพิ่ม / แก้ไข (full-page, matches product form style)
// ─────────────────────────────────────────────────────────────────
class _UserFormPage extends ConsumerStatefulWidget {
  final UserManagementModel? user; // null = สร้างใหม่

  const _UserFormPage({this.user});

  @override
  ConsumerState<_UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<_UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  String? _selectedRoleId;
  String? _selectedBranchId;
  bool _obscurePassword = true;
  bool _loading = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _usernameCtrl  = TextEditingController(text: u?.username ?? '');
    _passwordCtrl  = TextEditingController();
    _fullNameCtrl  = TextEditingController(text: u?.fullName ?? '');
    _emailCtrl     = TextEditingController(text: u?.email ?? '');
    _phoneCtrl     = TextEditingController(text: u?.phone ?? '');
    _selectedRoleId   = u?.roleId;
    _selectedBranchId = u?.branchId;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await ref.read(userListProvider.notifier).updateUser(
          userId:   widget.user!.userId,
          fullName: _fullNameCtrl.text.trim(),
          email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone:    _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          roleId:   _selectedRoleId,
          branchId: _selectedBranchId,
        );
      } else {
        await ref.read(userListProvider.notifier).createUser(
          username:  _usernameCtrl.text.trim(),
          password:  _passwordCtrl.text.trim(),
          fullName:  _fullNameCtrl.text.trim(),
          email:     _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone:     _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          roleId:    _selectedRoleId,
          branchId:  _selectedBranchId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating, width: 360,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);
    final branches = branchesAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Title Bar ─────────────────────────────────────────
          _buildTitleBar(context, isDark),

          // ── Form Body ─────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (ctx, bc) {
                    final isWide = bc.maxWidth >= 900;
                    final card1 = _UserSectionCard(
                      icon: Icons.person_outline,
                      iconColor: AppTheme.primaryColor,
                      title: 'ข้อมูลผู้ใช้',
                      child: Column(
                        children: [
                          // ชื่อ-นามสกุล
                          _UserFormField(
                            controller: _fullNameCtrl,
                            label: 'ชื่อ-นามสกุล',
                            icon: Icons.badge_outlined,
                            required: true,
                            enabled: !_loading,
                            validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุชื่อ' : null,
                          ),
                          const SizedBox(height: 14),

                          // Username
                          _UserFormField(
                            controller: _usernameCtrl,
                            label: 'Username',
                            icon: Icons.alternate_email,
                            required: !_isEdit,
                            readOnly: _isEdit,
                            helperText: _isEdit ? 'ไม่สามารถเปลี่ยน username ได้' : 'อย่างน้อย 3 ตัวอักษร',
                            enabled: !_loading,
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true) return 'กรุณาระบุ username';
                              if ((v?.trim().length ?? 0) < 3) return 'username ต้องมีอย่างน้อย 3 ตัวอักษร';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password (เฉพาะสร้างใหม่)
                          if (!_isEdit) ...[
                            _PasswordField(
                              controller: _passwordCtrl,
                              obscure: _obscurePassword,
                              enabled: !_loading,
                              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                              validator: (v) {
                                if (v?.trim().isEmpty ?? true) return 'กรุณาระบุรหัสผ่าน';
                                if ((v?.trim().length ?? 0) < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email
                          _UserFormField(
                            controller: _emailCtrl,
                            label: 'อีเมล',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 14),

                          // Phone
                          _UserFormField(
                            controller: _phoneCtrl,
                            label: 'เบอร์โทรศัพท์',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            enabled: !_loading,
                          ),
                        ],
                      ),
                    );

                    final card2 = _UserSectionCard(
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: AppTheme.infoColor,
                      title: 'สิทธิ์และสาขา',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Role
                          _DropdownSection<String?>(
                            label: 'บทบาท (Role)',
                            icon: Icons.security_outlined,
                            value: _selectedRoleId,
                            hint: 'เลือก Role',
                            enabled: !_loading,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                              ...appRoles.map((r) => DropdownMenuItem(
                                value: r.roleId,
                                child: Text(r.label),
                              )),
                            ],
                            onChanged: (v) => setState(() => _selectedRoleId = v),
                          ),
                          const SizedBox(height: 14),

                          // Branch
                          _DropdownSection<String?>(
                            label: 'สาขา',
                            icon: Icons.store_outlined,
                            value: _selectedBranchId,
                            hint: 'เลือกสาขา',
                            enabled: !_loading,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                              ...branches.map((b) => DropdownMenuItem(
                                value: b.branchId,
                                child: Text(b.branchName),
                              )),
                            ],
                            onChanged: (v) => setState(() => _selectedBranchId = v),
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: card1),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: card2),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card1,
                        const SizedBox(height: 16),
                        card2,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Bottom Action Bar ─────────────────────────────────
          Container(
            color: isDark ? AppTheme.darkTopBar : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(color: AppTheme.textSub)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isEdit ? 'บันทึก' : 'เพิ่มผู้ใช้', style: const TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.arrow_back, size: 20,
                    color: isDark ? Colors.white70 : AppTheme.textSub),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.manage_accounts_outlined,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'แก้ไขข้อมูลผู้ใช้' : 'เพิ่มผู้ใช้งานใหม่',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 20,
                  color: isDark ? Colors.white54 : AppTheme.textSub),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _UserSectionCard
// ─────────────────────────────────────────────────────────────────
class _UserSectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _UserSectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white12 : AppTheme.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _UserFormField
// ─────────────────────────────────────────────────────────────────
class _UserFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? helperText;
  final String? Function(String?)? validator;

  const _UserFormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : AppTheme.textSub),
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSub),
        prefixIcon: Icon(icon, size: 17, color: isDark ? Colors.white54 : AppTheme.textSub),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        filled: readOnly,
        fillColor: readOnly
            ? (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.08))
            : (isDark ? AppTheme.darkElement : Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _PasswordField
// ─────────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.enabled,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: 'รหัสผ่าน *',
        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : AppTheme.textSub),
        helperText: 'อย่างน้อย 6 ตัวอักษร',
        helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSub),
        prefixIcon: Icon(Icons.lock_outline, size: 17, color: isDark ? Colors.white54 : AppTheme.textSub),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18, color: isDark ? Colors.white54 : AppTheme.textSub),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkElement : Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _DropdownSection
// ─────────────────────────────────────────────────────────────────
class _DropdownSection<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T value;
  final String hint;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownSection({
    required this.label,
    required this.icon,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: isDark ? Colors.white54 : AppTheme.textSub),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : AppTheme.textSub)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkElement : Colors.white,
          ),
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ChangePasswordDialog
// ─────────────────────────────────────────────────────────────────
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  final UserManagementModel user;
  final bool isSelf;

  const _ChangePasswordDialog({required this.user, required this.isSelf});

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureOld  = true;
  bool _obscureNew  = true;
  bool _obscureConf = true;
  bool _loading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(userListProvider.notifier).changePassword(
        userId:      widget.user.userId,
        newPassword: _newCtrl.text.trim(),
        oldPassword: widget.isSelf ? _oldCtrl.text.trim() : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('เปลี่ยนรหัสผ่านสำเร็จ'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating, width: 280,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating, width: 360,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 4, height: 20,
                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('เปลี่ยนรหัสผ่าน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  buildMobileCloseCompactButton(context),
                ]),
                const SizedBox(height: 6),
                Text(
                  widget.user.fullName,
                  style: TextStyle(fontSize: 13, color: AppTheme.subtextColorOf(context)),
                ),
                const SizedBox(height: 20),

                // Old password (เฉพาะเปลี่ยนของตัวเอง)
                if (widget.isSelf) ...[
                  _buildPasswordField(
                    controller: _oldCtrl,
                    label: 'รหัสผ่านเดิม *',
                    obscure: _obscureOld,
                    onToggle: () => setState(() => _obscureOld = !_obscureOld),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุรหัสผ่านเดิม' : null,
                  ),
                  const SizedBox(height: 14),
                ],

                // New password
                _buildPasswordField(
                  controller: _newCtrl,
                  label: 'รหัสผ่านใหม่ *',
                  hint: 'อย่างน้อย 6 ตัวอักษร',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'กรุณาระบุรหัสผ่านใหม่';
                    if ((v?.trim().length ?? 0) < 6) return 'ต้องมีอย่างน้อย 6 ตัวอักษร';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                _buildPasswordField(
                  controller: _confirmCtrl,
                  label: 'ยืนยันรหัสผ่านใหม่ *',
                  obscure: _obscureConf,
                  onToggle: () => setState(() => _obscureConf = !_obscureConf),
                  validator: (v) {
                    if (v?.trim() != _newCtrl.text.trim()) return 'รหัสผ่านไม่ตรงกัน';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('เปลี่ยนรหัสผ่าน'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 18),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
