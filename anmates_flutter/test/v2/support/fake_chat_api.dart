import 'dart:convert';

import 'package:anmates/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const kMe = 'me-1';
const kBotLau = '00000000-0000-0000-0000-0000000000b1';

/// Stands in for the inbox endpoints: `GET /profile` (id [kMe]),
/// `GET /conversations` ([conversations], or [listStatus] when set),
/// `POST /demo/bots` (answers [bots]), `GET /matches/:id/messages`
/// (from [history], newest first like the API), `POST /matches/:id/read` and
/// `GET /matches/:id/booking` (404, no booking). Returns the call log.
List<String> serveChatApi({
  List<Map<String, dynamic>> conversations = const [],
  int? listStatus,
  List<Map<String, dynamic>> bots = const [],
  Map<String, List<Map<String, dynamic>>> history = const {},
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
    final path = req.url.path;
    calls.add('${req.method} $path');
    if (req.method == 'GET' && path == '/api/v1/profile') {
      return listStatus == 401 ? json(null, 401) : json({'id': kMe, 'name': 'Tôi'});
    }
    if (req.method == 'GET' && path == '/api/v1/conversations') {
      return listStatus != null ? json(null, listStatus) : json(conversations);
    }
    if (req.method == 'POST' && path == '/api/v1/demo/bots') return json(bots);
    final m = RegExp(r'^/api/v1/matches/([^/]+)/(messages|read|booking|emoji)$').firstMatch(path);
    if (m != null) {
      if (m.group(2) == 'emoji') calls.add('BODY ${req.body}');
      return switch (m.group(2)) {
        'emoji' => json({
            ...message(m.group(1)!, kMe, jsonDecode(req.body)['emoji'] as String, DateTime.now()),
            'msg_type': 'quick_emoji',
          }),
        'messages' => json([...?history[m.group(1)]].reversed.toList()),
        'read' => json({'read_at': DateTime.now().toUtc().toIso8601String()}),
        _ => json(null, 404),
      };
    }
    return json(null, 404);
  });
  return calls;
}

/// An inbox row as `GET /conversations` returns it.
Map<String, dynamic> conversation(
  String matchId,
  String partnerId,
  String name, {
  bool bot = false,
  String? last,
  String? lastSender,
  DateTime? lastAt,
  int unread = 0,
  DateTime? partnerReadAt,
  String quickEmoji = '👍',
  String? lastType,
}) =>
    {
      'match_id': matchId,
      'partner_id': partnerId,
      'partner_name': name,
      'partner_is_bot': bot,
      'last_message': last,
      'last_message_at': lastAt?.toUtc().toIso8601String(),
      'last_sender_id': lastSender,
      'unread_count': unread,
      'quick_emoji': quickEmoji,
      'last_message_type': lastType,
      'partner_read_at': partnerReadAt?.toUtc().toIso8601String(),
      'score': 0.5,
      'created_at': DateTime.utc(2026, 9, 20).toIso8601String(),
    };

/// A message row, oldest-first order is up to the caller.
Map<String, dynamic> message(String matchId, String sender, String content, DateTime at) => {
      'id': '$matchId-${at.microsecondsSinceEpoch}',
      'match_id': matchId,
      'sender_id': sender,
      'content': content,
      'msg_type': 'text',
      'created_at': at.toUtc().toIso8601String(),
    };
