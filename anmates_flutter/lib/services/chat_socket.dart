import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'match_service.dart';

/// Live chat WebSocket wrapper. Connects to the Go backend hub at
/// `/ws/chat/:matchId`, parses inbound envelopes into [ApiMessage]s (including
/// the AI Concierge's `ai_venue_card`), and sends user messages.
///
/// Wire format (matches handlers/chat.go): each frame is
/// `{"type":"message|typing|read|error","payload":{...}}`. For `message` the
/// payload is the saved message row. The hub excludes the sender from a
/// broadcast, so we only receive the OTHER user's messages + AI cards; our own
/// sends are appended optimistically by the UI.
class ChatSocket {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _controller = StreamController<ApiMessage>.broadcast();
  final _typing = StreamController<String>.broadcast();
  final _reads = StreamController<({String userId, DateTime at})>.broadcast();

  /// Inbound messages (broadcast — safe to listen once).
  Stream<ApiMessage> get messages => _controller.stream;

  /// User ids of the other side as they type (one event per keystroke burst).
  Stream<String> get typing => _typing.stream;

  /// Read receipts: the other side has seen everything up to `at`.
  Stream<({String userId, DateTime at})> get reads => _reads.stream;

  Future<void> connect(String matchId, String token) async {
    final url = '${ApiClient.wsUrl(matchId)}?access_token=$token';
    _ch = WebSocketChannel.connect(Uri.parse(url));
    await _ch!.ready;
    _sub = _ch!.stream.listen(
      (raw) {
        final m = _parse(raw);
        if (m != null && !_controller.isClosed) _controller.add(m);
        _parseEvent(raw);
      },
      onError: (_) {},
      onDone: () {},
      cancelOnError: false,
    );
  }

  void sendText(String content, {String msgType = 'text'}) {
    final sink = _ch?.sink;
    if (sink == null) return;
    sink.add(jsonEncode({
      'type': 'message',
      'payload': {'content': content, 'msg_type': msgType},
    }));
  }

  /// Tells the other side you are typing. Callers throttle it.
  void sendTyping() {
    _ch?.sink.add(jsonEncode({'type': 'typing'}));
  }

  void _parseEvent(dynamic raw) {
    try {
      final env = jsonDecode(raw as String);
      if (env is! Map<String, dynamic>) return;
      final payload = env['payload'];
      if (payload is! Map<String, dynamic>) return;
      final userId = payload['user_id'];
      if (userId is! String) return;
      switch (env['type']) {
        case 'typing':
          if (!_typing.isClosed) _typing.add(userId);
        case 'read':
          final at = DateTime.tryParse(payload['read_at'] as String? ?? '');
          if (at != null && !_reads.isClosed) _reads.add((userId: userId, at: at));
      }
    } catch (_) {}
  }

  ApiMessage? _parse(dynamic raw) {
    try {
      final env = jsonDecode(raw as String);
      if (env is! Map<String, dynamic> || env['type'] != 'message') return null;
      final payload = env['payload'];
      if (payload is! Map<String, dynamic>) return null;
      return ApiMessage.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _ch?.sink.close();
    if (!_controller.isClosed) await _controller.close();
    if (!_typing.isClosed) await _typing.close();
    if (!_reads.isClosed) await _reads.close();
  }
}
