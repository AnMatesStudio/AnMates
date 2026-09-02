import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Backend base URL, baked at build time. Only needed when the API does NOT sit
// behind the same origin as the app — i.e. local docker-compose (web on :54180,
// API on :8080) and native mobile builds:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.216:8080
// The k8s deploy leaves it unset on purpose: nginx in the anmates-web image
// reverse-proxies /api/ + /ws/ to the anmates-api Service, so the app is
// same-origin and resolves its own base at runtime (below). That keeps the
// image domain-agnostic — no rebuild when the public hostname changes.
const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Effective API base URL for this run.
///
/// Always an absolute `http(s)://` value, never a bare relative path:
/// [ApiClient.wsUrl] derives the chat WebSocket URL from it via a scheme
/// `replaceFirst`, and browsers reject a `WebSocket()` whose resolved scheme
/// isn't exactly ws/wss.
String get apiBaseUrl {
  if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
  // Web with no baked URL → the page's own origin (same-origin nginx proxy).
  if (kIsWeb) return Uri.base.origin;
  // Native with no baked URL → local dev backend.
  return 'http://localhost:8080';
}

String get _baseUrl => apiBaseUrl;

class AuthService {
  static final AuthService _instance = AuthService._();
  AuthService._();
  factory AuthService() => _instance;

  // HTTP client — overridable in tests with a MockClient.
  http.Client _client = http.Client();
  @visibleForTesting
  set httpClient(http.Client c) => _client = c;

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<String?> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  /// Whether the signed-in user has finished post-OTP onboarding (Screens 08+09).
  /// Defaults to false when unknown so new users are routed through onboarding.
  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }

  /// Locally marks onboarding as complete (called after Screen 09 persists).
  Future<void> setOnboardingDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', done);
  }

  /// Dev-only: skip real auth via `/api/v1/auth/dev-login`.
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      await _client.post(
        Uri.parse('$_baseUrl/api/v1/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'refresh_token': prefs.getString('refresh_token') ?? '',
        }),
      );
    }
    await clearSession();
  }

  /// Wipes the local session WITHOUT calling the server. Used when the refresh
  /// token is already known-invalid (e.g. expired past the 7-day window) so the
  /// splash can fall back to onboarding cleanly.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('onboarding_done');
  }

  /// Exchanges the stored refresh_token for a fresh access/refresh pair via
  /// `POST /auth/refresh` and persists them. Returns true on success.
  ///
  /// Access tokens live ~15 min; refresh tokens ~7 days (backend config). This
  /// is what keeps a returning user signed in: as long as the refresh token is
  /// still valid, the session is silently renewed. Returns false when there is
  /// no refresh token or the server rejected it (caller treats as logged out).
  Future<bool> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['access_token'] != null) {
      await prefs.setString('access_token', data['access_token'] as String);
    }
    if (data['refresh_token'] != null) {
      await prefs.setString('refresh_token', data['refresh_token'] as String);
    }
    final user = data['user'] as Map<String, dynamic>?;
    final userId = data['user_id'] as String? ?? user?['id'] as String?;
    if (userId != null) {
      await prefs.setString('user_id', userId);
    }
    // Persist server-reported onboarding state so the splash + auth flows can
    // route returning users straight to the main app.
    final onboardingDone = user?['onboarding_done'] as bool?;
    if (onboardingDone != null) {
      await prefs.setBool('onboarding_done', onboardingDone);
    }
  }
}
