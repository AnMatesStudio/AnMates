import 'api_client.dart';

/// Reasons the backend accepts for `POST /api/v1/reports`, with their
/// Vietnamese / English labels for the report picker.
const List<(String, String, String)> kReportReasons = [
  ('no_show', 'Không đến buổi hẹn', 'Did not show up'),
  ('harassment', 'Quấy rối', 'Harassment'),
  ('fake_profile', 'Hồ sơ giả', 'Fake profile'),
  ('inappropriate', 'Nội dung không phù hợp', 'Inappropriate content'),
  ('spam', 'Spam / quảng cáo', 'Spam'),
  ('other', 'Lý do khác', 'Other'),
];

/// One member's view of a meal rating: [myStars] and — only once both have
/// rated — [partnerStars]. Stars are 1..5.
class MealRatingView {
  final int? myStars;
  final int? partnerStars;
  final bool bothRated;

  MealRatingView({
    this.myStars,
    this.partnerStars,
    required this.bothRated,
  });

  factory MealRatingView.fromJson(Map<String, dynamic> j) {
    int? starsOf(dynamic v) {
      final m = v as Map<String, dynamic>?;
      return m?['stars'] as int?;
    }

    return MealRatingView(
      myStars: starsOf(j['mine']),
      partnerStars: starsOf(j['partner']),
      bothRated: j['both_rated'] as bool? ?? false,
    );
  }
}

/// Someone the user has blocked, for the Me screen's "Đã chặn" list.
class BlockedUser {
  final String userId;
  final String name;

  BlockedUser({required this.userId, required this.name});

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
    userId: j['user_id'] as String,
    name: j['name'] as String? ?? '',
  );
}

/// Counts shown on the Me screen.
class UserStats {
  final int meals;
  final int matches;

  UserStats({required this.meals, required this.matches});

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
    meals: j['meals'] as int? ?? 0,
    matches: j['matches'] as int? ?? 0,
  );
}

/// Unmatch / block / report, the meal rating and the Me screen's counts.
class SafetyService {
  static final SafetyService _instance = SafetyService._();
  SafetyService._();
  factory SafetyService() => _instance;

  final _api = ApiClient();

  /// DELETE /api/v1/matches/{matchId} — remove the match from both views.
  Future<void> unmatch(String matchId) async {
    await _api.delete('/api/v1/matches/$matchId');
  }

  /// POST /api/v1/blocks — block another user.
  Future<void> block(String userId) async {
    await _api.post('/api/v1/blocks', body: {'user_id': userId});
  }

  /// DELETE /api/v1/blocks/{userId} — unblock another user.
  Future<void> unblock(String userId) async {
    await _api.delete('/api/v1/blocks/$userId');
  }

  /// GET /api/v1/blocks — everyone this user has blocked, newest first.
  Future<List<BlockedUser>> listBlocked() async {
    final data = await _api.get('/api/v1/blocks') as List;
    return data
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/reports — report another user with a reason and optional note.
  Future<void> report(String userId, String reason, {String note = ''}) async {
    await _api.post(
      '/api/v1/reports',
      body: {'user_id': userId, 'reason': reason, 'note': note},
    );
  }

  /// POST /api/v1/matches/{matchId}/rating — rate the meal for this match.
  Future<void> rateMeal(String matchId, int stars, {String note = ''}) async {
    await _api.post(
      '/api/v1/matches/$matchId/rating',
      body: {'stars': stars, 'note': note},
    );
  }

  /// GET /api/v1/matches/{matchId}/rating — my rating and my partner's.
  Future<MealRatingView> mealRating(String matchId) async {
    final data = await _api.get('/api/v1/matches/$matchId/rating');
    return MealRatingView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/v1/profile/stats — the Me screen's meal / match counts.
  Future<UserStats> stats() async {
    final data = await _api.get('/api/v1/profile/stats');
    return UserStats.fromJson(data as Map<String, dynamic>);
  }
}
