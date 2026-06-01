import '../../../auth/domain/repositories/auth_repository.dart' show Result;
import '../entities/match_candidate.dart';

/// Auth feature's Result<T> is re-used (typed Either-style).
/// In Phase 5 these will move to a shared `core/result.dart` once more
/// features depend on the type.
export '../../../auth/domain/repositories/auth_repository.dart' show Result;

/// Domain contract for the Match feature.
abstract class MatchRepository {
  /// Fetch the next batch of swipe candidates for the current user.
  Future<Result<List<MatchCandidate>>> getCandidates();

  /// Record a swipe action on a candidate.
  /// Returns whether this swipe produced a mutual match.
  Future<Result<SwipeResult>> swipe({
    required String userId,
    required SwipeAction action,
  });
}

/// Outcome of a swipe call to the backend.
class SwipeResult {
  /// True if the other user has also liked the current user => instant match.
  final bool isMutualMatch;

  /// When isMutualMatch is true, the resulting match id (for chat routing).
  final String? matchId;

  const SwipeResult({required this.isMutualMatch, this.matchId});
}
