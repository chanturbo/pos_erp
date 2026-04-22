// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import '../license/license_local_service.dart';
import 'models/backup_manifest.dart';
import 'models/backup_result.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return BackupService(db);
});

class BackupService {
  static const backupFormatVersion = 1;
  static const backupFileExtension = 'posbak';
  static const manifestFileName = 'manifest.json';
  static const restorePendingFolderName = 'restore_pending';
  static const restorePayloadFolderName = 'payload';
  static const restoreRequestFileName = 'restore_request.json';
  static const restoreRollbackFolderName = 'restore_rollbacks';
  static const encryptionAlgorithm = 'AES-256-GCM';
  static const keyDerivationAlgorithm = 'PBKDF2-HMAC-SHA256';
  static const pbkdf2Iterations = 150000;
  static const _magic = 'POSBK1';
  static const _appName = 'POS ERP';
  static const _appVersion = '1.0.0';
  static const trackedInspectionTables = <String>[
    'companies',
    'branches',
    'warehouses',
    'products',
    'customers',
    'sales_orders',
    'users',
  ];

  final AppDatabase db;
  final Random _random = Random.secure();

  BackupService(this.db);

  String buildSuggestedFilename({
    required DateTime now,
    required String companyName,
  }) {
    final safeCompany = companyName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9ก-๙_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final prefix = safeCompany.isEmpty ? 'pos_erp' : safeCompany;
    return '${prefix}_backup_$stamp.$backupFileExtension';
  }

  Future<String?> pickBackupSavePath({
    required DateTime now,
    required String companyName,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'บันทึกไฟล์สำรองข้อมูล',
      fileName: buildSuggestedFilename(now: now, companyName: companyName),
      type: FileType.custom,
      allowedExtensions: const [backupFileExtension],
    );
  }

  Future<BackupResult> createEncryptedBackup({
    required String passphrase,
    required String companyName,
    String? outputPath,
  }) async {
    if (passphrase.trim().length < 8) {
      throw const BackupException('รหัสเข้ารหัสต้องมีอย่างน้อย 8 ตัวอักษร');
    }

    final now = DateTime.now();
    final backupId = _buildBackupId(now);
    final tempDir = await getTemporaryDirectory();
    final workingDir = Directory(
      p.join(tempDir.path, 'pos_erp_backup_$backupId'),
    );
    final stagingDir = Directory(p.join(workingDir.path, 'payload'));
    await stagingDir.create(recursive: true);

    try {
      final snapshotFile = File(
        p.join(stagingDir.path, AppDatabase.databaseFileName),
      );
      await _createDatabaseSnapshot(snapshotFile);

      final fileEntries = <BackupManifestFileEntry>[
        await _createFileEntry(
          file: snapshotFile,
          relativePath: AppDatabase.databaseFileName,
        ),
      ];

      final imageEntries = await _copyProductImages(stagingDir);
      fileEntries.addAll(imageEntries);

      final totalBytes = fileEntries.fold<int>(
        0,
        (sum, file) => sum + file.size,
      );
      final manifest = BackupManifest(
        formatVersion: backupFormatVersion,
        backupId: backupId,
        appName: _appName,
        appVersion: _appVersion,
        schemaVersion: db.schemaVersion.toString(),
        companyName: companyName.trim(),
        createdAt: now.toUtc().toIso8601String(),
        encryption: encryptionAlgorithm,
        kdf: keyDerivationAlgorithm,
        kdfIterations: pbkdf2Iterations,
        dbFileName: AppDatabase.databaseFileName,
        productImagesFolder: imageEntries.isEmpty
            ? null
            : AppDatabase.productImagesFolderName,
        fileCount: fileEntries.length + 1,
        totalBytes: totalBytes,
        files: fileEntries,
        appMeta: BackupAppMeta.fromJson(
          (await LicenseLocalService.buildBackupMetadata()).toJson(),
        ),
      );

      final manifestFile = File(p.join(stagingDir.path, manifestFileName));
      await manifestFile.writeAsString(manifest.toPrettyJson(), flush: true);

      final archiveBytes = await _createZipArchive(stagingDir);
      final encryptedBytes = await _encryptArchiveBytes(
        archiveBytes: archiveBytes,
        passphrase: passphrase,
        backupId: backupId,
        createdAt: now,
        manifest: manifest,
      );

      final targetFile = await _resolveOutputFile(
        outputPath: outputPath,
        now: now,
        companyName: companyName,
      );
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(encryptedBytes, flush: true);

      return BackupResult(
        backupId: backupId,
        createdAt: now,
        outputPath: targetFile.path,
        outputSize: encryptedBytes.length,
        archiveSize: archiveBytes.length,
        manifest: manifest,
      );
    } finally {
      if (workingDir.existsSync()) {
        await workingDir.delete(recursive: true);
      }
    }
  }

  Future<Map<String, dynamic>> readBackupHeader(File file) async {
    final bytes = await file.readAsBytes();
    return _parseEncryptedEnvelope(bytes).header;
  }

  Future<String?> pickBackupRestorePath() {
    return FilePicker.platform
        .pickFiles(
          dialogTitle: 'เลือกไฟล์สำรองข้อมูล',
          type: FileType.custom,
          allowedExtensions: const [backupFileExtension],
          allowMultiple: false,
        )
        .then((result) => result?.files.single.path);
  }

  Future<List<int>> decryptBackupArchive({
    required File file,
    required String passphrase,
  }) async {
    final bytes = await file.readAsBytes();
    final envelope = _parseEncryptedEnvelope(bytes);
    final algorithm = AesGcm.with256bits();
    final key = await _deriveKey(
      passphrase: passphrase,
      salt: base64Decode(envelope.header['salt'] as String),
    );
    final secretBox = SecretBox(
      envelope.cipherText,
      nonce: base64Decode(envelope.header['nonce'] as String),
      mac: Mac(base64Decode(envelope.header['mac'] as String)),
    );
    final clearBytes = await algorithm.decrypt(
      secretBox,
      secretKey: key,
      aad: envelope.headerBytes,
    );
    return clearBytes;
  }

  Future<RestorePreparationResult> prepareRestore({
    required File encryptedBackupFile,
    required String passphrase,
  }) async {
    final clearArchiveBytes = await decryptBackupArchive(
      file: encryptedBackupFile,
      passphrase: passphrase,
    );
    final manifest = await _extractAndValidateArchive(
      archiveBytes: clearArchiveBytes,
      encryptedBackupFile: encryptedBackupFile,
    );

    final backupDir = await AppDatabase.resolveBackupDirectory();
    final pendingRoot = Directory(
      p.join(backupDir.path, restorePendingFolderName),
    );
    if (pendingRoot.existsSync()) {
      await pendingRoot.delete(recursive: true);
    }
    final payloadDir = Directory(
      p.join(pendingRoot.path, restorePayloadFolderName),
    );
    await payloadDir.create(recursive: true);

    final archive = ZipDecoder().decodeBytes(clearArchiveBytes, verify: true);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final outputFile = File(p.join(payloadDir.path, entry.name));
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(entry.content, flush: true);
    }

    await _validateExtractedPayload(payloadDir, manifest);
    final inspection = await _inspectExtractedPayload(payloadDir, manifest);

    final requestFile = File(p.join(pendingRoot.path, restoreRequestFileName));
    final requestJson = {
      'prepared_at': DateTime.now().toUtc().toIso8601String(),
      'source_file': encryptedBackupFile.path,
      'manifest': manifest.toJson(),
    };
    await requestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(requestJson),
      flush: true,
    );

    return RestorePreparationResult(
      manifest: manifest,
      inspection: inspection,
      pendingDirectoryPath: pendingRoot.path,
      preparedAt: DateTime.now(),
    );
  }

  static Future<bool> applyPendingRestoreIfAny() async {
    final backupDir = await AppDatabase.resolveBackupDirectory();
    print('🔍 [Restore] backupDir: ${backupDir.path}');

    final pendingRoot = Directory(
      p.join(backupDir.path, restorePendingFolderName),
    );
    print('🔍 [Restore] pendingRoot: ${pendingRoot.path}');
    print('🔍 [Restore] pendingRoot exists: ${pendingRoot.existsSync()}');
    if (!pendingRoot.existsSync()) return false;

    final requestFile = File(p.join(pendingRoot.path, restoreRequestFileName));
    final payloadDir = Directory(
      p.join(pendingRoot.path, restorePayloadFolderName),
    );
    print('🔍 [Restore] requestFile exists: ${requestFile.existsSync()}');
    print('🔍 [Restore] payloadDir exists: ${payloadDir.existsSync()}');

    if (!requestFile.existsSync() || !payloadDir.existsSync()) {
      await pendingRoot.delete(recursive: true);
      return false;
    }

    final requestJson =
        jsonDecode(await requestFile.readAsString()) as Map<String, dynamic>;
    final manifest = BackupManifest.fromJson(
      requestJson['manifest'] as Map<String, dynamic>,
    );
    print('🔍 [Restore] manifest backupId: ${manifest.backupId}');
    print('🔍 [Restore] payload files:');
    await for (final f in payloadDir.list(recursive: true)) {
      if (f is File) print('   📄 ${f.path} (${await f.length()} bytes)');
    }

    await _validateExtractedPayload(payloadDir, manifest);
    print('✅ [Restore] payload validated');

    final rollbackRoot = Directory(
      p.join(
        backupDir.path,
        restoreRollbackFolderName,
        DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
      ),
    );
    await rollbackRoot.create(recursive: true);

    final currentDb = await AppDatabase.resolveDatabaseFile();
    print('🔍 [Restore] currentDb path: ${currentDb.path}');
    print('🔍 [Restore] currentDb exists: ${currentDb.existsSync()}');
    if (currentDb.existsSync()) {
      await currentDb.copy(
        p.join(rollbackRoot.path, AppDatabase.databaseFileName),
      );
      print('✅ [Restore] current db backed up to rollback');
    }

    final currentImages = await AppDatabase.resolveProductImagesDirectory();
    if (currentImages.existsSync()) {
      final rollbackImages = Directory(
        p.join(rollbackRoot.path, AppDatabase.productImagesFolderName),
      );
      await _copyDirectory(currentImages, rollbackImages);
    }

    final restoredDb = File(
      p.join(payloadDir.path, AppDatabase.databaseFileName),
    );
    print('🔍 [Restore] restoredDb path: ${restoredDb.path}');
    print('🔍 [Restore] restoredDb exists: ${restoredDb.existsSync()}');
    if (!restoredDb.existsSync()) {
      throw const BackupException('ไม่พบฐานข้อมูลในชุด restore');
    }

    await currentDb.parent.create(recursive: true);
    await restoredDb.copy(currentDb.path);
    print('✅ [Restore] db file copied to ${currentDb.path}');

    // Delete stale WAL files — if left behind SQLite replays old transactions
    // on top of the restored data, making the restore appear to have no effect.
    for (final suffix in ['-wal', '-shm']) {
      final stale = File('${currentDb.path}$suffix');
      if (stale.existsSync()) {
        await stale.delete();
        print('🗑️ [Restore] deleted stale WAL file: ${stale.path}');
      }
    }

    final restoredImages = Directory(
      p.join(payloadDir.path, AppDatabase.productImagesFolderName),
    );
    if (currentImages.existsSync()) await currentImages.delete(recursive: true);
    if (restoredImages.existsSync()) {
      await _copyDirectory(restoredImages, currentImages);
    }

    if (manifest.appMeta?.hasLicenseMetadata == true) {
      await LicenseLocalService.restoreBackupMetadata(
        LicenseBackupMetadata(
          firstLaunchDate: manifest.appMeta!.firstLaunchDate!,
          deviceId: manifest.appMeta!.deviceId!,
          checksum: manifest.appMeta!.checksum!,
          licensedEmail: manifest.appMeta!.licensedEmail,
        ),
      );
      print('✅ [Restore] restored license metadata from backup manifest');
    }

    await pendingRoot.delete(recursive: true);
    print('✅ [Restore] pendingRoot deleted — restore complete');
    return true;
  }

  Future<void> _createDatabaseSnapshot(File destination) async {
    final escapedPath = destination.path.replaceAll("'", "''");
    if (destination.existsSync()) {
      await destination.delete();
    }
    await destination.parent.create(recursive: true);
    await db.customStatement('PRAGMA wal_checkpoint(FULL)');
    await db.customStatement("VACUUM INTO '$escapedPath'");
  }

  Future<BackupManifest> _extractAndValidateArchive({
    required List<int> archiveBytes,
    required File encryptedBackupFile,
  }) async {
    final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    ArchiveFile? manifestEntry;
    for (final entry in archive) {
      if (entry.isFile && entry.name == manifestFileName) {
        manifestEntry = entry;
        break;
      }
    }
    if (manifestEntry == null) {
      throw BackupException(
        'ไม่พบ $manifestFileName ในไฟล์สำรอง ${p.basename(encryptedBackupFile.path)}',
      );
    }

    final manifest = BackupManifest.fromJson(
      jsonDecode(utf8.decode(manifestEntry.content)) as Map<String, dynamic>,
    );
    if (manifest.formatVersion != backupFormatVersion) {
      throw BackupException(
        'ไฟล์สำรองนี้ใช้ format ${manifest.formatVersion} ซึ่งยังไม่รองรับ',
      );
    }

    final archiveFiles = <String, ArchiveFile>{};
    for (final entry in archive) {
      if (entry.isFile) {
        archiveFiles[entry.name] = entry;
      }
    }

    for (final file in manifest.files) {
      final entry = archiveFiles[file.path];
      if (entry == null) {
        throw BackupException('ไฟล์ใน backup หายไป: ${file.path}');
      }
      final content = entry.content;
      if (content.length != file.size) {
        throw BackupException('ขนาดไฟล์ไม่ตรงกับ manifest: ${file.path}');
      }
      final hash = await _sha256OfBytes(content);
      if (hash != file.sha256) {
        throw BackupException('checksum ไม่ตรงกับ manifest: ${file.path}');
      }
    }

    return manifest;
  }

  static Future<void> _validateExtractedPayload(
    Directory payloadDir,
    BackupManifest manifest,
  ) async {
    final manifestFile = File(p.join(payloadDir.path, manifestFileName));
    if (!manifestFile.existsSync()) {
      throw const BackupException('ไม่พบ manifest หลังแตกไฟล์');
    }
    final manifestFromDisk = BackupManifest.fromJson(
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
    );
    if (manifestFromDisk.backupId != manifest.backupId) {
      throw const BackupException('manifest หลังแตกไฟล์ไม่ตรงกับต้นฉบับ');
    }

    for (final file in manifest.files) {
      final diskFile = File(p.join(payloadDir.path, file.path));
      if (!diskFile.existsSync()) {
        throw BackupException('ไฟล์ที่ต้องใช้ในการกู้คืนหายไป: ${file.path}');
      }
      final actualSize = await diskFile.length();
      if (actualSize != file.size) {
        throw BackupException('ขนาดไฟล์ที่กู้คืนไม่ถูกต้อง: ${file.path}');
      }
      final hash = await _sha256OfFile(diskFile);
      if (hash != file.sha256) {
        throw BackupException('checksum หลังแตกไฟล์ไม่ถูกต้อง: ${file.path}');
      }
    }
  }

  Future<BackupInspectionSummary> _inspectExtractedPayload(
    Directory payloadDir,
    BackupManifest manifest,
  ) async {
    final sourceDb = File(p.join(payloadDir.path, manifest.dbFileName));
    if (!sourceDb.existsSync()) {
      throw const BackupException('ไม่พบฐานข้อมูลใน payload สำหรับตรวจสอบ');
    }

    final tempDir = await getTemporaryDirectory();
    final workingDir = await Directory(
      p.join(tempDir.path, 'pos_erp_restore_inspect_${manifest.backupId}'),
    ).create(recursive: true);
    final tempDbFile = File(p.join(workingDir.path, manifest.dbFileName));

    try {
      await sourceDb.copy(tempDbFile.path);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final inspectDb = AppDatabase.forTesting(
        NativeDatabase(
          tempDbFile,
          enableMigrations: false,
          setup: (rawDb) {
            rawDb.execute('PRAGMA query_only = ON;');
          },
        ),
      );
      try {
        final tableCounts = <String, int>{};
        for (final table in trackedInspectionTables) {
          final row = await inspectDb
              .customSelect('SELECT COUNT(*) AS total FROM $table')
              .getSingle();
          tableCounts[table] = row.data['total'] as int? ?? 0;
        }

        final productImageCount = manifest.files
            .where(
              (file) => file.path.startsWith(
                '${AppDatabase.productImagesFolderName}/',
              ),
            )
            .length;

        return BackupInspectionSummary(
          tableCounts: tableCounts,
          productImageCount: productImageCount,
        );
      } finally {
        await inspectDb.close();
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      }
    } catch (e) {
      throw BackupException('ตรวจสอบข้อมูลใน backup ไม่สำเร็จ: $e');
    } finally {
      if (workingDir.existsSync()) {
        await workingDir.delete(recursive: true);
      }
    }
  }

  Future<List<BackupManifestFileEntry>> _copyProductImages(
    Directory stagingDir,
  ) async {
    final sourceDir = await AppDatabase.resolveProductImagesDirectory();
    if (!sourceDir.existsSync()) return const [];

    final targetDir = Directory(
      p.join(stagingDir.path, AppDatabase.productImagesFolderName),
    );
    await targetDir.create(recursive: true);

    final entries = <BackupManifestFileEntry>[];
    await for (final entity in sourceDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relativeSource = p.relative(entity.path, from: sourceDir.path);
      final normalizedRelative = relativeSource.replaceAll('\\', '/');
      final targetFile = File(p.join(targetDir.path, relativeSource));
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetFile.path);
      entries.add(
        await _createFileEntry(
          file: targetFile,
          relativePath:
              '${AppDatabase.productImagesFolderName}/$normalizedRelative',
        ),
      );
    }
    return entries;
  }

  Future<BackupManifestFileEntry> _createFileEntry({
    required File file,
    required String relativePath,
  }) async {
    return BackupManifestFileEntry(
      path: relativePath,
      size: await file.length(),
      sha256: await _sha256OfFile(file),
    );
  }

  Future<List<int>> _createZipArchive(Directory stagingDir) async {
    final archive = Archive();
    await for (final entity in stagingDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final relativePath = p
          .relative(entity.path, from: stagingDir.path)
          .replaceAll('\\', '/');
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }
    return ZipEncoder().encode(archive, level: 9);
  }

  Future<List<int>> _encryptArchiveBytes({
    required List<int> archiveBytes,
    required String passphrase,
    required String backupId,
    required DateTime createdAt,
    required BackupManifest manifest,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(AesGcm.defaultNonceLength);
    final key = await _deriveKey(passphrase: passphrase, salt: salt);
    final header = <String, dynamic>{
      'magic': _magic,
      'format_version': backupFormatVersion,
      'backup_id': backupId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'archive': 'zip',
      'encryption': encryptionAlgorithm,
      'kdf': keyDerivationAlgorithm,
      'kdf_iterations': pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'manifest_file_count': manifest.fileCount,
      'manifest_total_bytes': manifest.totalBytes,
    };
    final headerBytesWithoutMac = Uint8List.fromList(
      utf8.encode(jsonEncode(header)),
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      archiveBytes,
      secretKey: key,
      nonce: nonce,
      aad: headerBytesWithoutMac,
    );
    header['mac'] = base64Encode(secretBox.mac.bytes);
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
    final headerLength = ByteData(4)..setUint32(0, headerBytes.length);

    return <int>[
      ...utf8.encode(_magic),
      ...headerLength.buffer.asUint8List(),
      ...headerBytes,
      ...secretBox.cipherText,
    ];
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
  }) async {
    final pbkdf2 = Pbkdf2.hmacSha256(iterations: pbkdf2Iterations, bits: 256);
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Future<String> _sha256OfFile(File file) async {
    final algorithm = Sha256();
    final hash = await algorithm.hash(await file.readAsBytes());
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<String> _sha256OfBytes(List<int> bytes) async {
    final algorithm = Sha256();
    final hash = await algorithm.hash(bytes);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<File> _resolveOutputFile({
    required String? outputPath,
    required DateTime now,
    required String companyName,
  }) async {
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      return File(outputPath);
    }
    final backupDir = await AppDatabase.resolveBackupDirectory();
    final fileName = buildSuggestedFilename(now: now, companyName: companyName);
    return File(p.join(backupDir.path, fileName));
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  String _buildBackupId(DateTime now) {
    final millis = now.millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'BKP${millis}_$suffix';
  }

  _EncryptedEnvelope _parseEncryptedEnvelope(List<int> bytes) {
    if (bytes.length < _magic.length + 4) {
      throw const BackupException('ไฟล์สำรองข้อมูลไม่ถูกต้อง');
    }
    final magic = utf8.decode(bytes.sublist(0, _magic.length));
    if (magic != _magic) {
      throw const BackupException('รูปแบบไฟล์สำรองข้อมูลไม่รองรับ');
    }
    final headerLength = ByteData.sublistView(
      Uint8List.fromList(bytes),
      _magic.length,
      _magic.length + 4,
    ).getUint32(0);
    final headerStart = _magic.length + 4;
    final headerEnd = headerStart + headerLength;
    if (bytes.length <= headerEnd) {
      throw const BackupException('ไฟล์สำรองข้อมูลเสียหาย');
    }
    final headerBytes = Uint8List.fromList(
      bytes.sublist(headerStart, headerEnd),
    );
    final header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    final mac = header.remove('mac');
    if (mac == null || (mac as String).isEmpty) {
      throw const BackupException(
        'ไฟล์สำรองข้อมูลไม่มีข้อมูลยืนยันความถูกต้อง',
      );
    }
    final headerBytesWithoutMac = Uint8List.fromList(
      utf8.encode(jsonEncode(header)),
    );
    header['mac'] = mac;
    return _EncryptedEnvelope(
      header: header,
      headerBytes: headerBytesWithoutMac,
      cipherText: Uint8List.fromList(bytes.sublist(headerEnd)),
    );
  }
}

class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => message;
}

class _EncryptedEnvelope {
  final Map<String, dynamic> header;
  final List<int> headerBytes;
  final List<int> cipherText;

  const _EncryptedEnvelope({
    required this.header,
    required this.headerBytes,
    required this.cipherText,
  });
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relativePath = p.relative(entity.path, from: source.path);
    final targetPath = p.join(destination.path, relativePath);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await File(targetPath).parent.create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}
