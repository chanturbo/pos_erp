class KitchenQueueItemModel {
  final String itemId;
  final String orderId;
  final String orderNo;
  final String? tableId;
  final String? tableName;
  final String? sessionId;
  final int lineNo;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final String kitchenStatus; // PENDING | PREPARING | READY | SERVED | CANCELLED | HELD
  final int courseNo;
  final String? prepStation;  // kitchen | bar | dessert | cashier
  final String? specialInstructions;
  final DateTime createdAt;
  final DateTime? preparedAt;

  const KitchenQueueItemModel({
    required this.itemId,
    required this.orderId,
    required this.orderNo,
    this.tableId,
    this.tableName,
    this.sessionId,
    required this.lineNo,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.kitchenStatus,
    this.courseNo = 1,
    this.prepStation,
    this.specialInstructions,
    required this.createdAt,
    this.preparedAt,
  });

  bool get isPending => kitchenStatus == 'PENDING';
  bool get isPreparing => kitchenStatus == 'PREPARING';
  bool get isReady => kitchenStatus == 'READY';
  bool get isServed => kitchenStatus == 'SERVED';

  Duration get waitTime => DateTime.now().difference(createdAt);

  factory KitchenQueueItemModel.fromJson(Map<String, dynamic> json) =>
      KitchenQueueItemModel(
        itemId: json['item_id'] as String,
        orderId: json['order_id'] as String,
        orderNo: json['order_no'] as String? ?? '',
        tableId: json['table_id'] as String?,
        tableName: json['table_name'] as String?,
        sessionId: json['session_id'] as String?,
        lineNo: json['line_no'] as int? ?? 0,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String? ?? '',
        kitchenStatus: json['kitchen_status'] as String? ?? 'PENDING',
        courseNo: json['course_no'] as int? ?? 1,
        prepStation: json['prep_station'] as String?,
        specialInstructions: json['special_instructions'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        preparedAt: json['prepared_at'] != null
            ? DateTime.tryParse(json['prepared_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'order_id': orderId,
        'order_no': orderNo,
        'table_id': tableId,
        'table_name': tableName,
        'session_id': sessionId,
        'line_no': lineNo,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'kitchen_status': kitchenStatus,
        'course_no': courseNo,
        'prep_station': prepStation,
        'special_instructions': specialInstructions,
        'created_at': createdAt.toIso8601String(),
        'prepared_at': preparedAt?.toIso8601String(),
      };

  bool get isHeld => kitchenStatus == 'HELD';

  KitchenQueueItemModel copyWith({String? kitchenStatus, DateTime? preparedAt}) =>
      KitchenQueueItemModel(
        itemId: itemId,
        orderId: orderId,
        orderNo: orderNo,
        tableId: tableId,
        tableName: tableName,
        sessionId: sessionId,
        lineNo: lineNo,
        productId: productId,
        productName: productName,
        quantity: quantity,
        unit: unit,
        kitchenStatus: kitchenStatus ?? this.kitchenStatus,
        courseNo: courseNo,
        prepStation: prepStation,
        specialInstructions: specialInstructions,
        createdAt: createdAt,
        preparedAt: preparedAt ?? this.preparedAt,
      );
}

/// จัดกลุ่ม items ตาม order (1 ticket ต่อ 1 order)
class KitchenOrderGroup {
  final String orderId;
  final String orderNo;
  final String? tableId;
  final String? tableName;
  final List<KitchenQueueItemModel> items;

  const KitchenOrderGroup({
    required this.orderId,
    required this.orderNo,
    this.tableId,
    this.tableName,
    required this.items,
  });

  DateTime get createdAt => items.map((i) => i.createdAt).reduce(
      (a, b) => a.isBefore(b) ? a : b);

  static List<KitchenOrderGroup> groupItems(List<KitchenQueueItemModel> items) {
    final map = <String, KitchenOrderGroup>{};
    for (final item in items) {
      if (map.containsKey(item.orderId)) {
        map[item.orderId] = KitchenOrderGroup(
          orderId: item.orderId,
          orderNo: item.orderNo,
          tableId: item.tableId,
          tableName: item.tableName,
          items: [...map[item.orderId]!.items, item],
        );
      } else {
        map[item.orderId] = KitchenOrderGroup(
          orderId: item.orderId,
          orderNo: item.orderNo,
          tableId: item.tableId,
          tableName: item.tableName,
          items: [item],
        );
      }
    }
    final groups = map.values.toList();
    groups.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return groups;
  }
}

/// สรุปจำนวนต่อ station
class KitchenStationSummary {
  final String station;
  final int pendingCount;
  final int preparingCount;
  final int readyCount;

  const KitchenStationSummary({
    required this.station,
    required this.pendingCount,
    required this.preparingCount,
    required this.readyCount,
  });

  int get totalActive => pendingCount + preparingCount;

  factory KitchenStationSummary.fromJson(Map<String, dynamic> json) =>
      KitchenStationSummary(
        station: json['station'] as String,
        pendingCount: json['pending_count'] as int? ?? 0,
        preparingCount: json['preparing_count'] as int? ?? 0,
        readyCount: json['ready_count'] as int? ?? 0,
      );
}
