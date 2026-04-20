// ignore_for_file: avoid_print

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../services/license/license_local_service.dart';
import '../services/license/license_models.dart';

class CsvExport {
  /// Export data to CSV
  static Future<String?> exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
    bool chooseLocation = false,
  }) async {
    try {
      await LicenseLocalService.ensureFeatureAllowed(
        LicenseFeature.exportReport,
      );

      // สร้าง CSV content
      final csvContent = StringBuffer();

      // เพิ่ม BOM สำหรับ UTF-8
      csvContent.write('\uFEFF');

      // Headers
      csvContent.writeln(headers.map((h) => _escapeCsv(h)).join(','));

      // Rows
      for (var row in rows) {
        csvContent.writeln(row.map((cell) => _escapeCsv(cell)).join(','));
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suggestedName = '${filename}_$timestamp.csv';
      String? filepath;

      if (chooseLocation) {
        filepath = await FilePicker.platform.saveFile(
          dialogTitle: 'เลือกตำแหน่งบันทึก CSV',
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (filepath == null || filepath.isEmpty) {
          return null;
        }
      }

      // Save file
      filepath ??= await _fallbackPath(suggestedName);

      final file = File(filepath);
      await file.writeAsString(csvContent.toString());

      return filepath;
    } catch (e) {
      print('Export CSV error: $e');
      return null;
    }
  }

  /// Escape CSV field
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<String> _fallbackPath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }
}
