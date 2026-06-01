import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final token = await _token();
    final res = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<dynamic> delete(String path) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
    );
    return _parse(res);
  }

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
