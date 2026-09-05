import 'api_client.dart';

class MatchCandidate {
  final String userId;
  final String name;
  final String? avatarUrl;

  /// Whole years, computed server-side from birth_date — null when the
  /// candidate never set one. Never guessed or defaulted client-side.
  final int? age;

  /// The candidate's own onboarding tags (food_tags + vibe_tags) — real
  /// preference data, not an invented personality blurb.
  final List<String> tags;
  final int overlapCount;
  final List<String> overlapFoods;
  final double score;

  MatchCandidate({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.age,
    required this.tags,
    required this.overlapCount,
    required this.overlapFoods,
    required this.score,
  });

  factory MatchCandidate.fromJson(Map<String, dynamic> j) => MatchCandidate(
    userId: j['user_id'] as String,
    name: j['name'] as String,
    avatarUrl: j['avatar_url'] as String?,
    age: (j['age'] as num?)?.toInt(),
    tags: [
      ...?(j['food_tags'] as List?)?.whereType<String>(),
      ...?(j['vibe_tags'] as List?)?.whereType<String>(),
    ],
    overlapCount: j['overlap_count'] as int,
    overlapFoods:
        (j['overlap_foods'] as List?)?.map((e) => e as String).toList() ?? [],
    score: (j['score'] as num).toDouble(),
  );

  /// Real taste-overlap percentage — how much of the union of both users'
  /// interests is shared. Used as the swipe card's "% hợp gu" figure.
  int get matchPct => (score * 100).round();
}

class ApiMatch {
  final String id;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final double score;
  final DateTime createdAt;

  ApiMatch({
    required this.id,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.score,
    required this.createdAt,
  });

  factory ApiMatch.fromJson(Map<String, dynamic> j) => ApiMatch(
    id: j['match_id'] as String,
    partnerName: j['partner_name'] as String,
    partnerAvatarUrl: j['partner_avatar_url'] as String?,
    lastMessage: j['last_message'] as String?,
    lastMessageAt: j['last_message_at'] != null
        ? DateTime.parse(j['last_message_at'] as String)
        : null,
    score: (j['score'] as num).toDouble(),
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class ApiMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final String msgType;
  final DateTime createdAt;

  ApiMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.msgType,
    required this.createdAt,
  });

  factory ApiMessage.fromJson(Map<String, dynamic> j) => ApiMessage(
    id: j['id'] as String,
    matchId: j['match_id'] as String,
    senderId: j['sender_id'] as String,
    content: j['content'] as String,
    msgType: j['msg_type'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

/// Result of a like swipe. [matched] is true only when the other user had
/// already liked back; [matchId] is then the created/existing match id.
class SwipeResult {
  final bool matched;
  final String? matchId;
  SwipeResult({required this.matched, this.matchId});

  factory SwipeResult.fromJson(Map<String, dynamic> j) => SwipeResult(
    matched: j['matched'] as bool? ?? false,
    matchId: (j['match'] as Map<String, dynamic>?)?['id'] as String?,
  );
}

class MatchService {
  static final MatchService _instance = MatchService._();
  MatchService._();
  factory MatchService() => _instance;

  final _api = ApiClient();

  Future<List<MatchCandidate>> getCandidates() async {
    final data = await _api.get('/api/v1/matches') as List;
    return data
        .map((e) => MatchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Record a like/pass on another user. A reciprocated like creates the match
  /// (mutual-like gate) — [SwipeResult.matched] is then true.
  Future<SwipeResult> swipe(String targetUserId, bool liked) async {
    final data =
        await _api.post(
              '/api/v1/swipes',
              body: {'target_id': targetUserId, 'liked': liked},
            )
            as Map<String, dynamic>;
    return SwipeResult.fromJson(data);
  }

  /// Undo the caller's most recent swipe (rewind).
  Future<void> undoSwipe() async {
    await _api.post('/api/v1/swipes/undo');
  }

  Future<List<ApiMatch>> getConversations() async {
    final data = await _api.get('/api/v1/conversations') as List;
    return data
        .map((e) => ApiMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiMessage>> getHistory(String matchId, {int limit = 50}) async {
    final data =
        await _api.get('/api/v1/matches/$matchId/messages?limit=$limit')
            as List;
    return data
        .map((e) => ApiMessage.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList(); // API returns DESC, we want oldest first
  }
}
