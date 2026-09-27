import 'api_client.dart';

/// Backend codes for the filter/profile vibe chips, index-aligned with kVibeTags
/// (Ồn vui, Yên tĩnh, Ăn nhanh về, Ngồi lâu, Săn deal).
const List<String> kVibeCodes = ['lively', 'quiet', 'eat_run', 'long_sit', 'deal'];

/// The user's match preferences: vibe chips and optional price tier.
class MatchPrefs {
  final List<String> vibeTags;
  final int? priceTier;

  MatchPrefs({required this.vibeTags, this.priceTier});

  factory MatchPrefs.fromJson(Map<String, dynamic> j) => MatchPrefs(
    vibeTags: ((j['vibe_tags'] as List?) ?? const []).cast<String>().toList(),
    priceTier: (j['price_tier'] as num?)?.toInt(),
  );
}

/// A user's trust score: rating, activity and complaint counts.
class TrustScore {
  final int score;
  final int meals;
  final int goodRatings;
  final int noShowReports;
  final int otherReports;

  TrustScore({
    required this.score,
    required this.meals,
    required this.goodRatings,
    required this.noShowReports,
    required this.otherReports,
  });

  factory TrustScore.fromJson(Map<String, dynamic> j) => TrustScore(
    score: (j['score'] as num?)?.toInt() ?? 0,
    meals: (j['meals'] as num?)?.toInt() ?? 0,
    goodRatings: (j['good_ratings'] as num?)?.toInt() ?? 0,
    noShowReports: (j['no_show_reports'] as num?)?.toInt() ?? 0,
    otherReports: (j['other_reports'] as num?)?.toInt() ?? 0,
  );
}

/// One past meal: where, when, and with whom.
class Visit {
  final String restaurantName;
  final DateTime scheduledAt;
  final String partnerName;

  Visit({
    required this.restaurantName,
    required this.scheduledAt,
    required this.partnerName,
  });

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    restaurantName: j['restaurant_name'] as String? ?? '',
    scheduledAt: DateTime.parse(j['scheduled_at'] as String).toLocal(),
    partnerName: j['partner_name'] as String? ?? '',
  );
}

/// One meal rating the user gave, with the venue it was about.
class Review {
  final int stars;
  final String note;
  final String restaurantName;
  final DateTime createdAt;

  Review({
    required this.stars,
    required this.note,
    required this.restaurantName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    stars: (j['stars'] as num?)?.toInt() ?? 0,
    note: j['note'] as String? ?? '',
    restaurantName: j['restaurant_name'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

/// The Me screen's meal history: past visits and past ratings.
class MealHistory {
  final List<Visit> visits;
  final List<Review> reviews;

  MealHistory({required this.visits, required this.reviews});

  factory MealHistory.fromJson(Map<String, dynamic> j) => MealHistory(
    visits: ((j['visits'] as List?) ?? const [])
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList(),
    reviews: ((j['reviews'] as List?) ?? const [])
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A nearby user suggested as a potential meal partner.
class LocalMate {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? district;
  final int meals;
  final double distanceKm;

  LocalMate({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.district,
    required this.meals,
    required this.distanceKm,
  });

  factory LocalMate.fromJson(Map<String, dynamic> j) => LocalMate(
    userId: j['user_id'] as String,
    name: j['name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    district: j['district'] as String?,
    meals: (j['meals'] as num?)?.toInt() ?? 0,
    distanceKm: (j['distance_km'] as num).toDouble(),
  );
}

/// One push-style notification row for the notifications list.
class AppNotification {
  final String id;
  final String kind;
  final String? matchId;
  final String actorName;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.kind,
    this.matchId,
    required this.actorName,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: j['kind'] as String? ?? '',
    matchId: j['match_id'] as String?,
    actorName: j['actor_name'] as String? ?? '',
    read: j['read'] as bool? ?? false,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

/// One page of notifications plus how many are unread.
class NotificationPage {
  final List<AppNotification> items;
  final int unread;

  NotificationPage({required this.items, required this.unread});

  factory NotificationPage.fromJson(Map<String, dynamic> j) => NotificationPage(
    items: ((j['items'] as List?) ?? const [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(),
    unread: (j['unread'] as num?)?.toInt() ?? 0,
  );
}

/// Icebreaker prompts suggested for a match: bilingual lines and shared topics.
class IcebreakerSet {
  final List<({String vi, String en})> prompts;
  final List<String> shared;

  IcebreakerSet({required this.prompts, required this.shared});

  factory IcebreakerSet.fromJson(Map<String, dynamic> j) => IcebreakerSet(
    prompts: ((j['prompts'] as List?) ?? const [])
        .map((e) {
          final p = e as Map<String, dynamic>;
          return (vi: p['vi'] as String? ?? '', en: p['en'] as String? ?? '');
        })
        .toList(),
    shared: ((j['shared'] as List?) ?? const []).cast<String>().toList(),
  );
}

/// Match preferences, account deletion, trust score, meal history, nearby
/// locals and notifications.
class ExtrasService {
  static final ExtrasService _instance = ExtrasService._();
  ExtrasService._();
  factory ExtrasService() => _instance;

  final _api = ApiClient();

  /// GET /api/v1/profile/match-prefs — the user's current match preferences.
  Future<MatchPrefs> matchPrefs() async {
    final data = await _api.get('/api/v1/profile/match-prefs');
    return MatchPrefs.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /api/v1/profile/match-prefs — save vibe chips and price tier.
  Future<MatchPrefs> setMatchPrefs(List<String> vibeTags, int? priceTier) async {
    final data = await _api.patch(
      '/api/v1/profile/match-prefs',
      body: {'vibe_tags': vibeTags, 'price_tier': priceTier},
    );
    return MatchPrefs.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /api/v1/profile — delete the signed-in user's account.
  Future<void> deleteAccount() async {
    await _api.delete('/api/v1/profile');
  }

  /// GET /api/v1/profile/trust — the user's trust score and its counts.
  Future<TrustScore> trust() async {
    final data = await _api.get('/api/v1/profile/trust');
    return TrustScore.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/v1/profile/history — past meal visits and past ratings.
  Future<MealHistory> history() async {
    final data = await _api.get('/api/v1/profile/history');
    return MealHistory.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/v1/locals — nearby users suggested as meal partners.
  Future<List<LocalMate>> locals() async {
    final data = await _api.get('/api/v1/locals') as List;
    return data
        .map((e) => LocalMate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/v1/matches/:matchId/icebreakers — suggested icebreakers for a match.
  Future<IcebreakerSet> icebreakers(String matchId) async {
    final data = await _api.get('/api/v1/matches/$matchId/icebreakers');
    return IcebreakerSet.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/v1/notifications — notifications with the unread count.
  Future<NotificationPage> notifications() async {
    final data = await _api.get('/api/v1/notifications');
    return NotificationPage.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/v1/notifications/read — mark every notification as read.
  Future<void> markNotificationsRead() async {
    await _api.post('/api/v1/notifications/read');
  }
}
