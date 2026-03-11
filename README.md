# 🏪 POS & ERP System

ระบบ Point of Sale และ ERP แบบ Offline-First สำหรับร้านค้าทุกประเภท พัฒนาด้วย Flutter

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?style=flat&logo=sqlite&logoColor=white)

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

### 📦 Product Management
- CRUD Operations
- Product Search
- Price Levels (1-5)
- Stock Control Options
- Barcode Support

### 👥 Customer Management
- Customer Database
- Credit Terms
- Member System
- Points Tracking

### 📊 Inventory Management
- Stock Balance
- Stock Movements (In/Out/Adjust/Transfer)
- Auto Stock Deduction
- Low Stock Alerts
- Movement History
- Multi-warehouse Support

### 📈 Reports & Analytics
- Sales Summary
- Daily Sales Chart
- Top Products
- Top Customers
- Export to CSV

### ⚙️ Settings
- Company Information
- VAT Configuration
- Stock Alert Settings
- Keyboard Shortcuts

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- macOS (for macOS app) or Windows (for Windows app)

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd pos_erp_system
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
# For macOS
flutter run -d macos

# For Windows
flutter run -d windows
```

## 👤 Default Users

### Admin
- Username: `admin`
- Password: `admin123`
- Full Access

### Cashier
- Username: `cashier`
- Password: `cashier123`
- Limited Access (POS Only)

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| F1 | Open POS |
| F2 | Manage Products |
| F3 | Manage Customers |
| F4 | Sales History |
| F5 | Refresh |
| F6 | Inventory |
| F7 | Reports |
| F10 | Dashboard |
| ESC | Cancel/Close |

## 🗄️ Database Schema

ระบบใช้ SQLite Database ด้วย Drift ORM

### Main Tables
- `companies` - ข้อมูลบริษัท
- `branches` - ข้อมูลสาขา
- `users` - ผู้ใช้งาน
- `roles` - สิทธิ์การใช้งาน
- `products` - สินค้า
- `customers` - ลูกค้า
- `sales_orders` - ใบขาย
- `sales_order_items` - รายการสินค้าในใบขาย
- `stock_movements` - การเคลื่อนไหวสต๊อก
- `warehouses` - คลังสินค้า

รวม 40+ tables

## 📁 Project Structure
```
lib/
├── core/                 # Core functionality
│   ├── client/          # API Client
│   ├── database/        # Database & Tables
│   ├── server/          # API Server (Master Mode)
│   ├── shortcuts/       # Keyboard Shortcuts
│   └── utils/           # Utilities
├── features/            # Feature Modules
│   ├── auth/           # Authentication
│   ├── dashboard/      # Dashboard
│   ├── products/       # Product Management
│   ├── customers/      # Customer Management
│   ├── sales/          # POS & Sales
│   ├── inventory/      # Inventory Management
│   ├── reports/        # Reports & Analytics
│   └── settings/       # Settings
├── routes/             # Navigation
└── main.dart           # Entry Point
```

## 🛠️ Technologies Used

### Frontend
- **Flutter** - UI Framework
- **Riverpod** - State Management
- **Flutter ScreenUtil** - Responsive Design

### Backend (Master Mode)
- **Shelf** - HTTP Server
- **Shelf Router** - Routing

### Database
- **Drift** - Type-safe SQL ORM
- **SQLite** - Local Database

### Others
- **Dio** - HTTP Client
- **SharedPreferences** - Local Storage
- **FL Chart** - Charts & Graphs
- **Intl** - Internationalization

## 📊 Statistics

- **Total Files**: 100+ files
- **Lines of Code**: 15,000+ lines
- **Database Tables**: 40+ tables
- **API Endpoints**: 30+ endpoints
- **Features**: 10+ major features
- **Development Time**: 20 days (4 weeks)

## 🎯 Roadmap

# POS-ERP System

ระบบ Point of Sale และ ERP สำหรับธุรกิจค้าปลีก พัฒนาด้วย Flutter Desktop (macOS/Windows)  
**Tech Stack:** Flutter • Drift ORM • SQLite • Shelf API Server • Riverpod

---

## 🗺️ Roadmap & Progress

### ✅ Phase 1: Core System — เสร็จแล้ว

| รายการ | สถานะ |
|---|---|
| Authentication (Login/Logout) | ✅ |
| Database Setup (Drift + SQLite) | ✅ |
| API Server (Shelf) | ✅ |
| Product Management | ✅ |
| Customer Management | ✅ |
| Sales (POS) | ✅ |
| Sales History | ✅ |
| Stock Balance | ✅ |
| Inventory Management | ✅ |

---

### ✅ Phase 2 — Week 1: Procurement — เสร็จแล้ว

| รายการ | สถานะ |
|---|---|
| Supplier Management | ✅ |
| Purchase Order (PO) | ✅ |
| Goods Receipt (GR) | ✅ |
| Stock Movement Integration | ✅ |

---

### ✅ Phase 2 — Week 2: Supplier & AP (Day 26–30) — เสร็จแล้ว

**Day 26–27: Supplier Improvement**

| รายการ | สถานะ |
|---|---|
| Supplier Form Page (Create/Edit) | ✅ |
| Supplier Details Page | ✅ |
| Supplier Credit Limit Tracking | ✅ |
| Supplier Performance Tracking | ✅ |

**Day 28–30: Accounts Payable (AP)**

| รายการ | สถานะ |
|---|---|
| AP Invoice — Database Schema | ✅ |
| AP Invoice — API Routes | ✅ |
| AP Invoice — List Page | ✅ |
| AP Invoice — Form Page | ✅ |
| AP Invoice — Link กับ PO/GR | ✅ |
| AP Payment — Payment Recording | ✅ |
| AP Payment — Payment Allocation | ✅ |
| AP Payment — Payment History | ✅ |

---

### ✅ Phase 2 — Week 3: Returns & Adjustments (Day 31–35) — เสร็จแล้ว

**Day 31–32: Purchase Return**

| รายการ | สถานะ |
|---|---|
| Purchase Return — Database Schema | ✅ |
| Purchase Return — API Routes | ✅ |
| Purchase Return — List Page | ✅ |
| Purchase Return — Form Page (Select from GR) | ✅ |
| Purchase Return — Stock Adjustment | ✅ |

**Day 33–35: Stock Adjustment**

| รายการ | สถานะ |
|---|---|
| Adjust Stock — เพิ่ม/ลดทีละรายการ | ✅ |
| Stock Take — ตรวจนับสต๊อกทั้งคลัง + Variance | ✅ |
| Stock Transfer — โอนย้ายระหว่างคลัง | ✅ |
| Variance Report — รายงานผลต่าง | ✅ |

---

### 🔲 Phase 2 — Week 4: Accounts Receivable (Day 36–40) — ถัดไป

**Day 36–38: AR Invoice**

| รายการ | สถานะ |
|---|---|
| AR Invoice — Database Schema | 🔲 |
| AR Invoice — API Routes | 🔲 |
| AR Invoice — List Page | 🔲 |
| AR Invoice — Form Page | 🔲 |
| AR Invoice — Link กับ Sales Order | 🔲 |

**Day 39–40: AR Receipt**

| รายการ | สถานะ |
|---|---|
| AR Receipt — Payment Recording | 🔲 |
| AR Receipt — Payment Allocation | 🔲 |
| AR Receipt — Receipt Printing | 🔲 |
| AR Receipt — Payment History | 🔲 |

---

### 🔲 Phase 3: Advanced Features (Week 5–8)

**Week 5: Promotions & Discounts**
- 🔲 Buy 1 Get 1
- 🔲 Discount by Amount/Percentage
- 🔲 Time-based Promotions
- 🔲 Coupon System
- 🔲 Member/Loyalty Program

**Week 6: Reporting**
- 🔲 Sales Reports (Daily Summary, Product Performance, By Category, By Period)
- 🔲 Purchase Reports (Summary, Supplier Performance, By Category)
- 🔲 Inventory Reports (Stock Movement, Low Stock Alert, Stock Aging, Expiry Alert)
- 🔲 Financial Reports (P&L, Cash Flow, AR/AP Aging)

**Week 7: Multi-Branch & Sync**
- 🔲 Branch Management
- 🔲 Stock Transfer Between Branches
- 🔲 Data Synchronization
- 🔲 Master-Client Architecture
- 🔲 Offline Mode

**Week 8: Restaurant Features**
- 🔲 Table Management
- 🔲 Order Queue
- 🔲 Kitchen Display System (KDS)
- 🔲 Modifiers (เพิ่มเติม/ลด/ไม่ใส่)
- 🔲 Split Bill

---

### 🔲 Phase 4: Polish & Optimization (Week 9–10)

**Week 9: UI/UX**
- 🔲 Dark Mode
- 🔲 Responsive Design
- 🔲 Accessibility
- 🔲 Animation & Transitions
- 🔲 Loading States / Error Handling

**Week 10: Performance & Testing**
- 🔲 Performance Optimization
- 🔲 Unit / Integration / E2E Tests
- 🔲 Load Testing
- 🔲 Bug Fixes

---

### 🔲 Phase 5: Mobile & Deployment (Week 11–12)

**Week 11: Mobile App**
- 🔲 Android App
- 🔲 iOS App
- 🔲 Mobile-specific UI
- 🔲 QR Code / Barcode Scanner
- 🔲 Mobile Printing

**Week 12: Deployment**
- 🔲 Production Setup
- 🔲 Cloud Deployment (Optional)
- 🔲 Database Migration
- 🔲 User Training / Documentation
- 🔲 Maintenance Plan

---

## 📊 Progress Summary

```
Phase 1  ████████████████████  100%  ✅ เสร็จแล้ว
Phase 2  ████████████████░░░░   75%  🔄 Week 4 ยังเหลือ
Phase 3  ░░░░░░░░░░░░░░░░░░░░    0%  🔲 ยังไม่เริ่ม
Phase 4  ░░░░░░░░░░░░░░░░░░░░    0%  🔲 ยังไม่เริ่ม
Phase 5  ░░░░░░░░░░░░░░░░░░░░    0%  🔲 ยังไม่เริ่ม
```

**ปัจจุบัน:** Phase 2 Week 3 เสร็จสมบูรณ์ → กำลังจะเริ่ม **Week 4: AR Invoice & AR Receipt**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License.

## 👨‍💻 Author

Developed with ❤️ using Flutter

## 📞 Support

For support, email support@example.com or open an issue.

---

**🎉 Happy Coding!**