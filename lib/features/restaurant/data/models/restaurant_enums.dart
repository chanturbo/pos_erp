import 'package:flutter/material.dart';

enum BusinessMode {
  retail,
  restaurant,
  hybrid;

  String get value => name.toUpperCase();

  static BusinessMode fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'restaurant':
        return BusinessMode.restaurant;
      case 'hybrid':
        return BusinessMode.hybrid;
      default:
        return BusinessMode.retail;
    }
  }

  String get label {
    switch (this) {
      case BusinessMode.retail:
        return 'ร้านค้าปลีก';
      case BusinessMode.restaurant:
        return 'ร้านอาหาร';
      case BusinessMode.hybrid:
        return 'ผสม (Retail + Restaurant)';
    }
  }
}

enum ServiceType {
  dineIn,
  takeaway,
  delivery;

  String get value {
    switch (this) {
      case ServiceType.dineIn:
        return 'DINE_IN';
      case ServiceType.takeaway:
        return 'TAKEAWAY';
      case ServiceType.delivery:
        return 'DELIVERY';
    }
  }

  static ServiceType fromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'TAKEAWAY':
        return ServiceType.takeaway;
      case 'DELIVERY':
        return ServiceType.delivery;
      default:
        return ServiceType.dineIn;
    }
  }

  String get label {
    switch (this) {
      case ServiceType.dineIn:
        return 'ทานที่ร้าน';
      case ServiceType.takeaway:
        return 'ซื้อกลับบ้าน';
      case ServiceType.delivery:
        return 'ส่งถึงบ้าน';
    }
  }
}

enum PrepStation {
  kitchen,
  bar,
  dessert,
  cashier;

  String get value => name.toUpperCase();

  static PrepStation? fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'kitchen':
        return PrepStation.kitchen;
      case 'bar':
        return PrepStation.bar;
      case 'dessert':
        return PrepStation.dessert;
      case 'cashier':
        return PrepStation.cashier;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case PrepStation.kitchen:
        return 'ครัว';
      case PrepStation.bar:
        return 'บาร์';
      case PrepStation.dessert:
        return 'ของหวาน';
      case PrepStation.cashier:
        return 'แคชเชียร์';
    }
  }

  /// ไอคอนสำหรับแสดงใน KitchenDisplayPage
  IconData get icon {
    switch (this) {
      case PrepStation.kitchen:
        return Icons.restaurant;
      case PrepStation.bar:
        return Icons.local_bar;
      case PrepStation.dessert:
        return Icons.cake;
      case PrepStation.cashier:
        return Icons.point_of_sale;
    }
  }
}

enum ServiceMode {
  retail,
  restaurant,
  both;

  String get value => name.toUpperCase();

  static ServiceMode fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'restaurant':
        return ServiceMode.restaurant;
      case 'both':
        return ServiceMode.both;
      default:
        return ServiceMode.retail;
    }
  }

  String get label {
    switch (this) {
      case ServiceMode.retail:
        return 'ขายปลีก';
      case ServiceMode.restaurant:
        return 'ร้านอาหาร';
      case ServiceMode.both:
        return 'ทั้งสองแบบ';
    }
  }
}

enum KitchenStatus {
  pending,
  preparing,
  ready,
  served,
  cancelled;

  String get value => name.toUpperCase();

  static KitchenStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'preparing':
        return KitchenStatus.preparing;
      case 'ready':
        return KitchenStatus.ready;
      case 'served':
        return KitchenStatus.served;
      case 'cancelled':
        return KitchenStatus.cancelled;
      default:
        return KitchenStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case KitchenStatus.pending:
        return 'รอทำ';
      case KitchenStatus.preparing:
        return 'กำลังทำ';
      case KitchenStatus.ready:
        return 'พร้อมเสิร์ฟ';
      case KitchenStatus.served:
        return 'เสิร์ฟแล้ว';
      case KitchenStatus.cancelled:
        return 'ยกเลิก';
    }
  }
}

enum TableStatus {
  available,
  occupied,
  reserved,
  cleaning,
  disabled;

  String get value => name.toUpperCase();

  static TableStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
      case 'cleaning':
        return TableStatus.cleaning;
      case 'disabled':
        return TableStatus.disabled;
      default:
        return TableStatus.available;
    }
  }
}

enum TableSessionStatus {
  open,
  billed,
  closed,
  cancelled;

  String get value => name.toUpperCase();

  static TableSessionStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'billed':
        return TableSessionStatus.billed;
      case 'closed':
        return TableSessionStatus.closed;
      case 'cancelled':
        return TableSessionStatus.cancelled;
      default:
        return TableSessionStatus.open;
    }
  }
}
