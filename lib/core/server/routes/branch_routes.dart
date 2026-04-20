// ignore_for_file: avoid_print
// branch_routes.dart — Week 7: Branch & Warehouse API

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class BranchRoutes {
  final AppDatabase db;
  BranchRoutes(this.db);

  Router get router {
    final r = Router();

    // Static routes must come before dynamic `/<id>` routes, otherwise
    // requests like `/warehouses` are captured as a branch id and return 404.
    r.get('/warehouses', _listWarehouses);
    r.post('/warehouses', _createWarehouse);
    r.put('/warehouses/<id>', _updateWarehouse);

    // Sync
    r.get('/sync/status', _getSyncStatus);
    r.post('/sync/push', _pushSyncData);
    r.get('/sync/pull', _pullSyncData);
    r.post('/sync/acknowledge', _acknowledgeSyncData);

    // Branches
    r.get('/', _listBranches);
    r.post('/', _createBranch);
    r.get('/<branchId>/warehouses', _listWarehousesByBranch);
    r.get('/<id>', _getBranch);
    r.put('/<id>', _updateBranch);
    r.delete('/<id>', _deleteBranch);

    return r;
  }

  // ── Branch CRUD ────────────────────────────────────────────────────────────

  Future<Response> _listBranches(Request req) async {
    try {
      final branches = await (db.select(db.branches)
            ..orderBy([(b) => OrderingTerm.asc(b.branchCode)]))
          .get();

      final data = await Future.wait(branches.map((b) async {
        final wCount = await (db.select(db.warehouses)
              ..where((w) => w.branchId.equals(b.branchId)))
            .get();
        return {
          'branch_id': b.branchId,
          'company_id': b.companyId,
          'branch_code': b.branchCode,
          'branch_name': b.branchName,
          'address': b.address,
          'phone': b.phone,
          'is_active': b.isActive,
          'business_mode': b.businessMode,
          'warehouse_count': wCount.length,
          'created_at': b.createdAt.toIso8601String(),
          'updated_at': b.updatedAt.toIso8601String(),
        };
      }));

      return _ok(data);
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _getBranch(Request req, String id) async {
    try {
      final branch = await (db.select(db.branches)
            ..where((b) => b.branchId.equals(id)))
          .getSingleOrNull();

      if (branch == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'message': 'Branch not found'}),
            headers: {'Content-Type': 'application/json'});
      }

      final warehouses = await (db.select(db.warehouses)
            ..where((w) => w.branchId.equals(id)))
          .get();

      return _ok({
        'branch_id': branch.branchId,
        'company_id': branch.companyId,
        'branch_code': branch.branchCode,
        'branch_name': branch.branchName,
        'address': branch.address,
        'phone': branch.phone,
        'is_active': branch.isActive,
        'business_mode': branch.businessMode,
        'created_at': branch.createdAt.toIso8601String(),
        'updated_at': branch.updatedAt.toIso8601String(),
        'warehouses': warehouses.map((w) => {
              'warehouse_id': w.warehouseId,
              'warehouse_code': w.warehouseCode,
              'warehouse_name': w.warehouseName,
              'is_active': w.isActive,
            }).toList(),
      });
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _createBranch(Request req) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final branchId = 'BR${DateTime.now().millisecondsSinceEpoch}';

      // ดึง companyId แรกที่มี
      final companies = await db.select(db.companies).get();
      final companyId = data['company_id'] as String? ??
          (companies.isNotEmpty ? companies.first.companyId : 'COMP001');

      await db.into(db.branches).insert(BranchesCompanion(
            branchId: Value(branchId),
            companyId: Value(companyId),
            branchCode:
                Value(data['branch_code'] as String),
            branchName:
                Value(data['branch_name'] as String),
            address: Value(data['address'] as String?),
            phone: Value(data['phone'] as String?),
            isActive: Value(data['is_active'] as bool? ?? true),
            businessMode: Value(
                (data['business_mode'] as String?)?.toUpperCase() ?? 'RETAIL'),
          ));

      // สร้าง Warehouse default ให้ Branch ใหม่
      await db.into(db.warehouses).insert(WarehousesCompanion(
            warehouseId:
                Value('WH${DateTime.now().millisecondsSinceEpoch}'),
            warehouseCode: Value('${data['branch_code']}-WH01'),
            warehouseName: Value('คลังหลัก ${data['branch_name']}'),
            branchId: Value(branchId),
          ));

      print('✅ BranchRoutes: Created branch $branchId');
      return _okMsg({'branch_id': branchId}, 'Branch created');
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _updateBranch(Request req, String id) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(db.branches)
            ..where((b) => b.branchId.equals(id)))
          .write(BranchesCompanion(
        branchCode: Value(data['branch_code'] as String),
        branchName: Value(data['branch_name'] as String),
        address: Value(data['address'] as String?),
        phone: Value(data['phone'] as String?),
        isActive: Value(data['is_active'] as bool? ?? true),
        businessMode: data.containsKey('business_mode')
            ? Value((data['business_mode'] as String).toUpperCase())
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));
      return _okMsg({}, 'Branch updated');
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _deleteBranch(Request req, String id) async {
    try {
      await (db.delete(db.branches)
            ..where((b) => b.branchId.equals(id)))
          .go();
      return _okMsg({}, 'Branch deleted');
    } catch (e) {
      return _err(e);
    }
  }

  // ── Warehouse CRUD ─────────────────────────────────────────────────────────

  Future<Response> _listWarehouses(Request req) async {
    try {
      final results = await db.customSelect('''
        SELECT w.*, b.branch_name
        FROM warehouses w
        LEFT JOIN branches b ON w.branch_id = b.branch_id
        ORDER BY b.branch_code, w.warehouse_code
      ''').get();

      return _ok(results.map((r) => {
            'warehouse_id': r.read<String>('warehouse_id'),
            'warehouse_code': r.read<String>('warehouse_code'),
            'warehouse_name': r.read<String>('warehouse_name'),
            'branch_id': r.read<String>('branch_id'),
            'branch_name': r.readNullable<String>('branch_name'),
            'is_active': r.read<bool>('is_active'),
            'created_at':
                r.read<DateTime>('created_at').toIso8601String(),
          }).toList());
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _listWarehousesByBranch(
      Request req, String branchId) async {
    try {
      final warehouses = await (db.select(db.warehouses)
            ..where((w) => w.branchId.equals(branchId)))
          .get();

      return _ok(warehouses.map((w) => {
            'warehouse_id': w.warehouseId,
            'warehouse_code': w.warehouseCode,
            'warehouse_name': w.warehouseName,
            'branch_id': w.branchId,
            'is_active': w.isActive,
          }).toList());
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _createWarehouse(Request req) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final warehouseId = 'WH${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.warehouses).insert(WarehousesCompanion(
            warehouseId: Value(warehouseId),
            warehouseCode: Value(data['warehouse_code'] as String),
            warehouseName: Value(data['warehouse_name'] as String),
            branchId: Value(data['branch_id'] as String),
            isActive: Value(data['is_active'] as bool? ?? true),
          ));

      return _okMsg({'warehouse_id': warehouseId}, 'Warehouse created');
    } catch (e) {
      return _err(e);
    }
  }

  Future<Response> _updateWarehouse(Request req, String id) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await (db.update(db.warehouses)
            ..where((w) => w.warehouseId.equals(id)))
          .write(WarehousesCompanion(
        warehouseCode: Value(data['warehouse_code'] as String),
        warehouseName: Value(data['warehouse_name'] as String),
        isActive: Value(data['is_active'] as bool? ?? true),
      ));
      return _okMsg({}, 'Warehouse updated');
    } catch (e) {
      return _err(e);
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  Future<Response> _getSyncStatus(Request req) async {
    try {
      final pending = await (db.select(db.syncQueues)
            ..where((q) => q.syncStatus.equals('PENDING')))
          .get();
      final failed = await (db.select(db.syncQueues)
            ..where((q) => q.syncStatus.equals('FAILED')))
          .get();
      final lastSynced = await (db.select(db.syncQueues)
            ..where((q) => q.syncStatus.equals('SYNCED'))
            ..orderBy([(q) => OrderingTerm.desc(q.syncedAt)])
            ..limit(1))
          .getSingleOrNull();

      return _ok({
        'pending_count': pending.length,
        'failed_count': failed.length,
        'last_sync_at': lastSynced?.syncedAt?.toIso8601String(),
        'pending_items': pending.take(20).map((q) => {
              'queue_id': q.queueId,
              'table_name': q.tableNameValue,
              'record_id': q.recordId,
              'operation': q.operation,
              'created_at': q.createdAt.toIso8601String(),
            }).toList(),
      });
    } catch (e) {
      return _err(e);
    }
  }

  /// Client ส่งข้อมูลมาให้ Master — Client calls this on Master
  Future<Response> _pushSyncData(Request req) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];
      int processed = 0;

      for (final item in items) {
        final map = item as Map<String, dynamic>;
        // บันทึกลง sync_queue
        await db.into(db.syncQueues).insertOnConflictUpdate(
              SyncQueuesCompanion(
                queueId: Value(map['queue_id'] as String),
                deviceId: Value(map['device_id'] as String? ?? 'unknown'),
                tableNameValue:
                    Value(map['table_name'] as String),
                recordId: Value(map['record_id'] as String),
                operation: Value(map['operation'] as String),
                data: Value(map['data']),
                syncStatus: const Value('SYNCED'),
                syncedAt: Value(DateTime.now()),
              ),
            );
        processed++;
      }

      return _okMsg({'processed': processed}, 'Sync push received');
    } catch (e) {
      return _err(e);
    }
  }

  /// Master ส่งข้อมูลให้ Client — Client calls this on Master
  Future<Response> _pullSyncData(Request req) async {
    try {
      final since = req.url.queryParameters['since'];
      final deviceId = req.url.queryParameters['device_id'];

      var query = db.select(db.syncQueues);
      if (since != null) {
        final sinceDate = DateTime.parse(since);
        query = query
          ..where((q) => q.createdAt.isBiggerOrEqualValue(sinceDate));
      }
      if (deviceId != null) {
        query = query
          ..where((q) => q.deviceId.equals(deviceId).not());
      }

      final items = await (query
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
            ..limit(500))
          .get();

      return _ok({
        'items': items.map((q) => {
              'queue_id': q.queueId,
              'device_id': q.deviceId,
              'table_name': q.tableNameValue,
              'record_id': q.recordId,
              'operation': q.operation,
              'data': q.data,
              'created_at': q.createdAt.toIso8601String(),
            }).toList(),
        'count': items.length,
        'server_time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return _err(e);
    }
  }

  /// Client แจ้งว่า sync เสร็จแล้ว
  Future<Response> _acknowledgeSyncData(Request req) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final queueIds = (data['queue_ids'] as List).cast<String>();

      for (final id in queueIds) {
        await (db.update(db.syncQueues)
              ..where((q) => q.queueId.equals(id)))
            .write(SyncQueuesCompanion(
          syncStatus: const Value('SYNCED'),
          syncedAt: Value(DateTime.now()),
        ));
      }

      return _okMsg({'acknowledged': queueIds.length}, 'Acknowledged');
    } catch (e) {
      return _err(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Response _ok(dynamic data) => Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );

  Response _okMsg(Map<String, dynamic> data, String msg) => Response.ok(
        jsonEncode({'success': true, 'message': msg, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );

  Response _err(Object e) => Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
}
