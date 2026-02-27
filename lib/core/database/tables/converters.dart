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