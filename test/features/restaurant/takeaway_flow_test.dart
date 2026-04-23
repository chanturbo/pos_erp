import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/core/client/api_client.dart';
import 'package:pos_erp/features/auth/data/models/user_model.dart';
import 'package:pos_erp/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_erp/features/branches/data/models/branch_model.dart';
import 'package:pos_erp/features/branches/presentation/providers/branch_provider.dart';
import 'package:pos_erp/features/restaurant/data/models/restaurant_order_context.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/takeaway_orders_page.dart';
import 'package:pos_erp/features/sales/presentation/pages/payment_page.dart';
import 'package:pos_erp/features/sales/presentation/providers/cart_provider.dart';
import 'package:pos_erp/shared/services/app_alert_service.dart';

class _FakeTakeawayApiClient extends ApiClient {
  _FakeTakeawayApiClient() : super(baseUrl: 'http://localhost');

  final List<String> getCalls = [];
  final List<String> postCalls = [];
  late final List<Map<String, dynamic>> _sales;

  List<Map<String, dynamic>> _seedSales() {
    final now = DateTime.now();
    return [
      {
        'order_id': 'SO-TK-1',
        'order_no': 'TK-001',
        'order_date': DateTime(
          now.year,
          now.month,
          now.day,
          10,
          30,
        ).toIso8601String(),
        'customer_id': 'CUS1',
        'customer_name': 'ลูกค้าหน้าร้าน',
        'total_amount': 150,
        'discount_amount': 0,
        'payment_type': 'PENDING',
        'status': 'OPEN',
        'table_id': null,
        'session_id': null,
        'service_type': 'TAKEAWAY',
        'party_size': 1,
      },
      {
        'order_id': 'SO-DINE-1',
        'order_no': 'DN-001',
        'order_date': DateTime(
          now.year,
          now.month,
          now.day,
          10,
          0,
        ).toIso8601String(),
        'customer_id': 'CUS2',
        'customer_name': 'โต๊ะ A1',
        'total_amount': 220,
        'discount_amount': 0,
        'payment_type': 'PENDING',
        'status': 'OPEN',
        'table_id': 'TB1',
        'session_id': 'TS1',
        'service_type': 'DINE_IN',
        'party_size': 2,
      },
      {
        'order_id': 'SO-TK-2',
        'order_no': 'TK-002',
        'order_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'customer_id': 'CUS3',
        'customer_name': 'ลูกค้าปิดบิลแล้ว',
        'total_amount': 99,
        'discount_amount': 0,
        'payment_type': 'CASH',
        'status': 'COMPLETED',
        'table_id': null,
        'session_id': null,
        'service_type': 'TAKEAWAY',
        'party_size': 1,
      },
      {
        'order_id': 'SO-TK-3',
        'order_no': 'TK-003',
        'order_date': DateTime(
          now.year,
          now.month,
          now.day,
          9,
          45,
        ).toIso8601String(),
        'customer_id': 'CUS4',
        'customer_name': 'ลูกค้ายอดสูง',
        'total_amount': 320,
        'discount_amount': 0,
        'payment_type': 'PENDING',
        'status': 'OPEN',
        'table_id': null,
        'session_id': null,
        'service_type': 'TAKEAWAY',
        'party_size': 1,
      },
      {
        'order_id': 'SO-TK-4',
        'order_no': 'TK-004',
        'order_date': DateTime(
          now.year,
          now.month,
          now.day,
          8,
          30,
        ).toIso8601String(),
        'customer_id': 'CUS5',
        'customer_name': 'ลูกค้ายกเลิกแล้ว',
        'total_amount': 80,
        'discount_amount': 0,
        'payment_type': 'VOID',
        'status': 'CANCELLED',
        'table_id': null,
        'session_id': null,
        'service_type': 'TAKEAWAY',
        'party_size': 1,
      },
    ];
  }

  void addOpenTakeawayOrder({
    required String orderId,
    required String orderNo,
    required String customerName,
    required double totalAmount,
  }) {
    final now = DateTime.now();
    _sales.insert(0, {
      'order_id': orderId,
      'order_no': orderNo,
      'order_date': now.toIso8601String(),
      'customer_id': 'CUS-NEW',
      'customer_name': customerName,
      'total_amount': totalAmount,
      'discount_amount': 0,
      'payment_type': 'PENDING',
      'status': 'OPEN',
      'table_id': null,
      'session_id': null,
      'service_type': 'TAKEAWAY',
      'party_size': 1,
    });
  }

  factory _FakeTakeawayApiClient.seeded() {
    final client = _FakeTakeawayApiClient();
    client._sales = client._seedSales();
    return client;
  }

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path == '/api/sales') {
      return _response(path, 200, {'success': true, 'data': _sales});
    }

    if (path == '/api/sales/SO-TK-1') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_id': 'SO-TK-1',
          'order_no': 'TK-001',
          'order_date': DateTime(2026, 4, 23, 10, 30).toIso8601String(),
          'customer_id': 'CUS1',
          'customer_name': 'ลูกค้าหน้าร้าน',
          'subtotal': 150,
          'discount_amount': 0,
          'coupon_discount': 0,
          'table_id': null,
          'session_id': null,
          'service_type': 'TAKEAWAY',
          'party_size': 1,
          'service_charge_rate': 0,
          'service_charge_amount': 0,
          'total_amount': 150,
          'payment_type': 'PENDING',
          'paid_amount': 0,
          'change_amount': 0,
          'points_used': 0,
          'status': 'OPEN',
          'items': [
            {
              'item_id': 'IT-TK-1',
              'order_id': 'SO-TK-1',
              'line_no': 1,
              'product_id': 'P1',
              'product_code': 'P1',
              'product_name': 'Pad Thai',
              'unit': 'plate',
              'quantity': 1,
              'unit_price': 150,
              'amount': 150,
              'discount_amount': 0,
              'special_instructions': null,
              'course_no': 1,
              'kitchen_status': 'PENDING',
              'modifiers': const [],
              'is_free_item': false,
            },
          ],
        },
      });
    }

    if (path == '/api/customers/CUS1') {
      return _response(path, 200, {
        'success': true,
        'data': {'customer_id': 'CUS1', 'points': 12},
      });
    }

    if (path == '/api/customers' || path.startsWith('/api/customers?')) {
      return _response(path, 200, {
        'data': const <Map<String, dynamic>>[],
        'pagination': const {'total': 0, 'has_more': false},
      });
    }

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);

    if (path == '/api/sales/SO-TK-1/complete') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_no': 'TK-001',
          'order_id': 'SO-TK-1',
          'earned_points': 0,
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
      createdAt: DateTime(2026, 4, 23),
      updatedAt: DateTime(2026, 4, 23),
    );
  }
}

class _TestSelectedWarehouseNotifier extends SelectedWarehouseNotifier {
  @override
  WarehouseModel? build() {
    return WarehouseModel(
      warehouseId: 'WH1',
      warehouseCode: 'WH1',
      warehouseName: 'Main Warehouse',
      branchId: 'BR1',
      createdAt: DateTime(2026, 4, 23),
    );
  }
}

class _SeededCartNotifier extends CartNotifier {
  _SeededCartNotifier(this._state);

  final CartState _state;

  @override
  CartState build() => _state;
}

class _FakeAppAlertService extends AppAlertService {
  _FakeAppAlertService() : super(enableAudio: false);

  int takeawayAlertCount = 0;
  int kitchenAlertCount = 0;

  @override
  Future<void> playTakeawayNewOrderAlert() async {
    takeawayAlertCount++;
  }

  @override
  Future<void> playKitchenAlert() async {
    kitchenAlertCount++;
  }

  @override
  Future<void> dispose() async {}
}

ProviderContainer _createContainer({
  required ApiClient apiClient,
  CartState? cartState,
  RestaurantOrderContext? restaurantContext,
  AppAlertService? alertService,
}) {
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      authProvider.overrideWith(_TestAuthNotifier.new),
      selectedBranchProvider.overrideWith(_TestSelectedBranchNotifier.new),
      selectedWarehouseProvider.overrideWith(
        _TestSelectedWarehouseNotifier.new,
      ),
      if (cartState != null)
        cartProvider.overrideWith(() => _SeededCartNotifier(cartState)),
      if (restaurantContext != null)
        restaurantOrderContextProvider.overrideWith((ref) => restaurantContext),
      if (alertService != null)
        appAlertServiceProvider.overrideWithValue(alertService),
    ],
  );
}

Future<void> _pumpWithContainer(
  WidgetTester tester, {
  required ProviderContainer container,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  group('Takeaway flow tests', () {
    testWidgets('takeaway orders page shows only open takeaway orders', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(apiClient: fakeApi);

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();

      expect(find.text('TK-001'), findsOneWidget);
      expect(find.text('ลูกค้าหน้าร้าน'), findsOneWidget);
      expect(find.text('DN-001'), findsNothing);
      expect(find.text('TK-002'), findsNothing);
      expect(find.text('TK-003'), findsOneWidget);
    });

    testWidgets('takeaway orders page supports search and today filter', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(apiClient: fakeApi);

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ลูกค้าหน้าร้าน');
      await tester.pumpAndSettle();

      expect(find.text('TK-001'), findsOneWidget);
      expect(find.text('พบ 1 รายการ'), findsOneWidget);

      await tester.tap(find.text('วันนี้'));
      await tester.pumpAndSettle();

      expect(find.text('TK-001'), findsOneWidget);
      expect(find.text('TK-002'), findsNothing);
    });

    testWidgets('takeaway orders page supports sort by highest amount', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(apiClient: fakeApi);

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('ล่าสุด').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยอดสูงสุด').last);
      await tester.pumpAndSettle();

      final orderNos = find.textContaining('TK-');
      expect(orderNos.at(0), findsOneWidget);
      expect(find.text('TK-003'), findsWidgets);
      expect(
        tester.getTopLeft(find.text('TK-003').first).dy,
        lessThan(tester.getTopLeft(find.text('TK-001').first).dy),
      );
    });

    testWidgets('takeaway orders page supports filtering by status', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(apiClient: fakeApi);

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();

      expect(find.text('TK-001'), findsOneWidget);
      expect(find.text('TK-002'), findsNothing);
      expect(find.text('TK-004'), findsNothing);

      await tester.tap(find.text('OPEN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('COMPLETED').last);
      await tester.pumpAndSettle();

      expect(find.text('TK-002'), findsOneWidget);
      expect(find.text('TK-001'), findsNothing);
      expect(find.text('TK-004'), findsNothing);

      await tester.tap(find.text('COMPLETED').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELLED').last);
      await tester.pumpAndSettle();

      expect(find.text('TK-004'), findsOneWidget);
      expect(find.text('TK-002'), findsNothing);
    });

    testWidgets('new open takeaway orders show highlight and notification', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final fakeAlertService = _FakeAppAlertService();
      final container = _createContainer(
        apiClient: fakeApi,
        alertService: fakeAlertService,
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();
      expect(find.text('บิลใหม่'), findsNothing);

      fakeApi.addOpenTakeawayOrder(
        orderId: 'SO-TK-NEW',
        orderNo: 'TK-099',
        customerName: 'ลูกค้าใหม่',
        totalAmount: 199,
      );

      await tester.tap(find.byTooltip('รีเฟรช'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('TK-099'), findsOneWidget);
      expect(find.text('บิลใหม่'), findsOneWidget);
      expect(
        find.textContaining('มีบิลซื้อกลับบ้านใหม่: TK-099'),
        findsOneWidget,
      );
      expect(fakeAlertService.takeawayAlertCount, 1);
    });

    testWidgets('auto refresh picks up new takeaway orders and plays alert', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final fakeAlertService = _FakeAppAlertService();
      final container = _createContainer(
        apiClient: fakeApi,
        alertService: fakeAlertService,
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(
          pollingIntervalOverride: Duration(milliseconds: 200),
        ),
      );

      await tester.pumpAndSettle();

      fakeApi.addOpenTakeawayOrder(
        orderId: 'SO-TK-AUTO',
        orderNo: 'TK-100',
        customerName: 'ลูกค้า polling',
        totalAmount: 245,
      );

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('TK-100'), findsOneWidget);
      expect(
        find.textContaining('มีบิลซื้อกลับบ้านใหม่: TK-100'),
        findsOneWidget,
      );
      expect(fakeAlertService.takeawayAlertCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    testWidgets('tap pending takeaway order opens billing page by order id', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(apiClient: fakeApi);

      await _pumpWithContainer(
        tester,
        container: container,
        child: const TakeawayOrdersPage(enableAutoRefresh: false),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('TK-001'));
      await tester.pumpAndSettle();

      expect(fakeApi.getCalls, contains('/api/sales/SO-TK-1'));
      expect(find.text('Pad Thai'), findsOneWidget);
      expect(find.text('รวมโต๊ะ'), findsNothing);
      expect(find.text('แยกบิล'), findsNothing);
    });

    testWidgets('takeaway payment completes without table endpoints', (
      tester,
    ) async {
      final fakeApi = _FakeTakeawayApiClient.seeded();
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: [
            CartItem(
              productId: 'P1',
              productCode: 'P1',
              productName: 'Pad Thai',
              unit: 'plate',
              quantity: 1,
              unitPrice: 150,
              amount: 150,
              priceLevel1: 150,
            ),
          ],
          customerId: 'CUS1',
          customerName: 'ลูกค้าหน้าร้าน',
          customerPriceLevel: 1,
        ),
        restaurantContext:
            RestaurantOrderContext.takeaway(
              branchId: 'BR1',
              currentOrderId: 'SO-TK-1',
              currentOrderNo: 'TK-001',
            ).copyWith(
              subtotalOverride: 150,
              totalOverride: 150,
              serviceChargeOverride: 0,
              discountOverride: 0,
              paymentTitle: 'ชำระบิลซื้อกลับบ้าน',
              currentOrderIds: const ['SO-TK-1'],
            ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: const PaymentPage(),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('ชำระเงิน').first);
      await tester.pumpAndSettle();

      expect(fakeApi.postCalls, contains('/api/sales/SO-TK-1/complete'));
      expect(
        fakeApi.getCalls.where((call) => call.startsWith('/api/tables/')),
        isEmpty,
      );
      expect(
        fakeApi.postCalls.where((call) => call.startsWith('/api/tables/')),
        isEmpty,
      );
      expect(find.text('เปิดบิลใหม่'), findsOneWidget);
    });
  });
}
