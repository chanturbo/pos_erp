import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_erp/core/client/api_client.dart';
import 'package:pos_erp/features/auth/data/models/user_model.dart';
import 'package:pos_erp/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_erp/features/branches/data/models/branch_model.dart';
import 'package:pos_erp/features/branches/presentation/providers/branch_provider.dart';
import 'package:pos_erp/features/restaurant/data/models/bill_model.dart';
import 'package:pos_erp/features/restaurant/data/models/reservation_model.dart';
import 'package:pos_erp/features/restaurant/data/models/restaurant_order_context.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/billing_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/kitchen_display_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/reservation_form_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/reservations_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/split_bill_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/table_overview_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/table_timeline_page.dart';
import 'package:pos_erp/features/restaurant/presentation/providers/reservation_provider.dart';
import 'package:pos_erp/features/restaurant/presentation/providers/table_provider.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';
import 'package:pos_erp/shared/widgets/busy_overlay.dart';

class _FakeRestaurantApiClient extends ApiClient {
  _FakeRestaurantApiClient({
    this.confirmDelay,
    this.refreshDelay,
    this.confirmSucceeds = true,
    List<Map<String, dynamic>>? reservations,
  }) : _reservations =
           reservations ??
           [
             {
               'reservation_id': 'RES1',
               'table_id': null,
               'table_name': null,
               'branch_id': 'BR1',
               'customer_name': 'John',
               'customer_phone': '0812345678',
               'reservation_time': DateTime(
                 2026,
                 4,
                 20,
                 12,
                 0,
               ).toIso8601String(),
               'party_size': 2,
               'notes': 'Window seat',
               'status': 'PENDING',
               'session_id': null,
               'created_at': DateTime(2026, 4, 20, 9, 0).toIso8601String(),
             },
             {
               'reservation_id': 'RES2',
               'table_id': 'TB1',
               'table_name': 'A1',
               'branch_id': 'BR1',
               'customer_name': 'Mali',
               'customer_phone': '0899999999',
               'reservation_time': DateTime(
                 2026,
                 4,
                 20,
                 18,
                 30,
               ).toIso8601String(),
               'party_size': 4,
               'notes': 'Birthday cake',
               'status': 'CONFIRMED',
               'session_id': null,
               'created_at': DateTime(2026, 4, 20, 10, 0).toIso8601String(),
             },
           ],
       super(baseUrl: 'http://localhost');

  final Duration? confirmDelay;
  final Duration? refreshDelay;
  final bool confirmSucceeds;
  final List<String> getCalls = [];
  final List<String> postCalls = [];
  final List<Map<String, dynamic>> _reservations;

  int _confirmCount = 0;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path.startsWith('/api/tables/reservations?date=')) {
      final uri = Uri.parse(path);
      final query = (uri.queryParameters['query'] ?? '').trim().toLowerCase();
      if (refreshDelay != null) {
        await Future<void>.delayed(refreshDelay!);
      }
      final reservations = _reservations
          .map((reservation) {
            if (reservation['reservation_id'] == 'RES1' && _confirmCount > 0) {
              return {...reservation, 'status': 'CONFIRMED'};
            }
            return reservation;
          })
          .where((reservation) {
            if (query.isEmpty) return true;
            final customerName = (reservation['customer_name'] as String? ?? '')
                .toLowerCase();
            final customerPhone =
                (reservation['customer_phone'] as String? ?? '').toLowerCase();
            return customerName.contains(query) ||
                customerPhone.contains(query);
          })
          .toList();
      return _response(path, 200, {'success': true, 'data': reservations});
    }

    if (path == '/api/tables/?branch_id=BR1') {
      return _response(path, 200, {
        'success': true,
        'data': [
          {
            'table_id': 'TB1',
            'table_no': 'A1',
            'table_display_name': 'A1',
            'zone_id': 'ZN1',
            'zone_name': 'Front',
            'capacity': 4,
            'status': 'AVAILABLE',
            'current_order_id': null,
            'active_session_id': null,
            'active_guest_count': null,
            'session_opened_at': null,
          },
        ],
      });
    }

    if (path == '/api/tables/zones?branch_id=BR1') {
      return _response(path, 200, {
        'success': true,
        'data': [
          {
            'zone_id': 'ZN1',
            'zone_name': 'Front',
            'branch_id': 'BR1',
            'display_order': 0,
            'is_active': true,
          },
        ],
      });
    }

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/tables/TB1/update-guest-count') {
      return _response(path, 200, {
        'success': true,
        'data': {'guest_count': data['guest_count']},
      });
    }

    if (path == '/api/tables/reservations/RES1/seat') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'reservation_id': 'RES1',
          'session_id': 'TS1',
          'table_id': 'TB1',
        },
      });
    }

    if (path == '/api/tables/reservations/RES1/confirm') {
      if (confirmDelay != null) {
        await Future<void>.delayed(confirmDelay!);
      }
      if (!confirmSucceeds) {
        return _response(path, 500, {
          'success': false,
          'message': 'Confirm failed',
        });
      }
      _confirmCount++;
      return _response(path, 200, {
        'success': true,
        'data': {'reservation_id': 'RES1', 'status': 'CONFIRMED'},
      });
    }
    if (path == '/api/tables/reservations/RES1/cancel') {
      return _response(path, 200, {'success': true});
    }

    if (path == '/api/tables/reservations/RES1/no-show') {
      return _response(path, 200, {'success': true});
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

class _FakeBillingApiClient extends ApiClient {
  _FakeBillingApiClient({this.failBillLoad = false})
    : super(baseUrl: 'http://localhost');

  final List<String> getCalls = [];
  final List<String> postCalls = [];
  final List<String> putCalls = [];
  final bool failBillLoad;

  double _serviceChargeRate = 10;
  List<Map<String, dynamic>> _items = [
    {
      'item_id': 'IT1',
      'order_id': 'SO1',
      'line_no': 1,
      'product_id': 'P1',
      'product_name': 'Pad Thai',
      'quantity': 1,
      'unit': 'plate',
      'unit_price': 120,
      'discount_amount': 0,
      'amount': 120,
      'kitchen_status': 'PENDING',
      'course_no': 1,
      'special_instructions': 'No peanuts',
      'modifiers': [
        {
          'modifier_id': 'M1',
          'modifier_name': 'Extra egg',
          'price_adjustment': 15,
        },
      ],
    },
    {
      'item_id': 'IT2',
      'order_id': 'SO1',
      'line_no': 2,
      'product_id': 'P2',
      'product_name': 'Tom Yum Soup',
      'quantity': 1,
      'unit': 'bowl',
      'unit_price': 180,
      'discount_amount': 0,
      'amount': 180,
      'kitchen_status': 'HELD',
      'course_no': 2,
      'special_instructions': 'Less spicy',
      'modifiers': const [],
    },
  ];

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path == '/api/tables/TB1/bill') {
      if (failBillLoad) {
        return _response(path, 500, {
          'success': false,
          'message': 'Bill service unavailable',
        });
      }
      return _response(path, 200, {'success': true, 'data': _billJson()});
    }

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/tables/TB1/fire-course') {
      final courseNo = data['course_no'] as int?;
      _items = _items.map((item) {
        if (item['course_no'] == courseNo && item['kitchen_status'] == 'HELD') {
          return {...item, 'kitchen_status': 'PENDING'};
        }
        return item;
      }).toList();

      return _response(path, 200, {
        'success': true,
        'data': {'table_id': 'TB1', 'course_no': courseNo},
      });
    }

    if (path == '/api/tables/TB1/bill/service-charge') {
      _serviceChargeRate = (data['rate'] as num).toDouble();
      return _response(path, 200, {
        'success': true,
        'data': {'rate': _serviceChargeRate},
      });
    }

    throw UnimplementedError('Unhandled POST $path');
  }

  @override
  Future<Response> put(String path, {dynamic data}) async {
    putCalls.add(path);

    if (path == '/api/kitchen/items/IT1/status') {
      _items = _items.where((item) => item['item_id'] != 'IT1').toList();
      return _response(path, 200, {
        'success': true,
        'data': {'item_id': 'IT1', 'status': data['status']},
      });
    }

    throw UnimplementedError('Unhandled PUT $path');
  }

  Map<String, dynamic> _billJson() {
    final subtotal = _items.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );
    final serviceChargeAmount = subtotal * (_serviceChargeRate / 100);
    return {
      'session_id': 'TS1',
      'table_id': 'TB1',
      'guest_count': 3,
      'opened_at': DateTime(2026, 4, 20, 12, 0).toIso8601String(),
      'order_ids': ['SO1'],
      'items': _items,
      'subtotal': subtotal,
      'discount_amount': 0,
      'service_charge_rate': _serviceChargeRate,
      'service_charge_amount': serviceChargeAmount,
      'grand_total': subtotal + serviceChargeAmount,
    };
  }

  Response _response(String path, int statusCode, dynamic data) {
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
  }
}

class _FakeKitchenApiClient extends ApiClient {
  _FakeKitchenApiClient({
    required this.includeItems,
    this.failStatusUpdate = false,
    this.failFireCourse = false,
  }) : super(baseUrl: 'http://localhost');

  final bool includeItems;
  final bool failStatusUpdate;
  final bool failFireCourse;
  final List<String> getCalls = [];
  final List<String> postCalls = [];
  final List<String> putCalls = [];

  late List<Map<String, dynamic>> _items = includeItems
      ? [
          {
            'item_id': 'KI1',
            'order_id': 'SO1',
            'order_no': 'ORD-001',
            'table_id': 'TB1',
            'table_name': 'A1',
            'session_id': 'TS1',
            'line_no': 1,
            'product_id': 'P1',
            'product_name': 'Pad Thai',
            'quantity': 1,
            'unit': 'plate',
            'kitchen_status': 'PENDING',
            'course_no': 1,
            'prep_station': 'kitchen',
            'special_instructions': 'No peanuts',
            'created_at': DateTime(2026, 4, 20, 11, 55).toIso8601String(),
          },
          {
            'item_id': 'KI2',
            'order_id': 'SO1',
            'order_no': 'ORD-001',
            'table_id': 'TB1',
            'table_name': 'A1',
            'session_id': 'TS1',
            'line_no': 2,
            'product_id': 'P2',
            'product_name': 'Tom Yum Soup',
            'quantity': 1,
            'unit': 'bowl',
            'kitchen_status': 'HELD',
            'course_no': 2,
            'prep_station': 'kitchen',
            'special_instructions': 'Serve later',
            'created_at': DateTime(2026, 4, 20, 11, 56).toIso8601String(),
          },
          {
            'item_id': 'KI3',
            'order_id': 'SO2',
            'order_no': 'ORD-002',
            'table_id': 'TB2',
            'table_name': 'B2',
            'session_id': 'TS2',
            'line_no': 1,
            'product_id': 'P3',
            'product_name': 'Latte',
            'quantity': 1,
            'unit': 'glass',
            'kitchen_status': 'PENDING',
            'course_no': 1,
            'prep_station': 'bar',
            'special_instructions': null,
            'created_at': DateTime(2026, 4, 20, 11, 57).toIso8601String(),
          },
        ]
      : <Map<String, dynamic>>[];

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path.startsWith('/api/kitchen/queue?')) {
      final uri = Uri.parse(path);
      final station = uri.queryParameters['station'];
      final filtered = station == null
          ? _items
          : _items.where((item) => item['prep_station'] == station).toList();
      return _response(path, 200, {'success': true, 'data': filtered});
    }

    if (path == '/api/kitchen/summary?branch_id=BR1') {
      return _response(path, 200, {'success': true, 'data': _summaryJson()});
    }

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> put(String path, {dynamic data}) async {
    putCalls.add(path);

    if (path == '/api/kitchen/items/KI1/status') {
      if (failStatusUpdate) {
        return _response(path, 500, {
          'success': false,
          'message': 'Update failed',
        });
      }
      _items = _items.map((item) {
        if (item['item_id'] == 'KI1') {
          return {
            ...item,
            'kitchen_status': data['status'],
            if (data['status'] == 'READY')
              'prepared_at': DateTime(2026, 4, 20, 12, 5).toIso8601String(),
          };
        }
        return item;
      }).toList();

      return _response(path, 200, {
        'success': true,
        'data': {'item_id': 'KI1', 'status': data['status']},
      });
    }

    throw UnimplementedError('Unhandled PUT $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/tables/TB1/fire-course') {
      if (failFireCourse) {
        return _response(path, 500, {
          'success': false,
          'message': 'Fire failed',
        });
      }
      _items = _items.map((item) {
        if (item['table_id'] == 'TB1' &&
            item['course_no'] == data['course_no'] &&
            item['kitchen_status'] == 'HELD') {
          return {...item, 'kitchen_status': 'PENDING'};
        }
        return item;
      }).toList();

      return _response(path, 200, {
        'success': true,
        'data': {'table_id': 'TB1', 'course_no': data['course_no']},
      });
    }

    throw UnimplementedError('Unhandled POST $path');
  }

  List<Map<String, dynamic>> _summaryJson() {
    const stations = ['kitchen', 'bar', 'dessert'];
    return stations.map((station) {
      final stationItems = _items
          .where((item) => item['prep_station'] == station)
          .toList();
      final pendingCount = stationItems
          .where((item) => item['kitchen_status'] == 'PENDING')
          .length;
      final preparingCount = stationItems
          .where((item) => item['kitchen_status'] == 'PREPARING')
          .length;
      final readyCount = stationItems
          .where((item) => item['kitchen_status'] == 'READY')
          .length;
      return {
        'station': station,
        'pending_count': pendingCount,
        'preparing_count': preparingCount,
        'ready_count': readyCount,
      };
    }).toList();
  }

  Response _response(String path, int statusCode, dynamic data) {
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
  }
}

class _FakeRestaurantDetailApiClient extends ApiClient {
  _FakeRestaurantDetailApiClient() : super(baseUrl: 'http://localhost');

  final List<String> getCalls = [];
  final List<String> postCalls = [];

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path == '/api/tables/TB1/timeline') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'session_id': 'TS1',
          'table_id': 'TB1',
          'opened_at': null,
          'waiter_name': 'Nok',
          'guest_count': 4,
          'status': 'OPEN',
          'events': [
            {
              'type': 'opened',
              'description': 'เปิดโต๊ะ A1',
              'timestamp': DateTime(2026, 4, 22, 18, 0).toIso8601String(),
            },
            {
              'type': 'order',
              'description': 'รับออเดอร์รอบแรก',
              'timestamp': DateTime(2026, 4, 22, 18, 5).toIso8601String(),
              'data': {
                'items': [
                  {
                    'name': 'Pad Thai',
                    'qty': 1,
                    'course_no': 1,
                    'kitchen_status': 'READY',
                  },
                  {
                    'name': 'Tom Yum Soup',
                    'qty': 1,
                    'course_no': 2,
                    'kitchen_status': 'PENDING',
                  },
                ],
              },
            },
            {
              'type': 'waiter',
              'description': 'กำหนดพนักงานเสิร์ฟ Nok',
              'timestamp': DateTime(2026, 4, 22, 18, 7).toIso8601String(),
            },
            {
              'type': 'item_status',
              'description': 'Pad Thai พร้อมเสิร์ฟ',
              'timestamp': DateTime(2026, 4, 22, 18, 14).toIso8601String(),
            },
            {
              'type': 'billed',
              'description': 'พิมพ์ pre-bill ให้ลูกค้า',
              'timestamp': DateTime(2026, 4, 22, 18, 40).toIso8601String(),
            },
          ],
        },
      });
    }

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/tables/TB1/bill/split') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'mode': 'equal',
          'count': 2,
          'grand_total': 495,
          'per_person': 247.5,
          'preview_token': 'preview-001',
          'splits': [
            {
              'label': 'คน 1',
              'subtotal': 225,
              'discount_amount': 0,
              'service_charge': 22.5,
              'total': 247.5,
              'order_ids': const [],
              'items': [
                {
                  'item_id': 'IT1',
                  'product_id': 'P1',
                  'product_name': 'Pad Thai',
                  'quantity': 1,
                  'unit': 'plate',
                  'unit_price': 120,
                  'amount': 120,
                },
                {
                  'item_id': 'IT2',
                  'product_id': 'P2',
                  'product_name': 'Tom Yum Soup',
                  'quantity': 1,
                  'unit': 'bowl',
                  'unit_price': 105,
                  'amount': 105,
                },
              ],
            },
            {
              'label': 'คน 2',
              'subtotal': 225,
              'discount_amount': 0,
              'service_charge': 22.5,
              'total': 247.5,
              'order_ids': const [],
              'items': [
                {
                  'item_id': 'IT3',
                  'product_id': 'P3',
                  'product_name': 'Iced Latte',
                  'quantity': 1,
                  'unit': 'glass',
                  'unit_price': 95,
                  'amount': 95,
                },
                {
                  'item_id': 'IT4',
                  'product_id': 'P4',
                  'product_name': 'Mango Sticky Rice',
                  'quantity': 1,
                  'unit': 'plate',
                  'unit_price': 130,
                  'amount': 130,
                },
              ],
            },
          ],
        },
      });
    }

    if (path == '/api/tables/TB1/bill/split/apply') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'mode': 'by_item',
          'count': 2,
          'grand_total': 379.5,
          'per_person': 0,
          'splits': [
            {
              'label': 'คน 1',
              'subtotal': 225,
              'discount_amount': 0,
              'service_charge': 22.5,
              'total': 247.5,
              'order_ids': ['SO-SPLIT-1'],
              'items': [
                {
                  'item_id': 'IT1',
                  'product_id': 'P1',
                  'product_name': 'Pad Thai',
                  'quantity': 1,
                  'unit': 'plate',
                  'unit_price': 120,
                  'amount': 120,
                },
                {
                  'item_id': 'IT2',
                  'product_id': 'P2',
                  'product_name': 'Tom Yum Soup',
                  'quantity': 1,
                  'unit': 'bowl',
                  'unit_price': 105,
                  'amount': 105,
                },
              ],
            },
            {
              'label': 'คน 2',
              'subtotal': 120,
              'discount_amount': 0,
              'service_charge': 12,
              'total': 132,
              'order_ids': ['SO-SPLIT-2'],
              'items': [
                {
                  'item_id': 'IT3',
                  'product_id': 'P1',
                  'product_name': 'Pad Thai',
                  'quantity': 1,
                  'unit': 'plate',
                  'unit_price': 120,
                  'amount': 120,
                },
              ],
            },
          ],
        },
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

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: true,
      isRestoring: false,
      user: UserModel(
        userId: 'USR1',
        username: 'admin',
        fullName: 'Admin',
        roleId: 'ADMIN',
        branchId: 'BR1',
      ),
      token: 'token',
    );
  }
}

class _TestSelectedBranchNotifier extends SelectedBranchNotifier {
  @override
  BranchModel? build() {
    return BranchModel(
      branchId: 'BR1',
      companyId: 'COMP1',
      branchCode: 'B01',
      branchName: 'Restaurant 1',
      businessMode: 'RESTAURANT',
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );
  }
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this._state);

  final SettingsState _state;

  @override
  SettingsState build() => _state;
}

class _FakeTableOverviewApiClient extends ApiClient {
  _FakeTableOverviewApiClient({
    required this.initialStatus,
    this.returnActiveSession = true,
    this.openSucceeds = true,
    this.closeSucceeds = true,
    this.closeFailureMessage = 'ยังมี order ที่เปิดอยู่',
    List<Map<String, dynamic>>? tables,
    List<Map<String, dynamic>>? zones,
  }) : super(baseUrl: 'http://localhost') {
    _status = initialStatus;
    _guestCount = initialStatus == 'OCCUPIED' ? 2 : null;
    _activeSessionId = initialStatus == 'OCCUPIED' ? 'TS1' : null;
    _sessionOpenedAt = initialStatus == 'OCCUPIED'
        ? DateTime(2026, 4, 20, 11, 30)
        : null;
    _tables =
        tables ??
        [
          _buildTableJson(
            tableId: 'TB1',
            tableNo: 'A1',
            zoneId: 'ZN1',
            zoneName: 'Front',
            capacity: 4,
            status: initialStatus,
            currentOrderId: _activeSessionId != null ? 'SO1' : null,
            activeSessionId: _activeSessionId,
            activeGuestCount: _guestCount,
            sessionOpenedAt: _sessionOpenedAt,
          ),
        ];
    _zones =
        zones ??
        [
          {
            'zone_id': 'ZN1',
            'zone_name': 'Front',
            'branch_id': 'BR1',
            'display_order': 0,
            'is_active': true,
          },
        ];
  }

  final String initialStatus;
  final bool returnActiveSession;
  final bool openSucceeds;
  final bool closeSucceeds;
  final String closeFailureMessage;
  final List<String> postCalls = [];
  static const actionDelay = Duration(milliseconds: 200);

  late String _status;
  int? _guestCount;
  String? _activeSessionId;
  DateTime? _sessionOpenedAt;
  late List<Map<String, dynamic>> _tables;
  late List<Map<String, dynamic>> _zones;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == '/api/tables/?branch_id=BR1') {
      return _response(path, 200, {'success': true, 'data': _tables});
    }
    if (path == '/api/tables/zones?branch_id=BR1') {
      return _response(path, 200, {'success': true, 'data': _zones});
    }
    if (path == '/api/tables/TB1/session') {
      if (_activeSessionId == null || !returnActiveSession) {
        return _response(path, 404, {
          'success': false,
          'message': 'No active session',
        });
      }
      return _response(path, 200, {
        'success': true,
        'data': {
          'session_id': _activeSessionId,
          'table_id': 'TB1',
          'branch_id': 'BR1',
          'opened_at': (_sessionOpenedAt ?? DateTime(2026, 4, 20, 11, 30))
              .toIso8601String(),
          'closed_at': null,
          'guest_count': _guestCount ?? 1,
          'status': 'OPEN',
          'opened_by': 'USR1',
          'note': null,
        },
      });
    }
    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/tables/TB1/open') {
      await Future<void>.delayed(actionDelay);
      if (!openSucceeds) {
        return _response(path, 409, {
          'success': false,
          'message': 'Open failed',
        });
      }
      _status = 'OCCUPIED';
      _guestCount = data['guest_count'] as int? ?? 1;
      _activeSessionId = 'TS-OPEN';
      _sessionOpenedAt = DateTime(2026, 4, 20, 12, 0);
      _replaceTable(
        'TB1',
        _buildTableJson(
          tableId: 'TB1',
          tableNo: 'A1',
          zoneId: 'ZN1',
          zoneName: 'Front',
          capacity: 4,
          status: _status,
          currentOrderId: 'SO1',
          activeSessionId: _activeSessionId,
          activeGuestCount: _guestCount,
          sessionOpenedAt: _sessionOpenedAt,
        ),
      );
      return _response(path, 201, {
        'success': true,
        'data': {
          'session_id': _activeSessionId,
          'table_id': 'TB1',
          'branch_id': 'BR1',
          'opened_at': _sessionOpenedAt!.toIso8601String(),
          'guest_count': _guestCount,
          'status': 'OPEN',
          'opened_by': 'USR1',
        },
      });
    }

    if (path == '/api/tables/TB1/close') {
      await Future<void>.delayed(actionDelay);
      if (!closeSucceeds) {
        return _response(path, 409, {
          'success': false,
          'message': closeFailureMessage,
        });
      }
      _status = 'CLEANING';
      _activeSessionId = null;
      _guestCount = null;
      _sessionOpenedAt = null;
      _replaceTable(
        'TB1',
        _buildTableJson(
          tableId: 'TB1',
          tableNo: 'A1',
          zoneId: 'ZN1',
          zoneName: 'Front',
          capacity: 4,
          status: _status,
          currentOrderId: null,
          activeSessionId: null,
          activeGuestCount: null,
          sessionOpenedAt: null,
        ),
      );
      return _response(path, 200, {
        'success': true,
        'data': {'table_id': 'TB1', 'status': 'CLOSED'},
      });
    }

    if (path == '/api/tables/TB1/update-guest-count') {
      await Future<void>.delayed(actionDelay);
      _guestCount = data['guest_count'] as int?;
      _replaceTable(
        'TB1',
        _buildTableJson(
          tableId: 'TB1',
          tableNo: 'A1',
          zoneId: 'ZN1',
          zoneName: 'Front',
          capacity: 4,
          status: _status,
          currentOrderId: _activeSessionId != null ? 'SO1' : null,
          activeSessionId: _activeSessionId,
          activeGuestCount: _guestCount,
          sessionOpenedAt: _sessionOpenedAt,
        ),
      );
      return _response(path, 200, {
        'success': true,
        'data': {
          'session_id': _activeSessionId ?? 'TS1',
          'guest_count': _guestCount,
        },
      });
    }

    throw UnimplementedError('Unhandled POST $path');
  }

  static Map<String, dynamic> _buildTableJson({
    required String tableId,
    required String tableNo,
    required String zoneId,
    required String zoneName,
    required int capacity,
    required String status,
    String? currentOrderId,
    String? activeSessionId,
    int? activeGuestCount,
    DateTime? sessionOpenedAt,
  }) => {
    'table_id': tableId,
    'table_no': tableNo,
    'table_display_name': tableNo,
    'zone_id': zoneId,
    'zone_name': zoneName,
    'capacity': capacity,
    'status': status,
    'current_order_id': currentOrderId,
    'last_occupied_at': sessionOpenedAt?.toIso8601String(),
    'active_session_id': activeSessionId,
    'active_guest_count': activeGuestCount,
    'session_opened_at': sessionOpenedAt?.toIso8601String(),
  };

  void _replaceTable(String tableId, Map<String, dynamic> updated) {
    _tables = _tables.map((table) {
      if (table['table_id'] == tableId) return updated;
      return table;
    }).toList();
  }

  Response _response(String path, int statusCode, dynamic data) {
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
  }
}

const _billingContext = RestaurantOrderContext(
  tableId: 'TB1',
  tableName: 'A1',
  sessionId: 'TS1',
  branchId: 'BR1',
  guestCount: 3,
);

const _splitBillGoldenBill = BillModel(
  sessionId: 'TS1',
  tableId: 'TB1',
  guestCount: 4,
  openedAt: null,
  orderIds: ['SO1'],
  items: [
    BillItemModel(
      itemId: 'IT1',
      orderId: 'SO1',
      lineNo: 1,
      productId: 'P1',
      productName: 'Pad Thai',
      quantity: 1,
      unit: 'plate',
      unitPrice: 120,
      discountAmount: 0,
      amount: 120,
      kitchenStatus: 'PENDING',
    ),
    BillItemModel(
      itemId: 'IT2',
      orderId: 'SO1',
      lineNo: 2,
      productId: 'P2',
      productName: 'Tom Yum Soup',
      quantity: 1,
      unit: 'bowl',
      unitPrice: 105,
      discountAmount: 0,
      amount: 105,
      kitchenStatus: 'PENDING',
    ),
    BillItemModel(
      itemId: 'IT3',
      orderId: 'SO1',
      lineNo: 3,
      productId: 'P3',
      productName: 'Iced Latte',
      quantity: 1,
      unit: 'glass',
      unitPrice: 95,
      discountAmount: 0,
      amount: 95,
      kitchenStatus: 'READY',
    ),
    BillItemModel(
      itemId: 'IT4',
      orderId: 'SO1',
      lineNo: 4,
      productId: 'P4',
      productName: 'Mango Sticky Rice',
      quantity: 1,
      unit: 'plate',
      unitPrice: 130,
      discountAmount: 0,
      amount: 130,
      kitchenStatus: 'HELD',
      courseNo: 2,
    ),
  ],
  subtotal: 450,
  discountAmount: 0,
  serviceChargeRate: 10,
  serviceChargeAmount: 45,
  grandTotal: 495,
  previewToken: 'preview-001',
);

final _existingReservation = ReservationModel(
  reservationId: 'RES-EDIT',
  tableId: null,
  tableName: null,
  branchId: 'BR1',
  customerName: 'Khun Palm',
  customerPhone: '0811112222',
  reservationTime: DateTime(2026, 4, 22, 19, 30),
  partySize: 5,
  notes: 'Anniversary setup',
  status: 'CONFIRMED',
  sessionId: null,
  createdAt: DateTime(2026, 4, 22, 10, 0),
);

List<Map<String, dynamic>> _tableOverviewGoldenTables(String status) {
  final now = DateTime.now();
  return [
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB1',
      tableNo: 'A1',
      zoneId: 'ZN1',
      zoneName: 'Front',
      capacity: 4,
      status: status,
      currentOrderId: status == 'OCCUPIED' ? 'SO1' : null,
      activeSessionId: status == 'OCCUPIED' ? 'TS1' : null,
      activeGuestCount: status == 'OCCUPIED' ? 2 : null,
      sessionOpenedAt: status == 'OCCUPIED'
          ? now.subtract(const Duration(minutes: 35))
          : null,
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB2',
      tableNo: 'A2',
      zoneId: 'ZN1',
      zoneName: 'Front',
      capacity: 2,
      status: status,
      currentOrderId: status == 'OCCUPIED' ? 'SO2' : null,
      activeSessionId: status == 'OCCUPIED' ? 'TS2' : null,
      activeGuestCount: status == 'OCCUPIED' ? 2 : null,
      sessionOpenedAt: status == 'OCCUPIED'
          ? now.subtract(const Duration(minutes: 12))
          : null,
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB3',
      tableNo: 'B1',
      zoneId: 'ZN2',
      zoneName: 'Patio',
      capacity: 6,
      status: status,
      currentOrderId: status == 'OCCUPIED' ? 'SO3' : null,
      activeSessionId: status == 'OCCUPIED' ? 'TS3' : null,
      activeGuestCount: status == 'OCCUPIED' ? 4 : null,
      sessionOpenedAt: status == 'OCCUPIED'
          ? now.subtract(const Duration(hours: 1, minutes: 5))
          : null,
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB4',
      tableNo: 'B2',
      zoneId: 'ZN2',
      zoneName: 'Patio',
      capacity: 4,
      status: status,
      currentOrderId: status == 'OCCUPIED' ? 'SO4' : null,
      activeSessionId: status == 'OCCUPIED' ? 'TS4' : null,
      activeGuestCount: status == 'OCCUPIED' ? 3 : null,
      sessionOpenedAt: status == 'OCCUPIED'
          ? now.subtract(const Duration(minutes: 48))
          : null,
    ),
  ];
}

List<Map<String, dynamic>> _tableOverviewMixedGoldenTables() {
  final now = DateTime.now();
  return [
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB1',
      tableNo: 'A1',
      zoneId: 'ZN1',
      zoneName: 'Front',
      capacity: 4,
      status: 'AVAILABLE',
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB2',
      tableNo: 'A2',
      zoneId: 'ZN1',
      zoneName: 'Front',
      capacity: 2,
      status: 'OCCUPIED',
      currentOrderId: 'SO2',
      activeSessionId: 'TS2',
      activeGuestCount: 2,
      sessionOpenedAt: now.subtract(const Duration(minutes: 18)),
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB3',
      tableNo: 'B1',
      zoneId: 'ZN2',
      zoneName: 'Patio',
      capacity: 6,
      status: 'RESERVED',
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB4',
      tableNo: 'B2',
      zoneId: 'ZN2',
      zoneName: 'Patio',
      capacity: 4,
      status: 'CLEANING',
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB5',
      tableNo: 'C1',
      zoneId: 'ZN3',
      zoneName: 'VIP',
      capacity: 8,
      status: 'OCCUPIED',
      currentOrderId: 'SO5',
      activeSessionId: 'TS5',
      activeGuestCount: 5,
      sessionOpenedAt: now.subtract(const Duration(hours: 1, minutes: 10)),
    ),
    _FakeTableOverviewApiClient._buildTableJson(
      tableId: 'TB6',
      tableNo: 'C2',
      zoneId: 'ZN3',
      zoneName: 'VIP',
      capacity: 6,
      status: 'AVAILABLE',
    ),
  ];
}

List<Map<String, dynamic>> _tableOverviewGoldenZones() => const [
  {
    'zone_id': 'ZN1',
    'zone_name': 'Front',
    'branch_id': 'BR1',
    'display_order': 0,
    'is_active': true,
  },
  {
    'zone_id': 'ZN2',
    'zone_name': 'Patio',
    'branch_id': 'BR1',
    'display_order': 1,
    'is_active': true,
  },
  {
    'zone_id': 'ZN3',
    'zone_name': 'VIP',
    'branch_id': 'BR1',
    'display_order': 2,
    'is_active': true,
  },
];

Future<void> _pumpRestaurantApp(
  WidgetTester tester, {
  required Widget home,
  required ApiClient apiClient,
  Size size = const Size(1440, 1600),
  List overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        authProvider.overrideWith(_TestAuthNotifier.new),
        selectedBranchProvider.overrideWith(_TestSelectedBranchNotifier.new),
        ...overrides,
      ],
      child: MaterialApp(home: home),
    ),
  );
}

Future<void> _expectGolden(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$fileName'),
  );
}

void registerRestaurantTestSetup() {
  setUpAll(() async {
    await initializeDateFormatting('th');
  });
}

void registerReservationsTests() {
  group('Reservations provider tests', () {
    test(
      'reservation provider seat refreshes both reservations and tables',
      () async {
        final fakeApi = _FakeRestaurantApiClient();
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            authProvider.overrideWith(_TestAuthNotifier.new),
            selectedBranchProvider.overrideWith(
              _TestSelectedBranchNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(reservationsProvider.future);
        await container.read(tableListProvider.future);

        final result = await container
            .read(reservationsProvider.notifier)
            .seat('RES1', 'TB1', 'BR1');

        expect(result, isNotNull);
        expect(
          fakeApi.postCalls,
          contains('/api/tables/reservations/RES1/seat'),
        );
        expect(
          fakeApi.getCalls.where(
            (path) => path.startsWith('/api/tables/reservations?date='),
          ),
          hasLength(2),
        );
        expect(
          fakeApi.getCalls.where(
            (path) => path == '/api/tables/?branch_id=BR1',
          ),
          hasLength(2),
        );
      },
    );

    test('reservation provider appends search query to API request', () async {
      final fakeApi = _FakeRestaurantApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          authProvider.overrideWith(_TestAuthNotifier.new),
          selectedBranchProvider.overrideWith(_TestSelectedBranchNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      container.read(reservationSearchQueryProvider.notifier).state = 'mali';
      await container.read(reservationsProvider.future);

      expect(fakeApi.getCalls.last, contains('&query=mali'));
    });
  });

  group('Reservations widget tests', () {
    testWidgets(
      'reservations page shows busy overlay while confirming reservation',
      (tester) async {
        final fakeApi = _FakeRestaurantApiClient(
          confirmDelay: const Duration(milliseconds: 300),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
              authProvider.overrideWith(_TestAuthNotifier.new),
              selectedBranchProvider.overrideWith(
                _TestSelectedBranchNotifier.new,
              ),
            ],
            child: const MaterialApp(home: ReservationsPage()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('John'), findsOneWidget);
        await tester.tap(find.text('ยืนยัน'));
        await tester.pump();

        expect(find.text('กำลังอัปเดตการจอง...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('ยืนยันการจอง John แล้ว'), findsOneWidget);
      },
    );

    testWidgets('reservations page filters list by search query', (
      tester,
    ) async {
      final fakeApi = _FakeRestaurantApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const ReservationsPage(),
        apiClient: fakeApi,
      );

      await tester.pumpAndSettle();

      expect(find.text('John'), findsOneWidget);
      expect(find.text('Mali'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Mali');
      await tester.pumpAndSettle();

      expect(find.text('John'), findsNothing);
      expect(find.text('Mali'), findsNWidgets(2));
      expect(fakeApi.getCalls.last, contains('&query=Mali'));
    });

    testWidgets(
      'reservations page does not show success feedback when confirm fails',
      (tester) async {
        final fakeApi = _FakeRestaurantApiClient(confirmSucceeds: false);

        await _pumpRestaurantApp(
          tester,
          home: const ReservationsPage(),
          apiClient: fakeApi,
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('ยืนยัน'));
        await tester.pumpAndSettle();

        expect(find.text('ยืนยันการจอง John แล้ว'), findsNothing);
        expect(find.text('ยืนยันการจองไม่สำเร็จ'), findsOneWidget);
      },
    );
  });

  group('Reservations golden tests', () {
    testWidgets('reservations page empty state matches golden', (tester) async {
      final fakeApi = _FakeRestaurantApiClient(reservations: const []);

      await _pumpRestaurantApp(
        tester,
        home: const ReservationsPage(),
        apiClient: fakeApi,
        size: const Size(1280, 1600),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'reservations_page_empty.png');
    });

    testWidgets('reservations page list state matches golden', (tester) async {
      final fakeApi = _FakeRestaurantApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const ReservationsPage(),
        apiClient: fakeApi,
        size: const Size(1280, 1600),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'reservations_page_list.png');
    });

    testWidgets('reservations page loading overlay matches golden', (
      tester,
    ) async {
      const refreshDelay = Duration(milliseconds: 400);
      final fakeApi = _FakeRestaurantApiClient(refreshDelay: refreshDelay);

      await _pumpRestaurantApp(
        tester,
        home: const ReservationsPage(),
        apiClient: fakeApi,
        size: const Size(1280, 1600),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(find.text('กำลังรีเฟรชรายการจอง...'), findsOneWidget);
      await _expectGolden(tester, 'reservations_page_loading_overlay.png');
      await tester.pump(refreshDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('reservation form create state matches golden', (tester) async {
      final fakeApi = _FakeRestaurantApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const ReservationFormPage(),
        apiClient: fakeApi,
        size: const Size(1280, 1700),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'reservation_form_create.png');
    });

    testWidgets('reservation form edit state matches golden', (tester) async {
      final fakeApi = _FakeRestaurantApiClient();

      await _pumpRestaurantApp(
        tester,
        home: ReservationFormPage(existing: _existingReservation),
        apiClient: fakeApi,
        size: const Size(1280, 1700),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'reservation_form_edit.png');
    });
  });
}

void registerTablesTests() {
  group('Tables provider tests', () {
    test(
      'table provider refreshes with selected branch after update guest count',
      () async {
        final fakeApi = _FakeRestaurantApiClient();
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            authProvider.overrideWith(_TestAuthNotifier.new),
            selectedBranchProvider.overrideWith(
              _TestSelectedBranchNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(tableListProvider.future);
        final ok = await container
            .read(tableListProvider.notifier)
            .updateGuestCount('TB1', 4);

        expect(ok, isTrue);
        expect(
          fakeApi.postCalls,
          contains('/api/tables/TB1/update-guest-count'),
        );
        expect(
          fakeApi.getCalls.where(
            (path) => path == '/api/tables/?branch_id=BR1',
          ),
          hasLength(2),
        );
      },
    );
  });

  group('Tables widget tests', () {
    testWidgets('table overview open flow shows progress while opening table', (
      tester,
    ) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'AVAILABLE',
        returnActiveSession: false,
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
      );

      await tester.pumpAndSettle();

      expect(find.text('A1'), findsOneWidget);
      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();

      expect(find.text('เปิดโต๊ะ'), findsWidgets);
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();
      await tester.tap(find.text('เปิดโต๊ะ').last);
      await tester.pump();

      expect(find.text('กำลังเปิด...'), findsOneWidget);
      expect(fakeApi.postCalls, contains('/api/tables/TB1/open'));

      await tester.pump(_FakeTableOverviewApiClient.actionDelay);
      await tester.pumpAndSettle();

      expect(find.text('กำลังเปิด...'), findsNothing);
      expect(find.text('เปิดโต๊ะ'), findsNothing);
    });

    testWidgets('table overview does not open cleaning table flow', (
      tester,
    ) async {
      final fakeApi = _FakeTableOverviewApiClient(initialStatus: 'CLEANING');

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();

      expect(find.text('เปิดโต๊ะ'), findsNothing);
      expect(fakeApi.postCalls, isEmpty);
    });

    testWidgets(
      'table overview keeps open dialog visible and avoids success feedback on open failure',
      (tester) async {
        final fakeApi = _FakeTableOverviewApiClient(
          initialStatus: 'AVAILABLE',
          openSucceeds: false,
          returnActiveSession: false,
        );

        await _pumpRestaurantApp(
          tester,
          home: const TableOverviewPage(),
          apiClient: fakeApi,
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('A1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เปิดโต๊ะ').last);
        await tester.pump();
        await tester.pump(_FakeTableOverviewApiClient.actionDelay);
        await tester.pumpAndSettle();

        expect(
          find.text('เปิดโต๊ะไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          findsOneWidget,
        );
        expect(find.text('เปิดโต๊ะ A1 แล้ว'), findsNothing);
      },
    );

    testWidgets(
      'table overview close flow shows overlay and success feedback',
      (tester) async {
        final fakeApi = _FakeTableOverviewApiClient(initialStatus: 'OCCUPIED');

        await _pumpRestaurantApp(
          tester,
          home: const TableOverviewPage(),
          apiClient: fakeApi,
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('A1').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ปิดโต๊ะ'));
        await tester.pumpAndSettle();
        expect(find.text('ยืนยันการปิดโต๊ะ'), findsOneWidget);
        await tester.tap(find.text('ปิดโต๊ะ').last);
        await tester.pump();

        expect(find.byType(BusyOverlay), findsOneWidget);
        expect(find.text('กำลังปิดโต๊ะ A1...'), findsOneWidget);

        await tester.pump(_FakeTableOverviewApiClient.actionDelay);
        await tester.pumpAndSettle();

        expect(find.text('ปิดโต๊ะ A1 แล้ว'), findsOneWidget);
      },
    );

    testWidgets('table overview close flow surfaces backend failure message', (
      tester,
    ) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'OCCUPIED',
        closeSucceeds: false,
        closeFailureMessage:
            'ไม่สามารถปิดโต๊ะได้ เนื่องจากยังมี order ที่เปิดอยู่',
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ปิดโต๊ะ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ปิดโต๊ะ').last);
      await tester.pump();
      await tester.pump(_FakeTableOverviewApiClient.actionDelay);
      await tester.pumpAndSettle();

      expect(
        find.text('ไม่สามารถปิดโต๊ะได้ เนื่องจากยังมี order ที่เปิดอยู่'),
        findsOneWidget,
      );
    });

    testWidgets(
      'table overview guest count flow shows overlay and updated success message',
      (tester) async {
        final fakeApi = _FakeTableOverviewApiClient(initialStatus: 'OCCUPIED');

        await _pumpRestaurantApp(
          tester,
          home: const TableOverviewPage(),
          apiClient: fakeApi,
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('A1').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('อัปเดตจำนวนลูกค้า'));
        await tester.pumpAndSettle();

        expect(find.text('จำนวนลูกค้า — A1'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
        await tester.tap(find.text('บันทึก'));
        await tester.pump();

        expect(find.text('กำลังอัปเดตจำนวนลูกค้า...'), findsOneWidget);

        await tester.pump(_FakeTableOverviewApiClient.actionDelay);
        await tester.pumpAndSettle();

        expect(find.text('อัปเดตจำนวนลูกค้าเป็น 3 คนแล้ว'), findsOneWidget);
      },
    );
  });

  group('Tables golden tests', () {
    testWidgets('table overview available state matches golden', (
      tester,
    ) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'AVAILABLE',
        tables: _tableOverviewGoldenTables('AVAILABLE'),
        zones: _tableOverviewGoldenZones(),
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1800),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'table_overview_available.png');
    });

    testWidgets('table overview occupied state matches golden', (tester) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'OCCUPIED',
        tables: _tableOverviewGoldenTables('OCCUPIED'),
        zones: _tableOverviewGoldenZones(),
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1800),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'table_overview_occupied.png');
    });

    testWidgets('table overview cleaning state matches golden', (tester) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'CLEANING',
        tables: _tableOverviewGoldenTables('CLEANING'),
        zones: _tableOverviewGoldenZones(),
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1800),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'table_overview_cleaning.png');
    });

    testWidgets('table overview mixed states matches golden', (tester) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'AVAILABLE',
        tables: _tableOverviewMixedGoldenTables(),
        zones: _tableOverviewGoldenZones(),
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1900),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'table_overview_mixed_states.png');
    });

    testWidgets('table overview open dialog matches golden', (tester) async {
      final fakeApi = _FakeTableOverviewApiClient(
        initialStatus: 'AVAILABLE',
        returnActiveSession: false,
      );

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1700),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();

      await _expectGolden(tester, 'table_overview_open_dialog.png');
    });

    testWidgets('table overview guest count dialog matches golden', (
      tester,
    ) async {
      final fakeApi = _FakeTableOverviewApiClient(initialStatus: 'OCCUPIED');

      await _pumpRestaurantApp(
        tester,
        home: const TableOverviewPage(),
        apiClient: fakeApi,
        size: const Size(1440, 1700),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('อัปเดตจำนวนลูกค้า'));
      await tester.pumpAndSettle();

      await _expectGolden(tester, 'table_overview_guest_count_dialog.png');
    });

    testWidgets('table timeline page loaded matches golden', (tester) async {
      final fakeApi = _FakeRestaurantDetailApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const TableTimelinePage(tableId: 'TB1', tableName: 'A1'),
        apiClient: fakeApi,
        size: const Size(1280, 1800),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'table_timeline_loaded.png');
    });
  });
}

void registerBillingTests() {
  group('Billing widget tests', () {
    testWidgets('billing page fires held course and shows success feedback', (
      tester,
    ) async {
      final fakeApi = _FakeBillingApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const BillingPage(tableContext: _billingContext),
        apiClient: fakeApi,
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              SettingsState(defaultServiceChargeRate: 10),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.text('Course 2 — รอ Fire'), findsOneWidget);
      await tester.tap(find.text('Fire Course 2'));
      await tester.pumpAndSettle();

      expect(fakeApi.postCalls, contains('/api/tables/TB1/fire-course'));
      expect(
        find.text('Fire Course 2 แล้ว — ส่งครัวเรียบร้อย'),
        findsOneWidget,
      );
    });

    testWidgets('billing page shows error state when bill load fails', (
      tester,
    ) async {
      final fakeApi = _FakeBillingApiClient(failBillLoad: true);

      await _pumpRestaurantApp(
        tester,
        home: const BillingPage(tableContext: _billingContext),
        apiClient: fakeApi,
      );

      await tester.pumpAndSettle();

      expect(find.text('โหลดบิลไม่สำเร็จ'), findsOneWidget);
      expect(find.textContaining('Bill service unavailable'), findsOneWidget);
      expect(find.text('ลองใหม่'), findsOneWidget);
    });

    testWidgets('billing page void flow submits reason and manager pin', (
      tester,
    ) async {
      final fakeApi = _FakeBillingApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const BillingPage(tableContext: _billingContext),
        apiClient: fakeApi,
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              SettingsState(defaultServiceChargeRate: 10, managerPin: '2468'),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.text('Pad Thai'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      final dialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogFields.at(0), 'Customer changed mind');
      await tester.enterText(dialogFields.at(1), '2468');
      await tester.tap(find.text('ยืนยันยกเลิก'));
      await tester.pumpAndSettle();

      expect(fakeApi.putCalls, contains('/api/kitchen/items/IT1/status'));
      expect(find.text('ยกเลิกรายการ Pad Thai แล้ว'), findsOneWidget);
      expect(find.text('Pad Thai'), findsNothing);
    });
  });

  group('Billing golden tests', () {
    testWidgets('billing page void dialog matches golden', (tester) async {
      final fakeApi = _FakeBillingApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const BillingPage(tableContext: _billingContext),
        apiClient: fakeApi,
        size: const Size(1280, 1700),
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              SettingsState(defaultServiceChargeRate: 10, managerPin: '2468'),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      await _expectGolden(tester, 'billing_page_void_dialog.png');
    });

    testWidgets('split bill page equal preview matches golden', (tester) async {
      final fakeApi = _FakeRestaurantDetailApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const SplitBillPage(
          bill: _splitBillGoldenBill,
          tableContext: _billingContext,
        ),
        apiClient: fakeApi,
        size: const Size(1280, 1800),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('ดูตัวอย่างบิลแยก'));
      await tester.pumpAndSettle();

      expect(find.text('ยืนยันสร้างบิลแยก'), findsOneWidget);
      await _expectGolden(tester, 'split_bill_equal_preview.png');
    });

    testWidgets('split bill page item quantity editor matches golden', (
      tester,
    ) async {
      final fakeApi = _FakeRestaurantDetailApiClient();
      const quantityBill = BillModel(
        sessionId: 'TS1',
        tableId: 'TB1',
        guestCount: 2,
        openedAt: null,
        orderIds: ['SO1'],
        items: [
          BillItemModel(
            itemId: 'IT1',
            orderId: 'SO1',
            lineNo: 1,
            productId: 'P1',
            productName: 'Pad Thai',
            quantity: 2,
            unit: 'plate',
            unitPrice: 120,
            discountAmount: 0,
            amount: 240,
            kitchenStatus: 'PENDING',
          ),
          BillItemModel(
            itemId: 'IT2',
            orderId: 'SO1',
            lineNo: 2,
            productId: 'P2',
            productName: 'Tom Yum Soup',
            quantity: 1,
            unit: 'bowl',
            unitPrice: 105,
            discountAmount: 0,
            amount: 105,
            kitchenStatus: 'PENDING',
          ),
        ],
        subtotal: 345,
        discountAmount: 0,
        serviceChargeRate: 10,
        serviceChargeAmount: 34.5,
        grandTotal: 379.5,
        previewToken: 'preview-qty-golden',
      );

      await _pumpRestaurantApp(
        tester,
        home: const SplitBillPage(
          bill: quantityBill,
          tableContext: _billingContext,
        ),
        apiClient: fakeApi,
        size: const Size(1280, 1900),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('แยกรายการ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('เพิ่ม Pad Thai คน 1'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Pad Thai คน 2'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Tom Yum Soup คน 1'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Tom Yum Soup คน 1'));
      await tester.pumpAndSettle();

      await _expectGolden(tester, 'split_bill_item_quantity_editor.png');
    });

    testWidgets('split bill page item split result matches golden', (
      tester,
    ) async {
      final fakeApi = _FakeRestaurantDetailApiClient();
      const quantityBill = BillModel(
        sessionId: 'TS1',
        tableId: 'TB1',
        guestCount: 2,
        openedAt: null,
        orderIds: ['SO1'],
        items: [
          BillItemModel(
            itemId: 'IT1',
            orderId: 'SO1',
            lineNo: 1,
            productId: 'P1',
            productName: 'Pad Thai',
            quantity: 2,
            unit: 'plate',
            unitPrice: 120,
            discountAmount: 0,
            amount: 240,
            kitchenStatus: 'PENDING',
          ),
          BillItemModel(
            itemId: 'IT2',
            orderId: 'SO1',
            lineNo: 2,
            productId: 'P2',
            productName: 'Tom Yum Soup',
            quantity: 1,
            unit: 'bowl',
            unitPrice: 105,
            discountAmount: 0,
            amount: 105,
            kitchenStatus: 'PENDING',
          ),
        ],
        subtotal: 345,
        discountAmount: 0,
        serviceChargeRate: 10,
        serviceChargeAmount: 34.5,
        grandTotal: 379.5,
        previewToken: 'preview-qty-golden',
      );

      await _pumpRestaurantApp(
        tester,
        home: const SplitBillPage(
          bill: quantityBill,
          tableContext: _billingContext,
        ),
        apiClient: fakeApi,
        size: const Size(1280, 1900),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('แยกรายการ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('เพิ่ม Pad Thai คน 1'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Pad Thai คน 2'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Tom Yum Soup คน 1'));
      await tester.pump();
      await tester.tap(find.byTooltip('เพิ่ม Tom Yum Soup คน 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สร้างบิลแยก'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('คน 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('คน 2').last);
      await tester.pumpAndSettle();

      await _expectGolden(tester, 'split_bill_item_result.png');
    });

    testWidgets('billing page loaded matches golden', (tester) async {
      final fakeApi = _FakeBillingApiClient();

      await _pumpRestaurantApp(
        tester,
        home: const BillingPage(tableContext: _billingContext),
        apiClient: fakeApi,
        size: const Size(1280, 1600),
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              SettingsState(defaultServiceChargeRate: 10),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'billing_page_loaded.png');
    });
  });
}

void registerKitchenTests() {
  group('Kitchen widget tests', () {
    testWidgets('kitchen display shows feedback when fire course fails', (
      tester,
    ) async {
      final fakeApi = _FakeKitchenApiClient(
        includeItems: true,
        failFireCourse: true,
      );

      await _pumpRestaurantApp(
        tester,
        home: const KitchenDisplayPage(),
        apiClient: fakeApi,
        size: const Size(1600, 1000),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('รอ fire').first);
      await tester.pumpAndSettle();

      expect(find.text('Fire course 2 ไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('kitchen display updates status and switches station tabs', (
      tester,
    ) async {
      final fakeApi = _FakeKitchenApiClient(includeItems: true);

      await _pumpRestaurantApp(
        tester,
        home: const KitchenDisplayPage(),
        apiClient: fakeApi,
        size: const Size(1600, 1000),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pad Thai'), findsOneWidget);
      expect(find.text('Latte'), findsOneWidget);

      await tester.tap(find.text('เริ่มทำ').first);
      await tester.pumpAndSettle();

      expect(fakeApi.putCalls, contains('/api/kitchen/items/KI1/status'));
      expect(find.text('พร้อมเสิร์ฟ'), findsWidgets);

      await tester.tap(find.text('บาร์'));
      await tester.pumpAndSettle();

      expect(
        fakeApi.getCalls,
        contains(
          '/api/kitchen/queue?status=PENDING,PREPARING,READY,HELD&branch_id=BR1&station=bar',
        ),
      );
      expect(find.text('Latte'), findsOneWidget);
      expect(find.text('Pad Thai'), findsNothing);
    });

    testWidgets(
      'kitchen display swipe between tabs refreshes station-specific queue',
      (tester) async {
        final fakeApi = _FakeKitchenApiClient(includeItems: true);

        await _pumpRestaurantApp(
          tester,
          home: const KitchenDisplayPage(),
          apiClient: fakeApi,
          size: const Size(1600, 1000),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('ครัว'));
        await tester.pumpAndSettle();
        expect(
          fakeApi.getCalls,
          contains(
            '/api/kitchen/queue?status=PENDING,PREPARING,READY,HELD&branch_id=BR1&station=kitchen',
          ),
        );

        await tester.drag(find.byType(TabBarView), const Offset(-1200, 0));
        await tester.pumpAndSettle();

        expect(
          fakeApi.getCalls,
          contains(
            '/api/kitchen/queue?status=PENDING,PREPARING,READY,HELD&branch_id=BR1&station=bar',
          ),
        );
        expect(find.text('Latte'), findsOneWidget);
        expect(find.text('Pad Thai'), findsNothing);
      },
    );

    testWidgets('kitchen display shows feedback when status update fails', (
      tester,
    ) async {
      final fakeApi = _FakeKitchenApiClient(
        includeItems: true,
        failStatusUpdate: true,
      );

      await _pumpRestaurantApp(
        tester,
        home: const KitchenDisplayPage(),
        apiClient: fakeApi,
        size: const Size(1600, 1000),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('เริ่มทำ').first);
      await tester.pumpAndSettle();

      expect(find.text('อัปเดตสถานะรายการในครัวไม่สำเร็จ'), findsOneWidget);
    });
  });

  group('Kitchen golden tests', () {
    testWidgets('kitchen display empty state matches golden', (tester) async {
      final fakeApi = _FakeKitchenApiClient(includeItems: false);

      await _pumpRestaurantApp(
        tester,
        home: const KitchenDisplayPage(),
        apiClient: fakeApi,
        size: const Size(1600, 1000),
      );

      await tester.pumpAndSettle();
      await _expectGolden(tester, 'kitchen_display_empty.png');
    });
  });
}
