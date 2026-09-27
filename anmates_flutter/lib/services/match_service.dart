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

  /// The candidate's district (ward/county) — null when unset.
  final String? district;

  /// The candidate's price tier (0..3) — null when unset.
  final int? priceTier;

  /// The candidate's own vibe tags, kept separate from [tags].
  final List<String> vibeTags;

  /// km from the viewer; null when either side has no location.
  final double? distanceKm;

  MatchCandidate({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.age,
    required this.tags,
    required this.overlapCount,
    required this.overlapFoods,
    required this.score,
    this.district,
    this.priceTier,
    this.vibeTags = const [],
    this.distanceKm,
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
    district: j['district'] as String?,
    priceTier: (j['price_tier'] as num?)?.toInt(),
    vibeTags: [...?(j['vibe_tags'] as List?)?.whereType<String>()],
    distanceKm: (j['distance_km'] as num?)?.toDouble(),
  );

  /// Real taste-overlap percentage — how much of the union of both users'
  /// interests is shared. Used as the swipe card's "% hợp gu" figure.
  int get matchPct => (score * 100).round();
}

/// One row of the inbox (`GET /api/v1/conversations`).
class ApiMatch {
  final String id;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final bool partnerIsBot;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String? lastMessageType;

  /// The conversation's quick-reaction emoji, shared by both members.
  final String quickEmoji;

  /// Messages from the partner (or the concierge) you haven't opened yet.
  final int unreadCount;

  /// When the partner last opened the chat — your "Đã xem".
  final DateTime? partnerReadAt;
  final double score;
  final DateTime createdAt;

  ApiMatch({
    required this.id,
    this.partnerId = '',
    required this.partnerName,
    this.partnerAvatarUrl,
    this.partnerIsBot = false,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastMessageType,
    this.quickEmoji = '👍',
    this.unreadCount = 0,
    this.partnerReadAt,
    required this.score,
    required this.createdAt,
  });

  static DateTime? _time(Object? v) => v is String ? DateTime.parse(v) : null;

  factory ApiMatch.fromJson(Map<String, dynamic> j) => ApiMatch(
    id: j['match_id'] as String,
    partnerId: j['partner_id'] as String? ?? '',
    partnerName: j['partner_name'] as String,
    partnerAvatarUrl: j['partner_avatar_url'] as String?,
    partnerIsBot: j['partner_is_bot'] as bool? ?? false,
    lastMessage: j['last_message'] as String?,
    lastMessageAt: _time(j['last_message_at']),
    lastSenderId: j['last_sender_id'] as String?,
    lastMessageType: j['last_message_type'] as String?,
    quickEmoji: j['quick_emoji'] as String? ?? '👍',
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
    partnerReadAt: _time(j['partner_read_at']),
    score: (j['score'] as num).toDouble(),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  /// Newest activity: the last message, or the match itself.
  DateTime get activityAt => lastMessageAt ?? createdAt;
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

  /// Marks the match read up to now; the partner's socket gets the receipt.
  Future<void> markRead(String matchId) async {
    await _api.post('/api/v1/matches/$matchId/read');
  }

  /// Changes the conversation's quick emoji for both members; returns the
  /// transcript line recording the change.
  Future<ApiMessage> setQuickEmoji(String matchId, String emoji) async {
    final data = await _api.put('/api/v1/matches/$matchId/emoji', body: {'emoji': emoji});
    return ApiMessage.fromJson(data as Map<String, dynamic>);
  }

  /// Opens a chat with each demo bot (idempotent) and returns the inbox.
  Future<List<ApiMatch>> startBotChats() async {
    final data = await _api.post('/api/v1/demo/bots') as List;
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
