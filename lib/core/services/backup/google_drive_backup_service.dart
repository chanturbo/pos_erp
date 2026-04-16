import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_storage_provider.dart';
import 'models/backup_manifest.dart';

// ═══════════════════════════════════════════════════════════════════
// 🔑 Google OAuth Client IDs — ตั้งค่าโดย Developer ครั้งเดียว
//    สร้างที่ https://console.cloud.google.com/
//    APIs & Services → Credentials → Create Credentials → OAuth Client ID
//
//    macOS  : Application type = "macOS"
//    iOS    : Application type = "iOS"
//    Android: Application type = "Android" (ต้องใส่ SHA-1 fingerprint)
//    Windows: Application type = "Desktop app" (ได้ client_secret มาด้วย)
//
//    หลังสร้างแล้ว แทนที่ค่า YOUR_XXX ด้านล่างด้วยค่าจริง
//    macOS/iOS: อัปเดต REVERSED_CLIENT_ID ใน Info.plist ด้วย
// ═══════════════════════════════════════════════════════════════════
const _kClientIdMacOS = 'YOUR_MACOS_CLIENT_ID.apps.googleusercontent.com';
const _kClientIdIOS = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';
const _kClientIdAndroid = 'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com';
const _kClientIdWindows = 'YOUR_WINDOWS_CLIENT_ID.apps.googleusercontent.com';
const _kClientSecretWindows = 'YOUR_WINDOWS_CLIENT_SECRET';

// SharedPreferences keys
const _kGoogleDriveLastEmail = 'google_drive_last_email';
const _kWinAccessToken = 'gd_win_access_token';
const _kWinRefreshToken = 'gd_win_refresh_token';
const _kWinTokenExpiry = 'gd_win_token_expiry';

// Google OAuth endpoints
const _kAuthEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
const _kTokenEndpoint = 'https://oauth2.googleapis.com/token';

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>((
  ref,
) {
  return GoogleDriveBackupService(Dio());
});

class GoogleDriveSession {
  final String email;
  final String? displayName;

  const GoogleDriveSession({required this.email, required this.displayName});
}

class GoogleDriveUploadResult {
  final String fileId;
  final String fileName;

  const GoogleDriveUploadResult({required this.fileId, required this.fileName});
}

class DriveBackupItem {
  final String fileId;
  final String fileName;
  final String? backupId;
  final String? companyName;
  final String? createdAt;
  final String? uploadedBy;
  final int fileSize;

  const DriveBackupItem({
    required this.fileId,
    required this.fileName,
    this.backupId,
    this.companyName,
    this.createdAt,
    this.uploadedBy,
    required this.fileSize,
  });

  factory DriveBackupItem.fromJson(Map<String, dynamic> json) {
    final props = json['appProperties'] as Map<String, dynamic>? ?? {};
    final sizeStr = json['size'] as String?;
    return DriveBackupItem(
      fileId: json['id'] as String? ?? '',
      fileName: json['name'] as String? ?? '',
      backupId: props['backup_id'] as String?,
      companyName: props['company_name'] as String?,
      createdAt: props['created_at'] as String?,
      uploadedBy: props['uploaded_by'] as String?,
      fileSize: int.tryParse(sizeStr ?? '0') ?? 0,
    );
  }
}

class GoogleDriveBackupService implements BackupStorageProvider {
  static const _scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
    'email',
    'openid',
  ];
  static const _scopeAppData =
      'https://www.googleapis.com/auth/drive.appdata';
  static const _scopeProfile = 'email';

  final Dio _dio;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  // google_sign_in session (non-Windows)
  bool _gsiInitialized = false;
  GoogleSignInAccount? _gsiUser;

  GoogleDriveBackupService(this._dio);

  @override
  String get id => 'google_drive';

  @override
  String get displayName => 'Google Drive';

  bool get isPlatformSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  bool get _isWindows => Platform.isWindows;

  String get _platformClientId {
    if (Platform.isMacOS) return _kClientIdMacOS;
    if (Platform.isIOS) return _kClientIdIOS;
    if (Platform.isAndroid) return _kClientIdAndroid;
    if (Platform.isWindows) return _kClientIdWindows;
    throw const GoogleDriveBackupException(
      'แพลตฟอร์มนี้ยังไม่รองรับ Google Drive backup',
    );
  }

  bool get _isClientIdConfigured =>
      !_platformClientId.startsWith('YOUR_');

  // ─────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────

  Future<String?> loadLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGoogleDriveLastEmail);
  }

  Future<GoogleDriveSession?> tryRestoreSession() async {
    if (!isPlatformSupported || !_isClientIdConfigured) return null;
    if (_isWindows) {
      return _tryRestoreWindowsSession();
    } else {
      return _tryRestoreGsiSession();
    }
  }

  Future<GoogleDriveSession> signIn() async {
    if (!isPlatformSupported) {
      throw const GoogleDriveBackupException(
        'แพลตฟอร์มนี้ยังไม่รองรับ Google Drive backup',
      );
    }
    if (!_isClientIdConfigured) {
      throw const GoogleDriveBackupException(
        'Google Client ID ยังไม่ได้ตั้งค่า กรุณาติดต่อผู้พัฒนาแอป',
      );
    }
    if (_isWindows) {
      return _signInWindows();
    } else {
      return _signInGsi();
    }
  }

  Future<void> signOut() async {
    if (_isWindows) {
      await _signOutWindows();
    } else {
      await _signOutGsi();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGoogleDriveLastEmail);
  }

  @override
  Future<void> upload({
    required File encryptedBackupFile,
    required BackupManifest manifest,
  }) async {
    await uploadBackupFile(
      encryptedBackupFile: encryptedBackupFile,
      manifest: manifest,
    );
  }

  Future<GoogleDriveUploadResult> uploadBackupFile({
    required File encryptedBackupFile,
    required BackupManifest manifest,
  }) async {
    final session = await signIn();
    final accessToken = await _getAccessToken();
    final fileSize = await encryptedBackupFile.length();
    final fileName = p.basename(encryptedBackupFile.path);
    final metadata = {
      'name': fileName,
      'parents': ['appDataFolder'],
      'appProperties': {
        'backup_id': manifest.backupId,
        'company_name': manifest.companyName,
        'created_at': manifest.createdAt,
        'uploaded_by': session.email,
      },
    };

    final startResponse = await _dio.post<dynamic>(
      'https://www.googleapis.com/upload/drive/v3/files',
      queryParameters: const {'uploadType': 'resumable'},
      data: jsonEncode(metadata),
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $accessToken',
          'X-Upload-Content-Type': 'application/octet-stream',
          'X-Upload-Content-Length': '$fileSize',
          HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        },
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final locationHeader = startResponse.headers.value(
      HttpHeaders.locationHeader,
    );
    if (locationHeader == null || locationHeader.isEmpty) {
      throw const GoogleDriveBackupException(
        'Google Drive ไม่ส่งตำแหน่ง upload session กลับมา',
      );
    }

    final bytes = await encryptedBackupFile.readAsBytes();
    final uploadResponse = await _dio.put<dynamic>(
      locationHeader,
      data: Stream.fromIterable(<List<int>>[bytes]),
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $accessToken',
          HttpHeaders.contentLengthHeader: '$fileSize',
          HttpHeaders.contentTypeHeader: 'application/octet-stream',
        },
        responseType: ResponseType.json,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final data = uploadResponse.data as Map<String, dynamic>? ?? const {};
    final fileId = data['id'] as String?;
    if (fileId == null || fileId.isEmpty) {
      throw const GoogleDriveBackupException(
        'อัปโหลดขึ้น Google Drive สำเร็จแต่ไม่ได้รับ file id',
      );
    }

    return GoogleDriveUploadResult(fileId: fileId, fileName: fileName);
  }

  Future<List<DriveBackupItem>> listBackups({int pageSize = 20}) async {
    final accessToken = await _getAccessToken();
    final response = await _dio.get<dynamic>(
      'https://www.googleapis.com/drive/v3/files',
      queryParameters: {
        'spaces': 'appDataFolder',
        'fields': 'files(id,name,size,createdTime,appProperties)',
        'pageSize': pageSize,
        'orderBy': 'createdTime desc',
      },
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        },
        responseType: ResponseType.json,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final files = data['files'] as List? ?? [];
    return files
        .map((f) => DriveBackupItem.fromJson(f as Map<String, dynamic>))
        .where(
          (item) =>
              item.fileId.isNotEmpty && item.fileName.endsWith('.posbak'),
        )
        .toList();
  }

  Future<File> downloadBackup({
    required String fileId,
    required String fileName,
  }) async {
    final accessToken = await _getAccessToken();
    final tempDir = await getTemporaryDirectory();
    final destFile = File(
      p.join(tempDir.path, 'drive_restore_$fileId.posbak'),
    );
    if (destFile.existsSync()) await destFile.delete();

    await _dio.download(
      'https://www.googleapis.com/drive/v3/files/$fileId',
      destFile.path,
      queryParameters: {'alt': 'media'},
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    return destFile;
  }

  // ─────────────────────────────────────────────────────────────────
  // Access Token abstraction
  // ─────────────────────────────────────────────────────────────────

  Future<String> _getAccessToken() async {
    if (_isWindows) {
      return _getWindowsAccessToken();
    } else {
      return _getGsiAccessToken();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Windows: flutter_appauth path
  // ─────────────────────────────────────────────────────────────────

  Future<GoogleDriveSession?> _tryRestoreWindowsSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_kWinRefreshToken);
    if (refreshToken == null) return null;
    try {
      await _refreshWindowsToken(refreshToken);
      final email = prefs.getString(_kGoogleDriveLastEmail);
      if (email == null) return null;
      return GoogleDriveSession(email: email, displayName: null);
    } catch (_) {
      return null;
    }
  }

  Future<GoogleDriveSession> _signInWindows() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _kClientIdWindows,
        'http://127.0.0.1/',
        clientSecret: _kClientSecretWindows,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _kAuthEndpoint,
          tokenEndpoint: _kTokenEndpoint,
        ),
        scopes: _scopes,
        promptValues: ['select_account'],
      ),
    );

    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const GoogleDriveBackupException(
        'ไม่สามารถรับ access token จาก Google ได้',
      );
    }

    await _saveWindowsTokens(result);

    final email = _parseEmailFromIdToken(result.idToken) ??
        await _fetchEmailFromUserInfo(accessToken);
    if (email == null) {
      throw const GoogleDriveBackupException(
        'ไม่สามารถดึงอีเมลจาก Google ได้',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoogleDriveLastEmail, email);

    return GoogleDriveSession(email: email, displayName: null);
  }

  Future<void> _signOutWindows() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWinAccessToken);
    await prefs.remove(_kWinRefreshToken);
    await prefs.remove(_kWinTokenExpiry);
  }

  Future<String> _getWindowsAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_kWinTokenExpiry) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < expiry - 60000) {
      final token = prefs.getString(_kWinAccessToken);
      if (token != null && token.isNotEmpty) return token;
    }

    final refreshToken = prefs.getString(_kWinRefreshToken);
    if (refreshToken != null) {
      return _refreshWindowsToken(refreshToken);
    }

    throw const GoogleDriveBackupException(
      'กรุณาเชื่อมต่อ Google Drive ใหม่',
    );
  }

  Future<String> _refreshWindowsToken(String refreshToken) async {
    final result = await _appAuth.token(
      TokenRequest(
        _kClientIdWindows,
        'http://127.0.0.1/',
        clientSecret: _kClientSecretWindows,
        refreshToken: refreshToken,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _kAuthEndpoint,
          tokenEndpoint: _kTokenEndpoint,
        ),
        scopes: _scopes,
      ),
    );

    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const GoogleDriveBackupException(
        'ต่ออายุ token ไม่สำเร็จ กรุณาเชื่อมต่อใหม่',
      );
    }

    await _saveWindowsTokens(result);
    return accessToken;
  }

  Future<void> _saveWindowsTokens(TokenResponse result) async {
    final prefs = await SharedPreferences.getInstance();
    if (result.accessToken != null) {
      await prefs.setString(_kWinAccessToken, result.accessToken!);
    }
    if (result.refreshToken != null) {
      await prefs.setString(_kWinRefreshToken, result.refreshToken!);
    }
    final expiry = result.accessTokenExpirationDateTime?.millisecondsSinceEpoch;
    if (expiry != null) {
      await prefs.setInt(_kWinTokenExpiry, expiry);
    }
  }

  String? _parseEmailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      final claims = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      return claims['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchEmailFromUserInfo(String accessToken) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://www.googleapis.com/oauth2/v3/userinfo',
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $accessToken',
          },
          responseType: ResponseType.json,
        ),
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      return data['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Non-Windows: google_sign_in path
  // ─────────────────────────────────────────────────────────────────

  Future<void> _initGsi() async {
    if (_gsiInitialized) return;
    await GoogleSignIn.instance.initialize(clientId: _platformClientId);
    _gsiInitialized = true;
  }

  Future<GoogleDriveSession?> _tryRestoreGsiSession() async {
    await _initGsi();
    final user = await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (user == null) return null;
    _gsiUser = user;
    return GoogleDriveSession(
      email: user.email,
      displayName: user.displayName,
    );
  }

  Future<GoogleDriveSession> _signInGsi() async {
    await _initGsi();

    var user = _gsiUser;
    user ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (user == null) {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const GoogleDriveBackupException(
          'แพลตฟอร์มนี้ต้องใช้ UI login ของปลั๊กอินโดยตรง',
        );
      }
      user = await GoogleSignIn.instance.authenticate(
        scopeHint: const [_scopeAppData],
      );
    }
    _gsiUser = user;

    final auth = await _authorizeGsi(user);
    if (auth.accessToken.isEmpty) {
      throw const GoogleDriveBackupException(
        'ไม่สามารถขอ access token สำหรับ Google Drive ได้',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoogleDriveLastEmail, user.email);

    return GoogleDriveSession(email: user.email, displayName: user.displayName);
  }

  Future<void> _signOutGsi() async {
    await GoogleSignIn.instance.signOut();
    _gsiUser = null;
  }

  Future<String> _getGsiAccessToken() async {
    final user = _gsiUser;
    if (user == null) {
      throw const GoogleDriveBackupException(
        'กรุณาเชื่อมต่อ Google Drive ก่อนใช้งาน',
      );
    }
    final auth = await _authorizeGsi(user);
    return auth.accessToken;
  }

  Future<GoogleSignInClientAuthorization> _authorizeGsi(
    GoogleSignInAccount user,
  ) async {
    const scopes = <String>[_scopeAppData, _scopeProfile];
    var authorization =
        await user.authorizationClient.authorizationForScopes(scopes);
    authorization ??= await user.authorizationClient.authorizeScopes(scopes);
    return authorization;
  }
}

class GoogleDriveBackupException implements Exception {
  final String message;

  const GoogleDriveBackupException(this.message);

  @override
  String toString() => message;
}
