import 'package:shared_preferences/shared_preferences.dart';

enum SetupRestoreStatus { undecided, skipped, restored }

class SetupPosContextSnapshot {
  final String? branchId;
  final String? warehouseId;

  const SetupPosContextSnapshot({
    this.branchId,
    this.warehouseId,
  });
}

class SetupStorage {
  SetupStorage._();

  static const String setupCompletedKey = 'setup_completed';
  static const String restoreStatusKey = 'setup_restore_status';
  static const String restoreSourceKey = 'setup_restore_source';
  static const String restoreUpdatedAtKey = 'setup_restore_updated_at';
  static const String selectedBranchKey = 'selected_pos_branch_id';
  static const String selectedWarehouseKey = 'selected_pos_warehouse_id';
  static const String demoModeKey = 'demo_seed_mode'; // 'pos' | 'restaurant' | 'both' | 'none'

  static Future<String?> getDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(demoModeKey);
  }

  static Future<void> setDemoMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(demoModeKey, mode);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final explicit = prefs.getBool(setupCompletedKey);
    if (explicit != null) return explicit;
    final companyName = prefs.getString('company_name')?.trim() ?? '';
    return companyName.isNotEmpty;
  }

  static Future<String> getStoredCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_name')?.trim() ?? '';
  }

  static Future<SetupPosContextSnapshot> getPosContextSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return SetupPosContextSnapshot(
      branchId: prefs.getString(selectedBranchKey),
      warehouseId: prefs.getString(selectedWarehouseKey),
    );
  }

  static Future<void> markCompleted([bool value = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(setupCompletedKey, value);
  }

  static Future<SetupRestoreSnapshot> getRestoreSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(restoreStatusKey);
    final status = switch (raw) {
      'skipped' => SetupRestoreStatus.skipped,
      'restored' => SetupRestoreStatus.restored,
      _ => SetupRestoreStatus.undecided,
    };
    return SetupRestoreSnapshot(
      status: status,
      source: prefs.getString(restoreSourceKey),
      updatedAtIso: prefs.getString(restoreUpdatedAtKey),
    );
  }

  static Future<void> markRestoreSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(restoreStatusKey, 'skipped');
    await prefs.remove(restoreSourceKey);
    await prefs.setString(
      restoreUpdatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<void> markRestoreCompleted({String? source}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(restoreStatusKey, 'restored');
    if (source != null && source.isNotEmpty) {
      await prefs.setString(restoreSourceKey, source);
    } else {
      await prefs.remove(restoreSourceKey);
    }
    await prefs.setString(
      restoreUpdatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class SetupRestoreSnapshot {
  final SetupRestoreStatus status;
  final String? source;
  final String? updatedAtIso;

  const SetupRestoreSnapshot({
    required this.status,
    this.source,
    this.updatedAtIso,
  });
}
