import 'dart:convert';
import 'package:drift/drift.dart';

// JSON Converter สำหรับใช้ร่วมกัน
class JsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    return Map<String, dynamic>.from(
      jsonDecode(fromDb) as Map
    );
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}

/// Converter สำหรับ `List<String>` — เก็บเป็น JSON array ใน SQLite TEXT
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is List) return List<String>.from(decoded);
    return [];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}