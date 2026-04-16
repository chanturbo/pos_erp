import 'dart:io';

import 'models/backup_manifest.dart';

abstract class BackupStorageProvider {
  String get id;
  String get displayName;

  Future<void> upload({
    required File encryptedBackupFile,
    required BackupManifest manifest,
  });
}
