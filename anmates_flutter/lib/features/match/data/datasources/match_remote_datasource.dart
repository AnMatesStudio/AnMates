import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/match_candidate.dart';
import '../../domain/repositories/match_repository.dart';

/// Backend REST datasource for the match feature.
/// Parses raw JSON into domain entities; raises typed Failures on error.
class MatchRemoteDataSource {
  final Dio _dio;

  MatchRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient().client;

  /// GET /api/v1/matches — returns candidates for the current user.
  Future<List<MatchCandidate>> getCandidates() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/matches');
      final list = (response.data?['data'] as List?) ?? const [];
      return list
          .map((e) => _candidateFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Không tải được danh sách candidate');
    }
  }

  /// POST /api/v1/matches/:userId/accept (like)
  /// POST /api/v1/matches/:userId/pass (pass)
  /// POST /api/v1/matches/:userId/super (super-like)
  Future<SwipeResult> swipe({
    required String userId,
    required SwipeAction action,
  }) async {
    final endpoint = switch (action) {
      SwipeAction.like => '/api/v1/matches/$userId/accept',
      SwipeAction.pass => '/api/v1/matches/$userId/pass',
      SwipeAction.superLike => '/api/v1/matches/$userId/super',
    };
    try {
      final response = await _dio.post<Map<String, dynamic>>(endpoint);
      final data = response.data?['data'] as Map<String, dynamic>?;
      return SwipeResult(
        isMutualMatch: (data?['mutual_match'] as bool?) ?? false,
        matchId: data?['match_id'] as String?,
      );
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Swipe thất bại');
    }
  }

  MatchCandidate _candidateFromJson(Map<String, dynamic> j) {
    try {
      return MatchCandidate(
        userId: j['user_id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        overlapCount: (j['overlap_count'] as num?)?.toInt() ?? 0,
        overlapFoods:
            (j['overlap_foods'] as List?)?.map((e) => e as String).toList() ??
            const [],
        score: (j['score'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      throw DataParsingFailure('Malformed candidate: $e');
    }
  }

  Failure _mapToFailure(DioException e, String fallback) {
    final body = e.response?.data;
    var message = fallback;
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
