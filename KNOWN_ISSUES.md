# 🐛 Known Issues & Current Limitations

## Fixed Issues ✅

### 1. Cart Provider Error
- **Issue**: StateProvider error in cart_provider.dart
- **Fix**: Changed to NotifierProvider with proper state management
- **Status**: ✅ Fixed

### 2. Sales Routes Value Error
- **Issue**: Value<T> type mismatch in sales_routes.dart
- **Fix**: Added Value() wrapper to all optional fields
- **Status**: ✅ Fixed

### 3. Product List Page Error
- **Issue**: .when() method not defined for ProductListState
- **Fix**: Replaced with manual state checking (if/else)
- **Status**: ✅ Fixed

### 4. macOS Network Permission
- **Issue**: Cannot connect to localhost
- **Fix**: Added network entitlements, changed to 127.0.0.1
- **Status**: ✅ Fixed

## Current Limitations ⚠️

### 1. Receipt Printing
- **Status**: Implemented via PDF preview + system print dialog
- **Current Limitation**: ยังไม่มี direct thermal printer integration หรือ preset เครื่องพิมพ์เฉพาะทางในแอป
- **Workaround**: ใช้ปุ่มพิมพ์จาก PDF preview แล้วเลือก printer ผ่านระบบปฏิบัติการ

### 2. Barcode Input
- **Status**: Implemented
- **Supported**: USB keyboard-style scanner และ camera scanner ในหน้าที่รองรับ
- **Current Limitation**: ถ้าอุปกรณ์สแกนไม่ได้ส่งข้อมูลเป็น keyboard input มาตรฐาน อาจต้องกรอกเองหรือใช้ camera scanner แทน

### 3. Multi-branch Sync
- **Status**: Implemented for Master / Client modes
- **Current Limitation**: โหมด standalone จะไม่ sync อัตโนมัติ และการใช้งานหลายสาขาต้องตั้งค่า app mode / branch ให้ถูกต้องก่อน

### 4. Mobile / Responsive UI
- **Status**: Implemented
- **Current Limitation**: ระบบรองรับ responsive layout และมี mobile flow สำหรับบางหน้าหลัก แต่ประสบการณ์ใช้งานยังดีที่สุดบนหน้าจอ tablet/desktop สำหรับงาน back-office ที่ข้อมูลหนาแน่น

## Performance Notes 📊

### Tested Performance
- **Startup Time**: < 3 seconds
- **Database**: Fast with < 10,000 records
- **Search**: Instant with current data size
- **Navigation**: Smooth

### Recommended Limits
- Products: < 5,000 items
- Customers: < 2,000 customers
- Daily Orders: < 500 orders
- Stock Movements: < 1,000/day

### If Performance Degrades
1. Run database VACUUM
2. Clear old data
3. Archive old orders
4. Optimize queries

---

**Last Updated**: 2026-04-18
