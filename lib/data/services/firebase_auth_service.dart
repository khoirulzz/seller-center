import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/api_exception.dart';

class PasswordRuleCheck {
  const PasswordRuleCheck({required this.label, required this.isMet});
  final String label;
  final bool isMet;
}

class FirebaseSession {
  const FirebaseSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.emailVerified,
    required this.expiresAt,
  });

  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final bool emailVerified;
  final DateTime expiresAt;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'emailVerified': emailVerified,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory FirebaseSession.fromJson(Map<String, dynamic> json) {
    return FirebaseSession(
      uid: (json['uid'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      idToken: (json['idToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      emailVerified: json['emailVerified'] == true,
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

/// Layanan autentikasi Firebase Identity Toolkit REST (`nalarostore`) yang
/// menghasilkan Firebase ID Token RS256 resmi untuk diverifikasi Cloudflare Worker.
class FirebaseAuthService {
  FirebaseAuthService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Aturan kebijakan kata sandi proyek `nalarostore` (`src/lib/firebase.ts`).
  static List<PasswordRuleCheck> evaluatePasswordRules(String password) {
    return [
      PasswordRuleCheck(
        label: 'Minimal 8 karakter',
        isMet: password.length >= 8 && password.length <= 4096,
      ),
      PasswordRuleCheck(
        label: 'Huruf besar (A–Z)',
        isMet: RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        label: 'Huruf kecil (a–z)',
        isMet: RegExp(r'[a-z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        label: 'Angka (0–9)',
        isMet: RegExp(r'[0-9]').hasMatch(password),
      ),
    ];
  }

  static bool isPasswordPolicySatisfied(String password) {
    return evaluatePasswordRules(password).every((r) => r.isMet);
  }

  Uri _identityUri(String endpoint) {
    return Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/$endpoint?key=${AppConfig.firebaseApiKey}',
    );
  }

  Future<FirebaseSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _http.post(
      _identityUri('accounts:signInWithPassword'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final body = _decodeJson(response);
    if (response.statusCode != 200) {
      final code = _extractFirebaseErrorCode(body);
      throw ApiException(
        message: code,
        statusCode: response.statusCode,
        machineCode: code,
      );
    }

    final idToken = (body['idToken'] ?? '').toString();
    final verified = await _lookupEmailVerified(idToken);
    final expiresInSec =
        int.tryParse((body['expiresIn'] ?? '3600').toString()) ?? 3600;

    return FirebaseSession(
      uid: (body['localId'] ?? '').toString(),
      email: (body['email'] ?? email.trim()).toString(),
      idToken: idToken,
      refreshToken: (body['refreshToken'] ?? '').toString(),
      emailVerified: verified,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSec)),
    );
  }

  Future<FirebaseSession> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (!isPasswordPolicySatisfied(password)) {
      throw const ApiException(
        message: 'Kata sandi belum memenuhi persyaratan.',
        statusCode: 400,
        machineCode: 'WEAK_PASSWORD',
      );
    }

    final response = await _http.post(
      _identityUri('accounts:signUp'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final body = _decodeJson(response);
    if (response.statusCode != 200) {
      final code = _extractFirebaseErrorCode(body);
      throw ApiException(
        message: code,
        statusCode: response.statusCode,
        machineCode: code,
      );
    }

    final idToken = (body['idToken'] ?? '').toString();
    await sendEmailVerification(idToken);
    final expiresInSec =
        int.tryParse((body['expiresIn'] ?? '3600').toString()) ?? 3600;

    return FirebaseSession(
      uid: (body['localId'] ?? '').toString(),
      email: (body['email'] ?? email.trim()).toString(),
      idToken: idToken,
      refreshToken: (body['refreshToken'] ?? '').toString(),
      emailVerified: false,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSec)),
    );
  }

  Future<void> sendEmailVerification(String idToken) async {
    final response = await _http.post(
      _identityUri('accounts:sendOobCode'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'requestType': 'VERIFY_EMAIL', 'idToken': idToken}),
    );
    if (response.statusCode != 200) {
      final body = _decodeJson(response);
      final code = _extractFirebaseErrorCode(body);
      throw ApiException(
        message: code,
        statusCode: response.statusCode,
        machineCode: code,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final response = await _http.post(
      _identityUri('accounts:sendOobCode'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email.trim(),
      }),
    );
    if (response.statusCode != 200) {
      final body = _decodeJson(response);
      final code = _extractFirebaseErrorCode(body);
      if (code == 'EMAIL_NOT_FOUND') return;
      throw ApiException(
        message: code,
        statusCode: response.statusCode,
        machineCode: code,
      );
    }
  }

  Future<void> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isPasswordPolicySatisfied(newPassword)) {
      throw const ApiException(
        message: 'Kata sandi baru belum memenuhi persyaratan.',
        statusCode: 400,
        machineCode: 'WEAK_PASSWORD',
      );
    }
    final reauth = await signInWithPassword(
      email: email,
      password: currentPassword,
    );
    final response = await _http.post(
      _identityUri('accounts:update'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'idToken': reauth.idToken,
        'password': newPassword,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode != 200) {
      final body = _decodeJson(response);
      final code = _extractFirebaseErrorCode(body);
      throw ApiException(
        message: code,
        statusCode: response.statusCode,
        machineCode: code,
      );
    }
  }

  Future<FirebaseSession> refreshSession(FirebaseSession current) async {
    final response = await _http.post(
      Uri.parse(
        'https://securetoken.googleapis.com/v1/token?key=${AppConfig.firebaseApiKey}',
      ),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': current.refreshToken,
      },
    );
    final body = _decodeJson(response);
    if (response.statusCode != 200) {
      throw const ApiException(
        message: 'Sesi berakhir. Masuk kembali untuk melanjutkan.',
        statusCode: 401,
      );
    }
    final idToken = (body['id_token'] ?? '').toString();
    final verified = await _lookupEmailVerified(idToken);
    final expiresInSec =
        int.tryParse((body['expires_in'] ?? '3600').toString()) ?? 3600;

    return FirebaseSession(
      uid: (body['user_id'] ?? current.uid).toString(),
      email: current.email,
      idToken: idToken,
      refreshToken: (body['refresh_token'] ?? current.refreshToken).toString(),
      emailVerified: verified,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSec)),
    );
  }

  Future<bool> _lookupEmailVerified(String idToken) async {
    final response = await _http.post(
      _identityUri('accounts:lookup'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode != 200) return false;
    final body = _decodeJson(response);
    final users = (body['users'] as List<dynamic>?) ?? const [];
    if (users.isEmpty) return false;
    final first = users.first as Map<String, dynamic>;
    return first['emailVerified'] == true;
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  String _extractFirebaseErrorCode(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is Map<String, dynamic>) {
      return (err['message'] ?? 'UNKNOWN').toString();
    }
    return 'UNKNOWN';
  }
}
