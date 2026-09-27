import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

/// Per-user realtime notification socket. Connects to `/ws/notify` (the Go
/// backend's per-user hub; see handlers/push.go) and forwards the payload of
/// every `{"type":"notification","payload":{...}}` frame to [notifications].
///
/// Reconnects with a 2 s backoff doubling up to 60 s after done/error; a
/// received message resets the backoff to 2 s. [close] stops reconnecting.
class NotifySocket {
  static const int _initialDelayMs = 2000;
  static const int _maxDelayMs = 60000;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _reconnect;
  int _delayMs = _initialDelayMs;
  bool _closedByUs = false;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Inbound notification payloads (broadcast — safe to listen once).
  Stream<Map<String, dynamic>> get notifications => _controller.stream;

  /// Opens the socket with the current access token. A no-op (and stops
  /// retrying) when there is no token, i.e. the user is signed out.
  Future<void> connect() async {
    final token = await ApiClient.accessToken();
    if (token == null || _closedByUs) return;
    _connect(token);
  }

  void _connect(String token) {
    _closedByUs = false;
    _sub?.cancel();
    final url = '${ApiClient.notifyWsUrl()}?access_token='
        '${Uri.encodeQueryComponent(token)}';
    _ch = WebSocketChannel.connect(Uri.parse(url));
    _sub = _ch!.stream.listen(
      (raw) {
        _delayMs = _initialDelayMs;
        _parse(raw);
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_closedByUs || _reconnect != null) return;
    _reconnect = Timer(Duration(milliseconds: _delayMs), () {
      _reconnect = null;
      connect();
    });
    _delayMs = (_delayMs * 2).clamp(_initialDelayMs, _maxDelayMs);
  }

  void _parse(dynamic raw) {
    try {
      final env = jsonDecode(raw as String);
      if (env is! Map<String, dynamic> || env['type'] != 'notification') {
        return;
      }
      final payload = env['payload'];
      if (payload is Map<String, dynamic> && !_controller.isClosed) {
        _controller.add(payload);
      }
    } catch (_) {}
  }

  /// Stops reconnecting and closes the channel.
  void close() {
    _closedByUs = true;
    _reconnect?.cancel();
    _reconnect = null;
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    if (!_controller.isClosed) _controller.close();
  }
}
