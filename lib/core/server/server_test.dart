import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;  // ✅ เพิ่ม hide Column
import '../database/app_database.dart';
import '../utils/crypto_utils.dart';
import 'api_server.dart';

class ServerTestPage extends StatefulWidget {
  const ServerTestPage({super.key});

  @override
  State<ServerTestPage> createState() => _ServerTestPageState();
}

class _ServerTestPageState extends State<ServerTestPage> {
  final db = AppDatabase();
  ApiServer? server;
  String _status = 'รอเริ่มต้น...';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบ API Server'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startServer,
              child: const Text('🚀 เริ่ม Server'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _createTestUser,
              child: const Text('👤 สร้าง User ทดสอบ'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _stopServer,
              child: const Text('⏹️ หยุด Server'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _startServer() async {
    try {
      server = ApiServer(db);
      await server!.start(port: 8080);
      setState(() {
        _status = '✅ Server กำลังทำงานที่ http://localhost:8080\n\n'
                  'ทดสอบ API:\n'
                  'POST http://localhost:8080/api/auth/login\n'
                  '{\n'
                  '  "username": "admin",\n'
                  '  "password": "admin123"\n'
                  '}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }
  
  Future<void> _createTestUser() async {
    try {
      // สร้าง Role
      await db.into(db.roles).insert(
        RolesCompanion.insert(
          roleId: 'ROLE001',
          roleName: 'Administrator',
          permissions: {'sales': {'create': true}},
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      // สร้าง User
      await db.into(db.users).insert(
        UsersCompanion.insert(
          userId: 'USR001',
          username: 'admin',
          passwordHash: CryptoUtils.hashPassword('admin123'),
          fullName: 'ผู้ดูแลระบบ',
          roleId: const Value('ROLE001'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      
      setState(() {
        _status = '✅ สร้าง User ทดสอบสำเร็จ\n\n'
                  'Username: admin\n'
                  'Password: admin123';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }
  
  Future<void> _stopServer() async {
    await server?.stop();
    setState(() {
      _status = '⏹️ Server หยุดแล้ว';
    });
  }
  
  @override
  void dispose() {
    server?.stop();
    db.close();
    super.dispose();
  }
}