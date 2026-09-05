import '../../services/match_service.dart';
import 'v2_data.dart';
import 'v2_venue_mapper.dart' show artForCuisine;

/// Maps a real `MatchCandidate` (`GET /api/v1/matches`, a wishlist-overlap
/// ranking — see services/matching.go `ListCandidates`) onto the [Mate] the
/// swipe card renders.
///
/// The design's card also had "urgency" ("Cần ăn trong 1H"), a "dining intent"
/// sentence, and a Trust Score pill — none of which the schema has any concept
/// of, so none of it survives here. What replaces it is exactly what the API
/// actually knows: the candidate's own tags and what food you both share.
Mate mateFromCandidate(MatchCandidate c) => Mate(
      userId: c.userId,
      name: c.name,
      age: c.age,
      img: artForCuisine(c.tags),
      overlapFoods: c.overlapFoods,
      tags: c.tags,
      match: c.matchPct,
    );
