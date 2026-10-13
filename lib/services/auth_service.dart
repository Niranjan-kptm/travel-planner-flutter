import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Signed-in Firebase user plus the tokens needed for the REST APIs.
class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String idToken;
  final String refreshToken;
  final int expiresAt; // ms since epoch

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get tokenExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt - 60 * 1000;

  AuthUser copyWith({
    String? email,
    String? displayName,
    String? idToken,
    String? refreshToken,
    int? expiresAt,
  }) =>
      AuthUser(
        uid: uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        idToken: idToken ?? this.idToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
      };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        uid: j['uid'] as String,
        email: (j['email'] as String?) ?? '',
        displayName: (j['displayName'] as String?) ?? '',
        idToken: (j['idToken'] as String?) ?? '',
        refreshToken: (j['refreshToken'] as String?) ?? '',
        expiresAt: ((j['expiresAt'] as num?) ?? 0).toInt(),
      );
}

class AuthException implements Exception {
  /// Firebase error code (e.g. EMAIL_EXISTS) or "network".
  final String code;
  final String message;
  const AuthException(this.code, this.message);

  bool get isNetwork => code == 'network';

  @override
  String toString() => message;
}

/// Firebase Authentication (email/password) through the official
/// Identity Toolkit REST API. Works on Android, iOS and Web (FlutLab) without
/// google-services.json or native SDK setup; only the Web API key is needed.
class AuthService extends ChangeNotifier {
  static const String _sessionKey = 'auth_session_v1';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  AuthUser? _user;
  bool _restoring = true;
  Completer<String?>? _refreshing;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  AuthUser? get currentUser => _user;
  bool get isSignedIn => _user != null;
  bool get isRestoring => _restoring;
  bool get isConfigured => AppConfig.firebaseConfigured;

  Uri _authUri(String method) => Uri.parse(
      '${AppConfig.authBaseUrl}/accounts:$method?key=${AppConfig.effectiveApiKey}');

  // ---------------------------------------------------------------- session

  /// Restores the previous session (if any). If the device is offline the
  /// saved session is kept so local data stays available; tokens are refreshed
  /// when connectivity returns.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        _user = AuthUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        if (_user!.tokenExpired) {
          try {
            await _refresh();
          } on AuthException catch (e) {
            if (!e.isNetwork) await _clearSession();
          }
        }
      }
    } catch (e) {
      debugPrint('restoreSession failed: $e');
      _user = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final u = _user;
    if (u == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(u.toJson()));
    }
  }

  Future<void> _clearSession() async {
    _user = null;
    await _saveSession();
  }

  // ---------------------------------------------------------------- actions

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final data = await _post(_authUri('signUp'), {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    _user = _userFromSignIn(data, displayName: name.trim());
    await _saveSession();
    // Store the display name on the Firebase Auth account as well.
    try {
      await _post(_authUri('update'), {
        'idToken': _user!.idToken,
        'displayName': name.trim(),
        'returnSecureToken': false,
      });
    } on AuthException catch (e) {
      debugPrint('displayName update failed: $e');
    }
    notifyListeners();
    return _user!;
  }

  Future<AuthUser> signIn({required String email, required String password}) async {
    _ensureConfigured();
    final data = await _post(_authUri('signInWithPassword'), {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    _user = _userFromSignIn(data);
    await _saveSession();
    notifyListeners();
    return _user!;
  }

  Future<void> sendPasswordReset(String email) async {
    _ensureConfigured();
    await _post(_authUri('sendOobCode'), {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  Future<void> updateDisplayName(String name) async {
    final token = await getIdToken();
    if (token == null) return;
    await _post(_authUri('update'), {
      'idToken': token,
      'displayName': name.trim(),
      'returnSecureToken': false,
    });
    _user = _user?.copyWith(displayName: name.trim());
    await _saveSession();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearSession();
    notifyListeners();
  }

  /// A valid ID token for database requests, refreshing it when needed.
  /// Returns null when signed out or when the token cannot be refreshed
  /// because the device is offline.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _user;
    if (u == null) return null;
    if (!forceRefresh && !u.tokenExpired) return u.idToken;
    try {
      return await _refresh();
    } on AuthException catch (e) {
      if (!e.isNetwork) {
        await _clearSession();
        notifyListeners();
      }
      return null;
    }
  }

  Future<String?> _refresh() async {
    final pending = _refreshing;
    if (pending != null) return pending.future;
    final completer = Completer<String?>();
    _refreshing = completer;
    completer.future.catchError((Object _) => null);
    try {
      final u = _user;
      if (u == null) {
        completer.complete(null);
        return null;
      }
      final res = await _client
          .post(
            Uri.parse('${AppConfig.tokenUrl}?key=${AppConfig.effectiveApiKey}'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(u.refreshToken)}',
          )
          .timeout(_timeout);
      final data = _decode(res);
      _user = u.copyWith(
        idToken: data['id_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresAt: _expiry(data['expires_in']),
      );
      await _saveSession();
      completer.complete(_user!.idToken);
      return _user!.idToken;
    } on AuthException catch (e) {
      completer.completeError(e);
      rethrow;
    } catch (e) {
      final err = AuthException('network', 'Network error: $e');
      completer.completeError(err);
      throw err;
    } finally {
      _refreshing = null;
    }
  }

  // ---------------------------------------------------------------- helpers

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AuthException('not-configured',
          'Firebase is not configured. Add your Web API key and database URL in lib/config/app_config.dart.');
    }
  }

  AuthUser _userFromSignIn(Map<String, dynamic> d, {String? displayName}) => AuthUser(
        uid: d['localId'] as String,
        email: (d['email'] as String?) ?? '',
        displayName: displayName ?? (d['displayName'] as String?) ?? '',
        idToken: d['idToken'] as String,
        refreshToken: d['refreshToken'] as String,
        expiresAt: _expiry(d['expiresIn']),
      );

  int _expiry(dynamic expiresIn) {
    final secs = int.tryParse('$expiresIn') ?? 3600;
    return DateTime.now().millisecondsSinceEpoch + secs * 1000;
  }

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(_timeout);
    } catch (e) {
      throw AuthException('network',
          'Could not reach Firebase. Check your internet connection and try again.');
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      data = <String, dynamic>{};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final err = data['error'];
    String code = 'HTTP_${res.statusCode}';
    if (err is Map && err['message'] is String) {
      code = err['message'] as String;
    } else if (err is String) {
      code = err.toUpperCase();
    }
    throw AuthException(code, friendlyAuthError(code));
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

/// Maps Firebase Auth REST error codes to readable messages.
String friendlyAuthError(String code) {
  final c = code.split(':').first.trim().split(' ').first;
  switch (c) {
    case 'EMAIL_EXISTS':
      return 'An account already exists for this email. Try logging in.';
    case 'EMAIL_NOT_FOUND':
    case 'INVALID_PASSWORD':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'Incorrect email or password.';
    case 'USER_DISABLED':
      return 'This account has been disabled.';
    case 'TOO_MANY_ATTEMPTS_TRY_LATER':
      return 'Too many attempts. Please wait a few minutes and try again.';
    case 'WEAK_PASSWORD':
      return 'Password is too weak. Use at least 6 characters.';
    case 'INVALID_EMAIL':
      return 'Please enter a valid email address.';
    case 'MISSING_PASSWORD':
      return 'Please enter your password.';
    case 'OPERATION_NOT_ALLOWED':
      return 'Email/password sign-in is disabled. Enable it in Firebase Console > Authentication > Sign-in method.';
    case 'TOKEN_EXPIRED':
    case 'INVALID_REFRESH_TOKEN':
    case 'USER_NOT_FOUND':
    case 'INVALID_ID_TOKEN':
      return 'Your session has expired. Please log in again.';
    case 'CONFIGURATION_NOT_FOUND':
      return 'Firebase Authentication is not enabled for this project.';
    default:
      if (code.contains('API key not valid') || code.contains('API_KEY_INVALID')) {
        return 'The Firebase Web API key is invalid. Check lib/config/app_config.dart.';
      }
      return 'Authentication failed ($code).';
  }
}
