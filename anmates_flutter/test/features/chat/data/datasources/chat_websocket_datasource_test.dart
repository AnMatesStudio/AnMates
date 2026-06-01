import 'dart:async';
import 'dart:convert';

import 'package:anmates/core/storage/secure_storage_service.dart';
import 'package:anmates/features/chat/data/datasources/chat_websocket_datasource.dart';
import 'package:anmates/features/chat/domain/entities/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

/// A minimal WebSocketChannel fake. Uses StreamChannelMixin so we don't
/// have to implement every transform/pipe method ourselves.
class FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final _inbound = StreamController<dynamic>.broadcast();
  final _outbound = StreamController<dynamic>.broadcast();

  /// Allow test to simulate the server pushing a message.
  void pushInbound(String json) => _inbound.add(json);

  /// Test inspector: read what the client sent.
  Stream<dynamic> get sentMessages => _outbound.stream;

  @override
  Stream<dynamic> get stream => _inbound.stream;

  @override
  WebSocketSink get sink => _FakeSink(_outbound, _inbound);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;
}

class _FakeSink implements WebSocketSink {
  final StreamController<dynamic> _outbound;
  final StreamController<dynamic> _inbound;
  _FakeSink(this._outbound, this._inbound);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    // Closing the sink also closes the inbound stream — that's how a real
    // WS channel signals "stream done" to listeners.
    await _outbound.close();
    if (!_inbound.isClosed) await _inbound.close();
  }

  @override
  void add(dynamic data) => _outbound.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _outbound.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) => _outbound.addStream(stream);

  @override
  Future<void> get done => _outbound.done;
}

void main() {
  group('ChatWebSocketDataSource', () {
    late MockSecureStorage storage;
    late FakeWebSocketChannel fakeChannel;
    late ChatWebSocketDataSource ds;

    setUp(() {
      storage = MockSecureStorage();
      when(() => storage.accessToken).thenAnswer((_) async => 'jwt-token');
      fakeChannel = FakeWebSocketChannel();
      ds = ChatWebSocketDataSource(
        storage: storage,
        channelFactory: (_) => fakeChannel,
      );
    });

    tearDown(() async => ds.dispose());

    test('connect emits parsed ChatMessages from inbound JSON', () async {
      final stream = ds.connect('match-1');

      // Let the connect future resolve.
      await Future<void>.delayed(Duration.zero);

      fakeChannel.pushInbound(
        jsonEncode({
          'id': 'm-1',
          'match_id': 'match-1',
          'sender_id': 'u-2',
          'content': 'hello',
          'msg_type': 'text',
          'created_at': '2026-06-01T10:00:00Z',
        }),
      );

      final msg = await stream.first;
      expect(msg.id, 'm-1');
      expect(msg.content, 'hello');
      expect(msg.type, ChatMessageType.text);
    });

    test('ignores malformed payloads without killing the stream', () async {
      final stream = ds.connect('match-1');
      final received = <ChatMessage>[];
      final sub = stream.listen(received.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);

      fakeChannel.pushInbound('not-json');
      fakeChannel.pushInbound(
        jsonEncode({
          'id': 'm-good',
          'match_id': 'match-1',
          'sender_id': 'u-2',
          'content': 'ok',
          'msg_type': 'text',
          'created_at': '2026-06-01T10:00:00Z',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received, hasLength(1));
      expect(received.first.id, 'm-good');
    });

    test('connect with same matchId does not open a second channel', () async {
      var factoryCalls = 0;
      final reuseChannel = FakeWebSocketChannel();
      final ds2 = ChatWebSocketDataSource(
        storage: storage,
        channelFactory: (_) {
          factoryCalls++;
          return reuseChannel;
        },
      );
      addTearDown(ds2.dispose);

      ds2.connect('match-1');
      // Let the openChannel future resolve.
      await Future<void>.delayed(Duration.zero);
      ds2.connect('match-1');
      await Future<void>.delayed(Duration.zero);

      expect(factoryCalls, 1);
    });

    test('sendRaw writes JSON payload to the WS sink', () async {
      ds.connect('match-1');
      await Future<void>.delayed(Duration.zero);

      final sentFuture = fakeChannel.sentMessages.first;

      await ds.sendRaw(
        matchId: 'match-1',
        content: 'hi',
        type: ChatMessageType.text,
      );

      final sent = await sentFuture as String;
      final decoded = jsonDecode(sent) as Map<String, dynamic>;
      expect(decoded['content'], 'hi');
      expect(decoded['type'], 'text');
    });

    test('sendRaw without an open connection throws NetworkFailure', () async {
      expect(
        () => ds.sendRaw(
          matchId: 'match-1',
          content: 'hi',
          type: ChatMessageType.text,
        ),
        throwsA(isA<Object>()),
      );
    });

    test('dispose makes the datasource unusable', () async {
      await ds.dispose();
      expect(() => ds.connect('match-1'), throwsA(isA<Object>()));
    });
  });
}
