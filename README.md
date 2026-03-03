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

### Phase 1 ✅ (Completed)
- [x] Project Setup
- [x] Database Design
- [x] Authentication
- [x] Master Data (Products, Customers)
- [x] POS System
- [x] Inventory Management
- [x] Reports & Analytics

### Phase 2 (Future)
- [ ] Multi-branch Sync
- [ ] Barcode Scanner Integration
- [ ] Receipt Printer Integration
- [ ] Online Backup
- [ ] Mobile App
- [ ] Accounting Module
- [ ] Purchase Orders
- [ ] Supplier Management

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