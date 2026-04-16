import 'backup_manifest.dart';

class BackupResult {
  final String backupId;
  final DateTime createdAt;
  final String outputPath;
  final int outputSize;
  final int archiveSize;
  final BackupManifest manifest;

  const BackupResult({
    required this.backupId,
    required this.createdAt,
    required this.outputPath,
    required this.outputSize,
    required this.archiveSize,
    required this.manifest,
  });
}

class RestorePreparationResult {
  final BackupManifest manifest;
  final String pendingDirectoryPath;
  final DateTime preparedAt;

  const RestorePreparationResult({
    required this.manifest,
    required this.pendingDirectoryPath,
    required this.preparedAt,
  });
}
