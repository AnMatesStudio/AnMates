import 'api_client.dart';

/// A First Date booking for a match. [status] ∈ proposed|confirmed|cancelled|completed.
class Booking {
  final String id;
  final String matchId;
  final String proposedBy;
  final String restaurantName;
  final String restaurantAddress;
  final double? lat;
  final double? lng;
  final DateTime scheduledAt;
  final String status;

  Booking({
    required this.id,
    required this.matchId,
    required this.proposedBy,
    required this.restaurantName,
    required this.restaurantAddress,
    this.lat,
    this.lng,
    required this.scheduledAt,
    required this.status,
  });

  bool get isActive => status == 'proposed' || status == 'confirmed';

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'] as String,
    matchId: j['match_id'] as String,
    proposedBy: j['proposed_by'] as String,
    restaurantName: j['restaurant_name'] as String? ?? '',
    restaurantAddress: j['restaurant_address'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    scheduledAt: DateTime.parse(j['scheduled_at'] as String).toLocal(),
    status: j['status'] as String? ?? 'proposed',
  );
}

/// Meal arrival status for each side of a match's booking. [mine]/[partner] ∈
/// on_my_way|running_late_10|running_late_20|arrived, or null if not set.
class MealStatusView {
  final String? mine;
  final String? partner;

  MealStatusView({this.mine, this.partner});

  factory MealStatusView.fromJson(Map<String, dynamic> j) => MealStatusView(
    mine: j['mine'] as String?,
    partner: j['partner'] as String?,
  );
}

/// First Date booking API: one member proposes a venue + time, the other confirms.
class BookingService {
  final _api = ApiClient();

  Future<Booking> propose(
    String matchId, {
    required String restaurantName,
    String restaurantAddress = '',
    double? lat,
    double? lng,
    required DateTime scheduledAt,
  }) async {
    final data = await _api.post('/api/v1/matches/$matchId/booking', body: {
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress,
      'lat': ?lat,
      'lng': ?lng,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  /// Current booking for the match, or null if none exists yet (404).
  Future<Booking?> current(String matchId) async {
    try {
      final data = await _api.get('/api/v1/matches/$matchId/booking');
      return data is Map<String, dynamic> ? Booking.fromJson(data) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Booking> confirm(String matchId) async =>
      Booking.fromJson(await _api.post('/api/v1/matches/$matchId/booking/confirm') as Map<String, dynamic>);

  Future<Booking> cancel(String matchId) async =>
      Booking.fromJson(await _api.post('/api/v1/matches/$matchId/booking/cancel') as Map<String, dynamic>);

  /// GET /api/v1/matches/:matchId/booking/status — meal arrival status of each side.
  Future<MealStatusView> mealStatus(String matchId) async {
    final data = await _api.get('/api/v1/matches/$matchId/booking/status');
    return MealStatusView.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/v1/matches/:matchId/booking/status — set my meal arrival status.
  /// [status] ∈ on_my_way|running_late_10|running_late_20|arrived.
  /// ApiException propagates (409 = not now).
  Future<MealStatusView> setMealStatus(String matchId, String status) async {
    final data = await _api.post(
      '/api/v1/matches/$matchId/booking/status',
      body: {'status': status},
    );
    return MealStatusView.fromJson(data as Map<String, dynamic>);
  }
}
