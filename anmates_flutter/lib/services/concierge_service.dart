import '../models/ai_venue_card.dart';
import 'api_client.dart';

/// Where to center an on-demand venue suggestion.
enum VenueAnchor {
  midpoint, // between the two users (default)
  me, // near the current user (e.g. the mate comes to pick them up)
  mate, // near the other user
}

extension on VenueAnchor {
  String get wire => switch (this) {
    VenueAnchor.midpoint => 'midpoint',
    VenueAnchor.me => 'me',
    VenueAnchor.mate => 'mate',
  };
}

/// Calls the backend AI Concierge to re-suggest venues centered on a chosen anchor.
/// The result is NOT posted to chat — it's a private re-roll for the requester.
class ConciergeService {
  final _api = ApiClient();

  Future<AiVenueCardContent?> suggest(String matchId, VenueAnchor anchor) async {
    final data = await _api.post(
      '/api/v1/matches/$matchId/concierge/suggest',
      body: {'anchor': anchor.wire},
    );
    if (data is Map<String, dynamic>) {
      return AiVenueCardContent.fromJson(data);
    }
    return null;
  }
}
