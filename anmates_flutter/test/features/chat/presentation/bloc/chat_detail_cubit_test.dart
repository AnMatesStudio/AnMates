import 'dart:async';

import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/chat/domain/entities/chat_message.dart';
import 'package:anmates/features/chat/domain/repositories/chat_repository.dart';
import 'package:anmates/features/chat/presentation/bloc/chat_detail_cubit.dart';
import 'package:anmates/features/chat/presentation/bloc/chat_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

ChatMessage _msg({
  String id = 'm-1',
  String matchId = 'match-1',
  String sender = 'u-2',
  String content = 'hi',
  ChatMessageType type = ChatMessageType.text,
  ChatMessageStatus status = ChatMessageStatus.delivered,
}) {
  return ChatMessage(
    id: id,
    matchId: matchId,
    senderId: sender,
    content: content,
    type: type,
    createdAt: DateTime.utc(2026, 6, 1, 10),
    status: status,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(ChatMessageType.text);
  });

  late MockChatRepository repo;
  late StreamController<ChatMessage> inboundCtrl;
  late ChatDetailCubit cubit;

  setUp(() {
    repo = MockChatRepository();
    inboundCtrl = StreamController<ChatMessage>.broadcast();
    when(
      () => repo.connectToMatch(any()),
    ).thenAnswer((_) => inboundCtrl.stream);
    when(() => repo.disconnect()).thenAnswer((_) async {});
    cubit = ChatDetailCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    await inboundCtrl.close();
  });

  Future<void> drain() async => Future<void>.delayed(Duration.zero);

  group('ChatDetailCubit.start', () {
    test(
      'emits Loading then Loaded with history then connected=true',
      () async {
        when(() => repo.getHistory(matchId: any(named: 'matchId'))).thenAnswer(
          (_) async => Result.success([_msg(id: 'h-1', content: 'old')]),
        );

        final emitted = <ChatDetailState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.start(matchId: 'match-1');
        await drain();
        await sub.cancel();

        expect(emitted, hasLength(3));
        expect(emitted[0], isA<ChatDetailLoading>());
        final loadedNoConn = emitted[1] as ChatDetailLoaded;
        expect(loadedNoConn.messages, hasLength(1));
        expect(loadedNoConn.isConnected, false);
        final loadedConn = emitted[2] as ChatDetailLoaded;
        expect(loadedConn.isConnected, true);
      },
    );

    test('emits Error when history load fails', () async {
      when(
        () => repo.getHistory(matchId: any(named: 'matchId')),
      ).thenAnswer((_) async => Result.failure(const ServerFailure('boom')));

      final emitted = <ChatDetailState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.start(matchId: 'match-1');
      await drain();
      await sub.cancel();

      expect(emitted.last, isA<ChatDetailError>());
    });
  });

  group('ChatDetailCubit.sendMessage', () {
    test(
      'appends optimistic placeholder then marks delivered on success',
      () async {
        when(
          () => repo.getHistory(matchId: any(named: 'matchId')),
        ).thenAnswer((_) async => Result.success(const []));
        when(
          () => repo.sendMessage(
            matchId: any(named: 'matchId'),
            content: any(named: 'content'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => Result.success(_msg(id: 'sent-1')));

        await cubit.start(matchId: 'match-1');

        final emitted = <ChatDetailState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.sendMessage(content: 'hello');
        await drain();
        await sub.cancel();

        // 1) optimistic placeholder with isSending=true
        // 2) isSending cleared after success
        expect(emitted, hasLength(2));
        final s1 = emitted[0] as ChatDetailLoaded;
        expect(s1.messages, hasLength(1));
        expect(s1.messages.first.status, ChatMessageStatus.sending);
        expect(s1.isSending, true);
        expect((emitted[1] as ChatDetailLoaded).isSending, false);
      },
    );

    test('marks placeholder as failed when send fails', () async {
      when(
        () => repo.getHistory(matchId: any(named: 'matchId')),
      ).thenAnswer((_) async => Result.success(const []));
      when(
        () => repo.sendMessage(
          matchId: any(named: 'matchId'),
          content: any(named: 'content'),
          type: any(named: 'type'),
        ),
      ).thenAnswer(
        (_) async => Result.failure(const NetworkFailure(message: 'offline')),
      );

      await cubit.start(matchId: 'match-1');

      await cubit.sendMessage(content: 'hello');
      await drain();

      final s = cubit.state as ChatDetailLoaded;
      expect(s.messages.last.status, ChatMessageStatus.failed);
      expect(s.isSending, false);
    });

    test('ignores empty content', () async {
      when(
        () => repo.getHistory(matchId: any(named: 'matchId')),
      ).thenAnswer((_) async => Result.success(const []));
      await cubit.start(matchId: 'match-1');

      final before = (cubit.state as ChatDetailLoaded).messages.length;
      await cubit.sendMessage(content: '   ');
      await drain();
      final after = (cubit.state as ChatDetailLoaded).messages.length;

      expect(after, before);
      verifyNever(
        () => repo.sendMessage(
          matchId: any(named: 'matchId'),
          content: any(named: 'content'),
          type: any(named: 'type'),
        ),
      );
    });
  });

  group('ChatDetailCubit inbound stream', () {
    test('appends inbound messages from the WS stream', () async {
      when(
        () => repo.getHistory(matchId: any(named: 'matchId')),
      ).thenAnswer((_) async => Result.success(const []));
      await cubit.start(matchId: 'match-1');
      await drain();

      inboundCtrl.add(_msg(id: 'inbound-1', content: 'whoa'));
      await drain();

      final s = cubit.state as ChatDetailLoaded;
      expect(s.messages, hasLength(1));
      expect(s.messages.first.id, 'inbound-1');
    });
  });

  group('ChatDetailCubit.close', () {
    test('disconnects the repository on close', () async {
      when(
        () => repo.getHistory(matchId: any(named: 'matchId')),
      ).thenAnswer((_) async => Result.success(const []));
      await cubit.start(matchId: 'match-1');

      await cubit.close();

      verify(() => repo.disconnect()).called(1);
    });
  });
}
