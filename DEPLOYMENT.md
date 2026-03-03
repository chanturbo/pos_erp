# 🚀 Deployment Guide

## สารบัญ
1. [Build สำหรับ macOS](#build-สำหรับ-macos)
2. [Build สำหรับ Windows](#build-สำหรับ-windows)
3. [Database Migration](#database-migration)
4. [Configuration](#configuration)

---

## Build สำหรับ macOS

### Prerequisites
- macOS (Catalina or later)
- Xcode (latest version)
- Flutter SDK
- CocoaPods

### Steps

1. **Clean project**
```bash
flutter clean
flutter pub get
```

2. **Build macOS app**
```bash
flutter build macos --release
```

3. **Find the app**
```
build/macos/Build/Products/Release/pos_erp_system.app
```

4. **Create DMG (Optional)**
```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "POS System" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 185 \
  "POS-System-Installer.dmg" \
  "build/macos/Build/Products/Release/pos_erp_system.app"
```

### Code Signing (for distribution)
```bash
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR NAME" \
  "build/macos/Build/Products/Release/pos_erp_system.app"

# Verify
codesign --verify --deep --verbose=2 \
  "build/macos/Build/Products/Release/pos_erp_system.app"
```

---

## Build สำหรับ Windows

### Prerequisites
- Windows 10/11
- Visual Studio 2022 (with C++ workload)
- Flutter SDK

### Steps

1. **Clean project**
```bash
flutter clean
flutter pub get
```

2. **Build Windows app**
```bash
flutter build windows --release
```

3. **Find the executable**
```
build\windows\runner\Release\pos_erp_system.exe
```

4. **Create Installer (Optional)**

**Using Inno Setup:**

Install Inno Setup, then create script:
```inno
[Setup]
AppName=POS & ERP System
AppVersion=1.0
DefaultDirName={pf}\POSSystem
DefaultGroupName=POS System
OutputDir=output
OutputBaseFilename=POS-System-Setup

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\POS System"; Filename: "{app}\pos_erp_system.exe"
Name: "{commondesktop}\POS System"; Filename: "{app}\pos_erp_system.exe"
```

Compile with Inno Setup to create installer.

---

## Database Migration

### Initial Setup
Database is created automatically on first run with seed data.

### Manual Database Reset
```bash
# Delete database file
# macOS:
rm ~/Library/Application\ Support/com.example.posErpSystem/app_database.db

# Windows:
del %APPDATA%\pos_erp_system\app_database.db
```

### Backup Database
```bash
# macOS:
cp ~/Library/Application\ Support/com.example.posErpSystem/app_database.db \
   ~/Desktop/backup_$(date +%Y%m%d).db

# Windows:
copy %APPDATA%\pos_erp_system\app_database.db ^
     %USERPROFILE%\Desktop\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.db
```

---

## Configuration

### Environment Variables

Create `.env` file:
```
API_PORT=8080
DB_NAME=pos_database.db
COMPANY_NAME=Your Company Name
```

### App Settings

Edit `lib/core/config/app_config.dart`:
```dart
class AppConfig {
  static const String appName = 'POS System';
  static const String version = '1.0.0';
  static const int apiPort = 8080;
}
```

### Default Users

Default users are created in `lib/main.dart`:
- Admin: admin/admin123
- Cashier: cashier/cashier123

To change, edit `_createDefaultUser()` function.

---

## Network Configuration

### Firewall Rules

**macOS:**
```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw \
  --add /path/to/pos_erp_system.app
```

**Windows:**
```powershell
New-NetFirewallRule -DisplayName "POS System" `
  -Direction Inbound -Program "C:\path\to\pos_erp_system.exe" `
  -Action Allow
```

---

## Performance Optimization

### Release Build Flags
```bash
flutter build macos --release --split-debug-info=./debug-info

flutter build windows --release --split-debug-info=./debug-info
```

### Database Optimization
```sql
-- Run in SQLite
VACUUM;
ANALYZE;
```

---

## Troubleshooting

### macOS Issues

**Issue:** "App is damaged"
```bash
xattr -cr /path/to/pos_erp_system.app
```

**Issue:** Permission denied
```bash
chmod +x /path/to/pos_erp_system.app/Contents/MacOS/pos_erp_system
```

### Windows Issues

**Issue:** Missing DLL
- Ensure Visual C++ Redistributable is installed
- Include all DLLs from Release folder

**Issue:** Port already in use
- Change port in settings
- Kill process using port 8080

---

## Distribution

### macOS
1. Sign the app (required for Gatekeeper)
2. Notarize with Apple (for public distribution)
3. Create DMG installer
4. Distribute DMG file

### Windows
1. Sign with code signing certificate (optional)
2. Create installer with Inno Setup
3. Test on clean Windows installation
4. Distribute installer

---

**✅ Ready for Production!**