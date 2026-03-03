import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class CsvExport {
  /// Export data to CSV
  static Future<String?> exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    try {
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
      
      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filepath = '${directory.path}/${filename}_$timestamp.csv';
      
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
}