import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_erp/core/client/api_client.dart';
import 'package:pos_erp/core/database/app_database.dart';
import 'package:pos_erp/core/services/offline_sync_service.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    required this.pullItems,
  }) : super(baseUrl: 'http://localhost');

  final List<Map<String, dynamic>> pullItems;
  final List<List<String>> acknowledgedPayloads = [];

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == '/api/health') {
      return _response(path, 200, {'success': true});
    }
    if (path == '/api/branches/sync/status') {
      return _response(path, 200, {
        'success': true,
        'data': {'last_sync_at': null},
      });
    }
    if (path.startsWith('/api/branches/sync/pull')) {
      return _response(path, 200, {
        'success': true,
        'data': {'items': pullItems},
      });
    }
    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    if (path == '/api/sync/push-pending') {
      return _response(path, 200, {
        'success': true,
        'data': {'pushed': 0},
      });
    }
    if (path == '/api/branches/sync/acknowledge') {
      final queueIds = (data['queue_ids'] as List).cast<String>();
      acknowledgedPayloads.add(queueIds);
      return _response(path, 200, {
        'success': true,
        'data': {'acknowledged': queueIds.length},
      });
    }
    throw UnimplementedError('Unhandled POST $path');
  }

  Response _response(String path, int statusCode, dynamic data) {
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
  }
}

Provider<OfflineSyncService> _testServiceProvider(AppDatabase db) {
  return Provider<OfflineSyncService>(
    (ref) => OfflineSyncService(ref, database: db),
  );
}

void main() {
  group('OfflineSyncService syncNow', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement('PRAGMA foreign_keys = ON');
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'applies ordered composite and foreign-key items then acknowledges only successes',
      () async {
        final fakeApi = _FakeApiClient(
          pullItems: [
            {
              'queue_id': 'q1',
              'table_name': 'companies',
              'record_id': 'COMP1',
              'operation': 'INSERT',
              'data': {
                'company_name': 'Test Co',
              },
            },
            {
              'queue_id': 'q2',
              'table_name': 'branches',
              'record_id': 'BR1',
              'operation': 'INSERT',
              'data': {
                'company_id': 'COMP1',
                'branch_code': 'B01',
                'branch_name': 'Main Branch',
              },
            },
            {
              'queue_id': 'q3',
              'table_name': 'product_groups',
              'record_id': 'PG1',
              'operation': 'INSERT',
              'data': {
                'group_code': 'FOOD',
                'group_name': 'Food',
              },
            },
            {
              'queue_id': 'q4',
              'table_name': 'products',
              'record_id': 'PR1',
              'operation': 'INSERT',
              'data': {
                'product_code': 'P001',
                'product_name': 'Noodles',
                'base_unit': 'BOWL',
                'group_id': 'PG1',
                'price_level1': 99,
              },
            },
            {
              'queue_id': 'q5',
              'table_name': 'modifier_groups',
              'record_id': 'MG1',
              'operation': 'INSERT',
              'data': {
                'group_name': 'Toppings',
              },
            },
            {
              'queue_id': 'q6',
              'table_name': 'product_modifiers',
              'record_id': 'PR1|MG1',
              'operation': 'INSERT',
              'data': {
                'product_id': 'PR1',
                'modifier_group_id': 'MG1',
                'is_required': true,
              },
            },
            {
              'queue_id': 'q7',
              'table_name': 'zones',
              'record_id': 'ZN1',
              'operation': 'INSERT',
              'data': {
                'zone_name': 'Front',
                'branch_id': 'BR1',
              },
            },
            {
              'queue_id': 'q8',
              'table_name': 'dining_tables',
              'record_id': 'TB1',
              'operation': 'INSERT',
              'data': {
                'table_no': 'A01',
                'zone_id': 'ZN1',
                'capacity': 4,
              },
            },
            {
              'queue_id': 'q9',
              'table_name': 'product_modifiers',
              'record_id': 'BROKEN',
              'operation': 'INSERT',
              'data': const {},
            },
          ],
        );

        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(_testServiceProvider(db));
        final result = await service.syncNow();

        expect(result, isTrue);
        expect(fakeApi.acknowledgedPayloads, hasLength(1));
        expect(
          fakeApi.acknowledgedPayloads.single,
          equals(['q1', 'q2', 'q3', 'q5', 'q4', 'q6', 'q7', 'q8']),
        );
        expect(service.lastBatchMetrics, isNotNull);
        expect(service.lastBatchMetrics!.totalItems, 9);
        expect(service.lastBatchMetrics!.appliedItems, 8);
        expect(service.lastBatchMetrics!.passesUsed, 2);
        expect(service.lastBatchMetrics!.replayedItems, 1);
        expect(service.lastBatchMetrics!.pendingItems, 1);

        final productModifier = await (db.select(db.productModifiers)
              ..where((t) => t.productId.equals('PR1'))
              ..where((t) => t.modifierGroupId.equals('MG1')))
            .getSingleOrNull();
        final diningTable = await (db.select(db.diningTables)
              ..where((t) => t.tableId.equals('TB1')))
            .getSingleOrNull();
        final auditLogs = await (db.select(db.auditLogs)
              ..where((t) => t.action.equals('SYNC_BATCH'))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .get();

        expect(productModifier, isNotNull);
        expect(productModifier!.isRequired, isTrue);
        expect(diningTable, isNotNull);
        expect(diningTable!.zoneId, 'ZN1');
        expect(auditLogs, hasLength(1));
        expect(auditLogs.first.tableNameValue, 'sync_batches');
        expect(auditLogs.first.newValue, isA<Map>());
        final batchLog = Map<String, dynamic>.from(
          auditLogs.first.newValue as Map,
        );
        expect(batchLog['total_items'], 9);
        expect(batchLog['applied_items'], 8);
        expect(batchLog['replayed_items'], 1);
        expect(batchLog['pending_items'], 1);
      },
    );

    test(
      'replays dependent items within the same batch and acknowledges them after parents are applied',
      () async {
        final fakeApi = _FakeApiClient(
          pullItems: [
            {
              'queue_id': 'q1',
              'table_name': 'dining_tables',
              'record_id': 'TB1',
              'operation': 'INSERT',
              'data': {
                'table_no': 'A01',
                'zone_id': 'ZN1',
              },
            },
            {
              'queue_id': 'q2',
              'table_name': 'companies',
              'record_id': 'COMP1',
              'operation': 'INSERT',
              'data': {
                'company_name': 'Test Co',
              },
            },
            {
              'queue_id': 'q3',
              'table_name': 'branches',
              'record_id': 'BR1',
              'operation': 'INSERT',
              'data': {
                'company_id': 'COMP1',
                'branch_code': 'B01',
                'branch_name': 'Main Branch',
              },
            },
            {
              'queue_id': 'q4',
              'table_name': 'zones',
              'record_id': 'ZN1',
              'operation': 'INSERT',
              'data': {
                'zone_name': 'Front',
                'branch_id': 'BR1',
              },
            },
          ],
        );

        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(_testServiceProvider(db));
        final result = await service.syncNow();

        expect(result, isTrue);
        expect(fakeApi.acknowledgedPayloads, hasLength(1));
        expect(fakeApi.acknowledgedPayloads.single, equals(['q2', 'q3', 'q4', 'q1']));
        expect(service.lastBatchMetrics, isNotNull);
        expect(service.lastBatchMetrics!.totalItems, 4);
        expect(service.lastBatchMetrics!.appliedItems, 4);
        expect(service.lastBatchMetrics!.passesUsed, 1);
        expect(service.lastBatchMetrics!.replayedItems, 0);
        expect(service.lastBatchMetrics!.pendingItems, 0);

        final diningTable = await (db.select(db.diningTables)
              ..where((t) => t.tableId.equals('TB1')))
            .getSingleOrNull();
        final zone = await (db.select(db.zones)..where((t) => t.zoneId.equals('ZN1')))
            .getSingleOrNull();
        final auditLogs = await (db.select(db.auditLogs)
              ..where((t) => t.action.equals('SYNC_BATCH'))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .get();

        expect(diningTable, isNotNull);
        expect(diningTable!.zoneId, 'ZN1');
        expect(zone, isNotNull);
        expect(auditLogs, hasLength(1));
        final batchLog = Map<String, dynamic>.from(
          auditLogs.first.newValue as Map,
        );
        expect(batchLog['total_items'], 4);
        expect(batchLog['applied_items'], 4);
        expect(batchLog['replayed_items'], 0);
        expect(batchLog['pending_items'], 0);
      },
    );
  });
}
