import '../../../../core/errors/failures.dart';
import '../../domain/entities/match_candidate.dart';
import '../../domain/repositories/match_repository.dart';
import '../datasources/match_remote_datasource.dart';

class MatchRepositoryImpl implements MatchRepository {
  final MatchRemoteDataSource _remote;

  MatchRepositoryImpl({required MatchRemoteDataSource remote})
    : _remote = remote;

  @override
  Future<Result<List<MatchCandidate>>> getCandidates() async {
    try {
      final candidates = await _remote.getCandidates();
      return Result.success(candidates);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<SwipeResult>> swipe({
    required String userId,
    required SwipeAction action,
  }) async {
    try {
      final result = await _remote.swipe(userId: userId, action: action);
      return Result.success(result);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }
}
