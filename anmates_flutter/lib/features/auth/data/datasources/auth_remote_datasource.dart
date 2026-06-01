import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/auth_session.dart';

/// Backend REST datasource for auth endpoints.
/// Wraps Dio calls; converts errors into typed Failures.
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient().client;

  /// POST /api/v1/auth/phone-verify
  /// Exchanges a Firebase ID token for an app JWT.
  Future<AuthSession> phoneVerify({
    required String idToken,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/phone-verify',
        data: {'firebase_token': idToken, 'name': name},
      );
      return _sessionFromBody(response.data!);
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Xác thực thất bại');
    }
  }

  /// POST /api/v1/auth/dev-login
  /// Dev-only bypass. Backend rejects if DEV_MODE=false.
  Future<AuthSession> devLogin({
    required String secret,
    required String phone,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/dev-login',
        data: {'secret': secret, 'phone': phone, 'name': name},
      );
      return _sessionFromBody(response.data!);
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Dev login failed');
    }
  }

  /// POST /api/v1/auth/logout
  Future<void> logout({
    required String accessToken,
    String? refreshToken,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/v1/auth/logout',
        data: {'refresh_token': refreshToken ?? ''},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException {
      // Logout failures are tolerable — local tokens still get cleared by repo.
      return;
    }
  }

  AuthSession _sessionFromBody(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw DataParsingFailure('Response missing "data" field');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final userId =
        (data['user_id'] as String?) ??
        (data['user'] as Map<String, dynamic>?)?['id'] as String?;
    if (access == null || userId == null) {
      throw DataParsingFailure('Response missing access_token or user_id');
    }
    return AuthSession(
      userId: userId,
      accessToken: access,
      refreshToken: refresh,
      displayName: (data['user'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Failure _mapToFailure(DioException e, String fallback) {
    final body = e.response?.data;
    String message = fallback;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        message = (err['message'] as String?) ?? fallback;
      }
    }
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return AuthFailure(message: message, code: 'unauthorized');
    }
    if (code != null && code >= 500) {
      return ServerFailure(message);
    }
    return NetworkFailure(message: message, statusCode: code);
  }
}
