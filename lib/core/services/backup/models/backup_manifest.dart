import 'dart:convert';

class BackupManifestFileEntry {
  final String path;
  final int size;
  final String sha256;

  const BackupManifestFileEntry({
    required this.path,
    required this.size,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'size': size,
    'sha256': sha256,
  };

  factory BackupManifestFileEntry.fromJson(Map<String, dynamic> json) {
    return BackupManifestFileEntry(
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
    );
  }
}

class BackupManifest {
  final int formatVersion;
  final String backupId;
  final String appName;
  final String appVersion;
  final String schemaVersion;
  final String companyName;
  final String createdAt;
  final String encryption;
  final String kdf;
  final int kdfIterations;
  final String dbFileName;
  final String? productImagesFolder;
  final int fileCount;
  final int totalBytes;
  final List<BackupManifestFileEntry> files;

  const BackupManifest({
    required this.formatVersion,
    required this.backupId,
    required this.appName,
    required this.appVersion,
    required this.schemaVersion,
    required this.companyName,
    required this.createdAt,
    required this.encryption,
    required this.kdf,
    required this.kdfIterations,
    required this.dbFileName,
    required this.productImagesFolder,
    required this.fileCount,
    required this.totalBytes,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
    'format_version': formatVersion,
    'backup_id': backupId,
    'app_name': appName,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'company_name': companyName,
    'created_at': createdAt,
    'encryption': encryption,
    'kdf': kdf,
    'kdf_iterations': kdfIterations,
    'db_file_name': dbFileName,
    'product_images_folder': productImagesFolder,
    'file_count': fileCount,
    'total_bytes': totalBytes,
    'files': files.map((file) => file.toJson()).toList(),
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List? ?? const [];
    return BackupManifest(
      formatVersion: (json['format_version'] as num?)?.toInt() ?? 1,
      backupId: json['backup_id'] as String? ?? '',
      appName: json['app_name'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      schemaVersion: json['schema_version'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      encryption: json['encryption'] as String? ?? '',
      kdf: json['kdf'] as String? ?? '',
      kdfIterations: (json['kdf_iterations'] as num?)?.toInt() ?? 0,
      dbFileName: json['db_file_name'] as String? ?? '',
      productImagesFolder: json['product_images_folder'] as String?,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      files: rawFiles
          .map(
            (item) =>
                BackupManifestFileEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
