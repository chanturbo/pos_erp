import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/core/client/api_client.dart';
import 'package:pos_erp/features/auth/data/models/user_model.dart';
import 'package:pos_erp/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_erp/features/branches/data/models/branch_model.dart';
import 'package:pos_erp/features/branches/presentation/providers/branch_provider.dart';
import 'package:pos_erp/features/restaurant/data/models/bill_model.dart';
import 'package:pos_erp/features/restaurant/data/models/restaurant_order_context.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/billing_page.dart';
import 'package:pos_erp/features/restaurant/presentation/pages/split_bill_page.dart';
import 'package:pos_erp/features/sales/presentation/pages/payment_page.dart';
import 'package:pos_erp/features/sales/presentation/providers/cart_provider.dart';

class _FakePaymentSplitApiClient extends ApiClient {
  _FakePaymentSplitApiClient({
    this.closeSucceeds = true,
    this.closeFailureMessage = 'ยังไม่สามารถปิดโต๊ะอัตโนมัติได้',
    this.billItems,
  }) : super(baseUrl: 'http://localhost');

  final bool closeSucceeds;
  final String closeFailureMessage;
  final List<Map<String, dynamic>>? billItems;
  final List<String> getCalls = [];
  final List<String> postCalls = [];
  final Map<String, dynamic> postPayloads = {};

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(path);

    if (path == '/api/tables/TB1/bill') {
      final currentBillItems =
          billItems ??
          [
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
              'special_instructions': null,
              'modifiers': const [],
            },
          ];
      final subtotal = currentBillItems.fold<double>(
        0,
        (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
      );
      return _response(path, 200, {
        'success': true,
        'data': {
          'session_id': 'TS1',
          'table_id': 'TB1',
          'guest_count': 2,
          'opened_at': DateTime(2026, 4, 20, 12, 0).toIso8601String(),
          'customer_id': 'CUS1',
          'customer_name': 'สมาชิกทอง',
          'order_ids': ['SO-SPLIT-1'],
          'items': currentBillItems,
          'subtotal': subtotal,
          'discount_amount': 0,
          'service_charge_rate': 0,
          'service_charge_amount': 0,
          'grand_total': subtotal,
        },
      });
    }

    if (path == '/api/customers' || path.startsWith('/api/customers?')) {
      return _response(path, 200, {
        'data': const <Map<String, dynamic>>[],
        'pagination': const {'total': 0, 'has_more': false},
      });
    }

    if (path == '/api/customers/CUS1') {
      return _response(path, 200, {
        'success': true,
        'data': {'customer_id': 'CUS1', 'points': 10},
      });
    }

    if (path == '/api/sales/SO-TAKEAWAY-1') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_id': 'SO-TAKEAWAY-1',
          'order_no': 'TK-001',
          'order_date': DateTime(2026, 4, 20, 12, 0).toIso8601String(),
          'customer_id': 'CUS1',
          'customer_name': 'สมาชิกทอง',
          'subtotal': 150,
          'discount_amount': 0,
          'coupon_discount': 0,
          'coupon_codes': const <String>[],
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
              'order_id': 'SO-TAKEAWAY-1',
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

    throw UnimplementedError('Unhandled GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    postCalls.add(path);
    if (data is Map<String, dynamic>) {
      postPayloads[path] = data;
    }

    if (path == '/api/tables/TB1/bill/split') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'mode': 'equal',
          'count': 2,
          'grand_total': 240,
          'per_person': 120,
          'preview_token': 'preview-001',
          'splits': [
            {
              'label': 'คน 1',
              'subtotal': 120,
              'discount_amount': 0,
              'service_charge': 0,
              'total': 120,
              'order_ids': const <String>[],
              'items': [
                {
                  'item_id': 'IT1',
                  'product_id': 'P1',
                  'product_code': 'P1',
                  'product_name': 'Pad Thai',
                  'unit': 'plate',
                  'quantity': 1,
                  'unit_price': 120,
                  'amount': 120,
                },
              ],
            },
            {
              'label': 'คน 2',
              'subtotal': 120,
              'discount_amount': 0,
              'service_charge': 0,
              'total': 120,
              'order_ids': const <String>[],
              'items': [
                {
                  'item_id': 'IT2',
                  'product_id': 'P2',
                  'product_code': 'P2',
                  'product_name': 'Tom Yum Soup',
                  'unit': 'bowl',
                  'quantity': 1,
                  'unit_price': 120,
                  'amount': 120,
                },
              ],
            },
          ],
        },
      });
    }

    if (path == '/api/tables/TB1/bill/split/apply') {
      final body = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final splits =
          (body['splits'] as List?)
              ?.map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList() ??
          const <Map<String, dynamic>>[];
      final itemMode =
          splits.isNotEmpty &&
          splits.any(
            (split) => (split['items'] as List? ?? const []).isNotEmpty,
          );
      if (itemMode) {
        final generatedSplits = splits.asMap().entries.map((entry) {
          final index = entry.key;
          final split = entry.value;
          final splitItems = (split['items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          final detailedItems = splitItems.map((item) {
            final itemId = item['item_id'] as String;
            final quantity = (item['quantity'] as num).toDouble();
            final source = _bill.items.firstWhere(
              (billItem) => billItem.itemId == itemId,
            );
            final ratio = quantity / source.quantity;
            return {
              'item_id': itemId,
              'product_id': source.productId,
              'product_code': source.productId,
              'product_name': source.productName,
              'unit': source.unit,
              'quantity': quantity,
              'unit_price': source.unitPrice,
              'amount': source.amount * ratio,
            };
          }).toList();
          final subtotal = detailedItems.fold<double>(
            0,
            (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
          );
          return {
            'label': split['label'] as String? ?? 'คน ${index + 1}',
            'subtotal': subtotal,
            'discount_amount': 0,
            'service_charge': 0,
            'total': subtotal,
            'order_ids': ['SO-SPLIT-${index + 1}'],
            'items': detailedItems,
          };
        }).toList();

        return _response(path, 200, {
          'success': true,
          'data': {
            'mode': 'by_item',
            'count': generatedSplits.length,
            'grand_total': generatedSplits.fold<double>(
              0,
              (sum, split) => sum + ((split['total'] as num?)?.toDouble() ?? 0),
            ),
            'per_person': 0,
            'splits': generatedSplits,
          },
        });
      }

      return _response(path, 200, {
        'success': true,
        'data': {
          'mode': 'equal',
          'count': 2,
          'grand_total': 240,
          'per_person': 120,
          'splits': [
            {
              'label': 'คน 1',
              'subtotal': 120,
              'discount_amount': 0,
              'service_charge': 0,
              'total': 120,
              'order_ids': ['SO-SPLIT-1'],
              'items': [
                {
                  'item_id': 'IT1',
                  'product_id': 'P1',
                  'product_code': 'P1',
                  'product_name': 'Pad Thai',
                  'unit': 'plate',
                  'quantity': 1,
                  'unit_price': 120,
                  'amount': 120,
                },
              ],
            },
            {
              'label': 'คน 2',
              'subtotal': 120,
              'discount_amount': 0,
              'service_charge': 0,
              'total': 120,
              'order_ids': ['SO-SPLIT-2'],
              'items': [
                {
                  'item_id': 'IT2',
                  'product_id': 'P2',
                  'product_code': 'P2',
                  'product_name': 'Tom Yum Soup',
                  'unit': 'bowl',
                  'quantity': 1,
                  'unit_price': 120,
                  'amount': 120,
                },
              ],
            },
          ],
        },
      });
    }

    if (path == '/api/sales') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_no': 'ORD-001',
          'order_id': 'SO-NEW-1',
          'earned_points': 0,
        },
      });
    }

    if (path == '/api/sales/SO1/complete' ||
        path == '/api/sales/SO-SPLIT-1/complete') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_no': 'ORD-002',
          'order_id': 'SO-SPLIT-1',
          'earned_points': 0,
        },
      });
    }

    if (path == '/api/sales/SO-TAKEAWAY-1/complete') {
      return _response(path, 200, {
        'success': true,
        'data': {
          'order_no': 'TK-001',
          'order_id': 'SO-TAKEAWAY-1',
          'earned_points': 0,
        },
      });
    }

    if (path == '/api/tables/TB1/close') {
      return closeSucceeds
          ? _response(path, 200, {'success': true})
          : _response(path, 500, {
              'success': false,
              'message': closeFailureMessage,
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

class _TestSelectedWarehouseNotifier extends SelectedWarehouseNotifier {
  @override
  WarehouseModel? build() {
    return WarehouseModel(
      warehouseId: 'WH1',
      warehouseCode: 'WH1',
      warehouseName: 'Main Warehouse',
      branchId: 'BR1',
      createdAt: DateTime(2026, 4, 20),
    );
  }
}

class _SeededCartNotifier extends CartNotifier {
  _SeededCartNotifier(this._state);

  final CartState _state;

  @override
  CartState build() => _state;
}

class _ReceiptExitHarness extends StatefulWidget {
  const _ReceiptExitHarness();

  @override
  State<_ReceiptExitHarness> createState() => _ReceiptExitHarnessState();
}

class _ReceiptExitHarnessState extends State<_ReceiptExitHarness> {
  String _resultText = 'waiting';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.of(context).push<ReceiptExitAction>(
        MaterialPageRoute(builder: (_) => const PaymentPage()),
      );
      if (!mounted) return;
      setState(() {
        _resultText = result?.name ?? 'none';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(_resultText)));
  }
}

ProviderContainer _createContainer({
  required ApiClient apiClient,
  CartState? cartState,
  RestaurantOrderContext? restaurantContext,
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

final _bill = BillModel(
  sessionId: 'TS1',
  tableId: 'TB1',
  guestCount: 2,
  openedAt: DateTime(2026, 4, 20, 12, 0),
  orderIds: const ['SO1'],
  items: const [
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
      unitPrice: 120,
      discountAmount: 0,
      amount: 120,
      kitchenStatus: 'PENDING',
    ),
  ],
  subtotal: 240,
  discountAmount: 0,
  serviceChargeRate: 0,
  serviceChargeAmount: 0,
  grandTotal: 240,
);

final _tableContext = RestaurantOrderContext(
  tableId: 'TB1',
  tableName: 'A1',
  sessionId: 'TS1',
  branchId: 'BR1',
  guestCount: 2,
  currentOrderId: 'SO1',
  currentOrderIds: const ['SO1'],
);

final _takeawayContext = RestaurantOrderContext.takeaway(
  branchId: 'BR1',
  currentOrderId: 'SO-TAKEAWAY-1',
  currentOrderNo: 'TK-001',
);

void main() {
  group('Payment and split flow tests', () {
    testWidgets('equal split requires preview before apply', (tester) async {
      final fakeApi = _FakePaymentSplitApiClient();
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: const [],
          customerId: 'CUS1',
          customerName: 'สมาชิกทอง',
          customerPriceLevel: 3,
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: SplitBillPage(bill: _bill, tableContext: _tableContext),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('ดูตัวอย่างบิลแยก'));
      await tester.pumpAndSettle();

      expect(fakeApi.postCalls, contains('/api/tables/TB1/bill/split'));
      expect(
        fakeApi.postCalls,
        isNot(contains('/api/tables/TB1/bill/split/apply')),
      );
      expect(find.text('ยืนยันสร้างบิลแยก'), findsOneWidget);

      await tester.tap(find.text('ยืนยันสร้างบิลแยก'));
      await tester.pumpAndSettle();

      expect(fakeApi.postCalls, contains('/api/tables/TB1/bill/split/apply'));
      expect(find.text('ชำระ คน 1'), findsOneWidget);
    });

    testWidgets('split payment keeps original customer context', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: const [],
          customerId: 'CUS1',
          customerName: 'สมาชิกทอง',
          customerPriceLevel: 3,
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: SplitBillPage(bill: _bill, tableContext: _tableContext),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('ดูตัวอย่างบิลแยก'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยืนยันสร้างบิลแยก'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ชำระ คน 1'));
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart.customerId, 'CUS1');
      expect(cart.customerName, 'สมาชิกทอง');
      expect(cart.customerPriceLevel, 3);
      expect(find.byType(PaymentPage), findsOneWidget);
    });

    testWidgets('item split sends per-person quantities and keeps customer', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
      final bill = BillModel(
        sessionId: 'TS1',
        tableId: 'TB1',
        guestCount: 2,
        openedAt: DateTime(2026, 4, 20, 12, 0),
        orderIds: const ['SO1'],
        items: const [
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
            unitPrice: 120,
            discountAmount: 0,
            amount: 120,
            kitchenStatus: 'PENDING',
          ),
        ],
        subtotal: 360,
        discountAmount: 0,
        serviceChargeRate: 0,
        serviceChargeAmount: 0,
        grandTotal: 360,
        previewToken: 'preview-qty',
      );
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: const [],
          customerId: 'CUS1',
          customerName: 'สมาชิกทอง',
          customerPriceLevel: 3,
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: SplitBillPage(bill: bill, tableContext: _tableContext),
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

      expect(fakeApi.postCalls, contains('/api/tables/TB1/bill/split/apply'));
      expect(fakeApi.postPayloads['/api/tables/TB1/bill/split/apply'], {
        'splits': [
          {
            'label': 'คน 1',
            'items': [
              {'item_id': 'IT1', 'quantity': 1.0},
              {'item_id': 'IT2', 'quantity': 1.0},
            ],
          },
          {
            'label': 'คน 2',
            'items': [
              {'item_id': 'IT1', 'quantity': 1.0},
            ],
          },
        ],
        'preview_token': 'preview-qty',
      });

      await tester.tap(find.text('คน 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ชำระ คน 1'));
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart.customerId, 'CUS1');
      expect(cart.customerName, 'สมาชิกทอง');
      expect(cart.customerPriceLevel, 3);
      expect(find.byType(PaymentPage), findsOneWidget);
    });

    testWidgets('billing page carries bill customer into payment flow', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: const [],
          customerId: 'WALK_IN',
          customerName: 'ลูกค้าทั่วไป',
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: BillingPage(tableContext: _tableContext),
      );

      await tester.pumpAndSettle();
      final payBillButton = find.textContaining('ชำระเงิน');
      await tester.ensureVisible(payBillButton);
      await tester.tap(payBillButton);
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart.customerId, 'CUS1');
      expect(cart.customerName, 'สมาชิกทอง');
      expect(find.byType(PaymentPage), findsOneWidget);
    });

    testWidgets('takeaway billing page loads by order id and hides table actions', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
      final container = _createContainer(
        apiClient: fakeApi,
        cartState: CartState(
          items: const [],
          customerId: 'WALK_IN',
          customerName: 'ลูกค้าทั่วไป',
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: BillingPage(tableContext: _takeawayContext),
      );

      await tester.pumpAndSettle();

      expect(fakeApi.getCalls, contains('/api/sales/SO-TAKEAWAY-1'));
      expect(find.text('รวมโต๊ะ'), findsNothing);
      expect(find.text('แยกบิล'), findsNothing);
      expect(find.text('Service Charge'), findsNothing);
      expect(find.textContaining('ซื้อกลับบ้าน'), findsWidgets);
    });

    testWidgets('payment receipt propagates open new bill action', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
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
              unitPrice: 120,
              amount: 120,
              priceLevel1: 120,
            ),
          ],
        ),
      );

      await _pumpWithContainer(
        tester,
        container: container,
        child: const _ReceiptExitHarness(),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('ชำระเงิน').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('เปิดบิลใหม่'));
      await tester.pumpAndSettle();

      expect(find.text('openNewBill'), findsOneWidget);
    });

    testWidgets('receipt shows warning when auto close table fails', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient(
        closeSucceeds: false,
        closeFailureMessage:
            'ชำระเงินสำเร็จแล้ว แต่โต๊ะ A1 ยังปิดอัตโนมัติไม่สำเร็จ',
        billItems: const [],
      );
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
              unitPrice: 120,
              amount: 120,
              priceLevel1: 120,
            ),
          ],
        ),
        restaurantContext: _tableContext.copyWith(
          subtotalOverride: 120,
          totalOverride: 120,
          serviceChargeOverride: 0,
          discountOverride: 0,
          paymentTitle: 'ชำระบิลรวม',
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

      expect(find.textContaining('ปิดอัตโนมัติไม่สำเร็จ'), findsOneWidget);
    });

    testWidgets('takeaway payment completes without table bill or close calls', (
      tester,
    ) async {
      final fakeApi = _FakePaymentSplitApiClient();
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
          customerName: 'สมาชิกทอง',
          customerPriceLevel: 3,
        ),
        restaurantContext: _takeawayContext.copyWith(
          subtotalOverride: 150,
          totalOverride: 150,
          serviceChargeOverride: 0,
          discountOverride: 0,
          paymentTitle: 'ชำระบิลซื้อกลับบ้าน',
          currentOrderIds: const ['SO-TAKEAWAY-1'],
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

      expect(
        fakeApi.postCalls,
        contains('/api/sales/SO-TAKEAWAY-1/complete'),
      );
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
