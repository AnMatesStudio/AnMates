import '../../domain/entities/match_candidate.dart';

/// Sealed MatchState hierarchy.
sealed class MatchState {
  const MatchState();
}

/// Before any candidates have been fetched.
class MatchInitial extends MatchState {
  const MatchInitial();
}

/// Loading the next batch of candidates.
class MatchLoading extends MatchState {
  const MatchLoading();
}

/// Candidates loaded — the deck is ready for swipes.
/// `currentIndex` points at the top card; the deck advances after each swipe.
class MatchLoaded extends MatchState {
  final List<MatchCandidate> candidates;
  final int currentIndex;

  /// Set when a swipe-right produces a mutual match. UI shows a celebration
  /// overlay until cleared. Non-null only briefly between emit and consume.
  final String? mutualMatchUserId;

  const MatchLoaded({
    required this.candidates,
    this.currentIndex = 0,
    this.mutualMatchUserId,
  });

  /// True when the user has swiped through all loaded candidates.
  bool get isDeckEmpty => currentIndex >= candidates.length;

  /// Candidate at the top of the deck, or null when the deck is empty.
  MatchCandidate? get topCard => isDeckEmpty ? null : candidates[currentIndex];

  MatchLoaded copyWith({
    List<MatchCandidate>? candidates,
    int? currentIndex,
    String? mutualMatchUserId,
    bool clearMutualMatch = false,
  }) {
    return MatchLoaded(
      candidates: candidates ?? this.candidates,
      currentIndex: currentIndex ?? this.currentIndex,
      mutualMatchUserId: clearMutualMatch
          ? null
          : (mutualMatchUserId ?? this.mutualMatchUserId),
    );
  }
}

/// Error loading candidates — UI shows AnmErrorView with retry.
class MatchError extends MatchState {
  final String message;
  const MatchError(this.message);
}
