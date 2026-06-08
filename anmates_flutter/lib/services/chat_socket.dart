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

  /// Inbound messages (broadcast — safe to listen once).
  Stream<ApiMessage> get messages => _controller.stream;

  Future<void> connect(String matchId, String token) async {
    final url = '${ApiClient.wsUrl(matchId)}?access_token=$token';
    _ch = WebSocketChannel.connect(Uri.parse(url));
    await _ch!.ready;
    _sub = _ch!.stream.listen(
      (raw) {
        final m = _parse(raw);
        if (m != null && !_controller.isClosed) _controller.add(m);
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
  }
}
