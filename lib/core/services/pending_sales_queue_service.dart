
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../client/api_client.dart';
import 'package:flutter/foundation.dart';

class PendingSalesQueueService {
  static const _prefsKey = 'pending_sales_orders';

  final StreamController<int> _countController =
      StreamController<int>.broadcast();
  bool _initialized = false;
  bool _isReplaying = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _emitCount();
  }

  Stream<int> get countStream async* {
    await initialize();
    yield await pendingCount();
    yield* _countController.stream;
  }

  Future<int> pendingCount() async {
    final items = await _loadItems();
    return items.length;
  }

  Future<void> enqueueOrder(Map<String, dynamic> payload) async {
    final items = await _loadItems();
    items.add({
      'local_queue_id': 'LQ${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
      'payload': payload,
    });
    await _saveItems(items);
    if (kDebugMode) {
      debugPrint('🧾 Queued offline sale (${items.length} pending)');
    }
  }

  Future<int> replayPendingOrders(ApiClient apiClient) async {
    await initialize();
    if (_isReplaying) return 0;

    _isReplaying = true;
    try {
      final items = await _loadItems();
      if (items.isEmpty) return 0;

      final remaining = <Map<String, dynamic>>[];
      var replayed = 0;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final payload = Map<String, dynamic>.from(item['payload'] as Map);

        try {
          final response = await apiClient.post('/api/sales', data: payload);
          if (response.statusCode == 200) {
            replayed++;
            await _markCouponsUsed(apiClient, payload, response.data);
            continue;
          }
          remaining.add(item);
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode;
          if (statusCode != null && statusCode >= 400 && statusCode < 500) {
            remaining.add({
              ...item,
              'last_error': e.message,
              'last_error_at': DateTime.now().toIso8601String(),
            });
            continue;
          }

          remaining.addAll(items.sublist(i));
          break;
        } catch (e) {
          remaining.add({
            ...item,
            'last_error': '$e',
            'last_error_at': DateTime.now().toIso8601String(),
          });
        }
      }

      await _saveItems(remaining);
      if (replayed > 0) {
        if (kDebugMode) {
          debugPrint('✅ Replayed $replayed queued sale(s)');
        }
      }
      return replayed;
    } finally {
      _isReplaying = false;
    }
  }

  Future<void> _markCouponsUsed(
    ApiClient apiClient,
    Map<String, dynamic> payload,
    dynamic responseData,
  ) async {
    final coupons =
        (payload['coupon_codes'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
    if (coupons.isEmpty) return;

    final root = responseData is Map<String, dynamic>
        ? responseData
        : Map<String, dynamic>.from(responseData as Map);
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : Map<String, dynamic>.from(root['data'] as Map);
    final orderNo = data['order_no'] as String? ?? '-';

    for (final coupon in coupons) {
      try {
        await apiClient.put(
          '/api/promotions/coupons/${coupon.toUpperCase()}/use',
          data: {
            'customer_id': payload['customer_id'],
            'order_no': orderNo,
          },
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Could not mark queued coupon $coupon as used: $e');
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Pending queue decode error: $e');
      }
      return [];
    }
  }

  Future<void> _saveItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(items));
    await _emitCount();
  }

  Future<void> _emitCount() async {
    if (_countController.isClosed) return;
    _countController.add(await pendingCount());
  }
}

final pendingSalesQueueServiceProvider = Provider<PendingSalesQueueService>((
  ref,
) {
  final svc = PendingSalesQueueService();
  svc.initialize();
  return svc;
});

final pendingSalesQueueCountProvider = StreamProvider<int>((ref) {
  return ref.read(pendingSalesQueueServiceProvider).countStream;
});
