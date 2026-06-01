/// Domain entity for a potential match candidate shown in the swipe deck.
/// Pure Dart — no JSON, no Flutter imports.
class MatchCandidate {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int overlapCount;
  final List<String> overlapFoods;

  /// 0.0 – 1.0 algorithmic match score.
  final double score;

  const MatchCandidate({
    required this.userId,
    required this.name,
    required this.overlapCount,
    required this.overlapFoods,
    required this.score,
    this.avatarUrl,
  });

  /// Convenience: 0–100 integer (used by VibeRing UI).
  int get vibeScore => (score * 100).round();

  @override
  bool operator ==(Object other) =>
      other is MatchCandidate &&
      other.userId == userId &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      other.overlapCount == overlapCount &&
      other.score == score;

  @override
  int get hashCode => Object.hash(userId, name, avatarUrl, overlapCount, score);
}

/// Swipe action enum — what the user did on a card.
enum SwipeAction {
  /// Swipe right / tap heart.
  like,

  /// Swipe left / tap X.
  pass,

  /// Special purple sparkle action.
  superLike,
}
