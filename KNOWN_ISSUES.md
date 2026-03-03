# 🐛 Known Issues & Fixes

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

## Known Limitations ⚠️

### 1. Print Functionality
- **Status**: Not implemented
- **Workaround**: Export receipt as PDF or use screenshot
- **Planned**: Day 21+ (Future Enhancement)

### 2. Barcode Scanner
- **Status**: Not implemented
- **Workaround**: Manual entry or search
- **Planned**: Day 21+ (Future Enhancement)

### 3. Multi-branch Sync
- **Status**: Master mode only, no sync
- **Workaround**: Use single instance or manual data transfer
- **Planned**: Phase 2

### 4. Mobile Responsive
- **Status**: Desktop only
- **Note**: Optimized for macOS/Windows
- **Planned**: Phase 2 (Mobile App)

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

**Last Updated**: Day 20