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

    // Interceptor chain: order matters
    _dio.interceptors.add(AuthInterceptor());
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
      final data = fromJson != null
          ? fromJson(response.data as Map<String, dynamic>)
          : response.data;
      return (success: true, data: data as T, error: null);
    } catch (e) {
      return _handleError(e);
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
      final data = fromJson != null
          ? fromJson(response.data as Map<String, dynamic>)
          : response.data;
      return (success: true, data: data as T, error: null);
    } catch (e) {
      return _handleError(e);
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
      final data = fromJson != null
          ? fromJson(response.data as Map<String, dynamic>)
          : response.data;
      return (success: true, data: data as T, error: null);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE request
  Future<ApiResult<T>> delete<T>(String path) async {
    try {
      final response = await _dio.delete(path);
      final data = response.data as T;
      return (success: true, data: data, error: null);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Map exceptions to typed Failures
  ApiResult<T> _handleError<T>(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final message = error.message ?? 'Unknown error';

      if (error.type == DioExceptionType.connectionTimeout) {
        return (
          success: false,
          data: null,
          error: NetworkFailure(
            message: 'Connection timeout',
            statusCode: statusCode,
          ),
        );
      } else if (error.type == DioExceptionType.receiveTimeout) {
        return (
          success: false,
          data: null,
          error: NetworkFailure(
            message: 'Request timeout',
            statusCode: statusCode,
          ),
        );
      } else if (statusCode == 401) {
        return (
          success: false,
          data: null,
          error: AuthFailure(message: 'Unauthorized', code: 'unauthorized'),
        );
      } else if (statusCode == 403) {
        return (
          success: false,
          data: null,
          error: AuthFailure(message: 'Forbidden', code: 'forbidden'),
        );
      } else if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        return (
          success: false,
          data: null,
          error: NetworkFailure(message: message, statusCode: statusCode),
        );
      } else if (statusCode != null && statusCode >= 500) {
        return (success: false, data: null, error: ServerFailure(message));
      }
    }

    return (
      success: false,
      data: null,
      error: UnknownFailure(error.toString()),
    );
  }

  /// Raw Dio instance for advanced use cases (e.g., file uploads)
  Dio get client => _dio;
}

/// Interceptor: Attach JWT bearer token to outgoing requests
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

/// Interceptor: Retry failed requests with exponential backoff
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

    // Exponential backoff: 1s, 2s, 4s
    final delayMs = 1000 * (1 << retryCount);
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
}

/// Interceptor: Log requests/responses in debug mode (strip PII)
class LoggingInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    debugPrint('➜ ${options.method} ${options.path}');
    debugPrint('  Headers: ${options.headers}');
    if (options.data != null) {
      final data = options.data.toString();
      // Strip sensitive fields like 'phone', 'password'
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

  String _stripPii(String data) {
    return data
        .replaceAll(RegExp(r'"phone":"[^"]*"'), '"phone":"***"')
        .replaceAll(RegExp(r'"password":"[^"]*"'), '"password":"***"')
        .replaceAll(RegExp(r'"token":"[^"]*"'), '"token":"***"');
  }
}

/// Interceptor: Map HTTP errors to structured responses
class ErrorInterceptor extends Interceptor {
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Let ApiClient._handleError() take over
    handler.next(err);
    return Future<void>.value();
  }
}
