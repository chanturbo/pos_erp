import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/main.dart' show applyRestoreInPlace;
import '../../../../core/config/app_mode.dart';
import '../../../../core/services/backup/backup_service.dart';
import '../../../../core/services/backup/google_drive_backup_service.dart';
import '../../../../core/services/backup/models/backup_result.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../routes/app_router.dart';
import '../providers/auth_provider.dart'; // ✅ เพิ่ม สำหรับ isCashierRole helper

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');
  bool _obscurePassword = true;
  bool _isRestoringBackup = false;
  bool _isRestoringFromDrive = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      if (AppModeConfig.mode == AppMode.clientMobile) {
        Navigator.of(context).pushReplacementNamed(AppRouter.mobileOrder);
        return;
      }

      final user = ref.read(authProvider).user;
      final roleId = user?.roleId?.toUpperCase() ?? '';

      // ── Role-based redirect ─────────────────────────────────
      // CASHIER / SALE / POS → เข้า POS โดยตรง (isCashierMode: true)
      // ADMIN / อื่นๆ         → เข้าหน้าหลัก
      if (AppRouter.isCashierRole(roleId)) {
        Navigator.of(context).pushReplacementNamed(
          AppRouter.pos,
          arguments: true, // isCashierMode = true
        );
      } else {
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      }
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'เข้าสู่ระบบไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              const Text(
                'ใช้รหัสเดียวกับตอนสร้างไฟล์สำรองข้อมูล',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
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
    return result;
  }

  Widget _restoreInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 10),
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
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.refresh),
            label: const Text('กู้คืนข้อมูล'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _restoreFromBackup() async {
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

      await applyRestoreInPlace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กู้คืนข้อมูลสำเร็จแล้ว กรุณาเข้าสู่ระบบอีกครั้ง'),
          backgroundColor: AppTheme.success,
        ),
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
    setState(() => _isRestoringFromDrive = true);

    try {
      await googleDrive.signIn();
      if (!mounted) return;

      final items = await googleDrive.listBackups();
      if (!mounted) return;

      final selectedItem = await showDialog<DriveBackupItem>(
        context: context,
        builder: (context) =>
            _DriveBackupListDialog(items: items, dateTimeFmt: _dateTimeFmt),
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

        await applyRestoreInPlace();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'กู้คืนข้อมูลจาก Google Drive สำเร็จแล้ว กรุณาเข้าสู่ระบบอีกครั้ง',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
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
      if (mounted) setState(() => _isRestoringFromDrive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/logo-deepos.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.point_of_sale,
                          size: 80,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'DEE POS',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '[POINT OF SALE SYSTEM]',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'เข้าสู่ระบบ',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'กรุณากรอก Username'
                            : null,
                        enabled: !authState.isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'กรุณากรอก Password'
                            : null,
                        enabled: !authState.isLoading,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _handleLogin,
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed:
                              authState.isLoading ||
                                  _isRestoringBackup ||
                                  _isRestoringFromDrive
                              ? null
                              : _restoreFromBackup,
                          icon: _isRestoringBackup
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.settings_backup_restore_outlined,
                                ),
                          label: Text(
                            _isRestoringBackup
                                ? 'กำลังกู้คืนข้อมูล...'
                                : 'กู้คืนข้อมูลจากไฟล์สำรอง',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed:
                              authState.isLoading ||
                                  _isRestoringBackup ||
                                  _isRestoringFromDrive
                              ? null
                              : _restoreFromGoogleDrive,
                          icon: _isRestoringFromDrive
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          label: Text(
                            _isRestoringFromDrive
                                ? 'กำลังกู้คืนจาก Google Drive...'
                                : 'กู้คืนข้อมูลจาก Google Drive',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info box — รักษาจากไฟล์เดิม
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin: admin / admin123\nCashier: cashier / cashier123  (→ เข้า POS โดยตรง)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      title: Row(
        children: const [
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
                      child: const Text(
                        'กู้คืน',
                        style: TextStyle(color: Color(0xFF1A73E8)),
                      ),
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
