import 'package:flutter_test/flutter_test.dart';

import 'package:anmates/services/match_service.dart';
import 'package:anmates/views/v2/v2_mate_mapper.dart';

/// A real row shape from `GET /api/v1/matches` (services/matching.go
/// ListCandidates — age/food_tags/vibe_tags added alongside the photo work).
Map<String, dynamic> _row({
  String name = 'Hạnh',
  int? age = 26,
  List<String> foodTags = const ['spicy'],
  List<String> vibeTags = const ['loud'],
  List<String> overlapFoods = const ['lau', 'bun_bo'],
  int overlapCount = 2,
  double score = 0.92,
}) => {
      'user_id': '9c3f2b1a-1111-4a2b-9c3d-1234567890ab',
      'name': name,
      'avatar_url': null,
      'age': ?age,
      'food_tags': foodTags,
      'vibe_tags': vibeTags,
      'overlap_count': overlapCount,
      'overlap_foods': overlapFoods,
      'score': score,
    };

void main() {
  group('MatchCandidate.fromJson', () {
    test('parses a full row', () {
      final c = MatchCandidate.fromJson(_row());
      expect(c.name, 'Hạnh');
      expect(c.age, 26);
      expect(c.tags, ['spicy', 'loud']);
      expect(c.overlapFoods, ['lau', 'bun_bo']);
      expect(c.overlapCount, 2);
    });

    test('age is null rather than guessed when birth_date was never set', () {
      final c = MatchCandidate.fromJson(_row(age: null));
      expect(c.age, isNull);
    });

    test('matchPct is the real overlap score, not a fabricated rating', () {
      expect(MatchCandidate.fromJson(_row(score: 0.92)).matchPct, 92);
      expect(MatchCandidate.fromJson(_row(score: 0.5)).matchPct, 50);
    });
  });

  group('mateFromCandidate', () {
    test('carries real fields onto the swipe card, dropping fabricated ones', () {
      final mate = mateFromCandidate(MatchCandidate.fromJson(_row()));
      expect(mate.name, 'Hạnh');
      expect(mate.age, 26);
      expect(mate.tags, ['spicy', 'loud']);
      expect(mate.overlapFoods, ['lau', 'bun_bo']);
      expect(mate.match, 92);
    });

    test('a candidate with no birth_date shows no age, never a guess', () {
      final mate = mateFromCandidate(MatchCandidate.fromJson(_row(age: null)));
      expect(mate.age, isNull);
    });

    test('no shared foods is an empty list, not an invented sentence', () {
      final mate = mateFromCandidate(MatchCandidate.fromJson(_row(overlapFoods: const [])));
      expect(mate.overlapFoods, isEmpty);
    });
  });
}
