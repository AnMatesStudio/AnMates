import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/di/injection.dart';
import '../core/storage/secure_storage_service.dart';

/// Backend base URL. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.216:8080
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app',
);

/// Public copy for tests + dev-only flows (e.g. dev-login button).
const apiBaseUrl = _baseUrl;

/// Legacy auth service retained for views not yet migrated to AuthCubit.
///
/// All token I/O now goes through [SecureStorageService] (encrypted) —
/// the previous SharedPreferences-based path was the plaintext-JWT
/// vulnerability flagged in the security audit.
class AuthService {
  static final AuthService _instance = AuthService._();
  AuthService._();
  factory AuthService() => _instance;

  SecureStorageService get _storage =>
      getIt.isRegistered<SecureStorageService>()
      ? getIt<SecureStorageService>()
      : SecureStorageService();

  static const _userIdKey = 'user_id';

  Future<bool> isLoggedIn() async {
    final token = await _storage.accessToken;
    return token != null && token.isNotEmpty;
  }

  Future<String?> currentUserId() => _storage.read(_userIdKey);

  /// Xác thực Firebase ID token với backend, trả về JWT.
  /// [firebaseToken] — ID token từ Firebase Auth sau khi verify OTP.
  /// [name] — Tên hiển thị, dùng khi tạo tài khoản mới.
  Future<Map<String, dynamic>> phoneVerify(
    String firebaseToken, {
    String name = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/phone-verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'firebase_token': firebaseToken, 'name': name}),
    );
    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['error']?['message'] ?? 'xác thực thất bại';
      throw Exception(msg);
    }
    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
    await _saveTokens(data);
    return data;
  }

  /// Dev-only: skip Firebase OTP via `/api/v1/auth/dev-login`.
  /// Backend gates the route with `DEV_MODE=true` + matching `DEV_BYPASS_SECRET`.
  Future<Map<String, dynamic>> devLogin({
    required String secret,
    String phone = '+84999000001',
    String name = 'Dev User',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/dev-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'secret': secret, 'phone': phone, 'name': name}),
    );
    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['error']?['message'] ?? 'dev login failed';
      throw Exception(msg);
    }
    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
    await _saveTokens(data);
    return data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['error']?['message'] ?? 'login failed';
      throw Exception(msg);
    }
    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
    await _saveTokens(data);
    return data;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    if (res.statusCode != 201) {
      final msg =
          jsonDecode(res.body)['error']?['message'] ?? 'register failed';
      throw Exception(msg);
    }
    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
    await _saveTokens(data);
    return data;
  }

  Future<void> logout() async {
    final token = await _storage.accessToken;
    final refresh = await _storage.refreshToken;
    if (token != null) {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'refresh_token': refresh ?? ''}),
      );
    }
    await _storage.clearAll();
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access != null) {
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    }
    final userId =
        data['user_id'] as String? ??
        (data['user'] as Map<String, dynamic>?)?['id'] as String?;
    if (userId != null) {
      await _storage.write(_userIdKey, userId);
    }
  }
}
