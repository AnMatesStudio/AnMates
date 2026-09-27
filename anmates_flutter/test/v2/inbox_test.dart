import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_chat_format.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_chat_api.dart';

/// Tin nhắn: the inbox and the Messenger-style chat, through the real shell;
/// only the API server is faked (no token, so no live socket).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<V2State> pumpApp(WidgetTester tester, {V2Screen start = V2Screen.home}) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = V2State()..go(start);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<V2State>.value(value: s, child: const V2AppBody()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return s;
  }

  Future<void> openInbox(WidgetTester tester) async {
    await tester.tap(find.text('Tin nhắn').last); // the nav tab
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final now = DateTime.now();

  testWidgets('the Tin nhắn tab opens the inbox, not an empty "–" chat', (tester) async {
    final calls = serveChatApi();
    final s = await pumpApp(tester);
    await openInbox(tester);

    expect(s.screen, V2Screen.inbox);
    expect(calls, contains('GET /api/v1/conversations'));
    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);
    expect(find.text('Chat thử với bot demo'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('the empty inbox starts the demo bots, which then show as active', (tester) async {
    final calls = serveChatApi(bots: [
      conversation('m-b1', kBotLau, 'Bot Minh Anh',
          bot: true, last: 'Hí, mình là Minh Anh', lastSender: kBotLau, lastAt: now, unread: 1),
    ]);
    await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();

    await tester.tap(find.text('Chat thử với bot demo'));
    await tester.pump();
    await tester.pump();

    expect(calls, contains('POST /api/v1/demo/bots'));
    expect(find.text('Bot Minh Anh'), findsOneWidget);
    expect(find.text('BOT'), findsOneWidget);
    expect(find.text('Minh Anh'), findsOneWidget); // the active strip's first-name label
    expect(find.byKey(const Key('inbox-unread-m-b1')), findsOneWidget);
  });

  testWidgets('a row says "Bạn:" for your own last line and shows who has read it', (tester) async {
    serveChatApi(conversations: [
      conversation('m1', 'u1', 'Hạnh',
          last: 'Tối nay nha', lastSender: kMe, lastAt: now,
          partnerReadAt: now.add(const Duration(seconds: 5))),
      conversation('m2', 'u2', 'Khoa',
          last: 'Ok luôn', lastSender: 'u2', lastAt: now.subtract(const Duration(minutes: 1))),
    ]);
    await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();

    expect(find.text('Bạn: Tối nay nha'), findsOneWidget);
    expect(find.byKey(const Key('inbox-seen-m1')), findsOneWidget);
    expect(find.text('Ok luôn'), findsOneWidget);
    expect(find.byKey(const Key('inbox-seen-m2')), findsNothing);
    expect(find.byKey(const Key('inbox-unread-m2')), findsNothing);

    await tester.enterText(find.byKey(const Key('inbox-search')), 'kho');
    await tester.pump();
    expect(find.text('Khoa'), findsOneWidget);
    expect(find.text('Hạnh'), findsNothing);
  });

  testWidgets('signed out, the inbox asks you to sign in', (tester) async {
    serveChatApi(listStatus: 401);
    await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();
    expect(find.text('Đăng nhập để nhắn tin'), findsOneWidget);
  });

  testWidgets('opening a row: history, read receipt, "Đã xem", back to the inbox', (tester) async {
    final t0 = now.subtract(const Duration(hours: 2));
    final calls = serveChatApi(
      conversations: [
        conversation('m1', 'u1', 'Hạnh',
            last: 'Chốt 7h', lastSender: kMe, lastAt: t0.add(const Duration(hours: 1)),
            partnerReadAt: t0.add(const Duration(hours: 1, minutes: 1))),
      ],
      history: {
        'm1': [
          message('m1', 'u1', 'Tối nay đi lẩu không?', t0),
          message('m1', 'u1', 'Quán gần Q1 nha', t0.add(const Duration(seconds: 30))),
          message('m1', kMe, 'Chốt 7h', t0.add(const Duration(hours: 1))),
        ],
      },
    );
    final s = await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();

    await tester.tap(find.byKey(const Key('inbox-row-m1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(s.screen, V2Screen.chat);
    expect(calls, containsAll(['GET /api/v1/matches/m1/messages', 'POST /api/v1/matches/m1/read']));
    expect(find.text('Tối nay đi lẩu không?'), findsOneWidget);
    expect(find.text('Chốt 7h'), findsOneWidget);
    // An hour apart: two time separators, one per burst.
    expect(find.text(separatorTime(t0, en: false)), findsOneWidget);
    expect(find.text(separatorTime(t0.add(const Duration(hours: 1)), en: false)), findsOneWidget);
    expect(find.byKey(const Key('chat-status-seen')), findsOneWidget);
    expect(find.byKey(const Key('chat-online-dot')), findsNothing); // not a bot: presence unknown

    await tester.tap(find.text('‹'));
    await tester.pump();
    expect(s.screen, V2Screen.inbox);
  });

  testWidgets('your newest message reads "Đã gửi" until the partner opens it', (tester) async {
    final t0 = now.subtract(const Duration(minutes: 10));
    serveChatApi(
      conversations: [
        conversation('m1', kBotLau, 'Bot Minh Anh', bot: true, last: 'Alo', lastSender: kMe, lastAt: t0),
      ],
      history: {'m1': [message('m1', kMe, 'Alo', t0)]},
    );
    final s = await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-row-m1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('chat-status-sent')), findsOneWidget);
    expect(s.chatSub, 'Bot demo · Đang hoạt động');
    expect(find.byKey(const Key('chat-online-dot')), findsOneWidget);
  });

  testWidgets('the empty composer offers a one-tap 👍 that sends', (tester) async {
    serveChatApi(
      conversations: [conversation('m1', 'u1', 'Hạnh')],
      history: {'m1': []},
    );
    final s = await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-row-m1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('chat-like')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    expect(find.byKey(const Key('chat-send')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-like')));
    await tester.pump();
    expect(s.messages.last, (text: '👍', mine: true));
  });

  testWidgets("the like button is the chat's own emoji, and changing it is shared", (tester) async {
    final calls = serveChatApi(
      conversations: [conversation('m1', 'u1', 'Hạnh', quickEmoji: '🍜')],
      history: {'m1': []},
    );
    final s = await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-row-m1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(s.quickEmoji, '🍜');
    expect(find.descendant(of: find.byKey(const Key('chat-like')), matching: find.text('🍜')), findsOneWidget);

    await tester.longPress(find.byKey(const Key('chat-like')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emoji-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('emoji-🔥')));
    await tester.pumpAndSettle();

    expect(calls, containsAll(['PUT /api/v1/matches/m1/emoji', 'BODY {"emoji":"🔥"}']));
    expect(s.quickEmoji, '🔥');
    expect(find.text('Bạn đã đổi biểu tượng cảm xúc thành 🔥'), findsOneWidget);
    expect(find.byKey(const Key('chat-status-sent')), findsNothing); // a notice, not a message

    await tester.tap(find.byKey(const Key('chat-like')));
    await tester.pump();
    expect(s.messages.last, (text: '🔥', mine: true));
  });

  testWidgets("the inbox tells who changed the emoji", (tester) async {
    serveChatApi(conversations: [
      conversation('m1', 'u1', 'Hạnh', last: '❤️', lastSender: 'u1', lastType: 'quick_emoji', lastAt: now),
    ]);
    await pumpApp(tester, start: V2Screen.inbox);
    await tester.pump();
    expect(find.text('Hạnh đã đổi biểu tượng thành ❤️'), findsOneWidget);
  });

  group('time labels', () {
    final n = DateTime(2026, 9, 27, 18, 0); // a Sunday
    test('inbox: time today, weekday this week, date before', () {
      expect(inboxTime(DateTime(2026, 9, 27, 9, 5), en: false, now: n), '09:05');
      expect(inboxTime(DateTime(2026, 9, 25, 9, 5), en: false, now: n), 'T6');
      expect(inboxTime(DateTime(2026, 9, 25, 9, 5), en: true, now: n), 'Fri');
      expect(inboxTime(DateTime(2026, 9, 12, 9, 5), en: false, now: n), '12/09');
    });
    test('separator carries the time on older days too', () {
      expect(separatorTime(DateTime(2026, 9, 26, 19, 30), en: false, now: n), 'T7 19:30');
      expect(separatorTime(DateTime(2026, 8, 1, 7, 0), en: false, now: n), '01/08 07:00');
    });
    test('only short emoji-only lines go big', () {
      expect(isBigEmoji('👍'), isTrue);
      expect(isBigEmoji('😂😂'), isTrue);
      expect(isBigEmoji('❤️'), isTrue);
      expect(isBigEmoji('ok 👍'), isFalse);
      expect(isBigEmoji('😂😂😂😂'), isFalse);
    });
  });
}
