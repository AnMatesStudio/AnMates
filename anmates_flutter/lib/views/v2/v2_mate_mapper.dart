import 'package:flutter/widgets.dart';

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
      avatarUrl: c.avatarUrl,
      // The card's art is what you'd eat together, when there is any.
      img: artForCuisine(c.overlapFoods.isNotEmpty ? c.overlapFoods : c.tags),
      overlapFoods: c.overlapFoods,
      tags: c.tags,
      match: c.matchPct,
    );

/// The category keys the API's interests use, in words.
const Map<String, String> _tasteLabels = {
  'lau': 'Lẩu', 'nuong': 'Nướng', 'bbq': 'Nướng BBQ', 'korean': 'Món Hàn',
  'pho': 'Phở', 'bun': 'Bún', 'bun_bo': 'Bún bò', 'bun_cha': 'Bún chả',
  'bun_dau': 'Bún đậu', 'mi': 'Mì', 'ramen': 'Ramen', 'japanese': 'Món Nhật',
  'sushi': 'Sushi', 'com': 'Cơm', 'com_tam': 'Cơm tấm', 'banh_mi': 'Bánh mì',
  'banh_xeo': 'Bánh xèo', 'oc': 'Ốc', 'seafood': 'Hải sản', 'cafe': 'Cà phê',
  'trang_mieng': 'Tráng miệng', 'bia': 'Bia', 'beer': 'Bia', 'vietnamese': 'Món Việt',
  'spicy': 'Ăn cay', 'pizza': 'Pizza', 'italian': 'Món Ý',
};

/// "lau" → "Lẩu". A key the app doesn't know (a free-text dish, a vibe tag)
/// keeps its own words, underscores turned into spaces, first letter raised.
String tasteLabel(String tag) {
  final known = _tasteLabels[tag.trim().toLowerCase()];
  if (known != null) return known;
  final words = tag.replaceAll('_', ' ').trim();
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

/// The 3D render for a food key the app knows; null for anything else, so a
/// vibe tag like "spicy" never gets a burger drawn next to it.
String? tasteArt(String tag) {
  final k = tag.trim().toLowerCase();
  return _tasteLabels.containsKey(k) && k != 'spicy' ? artForCuisine([k]) : null;
}

/// "Nguyễn Minh Khoa" → "NK", "Hạnh" → "H": first and last word.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  if (words.length == 1) return first.toUpperCase();
  return (first + words.last.characters.first).toUpperCase();
}

/// A steady color per user for the initials avatar.
Color avatarColorFor(String userId) {
  const palette = [
    Color(0xFFF97360), Color(0xFF3B82F0), Color(0xFF8B5CF6),
    Color(0xFFE59A12), Color(0xFF10A37F), Color(0xFFE0457B),
  ];
  final hash = userId.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return palette[hash % palette.length];
}
