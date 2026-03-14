# 🏪 POS & ERP System

ระบบ Point of Sale และ ERP แบบ Offline-First สำหรับร้านค้าทุกประเภท พัฒนาด้วย Flutter

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?style=flat&logo=sqlite&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-47%20passed-brightgreen)
![Version](https://img.shields.io/badge/Version-1.0.0-blue)

---

## ✨ Features

### 🔐 Authentication
- Login/Logout System
- Role-based Access Control
- Token Persistence
- Multi-user Support

### 🛒 POS (Point of Sale)
- Product Grid Display
- Shopping Cart
- Customer Selection
- Discount Management (% และ ฿)
- Hold/Recall Orders
- Multiple Payment Methods (Cash/Card/Transfer)
- Change Calculation
- Receipt Generation
- Promotion & Coupon System

### 📦 Product Management
- CRUD Operations
- Product Search
- Price Levels (1-5)
- Stock Control Options
- Barcode Support

### 👥 Customer Management
- Customer Database
- Credit Terms
- Member/Loyalty System
- Points Tracking

### 📊 Inventory Management
- Stock Balance (Multi-warehouse)
- Stock Movements (In/Out/Adjust/Transfer)
- Auto Stock Deduction on Sale
- Low Stock Alerts
- Movement History

### 🏭 Procurement
- Supplier Management (+ Credit Limit / Performance)
- Purchase Order (PO)
- Goods Receipt (GR)
- Purchase Return
- Stock Adjustment / Stock Take

### 💰 Accounts Payable (AP)
- AP Invoice (linked to PO/GR)
- AP Payment Recording
- Payment Allocation
- Payment History

### 💳 Accounts Receivable (AR)
- AR Invoice (linked to Sales Order)
- AR Receipt Recording
- Payment Allocation
- Receipt Printing

### 🎁 Promotions & Discounts
- Buy 1 Get 1
- Discount by Amount / Percentage
- Time-based Promotions
- Coupon System

### 📈 Reports & Analytics
- Sales Summary (Daily/Weekly/Monthly)
- Product Performance
- Sales by Category & Period
- Purchase Reports
- Inventory Reports (Movement, Low Stock, Aging)
- Financial Reports (P&L, Cash Flow, AR/AP Aging)
- Export to CSV

### 🏢 Multi-Branch
- Branch Management
- Stock Transfer Between Branches
- Master-Client Architecture
- Offline Sync

### 🍽️ Restaurant Features
- Table Management
- Order Queue
- Kitchen Display System (KDS)
- Modifiers (เพิ่ม/ลด/ไม่ใส่)
- Split Bill

### ⚙️ Settings & UX
- Dark Mode
- Responsive Design (Mobile / Tablet / Desktop)
- Keyboard Shortcuts
- Company & VAT Configuration

---

## 🚀 Getting Started

### Prerequisites

| Platform | Requirements |
|---|---|
| macOS | macOS Catalina+, Xcode 15+, Flutter SDK |
| Windows | Windows 10/11, Visual Studio 2022 (C++), Flutter SDK |
| Android | Android Studio, Android SDK API 21+, JDK 17 |
| iOS | macOS, Xcode 15+, Apple Developer Account |

### Installation

```bash
# 1. Clone
git clone <repository-url>
cd pos_erp

# 2. Dependencies
flutter pub get

# 3. Run
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d android    # Android
flutter run -d ios        # iOS
```

### Build Release

```bash
flutter build macos   --release   # macOS .app
flutter build windows --release   # Windows .exe
flutter build apk     --release   # Android APK
flutter build appbundle --release # Android AAB (Play Store)
flutter build ios     --release   # iOS .ipa
```

---

## 👤 Default Users

| Username | Password | Role |
|---|---|---|
| `admin` | `admin123` | Administrator (Full Access) |
| `cashier` | `cashier123` | Cashier (POS Only) |

---

## ⌨️ Keyboard Shortcuts

| Key | Action |
|---|---|
| F1 | Open POS |
| F2 | Manage Products |
| F3 | Manage Customers |
| F4 | Sales History |
| F5 | Refresh |
| F6 | Inventory |
| F7 | Reports |
| F10 | Dashboard |
| ESC | Cancel/Close |

---

## 🗄️ Database Schema

ระบบใช้ SQLite Database ด้วย Drift ORM — **40+ tables**

| Module | Tables |
|---|---|
| System | companies, branches, users, roles |
| Products | products, product_groups, product_units |
| Customers | customers |
| Sales | sales_orders, sales_order_items |
| Inventory | warehouses, stock_movements, stock_balances |
| Procurement | suppliers, purchase_orders, purchase_order_items, goods_receipts |
| AP | ap_invoices, ap_invoice_items, ap_payments, ap_payment_allocations |
| AR | ar_invoices, ar_invoice_items, ar_receipts, ar_receipt_allocations |
| Promotions | promotions, coupons |
| Restaurant | tables, modifiers |

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/          # AppConfig, AppMode
│   ├── database/        # Drift DB, Tables, Seed Data
│   ├── server/          # Shelf API Server
│   ├── client/          # HTTP API Client
│   └── utils/           # CryptoUtils, CsvExport
├── features/
│   ├── auth/            # Authentication
│   ├── dashboard/       # Dashboard & Charts
│   ├── products/        # Product Management
│   ├── customers/       # Customer Management
│   ├── sales/           # POS & Sales History
│   ├── inventory/       # Stock Management
│   ├── procurement/     # PO, GR, Purchase Return
│   ├── ap/              # Accounts Payable
│   ├── ar/              # Accounts Receivable
│   ├── promotions/      # Promotions & Coupons
│   ├── reports/         # All Reports
│   ├── branch/          # Multi-Branch
│   ├── restaurant/      # Table & KDS
│   └── settings/        # Settings
├── shared/
│   ├── theme/           # AppTheme, ThemeProvider (Dark Mode)
│   ├── utils/           # ResponsiveUtils, AppTransitions, MobileConfig
│   ├── widgets/         # AsyncStateWidgets, LoadingOverlay
│   └── services/        # MobileScannerService, OfflineSyncService
├── routes/              # AppRouter
└── main.dart
```

---

## 🧪 Tests

```bash
# Run all tests
flutter test

# Run specific suite
flutter test test/all_tests.dart

# With coverage
flutter test --coverage
```

**Current: 47/47 tests passed ✅**

| Suite | Tests |
|---|---|
| ProductModel | 8 |
| ApInvoiceModel | 14 |
| CryptoUtils | 9 |
| ResponsiveUtils | 13 |
| Widget Smoke Test | 1 |
| **Total** | **47** |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter 3.x |
| State Management | Riverpod 2.x |
| Database | Drift ORM + SQLite |
| API Server | Shelf + Shelf Router |
| HTTP Client | Dio |
| Charts | FL Chart |
| Responsive | Flutter ScreenUtil |
| Storage | SharedPreferences |
| Barcode Scanner | mobile_scanner |
| i18n | Intl (th_TH) |

---

## 📊 Project Statistics

| Metric | Value |
|---|---|
| Total Files | 120+ files |
| Lines of Code | 20,000+ lines |
| Database Tables | 40+ tables |
| API Endpoints | 50+ endpoints |
| Test Cases | 47 passed |
| Platforms | macOS, Windows, Android, iOS |
| Development Time | 12 weeks |

---

## 🗺️ Roadmap

```
Phase 1  ████████████████████  100% ✅ Core System
Phase 2  ████████████████████  100% ✅ Procurement & Finance
Phase 3  ████████████████████  100% ✅ Advanced Features
Phase 4  ████████████████████  100% ✅ Polish & Testing
Phase 5  ████████████████████  100% ✅ Mobile & Deployment
```

**🎉 v1.0.0 — Production Ready**

---

## 📋 Maintenance Plan

### Regular Tasks
- **Daily**: Monitor error logs
- **Weekly**: Database VACUUM + backup
- **Monthly**: Dependency updates (`flutter pub upgrade`)
- **Quarterly**: Performance review, security audit

### Backup Strategy
```bash
# macOS
cp ~/Library/Application\ Support/<bundle>/pos_erp.db \
   ~/Backups/pos_erp_$(date +%Y%m%d).db

# Android (adb)
adb pull /data/data/<package>/databases/pos_erp.db ./backup.db
```

### Update Process
```bash
git pull origin main
flutter pub get
flutter build <platform> --release
```

---

## 🤝 Contributing

Pull Requests are welcome. For major changes, please open an issue first.

## 📝 License

MIT License

## 👨‍💻 Author

Developed with ❤️ using Flutter

## 📞 Support

For support, email support@example.com or open an issue.

---

**🎉 v1.0.0 — Production Ready!**