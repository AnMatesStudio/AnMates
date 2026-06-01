import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/chat_message.dart';

/// Builds the wss:// URL from the configured HTTP base.
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.anmates.app
const _httpBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app',
);

/// Real-time chat datasource over WebSocket.
///
/// Lifecycle invariants:
///   - At most ONE WebSocketChannel is open at a time per instance.
///   - The inbound stream is multicast (`asBroadcastStream`) so multiple
///     listeners (the cubit + a potential read-receipt watcher) can subscribe.
///   - `disconnect()` is idempotent and cancels both the underlying
///     subscription and closes the channel sink with code 1000 (Normal).
///   - Reconnect uses exponential backoff (1s, 2s, 4s, 8s) capped at 4 retries.
///
/// Why a separate datasource (not in the repository)?
/// - Decouples WS plumbing from JSON parsing and Failure mapping.
/// - Makes it trivial to mock for cubit tests — inject a fake datasource.
class ChatWebSocketDataSource {
  final SecureStorageService _storage;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamController<ChatMessage>? _outboundController;
  String? _currentMatchId;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  ChatWebSocketDataSource({
    required SecureStorageService storage,
    WebSocketChannel Function(Uri)? channelFactory,
  }) : _storage = storage,
       _channelFactory = channelFactory ?? WebSocketChannel.connect;

  /// Maximum reconnect attempts before giving up.
  static const _maxReconnects = 4;

  /// Open a stream of inbound messages for [matchId].
  /// If another connection is open it's closed first.
  Stream<ChatMessage> connect(String matchId) {
    if (_disposed) {
      throw const AuthFailure(
        message: 'Cannot reuse a disposed ChatWebSocketDataSource',
      );
    }

    // Idempotent: same match already connected -> return existing stream.
    if (_currentMatchId == matchId && _outboundController != null) {
      return _outboundController!.stream;
    }

    // Switching matches — clean up the previous connection first.
    _teardown();

    _currentMatchId = matchId;
    _outboundController = StreamController<ChatMessage>.broadcast();
    _reconnectAttempts = 0;
    unawaited(_openChannel(matchId));

    return _outboundController!.stream;
  }

  Future<void> _openChannel(String matchId) async {
    try {
      final token = await _storage.accessToken;
      final wsUrl = _buildWsUrl(matchId, token);
      _channel = _channelFactory(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (Object error) => _onError(error, matchId),
        onDone: () => _onDone(matchId),
        cancelOnError: false,
      );

      // Reset backoff counter on successful open.
      _reconnectAttempts = 0;
      if (kDebugMode) {
        debugPrint('ChatWS: connected to $matchId');
      }
    } catch (e) {
      _onError(e, matchId);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final message = _messageFromJson(json);
      _outboundController?.add(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ChatWS: ignoring malformed message: $e');
      }
      // Don't crash the stream on bad payloads — log and skip.
    }
  }

  void _onError(Object error, String matchId) {
    if (kDebugMode) {
      debugPrint('ChatWS: error on $matchId: $error');
    }
    _scheduleReconnect(matchId);
  }

  void _onDone(String matchId) {
    if (kDebugMode) {
      debugPrint('ChatWS: stream closed for $matchId');
    }
    // Distinguish intentional disconnect from server-side close: if the
    // controller is still open and matchId still current, attempt reconnect.
    if (_currentMatchId == matchId && _outboundController?.isClosed == false) {
      _scheduleReconnect(matchId);
    }
  }

  void _scheduleReconnect(String matchId) {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnects) {
      _outboundController?.addError(
        const NetworkFailure(message: 'WS reconnect budget exhausted'),
      );
      return;
    }
    final delaySeconds = 1 << _reconnectAttempts; // 1, 2, 4, 8
    _reconnectAttempts++;
    Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed && _currentMatchId == matchId) {
        unawaited(_openChannel(matchId));
      }
    });
  }

  /// Send a message over the open channel. Caller must ensure [connect] has
  /// returned a stream first.
  Future<void> sendRaw({
    required String matchId,
    required String content,
    required ChatMessageType type,
  }) async {
    if (_channel == null || _currentMatchId != matchId) {
      throw const NetworkFailure(message: 'WS not connected to this match');
    }
    final payload = jsonEncode({'content': content, 'type': _typeToWire(type)});
    _channel!.sink.add(payload);
  }

  /// Disconnect cleanly. Safe to call multiple times.
  Future<void> disconnect() async {
    _teardown();
  }

  /// Fully release resources — call from the cubit's `close()`.
  /// After this the instance cannot be reused.
  Future<void> dispose() async {
    _disposed = true;
    _teardown();
  }

  void _teardown() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close(1000, 'normal close');
    _channel = null;
    _outboundController?.close();
    _outboundController = null;
    _currentMatchId = null;
    _reconnectAttempts = 0;
  }

  Uri _buildWsUrl(String matchId, String? token) {
    final wsBase = _httpBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final tokenPart = token != null ? '?token=$token' : '';
    return Uri.parse('$wsBase/ws/chat/$matchId$tokenPart');
  }

  ChatMessage _messageFromJson(Map<String, dynamic> j) {
    return ChatMessage(
      id: j['id'] as String,
      matchId: j['match_id'] as String,
      senderId: j['sender_id'] as String,
      content: (j['content'] as String?) ?? '',
      type: _typeFromWire(j['msg_type'] as String? ?? 'text'),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  ChatMessageType _typeFromWire(String s) {
    switch (s) {
      case 'view_once':
        return ChatMessageType.viewOnce;
      case 'system':
        return ChatMessageType.system;
      case 'text':
      default:
        return ChatMessageType.text;
    }
  }

  String _typeToWire(ChatMessageType t) {
    switch (t) {
      case ChatMessageType.text:
        return 'text';
      case ChatMessageType.viewOnce:
        return 'view_once';
      case ChatMessageType.system:
        return 'system';
    }
  }
}
