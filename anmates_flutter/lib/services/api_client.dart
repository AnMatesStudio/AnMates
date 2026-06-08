import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app',
);

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  ApiClient._();
  factory ApiClient() => _instance;

  // HTTP client — overridable in tests with a MockClient.
  http.Client _client = http.Client();
  @visibleForTesting
  set httpClient(http.Client c) => _client = c;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path) => _send(
    (token) =>
        _client.get(Uri.parse('$_baseUrl$path'), headers: _headers(token)),
  );

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) => _send(
    (token) => _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    ),
  );

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) => _send(
    (token) => _client.put(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    ),
  );

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) => _send(
    (token) => _client.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    ),
  );

  Future<dynamic> delete(String path) => _send(
    (token) =>
        _client.delete(Uri.parse('$_baseUrl$path'), headers: _headers(token)),
  );

  /// Runs [request] with the current access token. On a 401 it attempts a single
  /// silent token refresh and replays the request once with the new token, so a
  /// returning user stays signed in transparently until the refresh token itself
  /// expires (~7 days). The refresh is single-flight: concurrent 401s share one
  /// refresh call rather than stampeding `/auth/refresh`.
  Future<dynamic> _send(
    Future<http.Response> Function(String? token) request,
  ) async {
    var res = await request(await _token());
    if (res.statusCode == 401) {
      if (await _refresh()) {
        res = await request(await _token());
      }
    }
    return _parse(res);
  }

  Future<bool>? _refreshing;

  Future<bool> _refresh() =>
      _refreshing ??= AuthService().refreshSession().whenComplete(() {
        _refreshing = null;
      });

  dynamic _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['data'];
    }
    final msg = body['error']?['message'] ?? 'unknown error';
    throw ApiException(res.statusCode, msg);
  }

  // Returns the raw token string for WebSocket use.
  static Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Derive WS scheme from the HTTP base so dev/prod and IP/domain all work.
  static String wsUrl(String matchId) {
    final wsBase = _baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws/chat/$matchId';
  }
}
