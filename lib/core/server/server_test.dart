import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
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
      body: SingleChildScrollView(  // ✅ เพิ่ม ScrollView
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
            ElevatedButton(  // ✅ เพิ่มปุ่มนี้
              onPressed: _checkUsers,
              child: const Text('🔍 ตรวจสอบ Users'),
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
      // ลบ User เก่าก่อน (ถ้ามี)
      await (db.delete(db.users)..where((t) => t.userId.equals('USR001'))).go();
      await (db.delete(db.roles)..where((t) => t.roleId.equals('ROLE001'))).go();
      
      // สร้าง Role
      await db.into(db.roles).insert(
        RolesCompanion.insert(
          roleId: 'ROLE001',
          roleName: 'Administrator',
          permissions: {'sales': {'create': true}},
        ),
      );
      
      final hashedPassword = CryptoUtils.hashPassword('admin123');
      
      // สร้าง User
      await db.into(db.users).insert(
        UsersCompanion.insert(
          userId: 'USR001',
          username: 'admin',
          passwordHash: hashedPassword,
          fullName: 'ผู้ดูแลระบบ',
          roleId: const Value('ROLE001'),
        ),
      );
      
      setState(() {
        _status = '✅ สร้าง User ทดสอบสำเร็จ\n\n'
                  'Username: admin\n'
                  'Password: admin123\n'
                  'Hashed: $hashedPassword';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }
  
  // ✅ เพิ่ม Function นี้
  Future<void> _checkUsers() async {
    try {
      final users = await db.select(db.users).get();
      
      if (users.isEmpty) {
        setState(() {
          _status = '⚠️ ไม่มี User ในระบบ\n\n'
                    'กด "👤 สร้าง User ทดสอบ" ก่อน';
        });
        return;
      }
      
      final userList = users.map((u) {
        return '• ${u.username}\n'
               '  ID: ${u.userId}\n'
               '  Name: ${u.fullName}\n'
               '  Active: ${u.isActive}\n'
               '  Hash: ${u.passwordHash.substring(0, 20)}...';
      }).join('\n\n');
      
      // ทดสอบ Password Hash
      final testUser = users.first;
      final testHash = CryptoUtils.hashPassword('admin123');
      final hashMatch = testUser.passwordHash == testHash;
      
      setState(() {
        _status = '✅ มี User ${users.length} คน:\n\n'
                  '$userList\n\n'
                  '🔐 ทดสอบ Hash:\n'
                  'Expected: $testHash\n'
                  'Actual:   ${testUser.passwordHash}\n'
                  'Match: ${hashMatch ? "✅ ตรงกัน" : "❌ ไม่ตรงกัน"}';
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