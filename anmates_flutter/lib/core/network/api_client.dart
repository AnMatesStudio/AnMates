import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/failures.dart';
import '../storage/secure_storage_service.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app',
);

/// Typed API result: Either success with data or typed Failure
typedef ApiResult<T> = ({bool success, T? data, Failure? error});

ApiResult<T> _success<T>(T data) => (success: true, data: data, error: null);

ApiResult<T> _failure<T>(Failure error) =>
    (success: false, data: null, error: error);

/// Dio HTTP client with interceptor chain for auth, retry, and error mapping
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Interceptor chain order:
    //   1. AuthInterceptor    — attach Bearer token from SecureStorage
    //   2. RefreshInterceptor — on 401, exchange refresh-token, retry once
    //   3. RetryInterceptor   — exponential backoff (honours Retry-After)
    //   4. LoggingInterceptor — debug-only, scrubs Authorization header
    //   5. ErrorInterceptor   — terminal mapping
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(RefreshInterceptor());
    _dio.interceptors.add(RetryInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(LoggingInterceptor());
    }
    _dio.interceptors.add(ErrorInterceptor());
  }

  factory ApiClient() => _instance;

  /// GET request with type-safe response
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _success(_parse<T>(response.data, fromJson));
    } catch (e) {
      return _failure(_mapError(e));
    }
  }

  /// POST request
  Future<ApiResult<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.post(path, data: body);
      return _success(_parse<T>(response.data, fromJson));
    } catch (e) {
      return _failure(_mapError(e));
    }
  }

  /// PUT request
  Future<ApiResult<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.put(path, data: body);
      return _success(_parse<T>(response.data, fromJson));
    } catch (e) {
      return _failure(_mapError(e));
    }
  }

  /// DELETE request
  Future<ApiResult<T>> delete<T>(String path) async {
    try {
      final response = await _dio.delete(path);
      return _success(response.data as T);
    } catch (e) {
      return _failure(_mapError(e));
    }
  }

  T _parse<T>(dynamic data, T Function(Map<String, dynamic>)? fromJson) {
    if (fromJson != null) {
      return fromJson(data as Map<String, dynamic>);
    }
    return data as T;
  }

  /// Map exceptions to typed Failures
  Failure _mapError(Object error) {
    if (error is! DioException) {
      return UnknownFailure(error.toString());
    }
    final code = error.response?.statusCode;
    final message = error.message ?? 'Unknown error';

    if (error.type == DioExceptionType.connectionTimeout) {
      return NetworkFailure(message: 'Connection timeout', statusCode: code);
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return NetworkFailure(message: 'Request timeout', statusCode: code);
    }
    if (code == 401) {
      return AuthFailure(message: 'Unauthorized', code: 'unauthorized');
    }
    if (code == 403) {
      return AuthFailure(message: 'Forbidden', code: 'forbidden');
    }
    if (code != null && code >= 400 && code < 500) {
      return NetworkFailure(message: message, statusCode: code);
    }
    if (code != null && code >= 500) {
      return ServerFailure(message);
    }
    return UnknownFailure(message);
  }

  /// Raw Dio instance for advanced use cases (e.g., file uploads)
  Dio get client => _dio;
}

/// Interceptor: Attach JWT bearer token to outgoing requests.
class AuthInterceptor extends Interceptor {
  final _secureStorage = SecureStorageService();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Interceptor: On 401, exchange the refresh token for a new access token
/// via `/api/v1/auth/refresh`, then replay the original request exactly
/// once. If refresh itself fails the user gets a clean AuthFailure so the
/// app can navigate to login — never a stuck spinner.
///
/// Single-flight: concurrent 401s queue behind one refresh attempt; all of
/// them retry with the same new token.
class RefreshInterceptor extends Interceptor {
  static const _refreshPath = '/api/v1/auth/refresh';

  final _storage = SecureStorageService();
  Future<bool>? _inFlight;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRefreshed = err.requestOptions.extra['didRefresh'] == true;
    final isRefreshCall = err.requestOptions.path == _refreshPath;

    if (!isUnauthorized || alreadyRefreshed || isRefreshCall) {
      handler.next(err);
      return;
    }

    final refreshedOk = await (_inFlight ??= _performRefresh());
    _inFlight = null;

    if (!refreshedOk) {
      handler.next(err);
      return;
    }

    // Replay the original request with the new token.
    try {
      final newToken = await _storage.accessToken;
      final cloned = err.requestOptions
        ..extra['didRefresh'] = true
        ..headers['Authorization'] = newToken != null
            ? 'Bearer $newToken'
            : null;
      final response = await ApiClient().client.fetch<dynamic>(cloned);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      // Build a one-shot Dio call without the interceptor chain — avoids
      // infinite recursion if the refresh endpoint itself 401s.
      final raw = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 15),
        ),
      );
      final res = await raw.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refresh_token': refreshToken},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final newAccess = data?['access_token'] as String?;
      final newRefresh = data?['refresh_token'] as String? ?? refreshToken;
      if (newAccess == null) return false;
      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } on DioException catch (_) {
      // Refresh failed (token expired / revoked) — clear local state so
      // the next AuthCubit.checkStatus() routes the user to login.
      await _storage.clearAll();
      return false;
    }
  }
}

/// Interceptor: Retry failed requests with exponential backoff. Honours
/// the server-supplied `Retry-After` header on 429 / 503 responses so we
/// don't hammer rate-limited endpoints — RFC 7231 §7.1.3 compliance.
class RetryInterceptor extends Interceptor {
  static const _maxRetries = 3;
  static const _retryableStatusCodes = {408, 429, 500, 502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final isRetryable =
        _retryableStatusCodes.contains(statusCode) ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    final retryCount = (err.requestOptions.extra['retryCount'] ?? 0) as int;

    if (!isRetryable || retryCount >= _maxRetries) {
      handler.next(err);
      return;
    }

    err.requestOptions.extra['retryCount'] = retryCount + 1;

    // Honour Retry-After when present (server is explicit about backoff).
    // Falls back to exponential backoff: 1s, 2s, 4s.
    final retryAfter = _parseRetryAfter(
      err.response?.headers.value('retry-after'),
    );
    final delayMs = retryAfter ?? 1000 * (1 << retryCount);
    await Future<void>.delayed(Duration(milliseconds: delayMs));

    try {
      final response = await ApiClient().client.fetch<dynamic>(
        err.requestOptions,
      );
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }

  /// Parses an HTTP `Retry-After` header value into milliseconds.
  /// Supports both delta-seconds ("120") and HTTP-date formats.
  /// Returns null for unparseable values so the caller can fall back to
  /// its own backoff math.
  int? _parseRetryAfter(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Delta-seconds form (most common).
    final seconds = int.tryParse(raw);
    if (seconds != null && seconds >= 0) {
      // Clamp at 60s — we don't want a misconfigured server to freeze the
      // app for hours.
      return seconds.clamp(0, 60) * 1000;
    }
    // HTTP-date form (RFC 1123).
    try {
      final date = HttpDate.parse(raw);
      final diff = date.difference(DateTime.now()).inMilliseconds;
      if (diff < 0) return 0;
      return diff.clamp(0, 60000);
    } catch (_) {
      return null;
    }
  }
}

/// Interceptor: Log requests/responses in debug mode (strip PII).
/// Authorization headers are NEVER printed — even at debug level — so a
/// stray screenshot or shared log can't leak a Bearer token.
class LoggingInterceptor extends Interceptor {
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    debugPrint('➜ ${options.method} ${options.path}');
    debugPrint('  Headers: ${_scrubHeaders(options.headers)}');
    if (options.data != null) {
      final data = options.data.toString();
      debugPrint('  Body: ${_stripPii(data)}');
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    debugPrint('✓ ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  /// Returns a map suitable for printing where any sensitive header value
  /// has been replaced with `***`.
  Map<String, dynamic> _scrubHeaders(Map<String, dynamic> headers) {
    return headers.map((k, v) {
      if (_sensitiveHeaders.contains(k.toLowerCase())) {
        return MapEntry(k, '***');
      }
      return MapEntry(k, v);
    });
  }

  String _stripPii(String data) {
    return data
        .replaceAll(RegExp(r'"phone":"[^"]*"'), '"phone":"***"')
        .replaceAll(RegExp(r'"password":"[^"]*"'), '"password":"***"')
        .replaceAll(RegExp(r'"token":"[^"]*"'), '"token":"***"')
        .replaceAll(
          RegExp(r'"firebase_token":"[^"]*"'),
          '"firebase_token":"***"',
        )
        .replaceAll(
          RegExp(r'"refresh_token":"[^"]*"'),
          '"refresh_token":"***"',
        );
  }
}

/// Interceptor: Map HTTP errors to structured responses
class ErrorInterceptor extends Interceptor {
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
    return Future<void>.value();
  }
}
