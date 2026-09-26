import 'dart:convert';

import 'package:anmates/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Stands in for the matching endpoints the Quẹt deck calls:
/// `GET /api/v1/matches` (answered with [candidates], or with [listStatus]
/// when that is set), `POST /api/v1/swipes` (matched when the target is in
/// [invitesBack]; [swipeStatus] makes it fail) and `POST /api/v1/swipes/undo`.
/// Returns the log of calls as "METHOD path body".
List<String> serveMatchApi({
  List<Map<String, dynamic>> candidates = const [],
  int? listStatus,
  Set<String> invitesBack = const {},
  int? swipeStatus,
}) {
  final calls = <String>[];
  http.Response json(Object? data, [int status = 200]) => http.Response(
        jsonEncode(status < 300
            ? {'success': true, 'data': data}
            : {'success': false, 'error': {'message': 'HTTP $status'}}),
        status,
        headers: {'content-type': 'application/json'},
      );

  ApiClient().httpClient = MockClient((req) async {
    calls.add('${req.method} ${req.url.path} ${req.body}'.trim());
    switch ((req.method, req.url.path)) {
      case ('GET', '/api/v1/matches'):
        return listStatus != null ? json(null, listStatus) : json(candidates);
      case ('POST', '/api/v1/swipes'):
        if (swipeStatus != null) return json(null, swipeStatus);
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final target = body['target_id'] as String;
        final matched = body['liked'] == true && invitesBack.contains(target);
        return json({
          'matched': matched,
          if (matched) 'match': {'id': 'match-$target'},
        });
      case ('POST', '/api/v1/swipes/undo'):
        return json({'undone': true});
      default:
        return json(null, 404);
    }
  });
  return calls;
}

/// A candidate row as `GET /api/v1/matches` returns it.
Map<String, dynamic> candidate(
  String id,
  String name, {
  int? age,
  List<String> foodTags = const ['spicy'],
  List<String> vibeTags = const ['chill'],
  List<String> overlap = const ['lau', 'oc'],
  double score = 0.8,
}) =>
    {
      'user_id': id,
      'name': name,
      'avatar_url': null,
      'age': age,
      'food_tags': foodTags,
      'vibe_tags': vibeTags,
      'overlap_count': overlap.length,
      'overlap_foods': overlap,
      'score': score,
    };
