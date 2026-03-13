# 🚀 Deployment Guide

## สารบัญ
1. [Build สำหรับ macOS](#build-สำหรับ-macos)
2. [Build สำหรับ Windows](#build-สำหรับ-windows)
3. [Build สำหรับ Android](#build-สำหรับ-android) ✨ ใหม่
4. [Build สำหรับ iOS](#build-สำหรับ-ios) ✨ ใหม่
5. [Database Migration](#database-migration)
6. [Configuration](#configuration)

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

## Build สำหรับ Android ✨

### Prerequisites
- Android Studio (latest)
- Android SDK (API 21+)
- JDK 17
- Flutter SDK

### 1. Enable Android support
```bash
flutter config --enable-android
flutter devices  # ตรวจสอบ device ที่เชื่อมต่อ
```

### 2. แก้ไข android/app/build.gradle
```gradle
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.yourcompany.pos_erp"
        minSdk 21          // Android 5.0+
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### 3. สร้าง Keystore สำหรับ Sign APK
```bash
keytool -genkey -v \
  -keystore ~/pos-erp-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias pos-erp
```

### 4. สร้างไฟล์ android/key.properties
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=pos-erp
storeFile=/Users/YOUR_NAME/pos-erp-release.jks
```

> ⚠️ อย่า commit ไฟล์นี้ใน Git — เพิ่มใน .gitignore

### 5. อัปเดต android/app/build.gradle ให้ใช้ keystore
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

### 6. เพิ่ม Permissions ใน android/app/src/main/AndroidManifest.xml
```xml
<manifest>
    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Camera (สำหรับ Scanner) -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />

    <!-- Storage (สำหรับ export) -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
</manifest>
```

### 7. Build APK / AAB
```bash
# APK (สำหรับติดตั้งตรง)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# AAB (สำหรับ Google Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# APK แยกตาม ABI (ขนาดเล็กลง)
flutter build apk --split-per-abi --release
```

### 8. ติดตั้งบน Device โดยตรง
```bash
flutter install
# หรือ
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Build สำหรับ iOS ✨

### Prerequisites
- macOS เท่านั้น
- Xcode 15+
- Apple Developer Account (สำหรับ distribution)
- CocoaPods

### 1. Enable iOS support
```bash
flutter config --enable-ios
cd ios && pod install && cd ..
```

### 2. แก้ไข ios/Runner/Info.plist — เพิ่ม Permissions
```xml
<dict>
    <!-- Camera สำหรับ Scanner -->
    <key>NSCameraUsageDescription</key>
    <string>ใช้กล้องสำหรับสแกนบาร์โค้ดและ QR Code</string>

    <!-- Photo Library -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>ใช้สำหรับแนบรูปภาพสินค้า</string>

    <!-- Local Network (สำหรับ connect master server) -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>ใช้สำหรับเชื่อมต่อกับเซิร์ฟเวอร์หลักในเครือข่าย</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_http._tcp</string>
    </array>
</dict>
```

### 3. แก้ไข Deployment Target ใน Xcode
```
Xcode → Runner → General → Minimum Deployments → iOS 13.0
```

หรือใน `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

### 4. Build สำหรับ Simulator (ทดสอบ)
```bash
# เปิด simulator
open -a Simulator

# Run บน simulator
flutter run

# Build สำหรับ simulator
flutter build ios --simulator
```

### 5. Build สำหรับ Device จริง
```bash
# ต้องมี Apple Developer Account และตั้งค่า signing ใน Xcode ก่อน
flutter build ios --release

# Output: build/ios/iphoneos/Runner.app
```

### 6. Archive & Export ผ่าน Xcode
```
1. flutter build ios --release
2. เปิด Xcode → open ios/Runner.xcworkspace
3. Product → Archive
4. Distribute App → App Store Connect หรือ Ad Hoc
```

### 7. TestFlight (Beta Distribution)
```bash
# ใช้ Transporter หรือ Xcode Organizer
# Upload .ipa ไปยัง App Store Connect
# เพิ่ม testers ใน TestFlight
```

---

## pubspec.yaml — Mobile Dependencies

เพิ่ม dependencies สำหรับ mobile:
```yaml
dependencies:
  # Barcode/QR Scanner
  mobile_scanner: ^6.0.0

  # Printing (สำหรับ receipt)
  printing: ^5.13.0
  pdf: ^3.11.0

  # Share/Export
  share_plus: ^10.0.0

  # File picker
  file_picker: ^8.0.0

  # Permission handler
  permission_handler: ^11.3.0
```

```bash
flutter pub get
```

---

## Database Migration

### Initial Setup
Database is created automatically on first run with seed data.

### Manual Database Reset
```bash
# macOS:
rm ~/Library/Application\ Support/com.example.posErpSystem/app_database.db

# Windows:
del %APPDATA%\pos_erp_system\app_database.db

# Android:
adb shell rm /data/data/com.yourcompany.pos_erp/databases/app_database.db

# iOS (Simulator):
# ลบ app แล้วติดตั้งใหม่
```

### Backup Database
```bash
# macOS:
cp ~/Library/Application\ Support/com.example.posErpSystem/app_database.db \
   ~/Desktop/backup_$(date +%Y%m%d).db

# Windows:
copy %APPDATA%\pos_erp_system\app_database.db ^
     %USERPROFILE%\Desktop\backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.db

# Android (adb):
adb pull /data/data/com.yourcompany.pos_erp/databases/app_database.db ./backup.db
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
# macOS
flutter build macos --release --split-debug-info=./debug-info

# Windows
flutter build windows --release --split-debug-info=./debug-info

# Android (ขนาดเล็กสุด)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info

# iOS
flutter build ios --release --obfuscate --split-debug-info=./debug-info
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

### Android Issues

**Issue:** `Cleartext HTTP traffic not permitted`

เพิ่มใน `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:usesCleartextTraffic="true">
```
หรือสร้าง `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">192.168.1.0</domain>
    </domain-config>
</network-security-config>
```

**Issue:** Build failed - Gradle version
```bash
cd android && ./gradlew wrapper --gradle-version=8.0
```

### iOS Issues

**Issue:** CocoaPods not found
```bash
sudo gem install cocoapods
cd ios && pod install
```

**Issue:** Signing certificate not found
```
Xcode → Preferences → Accounts → เพิ่ม Apple ID
Runner → Signing & Capabilities → Team → เลือก Team
```

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

### Android
1. Build AAB (`flutter build appbundle`)
2. Upload ไปยัง Google Play Console
3. ผ่าน Internal Testing → Closed Testing → Production

### iOS
1. Archive ผ่าน Xcode Organizer
2. Upload ไปยัง App Store Connect
3. TestFlight → App Store Review → Release

---

**✅ Ready for Production! (Desktop + Mobile)**