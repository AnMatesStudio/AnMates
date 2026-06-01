import '../../../../core/errors/failures.dart';
import '../entities/match_candidate.dart';
import '../repositories/match_repository.dart';

/// Record a swipe on a candidate.
/// Validates input here so the BLoC stays thin.
class SwipeUseCase {
  final MatchRepository _repo;
  const SwipeUseCase(this._repo);

  Future<Result<SwipeResult>> call({
    required String userId,
    required SwipeAction action,
  }) {
    if (userId.isEmpty) {
      return Future.value(
        Result.failure(const ValidationFailure('userId is required')),
      );
    }
    return _repo.swipe(userId: userId, action: action);
  }
}
