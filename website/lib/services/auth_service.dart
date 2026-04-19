import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  // สร้าง instance เดียวตลอด lifecycle ของ app ป้องกัน GSI initialize ซ้ำ
  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignInAccount? _user;
  GoogleSignInAccount? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> tryRestoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      _user = account;
    } catch (_) {}
  }

  Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      _user = account;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
  }
}
