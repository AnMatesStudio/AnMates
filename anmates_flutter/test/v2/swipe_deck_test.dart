import 'package:anmates/views/v2/v2_data.dart';
import 'package:flutter/services.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_match_api.dart';

/// The Quẹt deck through the real V2State/MatchService/ApiClient; only the API
/// server is faked (support/fake_match_api.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<String> names(V2State s) => s.deck.map((m) => m.name).toList();

  group('which deck', () {
    test('real candidates make a real deck', () async {
      serveMatchApi(candidates: [candidate('u1', 'Hạnh'), candidate('u2', 'Khoa')]);
      final s = V2State();

      await s.loadCandidates();

      expect(s.isSampleDeck, isFalse);
      expect(names(s), ['Hạnh', 'Khoa']);
      expect(s.deckPosition, 1);
      expect(s.deckTotal, 2);
    });

    test('no real candidate brings the ten sample profiles', () async {
      serveMatchApi(candidates: const []);
      final s = V2State();

      await s.loadCandidates();

      expect(s.isSampleDeck, isTrue);
      expect(s.sampleBecauseSignedOut, isFalse);
      expect(s.deck, hasLength(10));
      expect(s.deckTotal, 10);
    });

    test('signed out (401) brings the sample profiles too', () async {
      serveMatchApi(listStatus: 401);
      final s = V2State();

      await s.loadCandidates();

      expect(s.isSampleDeck, isTrue);
      expect(s.sampleBecauseSignedOut, isTrue);
      expect(s.candidatesError, isNull);
    });

    test('a server error is an error, not samples', () async {
      serveMatchApi(listStatus: 500);
      final s = V2State();

      await s.loadCandidates();

      expect(s.isSampleDeck, isFalse);
      expect(s.candidatesError, 'HTTP 500');
      expect(s.deck, isEmpty);
    });
  });

  group('sample profiles', () {
    test('are swiped without calling the API', () async {
      final calls = serveMatchApi(candidates: const []);
      final s = V2State();
      await s.loadCandidates();

      await s.skipMate();
      await s.inviteMate();
      await s.inviteMate();

      expect(calls.where((c) => c.contains('/swipes')), isEmpty);
      expect(s.deckPosition, 4);
    });

    test('one that invites back opens the match sheet, marked as a sample', () async {
      serveMatchApi(candidates: const []);
      final s = V2State();
      await s.loadCandidates();
      final first = s.deck.first;
      expect(kSampleInvitesBack, contains(first.userId));

      await s.inviteMate();

      expect(s.matchReveal?.name, first.name);
      expect(s.matchRevealIsSample, isTrue);
    });
  });

  group('sample profiles, after the match sheet', () {
    test('every sample has an illustrated avatar that ships in the bundle', () async {
      for (final m in kSampleMates) {
        final asset = m.avatarAsset;
        expect(asset, isNotNull, reason: m.name);
        expect((await rootBundle.load(asset!)).lengthInBytes, greaterThan(1000), reason: asset);
      }
    });

    test('Nhắn tin opens a local-only chat with the sample: nothing is sent', () async {
      final calls = serveMatchApi(candidates: const []);
      final s = V2State()..go(V2Screen.swipe);
      await s.loadCandidates();
      await s.inviteMate(); // the first sample invites back
      final partner = s.matchReveal!;

      await s.openMatchChat();
      s.sendRealMessage('Tối nay đi lẩu không?');

      expect(s.screen, V2Screen.chat);
      expect(s.isSampleChat, isTrue);
      expect(s.chatPartner.name, partner.name);
      expect(s.messages, [(text: 'Tối nay đi lẩu không?', mine: true)]);
      expect(calls, ['GET /api/v1/matches']);
    });

    test('a real match after a sample chat opens a real chat, not the sample one', () async {
      serveMatchApi(candidates: const []);
      final s = V2State()..go(V2Screen.swipe);
      await s.loadCandidates();
      await s.inviteMate();
      await s.openMatchChat();
      s.sendRealMessage('Chào');

      // Signed in later: a real candidate who invites back.
      serveMatchApi(candidates: [candidate('u1', 'Hạnh')], invitesBack: {'u1'});
      await s.loadCandidates();
      s.go(V2Screen.swipe);
      await s.inviteMate();
      s.dismissMatch(); // "Quẹt tiếp"
      s.go(V2Screen.chat); // then the Tin nhắn tab

      expect(s.chatPartner.name, 'Hạnh');
      expect(s.isSampleChat, isFalse);
      expect(s.messages, isEmpty);
    });
  });

  group('real swipes', () {
    test('a like that is returned shows the match sheet and stays on Quẹt', () async {
      final calls = serveMatchApi(candidates: [candidate('u1', 'Hạnh')], invitesBack: {'u1'});
      final s = V2State()..go(V2Screen.swipe);
      await s.loadCandidates();

      await s.inviteMate();

      expect(calls.last, contains('"target_id":"u1"'));
      expect(s.matchReveal?.name, 'Hạnh');
      expect(s.matchRevealIsSample, isFalse);
      expect(s.screen, V2Screen.swipe);
      expect(s.canUndo, isFalse); // undo would leave the match behind
    });

    test('a like not yet returned says so and can be undone', () async {
      final calls = serveMatchApi(candidates: [candidate('u1', 'Hạnh'), candidate('u2', 'Khoa')]);
      final s = V2State();
      await s.loadCandidates();

      await s.inviteMate();
      expect(s.matchReveal, isNull);
      expect(s.pendingNotice, contains('Hạnh'));
      expect(names(s), ['Khoa']);
      expect(s.canUndo, isTrue);

      await s.undoSwipe();

      expect(calls.last, startsWith('POST /api/v1/swipes/undo'));
      expect(names(s), ['Hạnh', 'Khoa']);
      expect(s.deckPosition, 1);
      expect(s.canUndo, isFalse);
    });

    test('a failed like puts the candidate back on top', () async {
      serveMatchApi(candidates: [candidate('u1', 'Hạnh'), candidate('u2', 'Khoa')], swipeStatus: 500);
      final s = V2State();
      await s.loadCandidates();

      await s.inviteMate();

      expect(names(s), ['Hạnh', 'Khoa']);
      expect(s.pendingNotice, contains('thất bại'));
    });
  });
}
