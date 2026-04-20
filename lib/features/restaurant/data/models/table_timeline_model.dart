class TableTimelineEvent {
  final String type; // 'opened' | 'order' | 'item_status' | 'waiter' | 'billed' | 'closed'
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> data;

  const TableTimelineEvent({
    required this.type,
    required this.timestamp,
    required this.description,
    this.data = const {},
  });

  factory TableTimelineEvent.fromJson(Map<String, dynamic> json) =>
      TableTimelineEvent(
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        description: json['description'] as String,
        data: (json['data'] as Map<String, dynamic>?) ?? {},
      );
}

class TableTimelineModel {
  final String sessionId;
  final String tableId;
  final String? tableName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status;
  final int guestCount;
  final String? waiterId;
  final String? waiterName;
  final List<TableTimelineEvent> events;

  const TableTimelineModel({
    required this.sessionId,
    required this.tableId,
    this.tableName,
    required this.openedAt,
    this.closedAt,
    required this.status,
    required this.guestCount,
    this.waiterId,
    this.waiterName,
    required this.events,
  });

  factory TableTimelineModel.fromJson(Map<String, dynamic> json) =>
      TableTimelineModel(
        sessionId: json['session_id'] as String,
        tableId: json['table_id'] as String,
        tableName: json['table_name'] as String?,
        openedAt: DateTime.parse(json['opened_at'] as String),
        closedAt: json['closed_at'] != null
            ? DateTime.tryParse(json['closed_at'] as String)
            : null,
        status: json['status'] as String,
        guestCount: json['guest_count'] as int? ?? 0,
        waiterId: json['waiter_id'] as String?,
        waiterName: json['waiter_name'] as String?,
        events: (json['events'] as List)
            .map((e) =>
                TableTimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Duration get duration {
    final end = closedAt ?? DateTime.now();
    return end.difference(openedAt);
  }
}

class KitchenAnalyticsModel {
  final String period;
  final int totalOrders;
  final int totalItems;
  final double avgPrepTimeMinutes;
  final double avgOrderTimeMinutes;
  final Map<String, int> itemsByStation;
  final Map<String, double> avgPrepByStation;
  final List<Map<String, dynamic>> topItems;

  const KitchenAnalyticsModel({
    required this.period,
    required this.totalOrders,
    required this.totalItems,
    required this.avgPrepTimeMinutes,
    required this.avgOrderTimeMinutes,
    required this.itemsByStation,
    required this.avgPrepByStation,
    required this.topItems,
  });

  factory KitchenAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      KitchenAnalyticsModel(
        period: json['period'] as String,
        totalOrders: json['total_orders'] as int? ?? 0,
        totalItems: json['total_items'] as int? ?? 0,
        avgPrepTimeMinutes:
            (json['avg_prep_time_minutes'] as num?)?.toDouble() ?? 0,
        avgOrderTimeMinutes:
            (json['avg_order_time_minutes'] as num?)?.toDouble() ?? 0,
        itemsByStation: Map<String, int>.from(
            (json['items_by_station'] as Map<String, dynamic>?)
                    ?.map((k, v) => MapEntry(k, v as int)) ??
                {}),
        avgPrepByStation: Map<String, double>.from(
            (json['avg_prep_by_station'] as Map<String, dynamic>?)
                    ?.map((k, v) =>
                        MapEntry(k, (v as num).toDouble())) ??
                {}),
        topItems: (json['top_items'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
      );
}
